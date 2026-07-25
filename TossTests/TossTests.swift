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
        XCTAssertFalse(viewModel.canStartRotation)
        XCTAssertEqual(viewModel.verticalOffset, viewModel.tossFlightOffset)
    }

    func testTossFlightCompletionStartsSpinning() throws {
        let viewModel = CoinTossViewModel()

        viewModel.endDrag(translation: CGSize(width: 0, height: -96))
        viewModel.completeTossFlight()

        XCTAssertEqual(viewModel.state, .spinning)
        XCTAssertTrue(viewModel.canStartRotation)
        XCTAssertEqual(viewModel.verticalOffset, viewModel.tossFlightOffset)
    }

    func testIdleDoesNotCompleteIntoSpinning() throws {
        let viewModel = CoinTossViewModel()

        viewModel.completeTossFlight()

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertFalse(viewModel.canStartRotation)
        XCTAssertEqual(viewModel.verticalOffset, 0)
    }

    func testCoinFlipGeometryShowsFrontAtRest() throws {
        let geometry = CoinFlipGeometry(rotationDegrees: 0, restingSide: .front)

        XCTAssertEqual(geometry.face, .front)
        XCTAssertEqual(geometry.frontOpacity, 1)
        XCTAssertEqual(geometry.backOpacity, 0)
        XCTAssertEqual(geometry.edgeVisibility, 0, accuracy: 0.01)
    }

    func testCoinFlipGeometryShowsEdgeMidFlip() throws {
        let geometry = CoinFlipGeometry(rotationDegrees: 90, restingSide: .front)

        XCTAssertEqual(geometry.frontOpacity, 0)
        XCTAssertEqual(geometry.backOpacity, 0)
        XCTAssertEqual(geometry.edgeVisibility, 1, accuracy: 0.01)
    }

    func testCoinFlipGeometryShowsBackAfterHalfTurn() throws {
        let geometry = CoinFlipGeometry(rotationDegrees: 180, restingSide: .front)

        XCTAssertEqual(geometry.face, .back)
        XCTAssertEqual(geometry.frontOpacity, 0)
        XCTAssertEqual(geometry.backOpacity, 1)
        XCTAssertEqual(geometry.edgeVisibility, 0, accuracy: 0.01)
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
