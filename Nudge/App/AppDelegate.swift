import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Always show menu bar icon first
        _ = DisplayHelper.shared
        statusBarController = StatusBarController()
        statusBarController.setup()

        // Check accessibility after a brief delay to let menu bar render
        DispatchQueue.main.async { [weak self] in
            if AccessibilityHelper.shared.isAccessibilityGranted {
                self?.startEngines()
            } else {
                NSApp.activate(ignoringOtherApps: true)
                AccessibilityHelper.shared.checkAndRequestAccess { granted in
                    guard granted else { return }
                    DispatchQueue.main.async {
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
