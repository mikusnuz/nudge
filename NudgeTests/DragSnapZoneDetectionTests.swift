import XCTest
@testable import Nudge

final class DragSnapZoneDetectionTests: XCTestCase {
    let manager = DragSnapManager.shared

    func testLeftEdge() {
        guard let screen = NSScreen.main else { return }
        let f = screen.frame
        XCTAssertEqual(manager.detectSnapZone(cursor: CGPoint(x: f.minX + 2, y: f.midY)), .leftHalf)
    }
    func testRightEdge() {
        guard let screen = NSScreen.main else { return }
        let f = screen.frame
        XCTAssertEqual(manager.detectSnapZone(cursor: CGPoint(x: f.maxX - 2, y: f.midY)), .rightHalf)
    }
    func testTopEdge() {
        guard let screen = NSScreen.main else { return }
        let f = screen.frame
        XCTAssertEqual(manager.detectSnapZone(cursor: CGPoint(x: f.midX, y: f.minY + 2)), .maximize)
    }
    func testTopLeftCorner() {
        guard let screen = NSScreen.main else { return }
        let f = screen.frame
        XCTAssertEqual(manager.detectSnapZone(cursor: CGPoint(x: f.minX + 2, y: f.minY + 2)), .topLeft)
    }
    func testTopRightCorner() {
        guard let screen = NSScreen.main else { return }
        let f = screen.frame
        XCTAssertEqual(manager.detectSnapZone(cursor: CGPoint(x: f.maxX - 2, y: f.minY + 2)), .topRight)
    }
    func testBottomLeftCorner() {
        guard let screen = NSScreen.main else { return }
        let f = screen.frame
        XCTAssertEqual(manager.detectSnapZone(cursor: CGPoint(x: f.minX + 2, y: f.maxY - 2)), .bottomLeft)
    }
    func testBottomRightCorner() {
        guard let screen = NSScreen.main else { return }
        let f = screen.frame
        XCTAssertEqual(manager.detectSnapZone(cursor: CGPoint(x: f.maxX - 2, y: f.maxY - 2)), .bottomRight)
    }
    func testCenterOfScreen() {
        guard let screen = NSScreen.main else { return }
        let f = screen.frame
        XCTAssertNil(manager.detectSnapZone(cursor: CGPoint(x: f.midX, y: f.midY)))
    }
    func testBottomEdgeNotMapped() {
        guard let screen = NSScreen.main else { return }
        let f = screen.frame
        XCTAssertNil(manager.detectSnapZone(cursor: CGPoint(x: f.midX, y: f.maxY - 2)))
    }
}
