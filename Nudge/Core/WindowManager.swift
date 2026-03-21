import Cocoa
import ApplicationServices

final class WindowManager {
    static let shared = WindowManager()

    private var previousFrames: [String: CGRect] = [:]
    /// Track the last snap action per window for multi-monitor cycling
    private var lastSnapAction: [String: SnapAction] = [:]
    private var lastSnapScreen: [String: Int] = [:] // screen index

    // MARK: - Get Focused Window

    func getFocusedWindow() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedApp: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp) == .success else {
            return nil
        }
        var focusedWindow: AnyObject?
        guard AXUIElementCopyAttributeValue(focusedApp as! AXUIElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success else {
            return nil
        }
        return (focusedWindow as! AXUIElement)
    }

    // MARK: - Get/Set Window Position & Size

    func getFrame(of window: AXUIElement) -> CGRect? {
        guard let position = getPosition(of: window),
              let size = getSize(of: window) else { return nil }
        return CGRect(origin: position, size: size)
    }

    func getPosition(of window: AXUIElement) -> CGPoint? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &value) == .success else { return nil }
        var point = CGPoint.zero
        AXValueGetValue(value as! AXValue, .cgPoint, &point)
        return point
    }

    func getSize(of window: AXUIElement) -> CGSize? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &value) == .success else { return nil }
        var size = CGSize.zero
        AXValueGetValue(value as! AXValue, .cgSize, &size)
        return size
    }

    func setPosition(of window: AXUIElement, to point: CGPoint) {
        var p = point
        let value = AXValueCreate(.cgPoint, &p)!
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
    }

    func setSize(of window: AXUIElement, to size: CGSize) {
        var s = size
        let value = AXValueCreate(.cgSize, &s)!
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
    }

    // MARK: - Move Window to Frame

    func move(window: AXUIElement, to frame: CGRect) {
        if let currentFrame = getFrame(of: window),
           let windowID = getWindowID(of: window) {
            previousFrames[windowID] = currentFrame
        }
        setPosition(of: window, to: frame.origin)
        setSize(of: window, to: frame.size)
    }

    // MARK: - Restore

    func hasPreviousFrame(for window: AXUIElement) -> Bool {
        guard let windowID = getWindowID(of: window) else { return false }
        return previousFrames[windowID] != nil
    }

    func restoreWindow(_ window: AXUIElement) {
        guard let windowID = getWindowID(of: window),
              let previousFrame = previousFrames[windowID] else { return }
        setPosition(of: window, to: previousFrame.origin)
        setSize(of: window, to: previousFrame.size)
        previousFrames.removeValue(forKey: windowID)
        lastSnapAction.removeValue(forKey: windowID)
        lastSnapScreen.removeValue(forKey: windowID)
    }

    // MARK: - Snap Actions

    func performAction(_ action: SnapAction) {
        guard let window = getFocusedWindow() else { return }
        guard let currentFrame = getFrame(of: window) else { return }
        let windowID = getWindowID(of: window) ?? "unknown"

        let currentScreen = DisplayHelper.shared.currentScreen(for: currentFrame)

        switch action {
        case .restore:
            restoreWindow(window)
            return
        case .center:
            center(window: window, on: currentScreen)
            return
        case .nextDisplay:
            moveToDisplay(window: window, from: currentScreen, next: true)
            return
        case .previousDisplay:
            moveToDisplay(window: window, from: currentScreen, next: false)
            return
        default:
            break
        }

        // Multi-monitor cycling: if same action pressed again, move to next monitor
        let screens = NSScreen.screens
        var targetScreen = currentScreen

        if let prevAction = lastSnapAction[windowID],
           prevAction == action,
           screens.count > 1 {
            // Same action pressed again — cycle to next monitor
            let currentIdx = lastSnapScreen[windowID] ?? screenIndex(of: currentScreen)
            let direction = cycleDirection(for: action)
            let nextIdx: Int
            if direction > 0 {
                nextIdx = (currentIdx + 1) % screens.count
            } else if direction < 0 {
                nextIdx = (currentIdx - 1 + screens.count) % screens.count
            } else {
                nextIdx = (currentIdx + 1) % screens.count
            }
            targetScreen = screens[nextIdx]
            lastSnapScreen[windowID] = nextIdx
        } else {
            // New action — snap on current screen
            lastSnapScreen[windowID] = screenIndex(of: targetScreen)
        }

        lastSnapAction[windowID] = action

        if let targetFrame = SnapZone.frame(for: action, on: targetScreen) {
            let cgFrame = convertToCG(nsFrame: targetFrame, screen: targetScreen)
            move(window: window, to: cgFrame)
        }
    }

    /// Determine cycle direction based on snap action
    /// Right-side actions cycle right (to next monitor), left-side cycle left
    private func cycleDirection(for action: SnapAction) -> Int {
        switch action {
        case .rightHalf, .topRight, .bottomRight, .rightThird, .rightTwoThirds:
            return 1 // cycle right
        case .leftHalf, .topLeft, .bottomLeft, .leftThird, .leftTwoThirds:
            return -1 // cycle left
        default:
            return 1 // default: cycle right
        }
    }

    private func screenIndex(of screen: NSScreen) -> Int {
        return NSScreen.screens.firstIndex(of: screen) ?? 0
    }

    // MARK: - Special Actions

    private func center(window: AXUIElement, on screen: NSScreen) {
        guard let size = getSize(of: window) else { return }
        let f = screen.visibleFrame
        let nsOrigin = CGPoint(
            x: f.minX + (f.width - size.width) / 2,
            y: f.minY + (f.height - size.height) / 2
        )
        guard let mainScreen = NSScreen.screens.first else { return }
        let cgY = mainScreen.frame.height - nsOrigin.y - size.height
        let cgOrigin = CGPoint(x: nsOrigin.x, y: cgY)
        if let currentFrame = getFrame(of: window),
           let windowID = getWindowID(of: window) {
            previousFrames[windowID] = currentFrame
        }
        setPosition(of: window, to: cgOrigin)
    }

    private func moveToDisplay(window: AXUIElement, from currentScreen: NSScreen, next: Bool) {
        let targetScreen: NSScreen?
        if next {
            targetScreen = DisplayHelper.shared.nextScreen(from: currentScreen)
        } else {
            targetScreen = DisplayHelper.shared.previousScreen(from: currentScreen)
        }
        guard let screen = targetScreen else { return }
        let targetFrame = screen.visibleFrame
        if let currentFrame = getFrame(of: window),
           let windowID = getWindowID(of: window) {
            previousFrames[windowID] = currentFrame
        }
        let cgFrame = convertToCG(nsFrame: targetFrame, screen: screen)
        move(window: window, to: cgFrame)
    }

    // MARK: - Window ID

    private func getWindowID(of window: AXUIElement) -> String? {
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        guard let position = getPosition(of: window) else { return "\(pid)-unknown" }
        for info in windowList {
            guard let wPid = info[kCGWindowOwnerPID as String] as? pid_t,
                  wPid == pid,
                  let wNumber = info[kCGWindowNumber as String] as? Int,
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
            let wX = bounds["X"] ?? 0
            let wY = bounds["Y"] ?? 0
            if abs(wX - position.x) < 5 && abs(wY - position.y) < 5 {
                return "\(pid)-\(wNumber)"
            }
        }
        return "\(pid)-unknown"
    }

    // MARK: - Coordinate Conversion

    private func convertToCG(nsFrame: CGRect, screen: NSScreen) -> CGRect {
        guard let mainScreen = NSScreen.screens.first else { return nsFrame }
        let mainHeight = mainScreen.frame.height
        let cgY = mainHeight - nsFrame.maxY
        return CGRect(x: nsFrame.minX, y: cgY, width: nsFrame.width, height: nsFrame.height)
    }
}
