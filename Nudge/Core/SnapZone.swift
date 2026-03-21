import Cocoa

struct SnapZone {
    static func frame(for action: SnapAction, on screen: NSScreen) -> CGRect? {
        let f = screen.visibleFrame
        switch action {
        case .leftHalf:
            return CGRect(x: f.minX, y: f.minY, width: floor(f.width / 2), height: f.height)
        case .rightHalf:
            let halfW = floor(f.width / 2)
            return CGRect(x: f.minX + halfW, y: f.minY, width: f.width - halfW, height: f.height)
        case .topHalf:
            let halfH = floor(f.height / 2)
            return CGRect(x: f.minX, y: f.minY + halfH, width: f.width, height: f.height - halfH)
        case .bottomHalf:
            return CGRect(x: f.minX, y: f.minY, width: f.width, height: floor(f.height / 2))
        case .topLeft:
            let halfW = floor(f.width / 2)
            let halfH = floor(f.height / 2)
            return CGRect(x: f.minX, y: f.minY + halfH, width: halfW, height: f.height - halfH)
        case .topRight:
            let halfW = floor(f.width / 2)
            let halfH = floor(f.height / 2)
            return CGRect(x: f.minX + halfW, y: f.minY + halfH, width: f.width - halfW, height: f.height - halfH)
        case .bottomLeft:
            return CGRect(x: f.minX, y: f.minY, width: floor(f.width / 2), height: floor(f.height / 2))
        case .bottomRight:
            let halfW = floor(f.width / 2)
            return CGRect(x: f.minX + halfW, y: f.minY, width: f.width - halfW, height: floor(f.height / 2))
        case .leftThird:
            return CGRect(x: f.minX, y: f.minY, width: floor(f.width / 3), height: f.height)
        case .centerThird:
            let thirdW = floor(f.width / 3)
            return CGRect(x: f.minX + thirdW, y: f.minY, width: thirdW, height: f.height)
        case .rightThird:
            let thirdW = floor(f.width / 3)
            return CGRect(x: f.minX + thirdW * 2, y: f.minY, width: f.width - thirdW * 2, height: f.height)
        case .leftTwoThirds:
            let thirdW = floor(f.width / 3)
            return CGRect(x: f.minX, y: f.minY, width: thirdW * 2, height: f.height)
        case .centerTwoThirds:
            let sixthW = floor(f.width / 6)
            return CGRect(x: f.minX + sixthW, y: f.minY, width: f.width - sixthW * 2, height: f.height)
        case .rightTwoThirds:
            let thirdW = floor(f.width / 3)
            return CGRect(x: f.minX + thirdW, y: f.minY, width: f.width - thirdW, height: f.height)
        case .maximize:
            return f
        case .center:
            return nil
        case .restore, .nextDisplay, .previousDisplay:
            return nil
        }
    }
}
