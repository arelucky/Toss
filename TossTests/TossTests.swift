//
//  TossTests.swift
//  TossTests
//
//  Created by henry on 2026/7/9.
//

import XCTest
import CoreGraphics
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

    func testUpwardDragBeyondThresholdStartsToss() throws {
        let viewModel = CoinTossViewModel()

        viewModel.endDrag(translation: CGSize(width: 0, height: -96))

        XCTAssertEqual(viewModel.state, .tossing)
        XCTAssertEqual(viewModel.verticalOffset, viewModel.tossFlightOffset)
    }

    func testDragBelowThresholdReturnsToIdle() throws {
        let viewModel = CoinTossViewModel()

        viewModel.updateDragTranslation(CGSize(width: 0, height: -32))
        viewModel.endDrag(translation: CGSize(width: 0, height: -32))

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(viewModel.verticalOffset, 0)
    }

    func testDraggingUpPreviewsLimitedCoinLift() throws {
        let viewModel = CoinTossViewModel()

        viewModel.updateDragTranslation(CGSize(width: 0, height: -60))

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(viewModel.verticalOffset, -21)
    }
}
