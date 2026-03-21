import Cocoa

/// Generates consistent 16x16 layout icons for menu items
struct SnapIconGenerator {

    static func icon(for action: SnapAction) -> NSImage {
        let size = NSSize(width: 16, height: 16)
        let image = NSImage(size: size, flipped: false) { rect in
            let inset: CGFloat = 1
            let box = rect.insetBy(dx: inset, dy: inset)
            let radius: CGFloat = 2

            if action == .restore {
                // Two overlapping rectangles (classic restore icon)
                let backRect = NSRect(x: box.minX + box.width * 0.25, y: box.minY + box.height * 0.3,
                                      width: box.width * 0.6, height: box.height * 0.55)
                let frontRect = NSRect(x: box.minX + box.width * 0.15, y: box.minY + box.height * 0.15,
                                       width: box.width * 0.6, height: box.height * 0.55)
                NSColor.secondaryLabelColor.withAlphaComponent(0.4).setStroke()
                let back = NSBezierPath(roundedRect: backRect, xRadius: 1, yRadius: 1)
                back.lineWidth = 1
                back.stroke()
                NSColor.controlTextColor.setFill()
                NSColor.controlTextColor.setStroke()
                let front = NSBezierPath(roundedRect: frontRect, xRadius: 1, yRadius: 1)
                front.lineWidth = 1
                front.fill()
                front.stroke()
            } else {
                // Outer frame
                NSColor.secondaryLabelColor.withAlphaComponent(0.4).setStroke()
                let outline = NSBezierPath(roundedRect: box, xRadius: radius, yRadius: radius)
                outline.lineWidth = 1
                outline.stroke()

                // Filled region
                if let fillRect = fillRect(for: action, in: box) {
                    NSColor.controlTextColor.setFill()
                    let fill = NSBezierPath(roundedRect: fillRect, xRadius: 1, yRadius: 1)
                    fill.fill()
                }
            }

            return true
        }
        image.isTemplate = true
        return image
    }

    private static func fillRect(for action: SnapAction, in box: NSRect) -> NSRect? {
        let x = box.minX
        let y = box.minY
        let w = box.width
        let h = box.height
        let p: CGFloat = 0.5 // padding between fill and outline

        switch action {
        // Halves
        case .leftHalf:
            return NSRect(x: x + p, y: y + p, width: w / 2 - p, height: h - p * 2)
        case .rightHalf:
            return NSRect(x: x + w / 2, y: y + p, width: w / 2 - p, height: h - p * 2)
        case .topHalf:
            return NSRect(x: x + p, y: y + h / 2, width: w - p * 2, height: h / 2 - p)
        case .bottomHalf:
            return NSRect(x: x + p, y: y + p, width: w - p * 2, height: h / 2 - p)

        // Quarters
        case .topLeft:
            return NSRect(x: x + p, y: y + h / 2, width: w / 2 - p, height: h / 2 - p)
        case .topRight:
            return NSRect(x: x + w / 2, y: y + h / 2, width: w / 2 - p, height: h / 2 - p)
        case .bottomLeft:
            return NSRect(x: x + p, y: y + p, width: w / 2 - p, height: h / 2 - p)
        case .bottomRight:
            return NSRect(x: x + w / 2, y: y + p, width: w / 2 - p, height: h / 2 - p)

        // Thirds
        case .leftThird:
            return NSRect(x: x + p, y: y + p, width: w / 3 - p, height: h - p * 2)
        case .centerThird:
            return NSRect(x: x + w / 3, y: y + p, width: w / 3, height: h - p * 2)
        case .rightThird:
            return NSRect(x: x + w * 2 / 3, y: y + p, width: w / 3 - p, height: h - p * 2)

        // Two Thirds
        case .leftTwoThirds:
            return NSRect(x: x + p, y: y + p, width: w * 2 / 3 - p, height: h - p * 2)
        case .centerTwoThirds:
            let margin = w / 6
            return NSRect(x: x + margin, y: y + p, width: w - margin * 2, height: h - p * 2)
        case .rightTwoThirds:
            return NSRect(x: x + w / 3, y: y + p, width: w * 2 / 3 - p, height: h - p * 2)

        // Maximize
        case .maximize:
            return NSRect(x: x + p, y: y + p, width: w - p * 2, height: h - p * 2)

        // Center — small rect in the middle
        case .center:
            let cw = w * 0.5
            let ch = h * 0.5
            return NSRect(x: x + (w - cw) / 2, y: y + (h - ch) / 2, width: cw, height: ch)

        // Restore — handled specially (two overlapping rects)
        case .restore:
            return nil

        // Next Display — right arrow shape (right half filled)
        case .nextDisplay:
            return NSRect(x: x + w * 0.5, y: y + p, width: w * 0.5 - p, height: h - p * 2)

        // Previous Display — left arrow shape (left half filled)
        case .previousDisplay:
            return NSRect(x: x + p, y: y + p, width: w * 0.5 - p, height: h - p * 2)
        }
    }
}
