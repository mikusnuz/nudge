import Cocoa
import ApplicationServices

final class AccessibilityHelper {
    static let shared = AccessibilityHelper()
    private var pollTimer: Timer?

    var isAccessibilityGranted: Bool {
        return AXIsProcessTrusted()
    }

    /// Request accessibility using the system prompt (no custom alert needed)
    func requestAccessAndPoll(completion: @escaping (Bool) -> Void) {
        if isAccessibilityGranted {
            completion(true)
            return
        }

        // This triggers the macOS system accessibility prompt automatically
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)

        if trusted {
            completion(true)
        } else {
            // Poll until user grants permission
            startPolling(completion: completion)
        }
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
