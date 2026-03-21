import XCTest
@testable import Nudge

final class SnapActionTests: XCTestCase {
    func testAllActionsHaveDisplayNames() {
        for action in SnapAction.allCases {
            XCTAssertFalse(action.displayName.isEmpty)
        }
    }
    func testAllActionsHaveDefaultHotkeys() {
        for action in SnapAction.allCases {
            XCTAssertGreaterThan(action.defaultHotkey.modifiers, 0)
        }
    }
    func testActionCount() {
        XCTAssertEqual(SnapAction.allCases.count, 19)
    }
    func testCategoriesAreValid() {
        let valid = ["Halves", "Quarters", "Thirds", "Two Thirds", "Other", "Display"]
        for action in SnapAction.allCases {
            XCTAssertTrue(valid.contains(action.category))
        }
    }
}
