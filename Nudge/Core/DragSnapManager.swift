import Cocoa

final class DragSnapManager {
    static let shared = DragSnapManager()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isDraggingWindow = false
    private var dragStartWindowPosition: CGPoint?
    private var dragStartCursorPosition: CGPoint?
    private var currentSnapAction: SnapAction?
    private var draggedWindow: AXUIElement?

    private let edgeThreshold: CGFloat = 5
    private let cornerRadius: CGFloat = 50

    func start() {
        guard UserPreferences.shared.dragSnapEnabled else { return }
        let mask: CGEventMask = (1 << CGEventType.leftMouseDragged.rawValue) |
                                 (1 << CGEventType.leftMouseUp.rawValue)
        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap,
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
                  let windowPos = WindowManager.shared.getPosition(of: window) else { return }
            dragStartWindowPosition = windowPos
            dragStartCursorPosition = cursorPosition
            draggedWindow = window
            isDraggingWindow = true
            return
        }

        guard let window = draggedWindow,
              let currentWindowPos = WindowManager.shared.getPosition(of: window),
              let startWindowPos = dragStartWindowPosition,
              let startCursorPos = dragStartCursorPosition else {
            resetDragState(); return
        }

        let windowDelta = CGPoint(x: currentWindowPos.x - startWindowPos.x, y: currentWindowPos.y - startWindowPos.y)
        let cursorDelta = CGPoint(x: cursorPosition.x - startCursorPos.x, y: cursorPosition.y - startCursorPos.y)

        let isWindowDrag = abs(windowDelta.x - cursorDelta.x) < 30 && abs(windowDelta.y - cursorDelta.y) < 30
        if !isWindowDrag && (abs(cursorDelta.x) > 20 || abs(cursorDelta.y) > 20) {
            resetDragState(); return
        }

        let detectedAction = detectSnapZone(cursor: cursorPosition)
        if detectedAction != currentSnapAction {
            currentSnapAction = detectedAction
            if let action = detectedAction, let screen = screenForCursor(cursorPosition) {
                if let frame = SnapZone.frame(for: action, on: screen) {
                    SnapOverlayWindow.shared.show(at: frame)
                }
            } else {
                SnapOverlayWindow.shared.hideOverlay()
            }
        }
    }

    private func handleMouseUp(cursorPosition: CGPoint) {
        defer { resetDragState() }
        guard isDraggingWindow, let action = currentSnapAction, let window = draggedWindow else {
            SnapOverlayWindow.shared.hideOverlay(); return
        }
        guard let screen = screenForCursor(cursorPosition) else {
            SnapOverlayWindow.shared.hideOverlay(); return
        }
        if let targetFrame = SnapZone.frame(for: action, on: screen) {
            let mainHeight = NSScreen.screens.first?.frame.height ?? 0
            let cgFrame = CGRect(x: targetFrame.minX, y: mainHeight - targetFrame.maxY, width: targetFrame.width, height: targetFrame.height)
            WindowManager.shared.move(window: window, to: cgFrame)
        }
        SnapOverlayWindow.shared.hideOverlay()
    }

    func detectSnapZone(cursor: CGPoint) -> SnapAction? {
        guard let screen = screenForCursor(cursor) else { return nil }
        let frame = screen.frame

        let nearLeft = cursor.x - frame.minX < edgeThreshold
        let nearRight = frame.maxX - cursor.x < edgeThreshold
        let nearTop = cursor.y - frame.minY < edgeThreshold
        let inCornerLeft = cursor.x - frame.minX < cornerRadius
        let inCornerRight = frame.maxX - cursor.x < cornerRadius
        let inCornerTop = cursor.y - frame.minY < cornerRadius
        let inCornerBottom = frame.maxY - cursor.y < cornerRadius

        // Corners (priority)
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
        // Bottom edge NOT mapped (Dock conflict)

        return nil
    }

    private func screenForCursor(_ point: CGPoint) -> NSScreen? {
        return DisplayHelper.shared.screen(at: point)
    }

    private func resetDragState() {
        isDraggingWindow = false
        dragStartWindowPosition = nil
        dragStartCursorPosition = nil
        currentSnapAction = nil
        draggedWindow = nil
    }
}
