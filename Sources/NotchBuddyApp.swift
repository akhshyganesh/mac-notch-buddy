import SwiftUI
import AppKit

@main
struct NotchBuddyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Notch Buddy", systemImage: "square.and.arrow.down") {
            Button(NotchOverlayWindow.shared.isVisible ? "Hide Notch Overlay" : "Show Notch Overlay") {
                if NotchOverlayWindow.shared.isVisible {
                    NotchOverlayWindow.shared.orderOut(nil)
                } else {
                    NotchOverlayWindow.shared.setup()
                }
            }

            Divider()

            Button("Settings…") {
                SettingsWindowController.shared.show()
            }

            Divider()

            Button("Quit Notch Buddy") {
                NSApp.terminate(nil)
            }
        }

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NotchDetectionManager.shared.startDetection()
        BatteryManager.shared.startMonitoring()
        ClipboardManager.shared.startMonitoring()

        // Set up the overlay; it stays hidden if no notch is detected.
        NotchOverlayWindow.shared.setup()
    }

    func applicationWillTerminate(_ notification: Notification) {
        BatteryManager.shared.stopMonitoring()
        ClipboardManager.shared.stopMonitoring()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
