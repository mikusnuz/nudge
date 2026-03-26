import Cocoa
import ApplicationServices
import os.log

private let log = OSLog(subsystem: "run.nudge.app", category: "WindowManager")

final class WindowManager {
    static let shared = WindowManager()

    private var previousFrames: [String: CGRect] = [:]
    private var lastSnapAction: (windowID: String, action: SnapAction, screen: NSScreen)?

    // MARK: - Get Focused Window

    func getFocusedWindow() -> AXUIElement? {
        // Step 1: Get the frontmost app's PID (two strategies)
        let pid: pid_t
        let appElement: AXUIElement

        let systemWide = AXUIElementCreateSystemWide()
        var focusedApp: AnyObject?
        let appResult = AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp)

        if appResult == .success, let app = focusedApp {
            let axApp = app as! AXUIElement
            var p: pid_t = 0
            AXUIElementGetPid(axApp, &p)
            pid = p
            appElement = axApp
        } else if let frontApp = NSWorkspace.shared.frontmostApplication {
            pid = frontApp.processIdentifier
            appElement = AXUIElementCreateApplication(pid)
        } else {
            FileLog.write("getFocusedWindow: no app found")
            return nil
        }

        let appName = NSRunningApplication(processIdentifier: pid)?.localizedName ?? "pid:\(pid)"

        // Step 2: Try AX attributes to get the focused/main window
        if let window = axWindow(from: appElement, appName: appName) {
            return window
        }

        // Step 3: If appElement came from systemWide, also try PID-based element
        if appResult == .success {
            let pidApp = AXUIElementCreateApplication(pid)
            if let window = axWindow(from: pidApp, appName: appName) {
                FileLog.write("getFocusedWindow: OK via PID-rebased [\(appName)]")
                return window
            }
        }

        // Step 4: Use CGWindowList to find the topmost on-screen window for this PID,
        //         then match it to an AX window by position
        if let window = windowViaCGWindowList(pid: pid, appElement: appElement, appName: appName) {
            return window
        }

        FileLog.write("getFocusedWindow: ALL methods failed [\(appName)]")
        return nil
    }

    /// Try focusedWindow → mainWindow → windows[] on an AX app element
    private func axWindow(from appElement: AXUIElement, appName: String) -> AXUIElement? {
        // focusedWindow
        var fw: AnyObject?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &fw) == .success,
           let w = fw as! AXUIElement?, getPosition(of: w) != nil {
            return w
        }
        // mainWindow
        var mw: AnyObject?
        if AXUIElementCopyAttributeValue(appElement, kAXMainWindowAttribute as CFString, &mw) == .success,
           let w = mw as! AXUIElement?, getPosition(of: w) != nil {
            return w
        }
        // walk windows array
        var wl: AnyObject?
        if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &wl) == .success,
           let windows = wl as? [AXUIElement] {
            for w in windows {
                if getPosition(of: w) != nil, getSize(of: w) != nil {
                    return w
                }
            }
        }
        return nil
    }

    /// Use CGWindowListCopyWindowInfo to find the topmost window for a PID,
    /// then match its bounds against AX windows to return the correct AXUIElement
    private func windowViaCGWindowList(pid: pid_t, appElement: AXUIElement, appName: String) -> AXUIElement? {
        let allWindows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

        // Find the topmost (first in z-order) normal window for this PID
        var targetBounds: CGRect?
        for info in allWindows {
            guard let wPid = info[kCGWindowOwnerPID as String] as? pid_t, wPid == pid,
                  let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
            let x = bounds["X"] ?? 0, y = bounds["Y"] ?? 0
            let w = bounds["Width"] ?? 0, h = bounds["Height"] ?? 0
            if w > 50 && h > 50 { // skip tiny windows (tooltips, etc.)
                targetBounds = CGRect(x: x, y: y, width: w, height: h)
                break // first match = topmost in z-order
            }
        }

        guard let target = targetBounds else { return nil }

        // Now match against AX windows by position
        let pidApp = AXUIElementCreateApplication(pid)
        var wl: AnyObject?
        guard AXUIElementCopyAttributeValue(pidApp, kAXWindowsAttribute as CFString, &wl) == .success,
              let windows = wl as? [AXUIElement] else { return nil }

        for w in windows {
            guard let pos = getPosition(of: w), let size = getSize(of: w) else { continue }
            if abs(pos.x - target.origin.x) < 10 &&
               abs(pos.y - target.origin.y) < 10 &&
               abs(size.width - target.width) < 10 &&
               abs(size.height - target.height) < 10 {
                FileLog.write("getFocusedWindow: OK via CGWindowList match [\(appName)]")
                return w
            }
        }

        // If no exact match, return the first window that has both pos and size
        for w in windows {
            if getPosition(of: w) != nil, getSize(of: w) != nil {
                FileLog.write("getFocusedWindow: OK via CGWindowList first-visible [\(appName)]")
                return w
            }
        }

        return nil
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

    @discardableResult
    func setPosition(of window: AXUIElement, to point: CGPoint) -> Bool {
        var p = point
        let value = AXValueCreate(.cgPoint, &p)!
        let result = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
        if result != .success {
            FileLog.write("setPosition FAILED: error=\(result.rawValue)")
        }
        return result == .success
    }

    @discardableResult
    func setSize(of window: AXUIElement, to size: CGSize) -> Bool {
        var s = size
        let value = AXValueCreate(.cgSize, &s)!
        let result = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
        if result != .success {
            FileLog.write("setSize FAILED: error=\(result.rawValue)")
        }
        return result == .success
    }

    // MARK: - Move Window to Frame

    func move(window: AXUIElement, to frame: CGRect) {
        if let currentFrame = getFrame(of: window),
           let windowID = getWindowID(of: window) {
            previousFrames[windowID] = currentFrame
        }
        setPosition(of: window, to: frame.origin)
        setSize(of: window, to: frame.size)
        // Force content re-layout: after a brief delay, nudge size by 1px then restore.
        // This makes apps like KakaoTalk, Electron apps, etc. re-render their internal content.
        let finalSize = frame.size
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            let nudged = CGSize(width: finalSize.width + 1, height: finalSize.height)
            self?.setSize(of: window, to: nudged)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                self?.setSize(of: window, to: finalSize)
            }
        }
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
    }

    func isWindowMaximized(_ window: AXUIElement) -> Bool {
        guard let frame = getFrame(of: window) else { return false }
        let screen = DisplayHelper.shared.currentScreen(for: frame)
        let visibleCG = convertToCG(nsFrame: screen.visibleFrame, screen: screen)
        return abs(frame.width - visibleCG.width) < 20 &&
               abs(frame.height - visibleCG.height) < 20
    }

    func restoreFromMaximized(_ window: AXUIElement, cursorCG: CGPoint? = nil) {
        guard let frame = getFrame(of: window) else { return }
        let screen = DisplayHelper.shared.currentScreen(for: frame)
        let visible = screen.visibleFrame
        let newWidth = visible.width * 0.7
        let newHeight = visible.height * 0.7
        let cgX: CGFloat
        let cgY: CGFloat
        if let cursor = cursorCG {
            cgX = cursor.x - newWidth / 2
            cgY = cursor.y
        } else {
            guard let mainScreen = NSScreen.screens.first else { return }
            cgX = visible.minX + (visible.width - newWidth) / 2
            cgY = mainScreen.frame.height - (visible.minY + (visible.height - newHeight) / 2) - newHeight
        }
        setSize(of: window, to: CGSize(width: newWidth, height: newHeight))
        setPosition(of: window, to: CGPoint(x: cgX, y: cgY))
    }

    func restoreWindowAtCursor(_ window: AXUIElement, cursorCG: CGPoint) {
        guard let windowID = getWindowID(of: window),
              let previousFrame = previousFrames[windowID] else { return }
        let prevSize = previousFrame.size
        let cgX = cursorCG.x - prevSize.width / 2
        let cgY = cursorCG.y
        setPosition(of: window, to: CGPoint(x: cgX, y: cgY))
        setSize(of: window, to: prevSize)
        previousFrames.removeValue(forKey: windowID)
    }

    // MARK: - Snap Actions

    func performAction(_ action: SnapAction) {
        // Try AX-based window detection first
        if let window = getFocusedWindow() {
            var axPid: pid_t = 0
            AXUIElementGetPid(window, &axPid)
            let axName = NSRunningApplication(processIdentifier: axPid)?.localizedName ?? "?"
            if let beforeFrame = getFrame(of: window) {
                // Try AX move/resize
                if let targetFrame = SnapZone.frame(for: action, on: DisplayHelper.shared.currentScreen(for: beforeFrame)) {
                    let cgFrame = convertToCG(nsFrame: targetFrame, screen: DisplayHelper.shared.currentScreen(for: beforeFrame))
                    let posOk = setPosition(of: window, to: cgFrame.origin)
                    let sizeOk = setSize(of: window, to: cgFrame.size)
                    // Verify move actually worked
                    if let afterFrame = getFrame(of: window),
                       abs(afterFrame.origin.x - cgFrame.origin.x) < 20 {
                        FileLog.write("performAction(\(action.rawValue)): AX OK [\(axName)]")
                        let windowID = getWindowID(of: window)
                        if let wid = windowID {
                            previousFrames[wid] = beforeFrame
                            lastSnapAction = (windowID: wid, action: action, screen: DisplayHelper.shared.currentScreen(for: beforeFrame))
                        }
                        // Content re-layout nudge
                        let finalSize = cgFrame.size
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                            let nudged = CGSize(width: finalSize.width + 1, height: finalSize.height)
                            self?.setSize(of: window, to: nudged)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                                self?.setSize(of: window, to: finalSize)
                            }
                        }
                        return
                    }
                    FileLog.write("performAction(\(action.rawValue)): AX move failed (pos=\(posOk) size=\(sizeOk)), trying SkyLight [\(axName)]")
                } else {
                    performActionOnAXWindow(window, action: action)
                    return
                }
            }
        }

        // Fallback: SkyLight private API for apps that don't expose AX windows
        // (e.g., Claude, some Electron apps)
        FileLog.write("performAction(\(action.rawValue)): entering SkyLight fallback, available=\(SkyLight.isAvailable)")
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            FileLog.write("SkyLight: no frontmostApplication")
            return
        }
        let pid = frontApp.processIdentifier
        let appName = frontApp.localizedName ?? "?"
        FileLog.write("SkyLight: frontApp=\(appName) pid=\(pid) bundle=\(frontApp.bundleIdentifier ?? "nil")")

        if let bundleID = frontApp.bundleIdentifier,
           UserPreferences.shared.isAppIgnored(bundleID) {
            FileLog.write("SkyLight: app is ignored")
            return
        }

        if let result = SkyLight.findMainWindowWithBounds(pid: pid) {
                let wid = result.wid
                let currentBounds = result.bounds
                FileLog.write("performAction: SkyLight [\(appName)] wid=\(wid) bounds=\(currentBounds)")
                let currentScreen = DisplayHelper.shared.currentScreen(for: currentBounds)

                if let targetFrame = SnapZone.frame(for: action, on: currentScreen) {
                    let cgFrame = convertToCG(nsFrame: targetFrame, screen: currentScreen)
                    let key = "\(pid)-\(wid)"
                    previousFrames[key] = currentBounds
                    let moved = SkyLight.moveWindow(windowID: wid, to: cgFrame.origin)
                    FileLog.write("SkyLight.moveWindow: \(moved)")
                    // Also try AX resize via PID-based element
                    let axApp = AXUIElementCreateApplication(pid)
                    var fw: AnyObject?
                    if AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &fw) == .success,
                       let axWin = fw as! AXUIElement? {
                        setSize(of: axWin, to: cgFrame.size)
                    }
                    return
                }
        } else {
            FileLog.write("performAction: SkyLight findMainWindow failed [\(appName)]")
        }

        FileLog.write("performAction(\(action.rawValue)): no focused window")
        os_log("performAction: no focused window", log: log, type: .error)
    }

    private func performActionOnAXWindow(_ window: AXUIElement, action: SnapAction) {
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        let appName = NSRunningApplication(processIdentifier: pid)?.localizedName ?? "?"
        os_log("performAction: %{public}@ on %{public}@", log: log, type: .info, action.rawValue, appName)
        if let app = NSRunningApplication(processIdentifier: pid),
           let bundleID = app.bundleIdentifier,
           UserPreferences.shared.isAppIgnored(bundleID) {
            return
        }

        guard let currentFrame = getFrame(of: window) else {
            os_log("performAction: cannot get window frame", log: log, type: .error)
            return
        }

        let currentScreen = DisplayHelper.shared.currentScreen(for: currentFrame)

        switch action {
        case .restore:
            restoreWindow(window)
            lastSnapAction = nil
            return
        case .center:
            center(window: window, on: currentScreen)
            lastSnapAction = nil
            return
        case .nextDisplay:
            moveToDisplay(window: window, from: currentScreen, next: true)
            lastSnapAction = nil
            return
        case .previousDisplay:
            moveToDisplay(window: window, from: currentScreen, next: false)
            lastSnapAction = nil
            return
        default:
            break
        }

        // Check if window is ALREADY at the target snap position on this screen
        let windowID = getWindowID(of: window)
        if let targetFrame = SnapZone.frame(for: action, on: currentScreen) {
            let cgTarget = convertToCG(nsFrame: targetFrame, screen: currentScreen)
            let exactMatch = isFrameMatch(currentFrame, cgTarget)
            let repeatMatch = windowID != nil &&
                lastSnapAction?.windowID == windowID &&
                lastSnapAction?.action == action &&
                lastSnapAction?.screen == currentScreen
            if exactMatch || repeatMatch {
                if !action.hasCycleDirection {
                    lastSnapAction = nil
                    return
                }
                lastSnapAction = nil
                cycleToNextMonitor(window: window, action: action, from: currentScreen)
                return
            }
        }

        // Normal snap on current screen
        if let targetFrame = SnapZone.frame(for: action, on: currentScreen) {
            let cgFrame = convertToCG(nsFrame: targetFrame, screen: currentScreen)
            move(window: window, to: cgFrame)
            if let wid = windowID {
                lastSnapAction = (windowID: wid, action: action, screen: currentScreen)
            }
        }
    }

    // MARK: - Multi-Monitor Cycling

    /// When window is already at the target position, move to next monitor with mirrored position
    private func cycleToNextMonitor(window: AXUIElement, action: SnapAction, from screen: NSScreen) {
        let screens = NSScreen.screens
        guard screens.count > 1 else { return }

        let direction = cycleDirection(for: action)
        let targetScreen: NSScreen?
        if direction > 0 {
            targetScreen = DisplayHelper.shared.nextScreen(from: screen)
        } else {
            targetScreen = DisplayHelper.shared.previousScreen(from: screen)
        }
        guard let nextScreen = targetScreen else { return }

        // Mirror the action horizontally when crossing monitors
        let mirroredAction = mirrorAction(action)

        if let targetFrame = SnapZone.frame(for: mirroredAction, on: nextScreen) {
            let cgFrame = convertToCG(nsFrame: targetFrame, screen: nextScreen)
            move(window: window, to: cgFrame)
        }
    }

    /// Mirror an action horizontally (right↔left, keeping top/bottom)
    /// For top/bottom half: keep the same shape on the next monitor
    private func mirrorAction(_ action: SnapAction) -> SnapAction {
        switch action {
        case .leftHalf: return .rightHalf
        case .rightHalf: return .leftHalf
        case .topLeft: return .topRight
        case .topRight: return .topLeft
        case .bottomLeft: return .bottomRight
        case .bottomRight: return .bottomLeft
        case .leftThird: return .rightThird
        case .rightThird: return .leftThird
        case .leftTwoThirds: return .rightTwoThirds
        case .rightTwoThirds: return .leftTwoThirds
        // Top/bottom half: mirror vertically when crossing monitors
        case .topHalf: return .bottomHalf
        case .bottomHalf: return .topHalf
        default: return action
        }
    }

    /// Right-side actions cycle right, left-side actions cycle left
    /// Bottom half cycles right (like rightHalf), top half cycles left (like leftHalf)
    private func cycleDirection(for action: SnapAction) -> Int {
        switch action {
        case .rightHalf, .topRight, .bottomRight, .rightThird, .rightTwoThirds, .bottomHalf:
            return 1
        case .leftHalf, .topLeft, .bottomLeft, .leftThird, .leftTwoThirds, .topHalf:
            return -1
        default:
            return 1
        }
    }

    /// Check if two frames match (within tolerance)
    private func isFrameMatch(_ a: CGRect, _ b: CGRect, tolerance: CGFloat = 15) -> Bool {
        return abs(a.origin.x - b.origin.x) < tolerance &&
               abs(a.origin.y - b.origin.y) < tolerance &&
               abs(a.width - b.width) < tolerance &&
               abs(a.height - b.height) < tolerance
    }

    // MARK: - Special Actions

    private func center(window: AXUIElement, on screen: NSScreen) {
        guard let size = getSize(of: window) else { return }
        guard let currentFrame = getFrame(of: window) else { return }

        let screenCG = convertToCG(nsFrame: screen.visibleFrame, screen: screen)
        let cgX = screenCG.minX + (screenCG.width - size.width) / 2
        let cgY = screenCG.minY + (screenCG.height - size.height) / 2

        if let windowID = getWindowID(of: window) {
            previousFrames[windowID] = currentFrame
        }
        setPosition(of: window, to: CGPoint(x: cgX, y: cgY))
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

    func convertToCG(nsFrame: CGRect, screen: NSScreen) -> CGRect {
        guard let mainScreen = NSScreen.screens.first else { return nsFrame }
        let mainHeight = mainScreen.frame.height
        let cgY = mainHeight - nsFrame.maxY
        return CGRect(x: nsFrame.minX, y: cgY, width: nsFrame.width, height: nsFrame.height)
    }
}
