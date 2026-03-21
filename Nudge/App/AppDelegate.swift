import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        AccessibilityHelper.shared.checkAndRequestAccess { [weak self] granted in
            guard granted else { return }
            DispatchQueue.main.async {
                self?.setupApp()
            }
        }
    }

    private func setupApp() {
        _ = DisplayHelper.shared
        statusBarController = StatusBarController()
        statusBarController.setup()
        HotkeyManager.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.stop()
    }
}
