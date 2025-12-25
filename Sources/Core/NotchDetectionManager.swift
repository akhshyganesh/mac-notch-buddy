import SwiftUI
import AppKit
import Combine
import CoreGraphics

extension Notification.Name {
    static let notchGeometryDidChange = Notification.Name("NotchBuddy.NotchGeometryDidChange")
}

/// Manages detection of the screen notch and its geometry.
/// This class is responsible for determining if the current screen has a notch
/// and providing the dimensions for the UI to anchor to.
@MainActor
final class NotchDetectionManager: ObservableObject {
    static let shared = NotchDetectionManager()
    
    @Published var hasNotch: Bool = false
    @Published var notchRect: CGRect = .zero
    @Published var safeAreaTop: CGFloat = 0
    @Published var notchScreenNumber: NSNumber? = nil
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    func startDetection() {
        updateNotchInfo()
        
        // Listen for screen configuration changes
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateNotchInfo()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateNotchInfo() {
        // `NSScreen.main` is not guaranteed to be the built-in display.
        // If an external monitor is "main", notch detection will fail and the overlay won't show.
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            self.hasNotch = false
            self.notchRect = .zero
            self.safeAreaTop = 0
            self.notchScreenNumber = nil
            return
        }
        
        // The safe area insets give us a hint.
        // On Macs with a notch, the top safe area is usually > 0 (often around 32-44pts).
        // However, safeAreaInsets alone isn't a guarantee of a physical notch (could be menu bar).
        // We check auxiliaryTopLeftArea and auxiliaryTopRightArea which are specific to the notch API.
        
        var newHasNotch = false
        var newNotchRect: CGRect = .zero
        var newSafeAreaTop: CGFloat = NSScreen.main?.safeAreaInsets.top ?? 0
        var newScreenNumber: NSNumber? = nil

        if #available(macOS 12.0, *) {
            if let notchScreen = screens.first(where: { $0.auxiliaryTopLeftArea != nil && $0.auxiliaryTopRightArea != nil }),
               let topLeft = notchScreen.auxiliaryTopLeftArea,
               let topRight = notchScreen.auxiliaryTopRightArea {
                let notchLeft = topLeft.maxX
                let notchRight = topRight.minX
                let notchWidth = notchRight - notchLeft
                let notchHeight = notchScreen.safeAreaInsets.top

                let notchY = notchScreen.frame.maxY - notchHeight
                newHasNotch = true
                newNotchRect = CGRect(x: notchLeft, y: notchY, width: notchWidth, height: notchHeight)
                newSafeAreaTop = notchHeight
                newScreenNumber = notchScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            }
        }

        // Fallback: if we can't access auxiliary notch areas (some setups / permissions / APIs can be flaky),
        // still place the overlay at the top-center of the built-in display so the app remains usable.
        if !newHasNotch {
            let builtinScreen: NSScreen? = screens.first(where: { screen in
                guard let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
                return CGDisplayIsBuiltin(num.uint32Value) != 0
            })

            if let builtinScreen {
                let approxHeight = max(builtinScreen.safeAreaInsets.top, 32)
                let approxWidth: CGFloat = 180
                let x = builtinScreen.frame.midX - (approxWidth / 2)
                let y = builtinScreen.frame.maxY - approxHeight

                newHasNotch = true
                newNotchRect = CGRect(x: x, y: y, width: approxWidth, height: approxHeight)
                newSafeAreaTop = approxHeight
                newScreenNumber = builtinScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            }
        }
        
        // Fallback or no notch
        // Even without a physical notch, we might want to simulate one for testing if requested,
        // but per requirements, we disable notch UI if no notch.
        
        let didChange = (self.hasNotch != newHasNotch)
            || (self.notchRect != newNotchRect)
            || (self.safeAreaTop != newSafeAreaTop)
            || (self.notchScreenNumber != newScreenNumber)

        self.hasNotch = newHasNotch
        self.notchRect = newNotchRect
        self.safeAreaTop = newSafeAreaTop
        self.notchScreenNumber = newScreenNumber

        if didChange {
            NotificationCenter.default.post(name: .notchGeometryDidChange, object: nil)
        }

        #if DEBUG
        print(newHasNotch ? "Notch Buddy: notch detected \(newNotchRect)" : "Notch Buddy: no notch detected")
        #endif
    }
}
