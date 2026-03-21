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

    /// Check if window is currently maximized (fills the screen's visible area)
    func isWindowMaximized(_ window: AXUIElement) -> Bool {
        guard let frame = getFrame(of: window) else { return false }
        let screen = DisplayHelper.shared.currentScreen(for: frame)
        let visibleCG = convertToCG(nsFrame: screen.visibleFrame, screen: screen)
        // Allow 20px tolerance
        return abs(frame.width - visibleCG.width) < 20 &&
               abs(frame.height - visibleCG.height) < 20
    }

    /// Restore a maximized window to ~70% of screen size, positioned so title bar is at cursor
    func restoreFromMaximized(_ window: AXUIElement, cursorCG: CGPoint? = nil) {
        guard let frame = getFrame(of: window) else { return }
        let screen = DisplayHelper.shared.currentScreen(for: frame)
        let visible = screen.visibleFrame
        let newWidth = visible.width * 0.7
        let newHeight = visible.height * 0.7

        // Position window so the title bar is at the cursor position
        // CG coordinates: (0,0) = top-left, y increases downward
        let cgX: CGFloat
        let cgY: CGFloat

        if let cursor = cursorCG {
            // Center horizontally on cursor, top edge at cursor Y
            cgX = cursor.x - newWidth / 2
            cgY = cursor.y
        } else {
            // Fallback: center on screen
            guard let mainScreen = NSScreen.screens.first else { return }
            let nsOriginX = visible.minX + (visible.width - newWidth) / 2
            let nsOriginY = visible.minY + (visible.height - newHeight) / 2
            cgX = nsOriginX
            cgY = mainScreen.frame.height - nsOriginY - newHeight
        }

        setSize(of: window, to: CGSize(width: newWidth, height: newHeight))
        setPosition(of: window, to: CGPoint(x: cgX, y: cgY))
    }

    /// Restore Nudge-snapped window, positioned so title bar is at cursor
    func restoreWindowAtCursor(_ window: AXUIElement, cursorCG: CGPoint) {
        guard let windowID = getWindowID(of: window),
              let previousFrame = previousFrames[windowID] else { return }
        let prevSize = previousFrame.size
        // Center horizontally on cursor, top edge at cursor Y
        let cgX = cursorCG.x - prevSize.width / 2
        let cgY = cursorCG.y
        setPosition(of: window, to: CGPoint(x: cgX, y: cgY))
        setSize(of: window, to: prevSize)
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
