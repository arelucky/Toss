import XCTest
@testable import Toss

final class TossVisualStyleTests: XCTestCase {
    func testStillnessControlsMeetMinimumTouchTarget() {
        XCTAssertEqual(TossVisualStyle.controlSize, 44)
    }

    func testStillnessPaletteUsesWarmGoldOnlyAsAccent() {
        XCTAssertGreaterThan(TossVisualStyle.selectionGold.red, TossVisualStyle.selectionGold.blue)
        XCTAssertGreaterThan(TossVisualStyle.primaryText.opacity, TossVisualStyle.secondaryText.opacity)
    }
}
