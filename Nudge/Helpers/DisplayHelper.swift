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

    func nextScreen(from current: NSScreen) -> NSScreen? {
        let screens = NSScreen.screens
        guard screens.count > 1 else { return nil }
        guard let idx = screens.firstIndex(of: current) else { return screens.first }
        return screens[(idx + 1) % screens.count]
    }

    func previousScreen(from current: NSScreen) -> NSScreen? {
        let screens = NSScreen.screens
        guard screens.count > 1 else { return nil }
        guard let idx = screens.firstIndex(of: current) else { return screens.last }
        return screens[(idx - 1 + screens.count) % screens.count]
    }
}

extension Notification.Name {
    static let displaysChanged = Notification.Name("NudgeDisplaysChanged")
}
