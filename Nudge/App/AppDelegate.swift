import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Temporarily become a regular app so menu bar + alerts work
        NSApp.setActivationPolicy(.regular)

        _ = DisplayHelper.shared
        statusBarController = StatusBarController()
        statusBarController.setup()

        // Switch back to accessory (no Dock icon), then check accessibility
        DispatchQueue.main.async { [weak self] in
            NSApp.setActivationPolicy(.accessory)

            if AccessibilityHelper.shared.isAccessibilityGranted {
                self?.startEngines()
            } else {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
                AccessibilityHelper.shared.checkAndRequestAccess { granted in
                    guard granted else { return }
                    DispatchQueue.main.async {
                        NSApp.setActivationPolicy(.accessory)
                        self?.startEngines()
                    }
                }
            }
        }
    }

    private func startEngines() {
        HotkeyManager.shared.start()
        DragSnapManager.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.stop()
        DragSnapManager.shared.stop()
    }
}
