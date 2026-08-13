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

    func testHomeCoin3DStyleUsesLargerHomepageScale() throws {
        XCTAssertEqual(Coin3DViewStyle.home.targetSize, 0.90, accuracy: 0.001)
    }

    func testHomeCoin3DStyleUsesChampagneGoldMaterialOverride() throws {
        let material = Coin3DViewStyle.home.materialStyle

        XCTAssertEqual(material.baseColor.x, 0.93, accuracy: 0.001)
        XCTAssertEqual(material.baseColor.y, 0.76, accuracy: 0.001)
        XCTAssertEqual(material.baseColor.z, 0.46, accuracy: 0.001)
        XCTAssertEqual(material.baseColor.w, 1, accuracy: 0.001)
        XCTAssertEqual(material.metallic, 1, accuracy: 0.001)
        XCTAssertEqual(material.roughness, 0.28, accuracy: 0.001)
    }

    @MainActor
    func testCoinLoadStateNotifierSendsSuccessForCurrentSource() async {
        var receivedStates: [Bool] = []
        let notifier = CoinLoadStateNotifier { receivedStates.append($0) }

        notifier.notifyLoaded(.bundledClassic, currentSource: { .bundledClassic })
        await Task.yield()

        XCTAssertEqual(receivedStates, [true])
    }

    @MainActor
    func testCoinLoadStateNotifierIgnoresStaleSource() async {
        var receivedStates: [Bool] = []
        let staleURL = URL(fileURLWithPath: "/tmp/stale.usdz")
        let notifier = CoinLoadStateNotifier { receivedStates.append($0) }

        notifier.notifyLoaded(.bundledClassic, currentSource: { .downloaded(staleURL) })
        await Task.yield()

        XCTAssertTrue(receivedStates.isEmpty)
    }

    @MainActor
    func testCoinLibraryHeroUsesDedicatedTargetSize() throws {
        XCTAssertGreaterThan(
            Coin3DViewStyle.libraryHero.targetSize,
            Coin3DViewStyle.home.targetSize
        )
        XCTAssertEqual(Coin3DViewStyle.home.targetSize, 0.90, accuracy: 0.001)
        XCTAssertEqual(Coin3DViewStyle.libraryHero.materialStyle, .champagneGold)
    }

    func testTossBackgroundUsesNeutralDisplayEnvironment() throws {
        let style = TossBackgroundStyle.defaultDisplay

        XCTAssertLessThan(style.topColor.red, 0.13)
        XCTAssertLessThan(style.topColor.green, 0.13)
        XCTAssertLessThan(style.topColor.blue, 0.14)
        XCTAssertLessThan(abs(style.topColor.red - style.topColor.green), 0.03)
        XCTAssertLessThan(abs(style.topColor.green - style.topColor.blue), 0.03)

        XCTAssertLessThan(style.bottomColor.red, style.topColor.red)
        XCTAssertLessThan(style.bottomColor.green, style.topColor.green)
        XCTAssertLessThan(style.bottomColor.blue, style.topColor.blue)

        XCTAssertLessThan(style.centerLightColor.red - style.centerLightColor.blue, 0.04)
        XCTAssertGreaterThan(style.centerLightOpacity, 0.16)
        XCTAssertLessThan(style.centerLightOpacity, 0.32)
        XCTAssertGreaterThan(style.floorShadowOpacity, 0.08)
        XCTAssertLessThan(style.floorShadowOpacity, 0.22)
    }

    func testSoundEffectsExposeExpectedWavNames() throws {
        XCTAssertEqual(
            TossSoundEffect.allCases.map(\.fileName),
            [
                "coin_throw",
                "coin_air_spin"
            ]
        )
        XCTAssertTrue(TossSoundEffect.allCases.allSatisfy { $0.fileExtension == "wav" })
    }

    func testSoundResourcesExistInProject() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let soundsDirectory = projectRoot
            .appendingPathComponent("Toss")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Sounds")

        for effect in TossSoundEffect.allCases {
            let resourceURL = soundsDirectory
                .appendingPathComponent(effect.fileName)
                .appendingPathExtension(effect.fileExtension)

            XCTAssertTrue(
                FileManager.default.fileExists(atPath: resourceURL.path),
                "Missing sound resource: \(resourceURL.path)"
            )
        }
    }

    func testHapticManagerThrottlesHighSpeedPreviewFeedback() throws {
        let manager = HapticManager(isEnabled: false)
        let start = Date(timeIntervalSince1970: 0)

        XCTAssertEqual(manager.previewSpinSpeedThreshold, 455, accuracy: 0.001)
        XCTAssertEqual(manager.previewSpinMinimumInterval, 0.12, accuracy: 0.001)
        XCTAssertEqual(manager.previewSpinFeedbackStyle, .rigid)
        XCTAssertEqual(manager.previewSpinIntensity, 0.72, accuracy: 0.001)
        XCTAssertFalse(
            manager.triggerPreviewSpinIfNeeded(
                speed: manager.previewSpinSpeedThreshold - 1,
                now: start
            )
        )
        XCTAssertTrue(
            manager.triggerPreviewSpinIfNeeded(
                speed: manager.previewSpinSpeedThreshold,
                now: start
            )
        )
        XCTAssertFalse(
            manager.triggerPreviewSpinIfNeeded(
                speed: manager.previewSpinSpeedThreshold,
                now: start.addingTimeInterval(manager.previewSpinMinimumInterval - 0.01)
            )
        )
        XCTAssertTrue(
            manager.triggerPreviewSpinIfNeeded(
                speed: manager.previewSpinSpeedThreshold,
                now: start.addingTimeInterval(manager.previewSpinMinimumInterval + 0.01)
            )
        )
    }

    func testHapticManagerUsesDelayedLightTossFlightPulse() throws {
        let manager = HapticManager(isEnabled: false)

        XCTAssertEqual(manager.tossStartFeedbackStyle, .medium)
        XCTAssertEqual(manager.tossStartIntensity, 0.82, accuracy: 0.001)
        XCTAssertEqual(manager.tossFlightInitialDelay, 0.1, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(manager.tossFlightPulseInterval, 0.18)
        XCTAssertLessThanOrEqual(manager.tossFlightPulseInterval, 0.25)
    }

    func testTossGestureEventCapturesDirectionDistanceAndSpeed() throws {
        let event = TossGestureEvent(
            translation: CGSize(width: 12, height: -96),
            duration: 0.24
        )

        XCTAssertEqual(event.direction, .up)
        XCTAssertEqual(event.verticalDistance, 96)
        XCTAssertEqual(event.distance, hypot(12, 96), accuracy: 0.001)
        XCTAssertEqual(event.velocity.height, -400, accuracy: 0.001)
        XCTAssertEqual(event.speed, hypot(50, 400), accuracy: 0.001)
    }

    func testCoinPreviewRotationMapsHorizontalDragToYAxis() throws {
        let rotation = CoinPreviewRotation(translation: CGSize(width: 90, height: 0))

        XCTAssertEqual(rotation.yAngle, .pi / 2, accuracy: 0.001)
        XCTAssertEqual(rotation.xAngle, 0, accuracy: 0.001)
    }

    func testCoinPreviewRotationMapsVerticalDragToSubtleXAxis() throws {
        let rotation = CoinPreviewRotation(translation: CGSize(width: 0, height: -52))

        XCTAssertEqual(rotation.xAngle, .pi / 10, accuracy: 0.001)
        XCTAssertEqual(rotation.yAngle, 0, accuracy: 0.001)
    }

    func testCoinPreviewRotationClampsToStablePreviewRange() throws {
        let rotation = CoinPreviewRotation(translation: CGSize(width: 900, height: -900))

        XCTAssertEqual(rotation.yAngle, .pi, accuracy: 0.001)
        XCTAssertEqual(rotation.xAngle, .pi / 7, accuracy: 0.001)
    }

    func testCoinPreviewInertiaUsesReleaseVelocity() throws {
        let slowInertia = CoinPreviewInertia(
            translation: CGSize(width: 60, height: 0),
            duration: 0.6
        )
        let fastInertia = CoinPreviewInertia(
            translation: CGSize(width: 360, height: 0),
            duration: 0.18
        )

        XCTAssertGreaterThan(abs(fastInertia.yAngle), abs(slowInertia.yAngle))
        XCTAssertLessThanOrEqual(abs(fastInertia.yAngle), .pi * 2)
        XCTAssertGreaterThanOrEqual(fastInertia.duration, 0.5)
        XCTAssertLessThanOrEqual(fastInertia.duration, 0.8)
    }

    func testCoinPreviewInertiaMapsVelocityToAxes() throws {
        let inertia = CoinPreviewInertia(
            translation: CGSize(width: 180, height: -90),
            duration: 0.18
        )

        XCTAssertGreaterThan(inertia.yAngle, 0)
        XCTAssertGreaterThan(inertia.xAngle, 0)
        XCTAssertLessThanOrEqual(abs(inertia.xAngle), .pi / 3)
    }

    func testCoinPreviewInertiaUsesEaseOutDeceleration() throws {
        let inertia = CoinPreviewInertia(
            translation: CGSize(width: 360, height: 0),
            duration: 0.18
        )

        let firstHalfDelta = inertia.rotation(at: 0.5).yAngle - inertia.rotation(at: 0).yAngle
        let secondHalfDelta = inertia.rotation(at: 1).yAngle - inertia.rotation(at: 0.5).yAngle

        XCTAssertGreaterThan(firstHalfDelta, secondHalfDelta)
        XCTAssertEqual(inertia.rotation(at: 1).yAngle, inertia.yAngle, accuracy: 0.001)
    }

    func testUpwardDragBeyondThresholdTriggersTossEvent() throws {
        let viewModel = CoinTossViewModel()
        var receivedEvent: TossGestureEvent?

        viewModel.endDrag(
            translation: CGSize(width: 0, height: -96),
            duration: 0.32,
            onToss: { receivedEvent = $0 }
        )

        XCTAssertEqual(viewModel.state, .tossing)
        XCTAssertEqual(viewModel.latestGestureEvent?.direction, .up)
        XCTAssertEqual(viewModel.lastTossEvent?.verticalDistance, 96)
        XCTAssertEqual(receivedEvent?.direction, .up)
    }

    func testSuccessfulTossGeneratesConfiguredResult() throws {
        let viewModel = CoinTossViewModel(resultProvider: { .tails })

        viewModel.endDrag(translation: CGSize(width: 0, height: -96), duration: 0.32)

        XCTAssertEqual(viewModel.lastTossResult, .tails)
    }

    func testTossMotionUsesGestureDistanceWithCappedLift() throws {
        let lightSwipe = TossGestureEvent(
            translation: CGSize(width: 0, height: -96),
            duration: 0.3
        )
        let strongSwipe = TossGestureEvent(
            translation: CGSize(width: 0, height: -700),
            duration: 0.2
        )

        XCTAssertEqual(CoinTossMotion(event: lightSwipe).peakOffset, -210)
        XCTAssertEqual(CoinTossMotion(event: strongSwipe).peakOffset, -320)
        XCTAssertEqual(CoinTossMotion(event: lightSwipe).settledOffset, 0)
    }

    func testTossMotionDefinesRealityKitRotationParameters() throws {
        let event = TossGestureEvent(
            translation: CGSize(width: 0, height: -160),
            duration: 0.28
        )
        let motion = CoinTossMotion(event: event)

        XCTAssertEqual(motion.rotationTurns, 4, accuracy: 0.01)
        XCTAssertLessThan(motion.rotationDuration, motion.flightDuration)
        XCTAssertEqual(motion.rotationAngle(at: 0), 0, accuracy: 0.001)
        XCTAssertEqual(motion.rotationAngle(at: 1), motion.finalRotationAngle, accuracy: 0.001)
        XCTAssertEqual(motion.normalizedFinalRotationAngle, 0, accuracy: 0.001)
    }

    func testTossMotionHasFasterReleaseAndNaturalFall() throws {
        let event = TossGestureEvent(
            translation: CGSize(width: 0, height: -160),
            duration: 0.28
        )
        let motion = CoinTossMotion(event: event)

        XCTAssertEqual(motion.riseDuration, 0.24, accuracy: 0.001)
        XCTAssertEqual(motion.fallDuration, 0.74, accuracy: 0.001)
        XCTAssertLessThan(motion.riseDuration, motion.fallDuration)
    }

    func testTossMotionStopsRotationBeforeLandingHold() throws {
        let event = TossGestureEvent(
            translation: CGSize(width: 0, height: -160),
            duration: 0.28
        )
        let motion = CoinTossMotion(event: event)

        XCTAssertEqual(motion.flightDuration, motion.riseDuration + motion.fallDuration, accuracy: 0.001)
        XCTAssertEqual(motion.rotationDuration, motion.riseDuration + motion.fallDuration * 0.72, accuracy: 0.001)
        XCTAssertLessThan(motion.rotationDuration, motion.flightDuration)
        XCTAssertGreaterThan(motion.flightDuration - motion.rotationDuration, 0.18)
    }

    func testTossMotionScalesCoinDownThenRestoresBeforeLanding() throws {
        let event = TossGestureEvent(
            translation: CGSize(width: 0, height: -160),
            duration: 0.28
        )
        let motion = CoinTossMotion(event: event)

        XCTAssertEqual(motion.restingTargetSize, 0.90, accuracy: 0.001)
        XCTAssertEqual(motion.flightTargetSize, 0.82, accuracy: 0.001)
        XCTAssertEqual(motion.flightScaleRatio, 0.82 / 0.90, accuracy: 0.001)
        XCTAssertGreaterThan(motion.scaleRecoveryDelay, motion.riseDuration)
        XCTAssertLessThan(motion.scaleRecoveryDelay, motion.flightDuration)
        XCTAssertLessThanOrEqual(motion.scaleRecoveryDelay + motion.scaleRecoveryDuration, motion.flightDuration)
    }

    func testTossMotionUsesGestureDistanceForRotationTurns() throws {
        let shortSwipe = TossGestureEvent(
            translation: CGSize(width: 0, height: -96),
            duration: 0.3
        )
        let mediumSwipe = TossGestureEvent(
            translation: CGSize(width: 0, height: -240),
            duration: 0.28
        )
        let longSwipe = TossGestureEvent(
            translation: CGSize(width: 0, height: -700),
            duration: 0.2
        )

        XCTAssertEqual(CoinTossMotion(event: shortSwipe, result: .heads).rotationTurns, 3, accuracy: 0.01)
        XCTAssertEqual(CoinTossMotion(event: mediumSwipe, result: .heads).rotationTurns, 5, accuracy: 0.01)
        XCTAssertEqual(CoinTossMotion(event: longSwipe, result: .heads).rotationTurns, 8, accuracy: 0.01)
        XCTAssertEqual(CoinTossMotion(event: shortSwipe, result: .tails).rotationTurns, 3.5, accuracy: 0.01)
    }

    func testTossMotionStopsHeadsAtFrontAndTailsAtBack() throws {
        let event = TossGestureEvent(
            translation: CGSize(width: 0, height: -160),
            duration: 0.28
        )

        let headsMotion = CoinTossMotion(event: event, result: .heads)
        let tailsMotion = CoinTossMotion(event: event, result: .tails)

        XCTAssertEqual(headsMotion.rotationAngle(at: 1), headsMotion.finalRotationAngle, accuracy: 0.001)
        XCTAssertEqual(tailsMotion.rotationAngle(at: 1), tailsMotion.finalRotationAngle, accuracy: 0.001)
        XCTAssertEqual(headsMotion.normalizedFinalRotationAngle, 0, accuracy: 0.001)
        XCTAssertEqual(tailsMotion.normalizedFinalRotationAngle, .pi, accuracy: 0.001)
        XCTAssertEqual(headsMotion.rotationTurns, 4, accuracy: 0.001)
        XCTAssertEqual(tailsMotion.rotationTurns, 3.5, accuracy: 0.001)
    }

    func testTossMotionNormalizesFinalAngleAcrossRepeatedTosses() throws {
        let event = TossGestureEvent(
            translation: CGSize(width: 0, height: -700),
            duration: 0.2
        )

        let firstHeads = CoinTossMotion(event: event, result: .heads)
        let secondHeads = CoinTossMotion(event: event, result: .heads)
        let tails = CoinTossMotion(event: event, result: .tails)

        XCTAssertGreaterThan(firstHeads.finalRotationAngle, .pi * 2)
        XCTAssertEqual(firstHeads.normalizedFinalRotationAngle, secondHeads.normalizedFinalRotationAngle, accuracy: 0.001)
        XCTAssertEqual(firstHeads.normalizedFinalRotationAngle, 0, accuracy: 0.001)
        XCTAssertEqual(tails.normalizedFinalRotationAngle, .pi, accuracy: 0.001)
        XCTAssertLessThan(tails.normalizedFinalRotationAngle, .pi * 2)
    }

    func testTossMotionRotationDeceleratesDuringFall() throws {
        let event = TossGestureEvent(
            translation: CGSize(width: 0, height: -160),
            duration: 0.28
        )
        let motion = CoinTossMotion(event: event)

        let earlyDelta = motion.rotationAngle(at: 0.25) - motion.rotationAngle(at: 0)
        let lateDelta = motion.rotationAngle(at: 1) - motion.rotationAngle(at: 0.75)

        XCTAssertGreaterThan(earlyDelta, lateDelta)
    }

    func testTossMotionKeepsFinalDecelerationContinuous() throws {
        let event = TossGestureEvent(
            translation: CGSize(width: 0, height: -160),
            duration: 0.28
        )
        let motion = CoinTossMotion(event: event)

        let midLateDelta = motion.rotationAngle(at: 0.9) - motion.rotationAngle(at: 0.84)
        let finalDelta = motion.rotationAngle(at: 0.98) - motion.rotationAngle(at: 0.92)
        let lastTinyDelta = motion.rotationAngle(at: 0.995) - motion.rotationAngle(at: 0.985)

        XCTAssertGreaterThan(midLateDelta, finalDelta)
        XCTAssertGreaterThan(finalDelta, 0.015)
        XCTAssertGreaterThan(lastTinyDelta, 0.001)
    }

    func testTossMotionAddsSubtleRevealSettleBeforeFinalHold() throws {
        let event = TossGestureEvent(
            translation: CGSize(width: 0, height: -160),
            duration: 0.28
        )
        let motion = CoinTossMotion(event: event)

        XCTAssertGreaterThan(motion.revealSettleOffset(at: 0.9), 0)
        XCTAssertTrue(motion.revealSettleOffset(at: 0.9) < 0.12)
        XCTAssertEqual(motion.revealSettleOffset(at: 1), 0, accuracy: 0.001)
        XCTAssertEqual(motion.rotationAngle(at: 1), motion.finalRotationAngle, accuracy: 0.001)
    }

    func testTossMotionTriggersLandingFeedbackBeforeResultHold() throws {
        let event = TossGestureEvent(
            translation: CGSize(width: 0, height: -160),
            duration: 0.28
        )
        let motion = CoinTossMotion(event: event)

        XCTAssertEqual(motion.landingFeedbackLeadTime, 0.08, accuracy: 0.001)
        XCTAssertEqual(motion.landingFeedbackDelay, motion.flightDuration - 0.08, accuracy: 0.001)
    }

    func testTossMotionCompletionHoldsResult() throws {
        let viewModel = CoinTossViewModel()

        viewModel.endDrag(translation: CGSize(width: 0, height: -96), duration: 0.32)
        viewModel.completeTossMotion()

        XCTAssertEqual(viewModel.state, .resultHolding)
        XCTAssertNotNil(viewModel.lastTossResult)
    }

    func testNextUpwardDragCanStartNewTossFromHeldResult() throws {
        var results: [TossResult] = [.tails, .heads]
        let viewModel = CoinTossViewModel(resultProvider: { results.removeFirst() })

        viewModel.endDrag(translation: CGSize(width: 0, height: -96), duration: 0.32)
        viewModel.completeTossMotion()
        viewModel.endDrag(translation: CGSize(width: 0, height: -104), duration: 0.3)

        XCTAssertEqual(viewModel.state, .tossing)
        XCTAssertEqual(viewModel.lastTossResult, .heads)
    }

    func testHorizontalDragDoesNotTriggerTossEvent() throws {
        let viewModel = CoinTossViewModel()
        var didTriggerToss = false

        viewModel.endDrag(
            translation: CGSize(width: 120, height: -96),
            duration: 0.32,
            onToss: { _ in didTriggerToss = true }
        )

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(viewModel.latestGestureEvent?.direction, .right)
        XCTAssertNil(viewModel.lastTossEvent)
        XCTAssertNil(viewModel.lastTossResult)
        XCTAssertFalse(didTriggerToss)
    }

    func testDragBelowThresholdReturnsToIdle() throws {
        let viewModel = CoinTossViewModel()

        viewModel.updateDragTranslation(CGSize(width: 0, height: -32))
        viewModel.endDrag(translation: CGSize(width: 0, height: -32), duration: 0.2)

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(viewModel.latestGestureEvent?.verticalDistance, 32)
        XCTAssertNil(viewModel.lastTossEvent)
        XCTAssertNil(viewModel.lastTossResult)
    }
}
