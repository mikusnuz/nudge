import Cocoa

final class DragSnapManager {
    static let shared = DragSnapManager()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isDraggingWindow = false
    private var isTitleBarDrag = false
    private var dragStartWindowPosition: CGPoint?
    private var dragStartCursorPosition: CGPoint?
    private var currentSnapAction: SnapAction?
    private var draggedWindow: AXUIElement?
    private var dragEventCount = 0
    private var didRestoreFromSnap = false

    private let edgeThreshold: CGFloat = 100
    private let cornerRadius: CGFloat = 200
    private let titleBarHeight: CGFloat = 40

    func start() {
        guard UserPreferences.shared.dragSnapEnabled else { return }
        let mask: CGEventMask = (1 << CGEventType.leftMouseDragged.rawValue) |
                                 (1 << CGEventType.leftMouseUp.rawValue)
        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap, place: .headInsertEventTap, options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, _ -> Unmanaged<CGEvent>? in
                DragSnapManager.shared.handleEvent(type: type, event: event)
                return Unmanaged.passUnretained(event)
            }, userInfo: nil
        )
        guard let eventTap = eventTap else { return }
        runLoopSource = CFMachPortCreateRunLoopSource(nil, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func stop() {
        if let eventTap = eventTap { CGEvent.tapEnable(tap: eventTap, enable: false) }
        if let source = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes) }
        eventTap = nil
        runLoopSource = nil
    }

    func reload() { stop(); start() }

    private func handleEvent(type: CGEventType, event: CGEvent) {
        let cursorPosition = event.location
        switch type {
        case .leftMouseDragged:
            handleDrag(cursorPosition: cursorPosition)
        case .leftMouseUp:
            handleMouseUp(cursorPosition: cursorPosition)
        default: break
        }
    }

    private func handleDrag(cursorPosition: CGPoint) {
        if !isDraggingWindow {
            guard let window = WindowManager.shared.getFocusedWindow(),
                  let windowPos = WindowManager.shared.getPosition(of: window),
                  let windowSize = WindowManager.shared.getSize(of: window) else { return }

            // Check if drag started on the title bar (top ~40px of window)
            // CG coordinates: window top = windowPos.y, title bar = windowPos.y to windowPos.y + 40
            let cursorRelativeY = cursorPosition.y - windowPos.y
            isTitleBarDrag = cursorRelativeY >= 0 && cursorRelativeY <= titleBarHeight
                && cursorPosition.x >= windowPos.x && cursorPosition.x <= windowPos.x + windowSize.width

            dragStartWindowPosition = windowPos
            dragStartCursorPosition = cursorPosition
            draggedWindow = window
            isDraggingWindow = true
            dragEventCount = 0
            didRestoreFromSnap = false
            return
        }

        dragEventCount += 1
        if dragEventCount < 3 { return }

        if dragEventCount == 3 {
            guard let window = draggedWindow,
                  let currentWindowPos = WindowManager.shared.getPosition(of: window),
                  let startWindowPos = dragStartWindowPosition,
                  let startCursorPos = dragStartCursorPosition else {
                resetDragState()
                return
            }

            let windowDelta = hypot(currentWindowPos.x - startWindowPos.x, currentWindowPos.y - startWindowPos.y)
            let cursorDelta = hypot(cursorPosition.x - startCursorPos.x, cursorPosition.y - startCursorPos.y)

            if cursorDelta > 30 && windowDelta < 5 {
                resetDragState()
                return
            }

            // Only restore from snap if dragging from the title bar
            if !didRestoreFromSnap && isTitleBarDrag {
                didRestoreFromSnap = true
                let cursor = cursorPosition
                if WindowManager.shared.hasPreviousFrame(for: window) {
                    DispatchQueue.main.async {
                        WindowManager.shared.restoreWindowAtCursor(window, cursorCG: cursor)
                    }
                    return
                } else if WindowManager.shared.isWindowMaximized(window) {
                    DispatchQueue.main.async {
                        WindowManager.shared.restoreFromMaximized(window, cursorCG: cursor)
                    }
                    return
                }
            }
        }

        let detectedAction = detectSnapZone(cursor: cursorPosition)

        if detectedAction != currentSnapAction {
            currentSnapAction = detectedAction
            DispatchQueue.main.async {
                if let action = detectedAction, let screen = self.screenForCursor(cursorPosition) {
                    if let frame = SnapZone.frame(for: action, on: screen) {
                        SnapOverlayWindow.shared.show(at: frame)
                    }
                } else {
                    SnapOverlayWindow.shared.hideOverlay()
                }
            }
        }
    }

    private func handleMouseUp(cursorPosition: CGPoint) {
        let action = currentSnapAction
        let window = draggedWindow
        let wasDragging = isDraggingWindow

        resetDragState()

        guard wasDragging, let action = action, let window = window else {
            DispatchQueue.main.async { SnapOverlayWindow.shared.hideOverlay() }
            return
        }
        guard let screen = screenForCursor(cursorPosition) else {
            DispatchQueue.main.async { SnapOverlayWindow.shared.hideOverlay() }
            return
        }

        if let targetFrame = SnapZone.frame(for: action, on: screen) {
            let mainHeight = NSScreen.screens.first?.frame.height ?? 0
            let cgFrame = CGRect(x: targetFrame.minX, y: mainHeight - targetFrame.maxY,
                                 width: targetFrame.width, height: targetFrame.height)
            DispatchQueue.main.async {
                WindowManager.shared.move(window: window, to: cgFrame)
                SnapOverlayWindow.shared.hideOverlay()
            }
        } else {
            DispatchQueue.main.async { SnapOverlayWindow.shared.hideOverlay() }
        }
    }

    // MARK: - Zone Detection

    func detectSnapZone(cursor: CGPoint) -> SnapAction? {
        guard let mainScreen = NSScreen.screens.first else { return nil }
        let mainHeight = mainScreen.frame.height
        let nsCursor = CGPoint(x: cursor.x, y: mainHeight - cursor.y)

        guard let screen = screenForNSPoint(nsCursor) else { return nil }
        let frame = screen.frame

        let distLeft = nsCursor.x - frame.minX
        let distRight = frame.maxX - nsCursor.x
        let distTop = frame.maxY - nsCursor.y
        let distBottom = nsCursor.y - frame.minY

        let nearLeft = distLeft < edgeThreshold
        let nearRight = distRight < edgeThreshold
        let nearTop = distTop < edgeThreshold

        let inCornerLeft = distLeft < cornerRadius
        let inCornerRight = distRight < cornerRadius
        let inCornerTop = distTop < cornerRadius
        let inCornerBottom = distBottom < cornerRadius

        // Corners first
        if nearTop && inCornerLeft { return .topLeft }
        if nearTop && inCornerRight { return .topRight }
        if nearLeft && inCornerTop { return .topLeft }
        if nearRight && inCornerTop { return .topRight }
        if nearLeft && inCornerBottom { return .bottomLeft }
        if nearRight && inCornerBottom { return .bottomRight }

        // Edges
        if nearLeft { return .leftHalf }
        if nearRight { return .rightHalf }
        if nearTop { return .maximize }

        return nil
    }

    private func screenForCursor(_ cgPoint: CGPoint) -> NSScreen? {
        guard let mainScreen = NSScreen.screens.first else { return nil }
        let nsPoint = CGPoint(x: cgPoint.x, y: mainScreen.frame.height - cgPoint.y)
        return screenForNSPoint(nsPoint)
    }

    private func screenForNSPoint(_ nsPoint: CGPoint) -> NSScreen? {
        for screen in NSScreen.screens {
            if screen.frame.contains(nsPoint) {
                return screen
            }
        }
        return NSScreen.main
    }

    private func resetDragState() {
        isDraggingWindow = false
        isTitleBarDrag = false
        dragStartWindowPosition = nil
        dragStartCursorPosition = nil
        currentSnapAction = nil
        draggedWindow = nil
        dragEventCount = 0
        didRestoreFromSnap = false
    }
}
