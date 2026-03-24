import Cocoa

final class DisplayHelper {
    static let shared = DisplayHelper()

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screenParametersChanged() {
        NotificationCenter.default.post(name: .displaysChanged, object: nil)
    }

    func screen(at point: CGPoint) -> NSScreen? {
        for screen in NSScreen.screens {
            if screen.frame.contains(point) {
                return screen
            }
        }
        return NSScreen.main
    }

    func currentScreen(for windowFrame: CGRect) -> NSScreen {
        var maxArea: CGFloat = 0
        var bestScreen = NSScreen.main!
        for screen in NSScreen.screens {
            let intersection = screen.frame.intersection(windowFrame)
            let area = intersection.width * intersection.height
            if area > maxArea {
                maxArea = area
                bestScreen = screen
            }
        }
        return bestScreen
    }

    private var sortedScreens: [NSScreen] {
        NSScreen.screens.sorted { $0.frame.origin.x < $1.frame.origin.x }
    }

    /// Next screen to the right (by physical position). No wrap.
    func nextScreen(from current: NSScreen) -> NSScreen? {
        let screens = sortedScreens
        guard screens.count > 1 else { return nil }
        guard let idx = screens.firstIndex(of: current) else { return nil }
        let nextIdx = idx + 1
        guard nextIdx < screens.count else { return nil }
        return screens[nextIdx]
    }

    /// Previous screen to the left (by physical position). No wrap.
    func previousScreen(from current: NSScreen) -> NSScreen? {
        let screens = sortedScreens
        guard screens.count > 1 else { return nil }
        guard let idx = screens.firstIndex(of: current) else { return nil }
        let prevIdx = idx - 1
        guard prevIdx >= 0 else { return nil }
        return screens[prevIdx]
    }
}

extension Notification.Name {
    static let displaysChanged = Notification.Name("NudgeDisplaysChanged")
}
