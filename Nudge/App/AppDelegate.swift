import Cocoa
import ApplicationServices

func debugLog(_ msg: String) {
    let line = "[\(Date())] \(msg)\n"
    let path = "/tmp/nudge-debug.log"
    if let fh = FileHandle(forWritingAtPath: path) {
        fh.seekToEndOfFile()
        fh.write(line.data(using: .utf8)!)
        fh.closeFile()
    } else {
        FileManager.default.createFile(atPath: path, contents: line.data(using: .utf8))
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!
    private var didSetup = false

    func setup() {
        guard !didSetup else { return }
        didSetup = true

        debugLog("setup: start")
        _ = DisplayHelper.shared
        statusBarController = StatusBarController()
        statusBarController.setup()
        debugLog("setup: statusbar done")

        let granted = AXIsProcessTrusted()
        debugLog("setup: AXIsProcessTrusted=\(granted)")

        if granted {
            startEngines()
        } else {
            debugLog("setup: requesting access...")
            AccessibilityHelper.shared.requestAccessAndPoll { [weak self] granted in
                debugLog("setup: poll callback granted=\(granted)")
                guard granted else { return }
                DispatchQueue.main.async {
                    self?.startEngines()
                }
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        debugLog("applicationDidFinishLaunching called")
        setup()
    }

    private func startEngines() {
        debugLog("startEngines: starting HotkeyManager...")
        HotkeyManager.shared.start()
        debugLog("startEngines: HotkeyManager done")
        DragSnapManager.shared.start()
        debugLog("startEngines: DragSnapManager done")
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.stop()
        DragSnapManager.shared.stop()
    }
}
