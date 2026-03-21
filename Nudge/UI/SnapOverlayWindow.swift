import Cocoa

final class SnapOverlayWindow: NSWindow {
    static let shared = SnapOverlayWindow()

    private init() {
        super.init(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = true
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        contentView = OverlayView()
    }

    func show(at frame: CGRect) {
        setFrame(frame, display: true)
        alphaValue = 0
        orderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            self.animator().alphaValue = 1
        }
    }

    func hideOverlay() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }
}

private class OverlayView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 4), xRadius: 8, yRadius: 8)
        NSColor.systemBlue.withAlphaComponent(0.3).setFill()
        path.fill()
        NSColor.systemBlue.withAlphaComponent(0.6).setStroke()
        path.lineWidth = 2
        path.stroke()
    }
}
