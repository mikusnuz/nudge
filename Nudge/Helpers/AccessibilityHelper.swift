import Cocoa
import ApplicationServices

final class AccessibilityHelper {
    static let shared = AccessibilityHelper()
    private var pollTimer: Timer?

    var isAccessibilityGranted: Bool {
        return AXIsProcessTrusted()
    }

    func checkAndRequestAccess(completion: @escaping (Bool) -> Void) {
        if isAccessibilityGranted {
            completion(true)
            return
        }
        let alert = NSAlert()
        alert.messageText = "Accessibility Access Required"
        alert.informativeText = "Nudge needs accessibility access to move and resize windows. Please grant access in System Settings > Privacy & Security > Accessibility."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Quit")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openAccessibilitySettings()
            startPolling(completion: completion)
        } else {
            NSApp.terminate(nil)
        }
    }

    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private func startPolling(completion: @escaping (Bool) -> Void) {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            if AXIsProcessTrusted() {
                timer.invalidate()
                self?.pollTimer = nil
                completion(true)
            }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
