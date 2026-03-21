import XCTest
@testable import Nudge

final class SnapZoneTests: XCTestCase {
    func testLeftHalf() {
        guard let screen = NSScreen.main else { return }
        let f = screen.visibleFrame
        let result = SnapZone.frame(for: .leftHalf, on: screen)!
        XCTAssertEqual(result.origin.x, f.minX)
        XCTAssertEqual(result.origin.y, f.minY)
        XCTAssertEqual(result.width, floor(f.width / 2))
        XCTAssertEqual(result.height, f.height)
    }
    func testRightHalf() {
        guard let screen = NSScreen.main else { return }
        let f = screen.visibleFrame
        let result = SnapZone.frame(for: .rightHalf, on: screen)!
        let halfW = floor(f.width / 2)
        XCTAssertEqual(result.origin.x, f.minX + halfW)
        XCTAssertEqual(result.width, f.width - halfW)
    }
    func testTopHalf() {
        guard let screen = NSScreen.main else { return }
        let f = screen.visibleFrame
        let result = SnapZone.frame(for: .topHalf, on: screen)!
        let halfH = floor(f.height / 2)
        XCTAssertEqual(result.origin.y, f.minY + halfH)
        XCTAssertEqual(result.height, f.height - halfH)
    }
    func testBottomHalf() {
        guard let screen = NSScreen.main else { return }
        let f = screen.visibleFrame
        let result = SnapZone.frame(for: .bottomHalf, on: screen)!
        XCTAssertEqual(result.origin.y, f.minY)
        XCTAssertEqual(result.height, floor(f.height / 2))
    }
    func testMaximize() {
        guard let screen = NSScreen.main else { return }
        let result = SnapZone.frame(for: .maximize, on: screen)!
        XCTAssertEqual(result, screen.visibleFrame)
    }
    func testQuartersCoverScreen() {
        guard let screen = NSScreen.main else { return }
        let f = screen.visibleFrame
        let tl = SnapZone.frame(for: .topLeft, on: screen)!
        let tr = SnapZone.frame(for: .topRight, on: screen)!
        let bl = SnapZone.frame(for: .bottomLeft, on: screen)!
        let br = SnapZone.frame(for: .bottomRight, on: screen)!
        XCTAssertEqual(tl.width + tr.width, f.width, accuracy: 1)
        XCTAssertEqual(bl.width + br.width, f.width, accuracy: 1)
        XCTAssertEqual(tl.height + bl.height, f.height, accuracy: 1)
    }
    func testThirdsCoverScreen() {
        guard let screen = NSScreen.main else { return }
        let f = screen.visibleFrame
        let l = SnapZone.frame(for: .leftThird, on: screen)!
        let c = SnapZone.frame(for: .centerThird, on: screen)!
        let r = SnapZone.frame(for: .rightThird, on: screen)!
        XCTAssertEqual(l.width + c.width + r.width, f.width, accuracy: 1)
    }
    func testRestoreReturnsNil() {
        guard let screen = NSScreen.main else { return }
        XCTAssertNil(SnapZone.frame(for: .restore, on: screen))
    }
    func testCenterReturnsNil() {
        guard let screen = NSScreen.main else { return }
        XCTAssertNil(SnapZone.frame(for: .center, on: screen))
    }
    func testDisplayActionsReturnNil() {
        guard let screen = NSScreen.main else { return }
        XCTAssertNil(SnapZone.frame(for: .nextDisplay, on: screen))
        XCTAssertNil(SnapZone.frame(for: .previousDisplay, on: screen))
    }
}
