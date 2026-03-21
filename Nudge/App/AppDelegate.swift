import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = DisplayHelper.shared
        statusBarController = StatusBarController()
        statusBarController.setup()

        // Request accessibility — system shows its own prompt
        AccessibilityHelper.shared.requestAccessAndPoll { [weak self] granted in
            guard granted else { return }
            DispatchQueue.main.async {
                self?.startEngines()
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
