import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// A non-activating overlay panel that normally only covers the notch hit area.
/// When expanded, the panel animates its frame downward from the notch.
final class NotchOverlayWindow: NSPanel {
    static let shared = NotchOverlayWindow()

    private init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isFloatingPanel = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Keep the overlay aligned with the notch even when the menu bar is present.
        // `statusBar` can end up visually below the menu bar; `mainMenu` ensures it sits at the top.
        level = .popUpMenu

        acceptsMouseMovedEvents = true
        ignoresMouseEvents = false

        let trackingHost = NotchTrackingHostView(rootView: NotchShelfView())
        trackingHost.wantsLayer = true
        trackingHost.layer?.backgroundColor = NSColor.clear.cgColor
        contentView = trackingHost
    }

    func setup() {
        updateFrame(animated: false)
        orderFrontRegardless()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: .notchGeometryDidChange,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(expandedStateChanged),
            name: .notchStateDidChange,
            object: nil
        )
    }

    @objc private func screenParametersChanged() {
        updateFrame(animated: false)
    }

    @objc private func expandedStateChanged() {
        updateFrame(animated: true)
    }

    private func updateFrame(animated: Bool) {
        let notch = NotchDetectionManager.shared
        let settings = SettingsManager.shared

        // Determine which screen to use.
        // If "Simulate Notch" is on, prefer the main screen (which might be external).
        // Otherwise, prefer the screen with the actual notch.
        let screen: NSScreen? = {
            if settings.useSimulatedNotch {
                return NSScreen.main
            }
            
            if let screenNumber = notch.notchScreenNumber {
                return NSScreen.screens.first(where: {
                    ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber) == screenNumber
                })
            }
            return NSScreen.main
        }()

        guard let screen else { return }

        // If we are simulating, we always "have a notch" effectively.
        // If not simulating, we need an actual detected notch.
        if !settings.useSimulatedNotch && !notch.hasNotch {
            orderOut(nil)
            return
        }

        // If we were previously ordered out (e.g. app launched before notch detection finished),
        // bring the overlay back as soon as we have geometry to anchor to.
        if !isVisible {
            orderFrontRegardless()
        }

        let isExpanded = NotchState.shared.isExpanded

        // If simulating on a screen without a real notch, make up some dimensions.
        let effectiveNotchWidth: CGFloat
        let effectiveNotchHeight: CGFloat
        let effectiveNotchRect: CGRect
        
        if settings.useSimulatedNotch && (screen != NSScreen.screens.first(where: { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber) == notch.notchScreenNumber })) {
            // Simulating on a non-notched screen (e.g. external monitor)
            effectiveNotchWidth = 180
            effectiveNotchHeight = max(screen.safeAreaInsets.top, 32) // Default menu bar height approx
            let x = screen.frame.midX - (effectiveNotchWidth / 2)
            let y = screen.frame.maxY - effectiveNotchHeight
            effectiveNotchRect = CGRect(x: x, y: y, width: effectiveNotchWidth, height: effectiveNotchHeight)
        } else {
            // Use actual notch
            effectiveNotchWidth = max(1, notch.notchRect.width)
            effectiveNotchHeight = max(1, notch.safeAreaTop)
            effectiveNotchRect = notch.notchRect
        }

        let expandedWidth = CGFloat(settings.windowWidth)
        let expandedHeight = CGFloat(settings.windowHeight)
        let verticalOffset = CGFloat(settings.verticalOffset)
        let horizontalOffset = CGFloat(settings.horizontalOffset)

        let width = isExpanded ? expandedWidth : effectiveNotchWidth
        // Give the collapsed panel a slightly larger transparent hit area so Finder drags
        // can reliably enter and expand the overlay.
        let collapsedHitHeight: CGFloat = max(effectiveNotchHeight, 72)
        // `NotchShelfView` includes a notch-height strip at the top of the layout.
        // The window must include that strip or the UI will be clipped and look misaligned.
        let height = isExpanded ? (effectiveNotchHeight + expandedHeight) : collapsedHitHeight

        // `notchRect` is stored in global screen coordinates.
        let notchCenterX = effectiveNotchRect.midX
        let x = notchCenterX - (width / 2) + horizontalOffset
        let y = screen.frame.maxY - height - verticalOffset

        let newFrame = CGRect(x: x, y: y, width: width, height: height)
        
        #if DEBUG
        print("Notch Buddy: screen=\(screen.localizedName) frame=\(newFrame) notch=\(effectiveNotchRect)")
        #endif

        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.22
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animator().setFrame(newFrame, display: true)
            }
        } else {
            setFrame(newFrame, display: true)
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Hosts SwiftUI while providing a reliable AppKit tracking area for mouse enter/exit.
/// This avoids flaky `.onHover` behavior with transparent SwiftUI layers.
final class NotchTrackingHostView<Content: View>: NSView {
    private let hostingView: NSHostingView<Content>
    private var trackingAreaRef: NSTrackingArea?
    private var pendingCollapse: DispatchWorkItem?

    // Small hysteresis to prevent rapid enter/exit toggling when the panel resizes.
    private let collapseDelay: TimeInterval = 0.18

    init(rootView: Content) {
        self.hostingView = NSHostingView(rootView: rootView)
        super.init(frame: .zero)

        registerForDraggedTypes([
            .fileURL,
            .URL,
            .string,
            .tiff
        ])

        addSubview(hostingView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Ensure we catch mouse events even if the SwiftUI content is transparent
        let view = super.hitTest(point)
        return view ?? self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }

        let options: NSTrackingArea.Options = [
            .activeAlways,
            .inVisibleRect,
            .mouseEnteredAndExited
        ]
        let area = NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingAreaRef = area
    }

    override func mouseEntered(with event: NSEvent) {
        #if DEBUG
        print("Notch Buddy: mouse entered")
        #endif
        super.mouseEntered(with: event)
        pendingCollapse?.cancel()
        pendingCollapse = nil
        Task { @MainActor in
            NotchState.shared.isExpanded = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        #if DEBUG
        print("Notch Buddy: mouse exited")
        #endif
        super.mouseExited(with: event)

        // If the user pinned the overlay open, don't auto-collapse.
        if NotchState.shared.isPinned {
            return
        }

        // Don't immediately collapse; resizing/relayout can produce transient exit events.
        pendingCollapse?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            // Double-check actual mouse position relative to this window.
            if self.isMouseActuallyInsideWindowContent() {
                return
            }
            Task { @MainActor in
                NotchState.shared.isExpanded = false
            }
        }
        pendingCollapse = work
        DispatchQueue.main.asyncAfter(deadline: .now() + collapseDelay, execute: work)
    }

    private func isMouseActuallyInsideWindowContent() -> Bool {
        guard let window else { return false }

        // Global mouse location is in screen coordinates.
        let mouseScreen = NSEvent.mouseLocation
        let mouseWindow = window.convertPoint(fromScreen: mouseScreen)

        // Use a small inset to reduce jitter at the exact edge.
        let boundsInset = bounds.insetBy(dx: 2, dy: 2)
        return boundsInset.contains(convert(mouseWindow, from: nil))
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        Task { @MainActor in
            NotchState.shared.isExpanded = true
            NotchState.shared.isDraggingOver = true
            NotchState.shared.activeDropZone = dropZone(for: sender)
        }
        return validateDrag(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        Task { @MainActor in
            NotchState.shared.isDraggingOver = true
            NotchState.shared.activeDropZone = dropZone(for: sender)
        }
        return validateDrag(sender)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        Task { @MainActor in
            NotchState.shared.isDraggingOver = false
            NotchState.shared.activeDropZone = nil
        }
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        let urls = (pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL]) ?? []

        guard !urls.isEmpty else { return false }

        let zone = dropZone(for: sender)
        if zone == .airdrop {
            Task { _ = await DropManager.shared.handleAirDrop(urls: urls) }
        } else {
            Task { _ = await DropManager.shared.handleDroppedFiles(urls: urls) }
        }

        Task { @MainActor in
            NotchState.shared.isDraggingOver = false
            NotchState.shared.activeDropZone = nil
        }

        return true
    }

    private func validateDrag(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard
        let urls = (pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL]) ?? []

        return urls.isEmpty ? [] : .copy
    }

    private func dropZone(for sender: NSDraggingInfo) -> NotchBuddyDropZone {
        let windowPoint = sender.draggingLocation
        let localPoint = convert(windowPoint, from: nil)
        // UI layout: AirDrop on the left, Tray/Store on the right.
        return localPoint.x >= bounds.midX ? .store : .airdrop
    }
}
