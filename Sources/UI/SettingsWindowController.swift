import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    private init() {}

    private var settingsWindowLevel: NSWindow.Level {
        let aboveOverlay = NSWindow.Level(rawValue: NotchOverlayWindow.shared.level.rawValue + 1)
        return max(aboveOverlay, .floating)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)

        if let window {
            window.level = settingsWindowLevel
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            return
        }

        let hosting = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "Notch Buddy Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.level = settingsWindowLevel
        window.collectionBehavior = [.moveToActiveSpace]
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        self.window = window
    }
}
