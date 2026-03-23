import Cocoa
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!
    private var didSetup = false

    func setup() {
        guard !didSetup else { return }
        didSetup = true

        Analytics.track("app_launched")

        _ = DisplayHelper.shared
        statusBarController = StatusBarController()
        statusBarController.setup()

        if AXIsProcessTrusted() {
            startEngines()
        } else {
            AccessibilityHelper.shared.requestAccessAndPoll { [weak self] granted in
                guard granted else { return }
                DispatchQueue.main.async {
                    self?.startEngines()
                }
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setup()
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
