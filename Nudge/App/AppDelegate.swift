import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Always show menu bar icon first
        _ = DisplayHelper.shared
        statusBarController = StatusBarController()
        statusBarController.setup()

        // Then check accessibility and start engines
        if AccessibilityHelper.shared.isAccessibilityGranted {
            startEngines()
        } else {
            NSApp.activate(ignoringOtherApps: true)
            AccessibilityHelper.shared.checkAndRequestAccess { [weak self] granted in
                guard granted else { return }
                DispatchQueue.main.async {
                    self?.startEngines()
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
