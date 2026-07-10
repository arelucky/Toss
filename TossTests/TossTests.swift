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
        XCTAssertEqual(theme.outerRingLineWidth, 7)
        XCTAssertEqual(theme.innerRingLineWidth, 2)
        XCTAssertEqual(theme.raisedCenterScale, 0.54)
        XCTAssertEqual(theme.backCircleScales, [0.28, 0.42, 0.58])
    }
}
