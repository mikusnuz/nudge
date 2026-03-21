import Cocoa

/// Generates consistent 18x18 layout icons for menu items
struct SnapIconGenerator {

    static func icon(for action: SnapAction) -> NSImage {
        let size = NSSize(width: 18, height: 14)
        let image = NSImage(size: size, flipped: false) { rect in
            let box = NSRect(x: 0.5, y: 0.5, width: rect.width - 1, height: rect.height - 1)
            let radius: CGFloat = 2

            if action == .restore {
                drawRestore(in: box)
            } else {
                // Outer frame
                NSColor.secondaryLabelColor.withAlphaComponent(0.5).setStroke()
                let outline = NSBezierPath(roundedRect: box, xRadius: radius, yRadius: radius)
                outline.lineWidth = 1
                outline.stroke()

                // Filled region
                if let fillRect = fillRect(for: action, in: box) {
                    NSColor.controlTextColor.withAlphaComponent(0.8).setFill()
                    let fill = NSBezierPath(roundedRect: fillRect, xRadius: 1, yRadius: 1)
                    fill.fill()
                }
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func drawRestore(in box: NSRect) {
        // Two overlapping rectangles — classic restore/unmaximize icon
        let w = box.width
        let h = box.height
        let smallW = w * 0.6
        let smallH = h * 0.6
        let offset: CGFloat = 3

        // Back rect (outline only)
        let backRect = NSRect(x: box.minX + offset + 1, y: box.minY + 1, width: smallW, height: smallH)
        NSColor.secondaryLabelColor.withAlphaComponent(0.5).setStroke()
        let back = NSBezierPath(roundedRect: backRect, xRadius: 1, yRadius: 1)
        back.lineWidth = 1
        back.stroke()

        // Front rect (filled)
        let frontRect = NSRect(x: box.minX + 1, y: box.minY + offset + 1, width: smallW, height: smallH)
        NSColor.controlTextColor.withAlphaComponent(0.8).setFill()
        NSColor.controlTextColor.withAlphaComponent(0.8).setStroke()
        let front = NSBezierPath(roundedRect: frontRect, xRadius: 1, yRadius: 1)
        front.fill()
    }

    private static func fillRect(for action: SnapAction, in box: NSRect) -> NSRect? {
        let x = box.minX
        let y = box.minY
        let w = box.width
        let h = box.height
        let g: CGFloat = 1 // gap from outline

        switch action {
        // Halves
        case .leftHalf:
            return NSRect(x: x + g, y: y + g, width: w / 2 - g, height: h - g * 2)
        case .rightHalf:
            return NSRect(x: x + w / 2, y: y + g, width: w / 2 - g, height: h - g * 2)
        case .topHalf:
            return NSRect(x: x + g, y: y + h / 2, width: w - g * 2, height: h / 2 - g)
        case .bottomHalf:
            return NSRect(x: x + g, y: y + g, width: w - g * 2, height: h / 2 - g)

        // Quarters
        case .topLeft:
            return NSRect(x: x + g, y: y + h / 2, width: w / 2 - g, height: h / 2 - g)
        case .topRight:
            return NSRect(x: x + w / 2, y: y + h / 2, width: w / 2 - g, height: h / 2 - g)
        case .bottomLeft:
            return NSRect(x: x + g, y: y + g, width: w / 2 - g, height: h / 2 - g)
        case .bottomRight:
            return NSRect(x: x + w / 2, y: y + g, width: w / 2 - g, height: h / 2 - g)

        // Thirds
        case .leftThird:
            return NSRect(x: x + g, y: y + g, width: w / 3 - g, height: h - g * 2)
        case .centerThird:
            return NSRect(x: x + w / 3, y: y + g, width: w / 3, height: h - g * 2)
        case .rightThird:
            let thirdW = w / 3
            return NSRect(x: x + thirdW * 2, y: y + g, width: w - thirdW * 2 - g, height: h - g * 2)

        // Two Thirds
        case .leftTwoThirds:
            return NSRect(x: x + g, y: y + g, width: w * 2 / 3 - g, height: h - g * 2)
        case .centerTwoThirds:
            let margin = w / 6
            return NSRect(x: x + margin, y: y + g, width: w - margin * 2, height: h - g * 2)
        case .rightTwoThirds:
            return NSRect(x: x + w / 3, y: y + g, width: w * 2 / 3 - g, height: h - g * 2)

        // Maximize — full fill
        case .maximize:
            return NSRect(x: x + g, y: y + g, width: w - g * 2, height: h - g * 2)

        // Center — centered small rect
        case .center:
            let cw = w * 0.45
            let ch = h * 0.45
            return NSRect(x: x + (w - cw) / 2, y: y + (h - ch) / 2, width: cw, height: ch)

        // Next/Previous Display — arrow-like fills
        case .nextDisplay:
            return NSRect(x: x + w * 0.55, y: y + g, width: w * 0.45 - g, height: h - g * 2)
        case .previousDisplay:
            return NSRect(x: x + g, y: y + g, width: w * 0.45 - g, height: h - g * 2)

        case .restore:
            return nil // handled specially
        }
    }
}
