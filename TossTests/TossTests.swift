//
//  TossTests.swift
//  TossTests
//
//  Created by henry on 2026/7/9.
//

import XCTest
@testable import Toss

final class TossTests: XCTestCase {

    func testDefaultGoldThemeKeepsCoinStructureStable() throws {
        let theme = CoinTheme.defaultGold

        XCTAssertEqual(theme.defaultSize, 220)
        XCTAssertEqual(theme.outerRingLineWidth, 6.3)
        XCTAssertEqual(theme.innerRingLineWidth, 2)
        XCTAssertEqual(theme.raisedCenterScale, 0.58)
        XCTAssertEqual(theme.backCircleScales, [0.22, 0.34, 0.47, 0.61])
    }
}
