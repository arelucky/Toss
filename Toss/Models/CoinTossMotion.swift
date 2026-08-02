import CoreGraphics
import Foundation

struct CoinPreviewRotation: Equatable {
    let xAngle: Double
    let yAngle: Double

    static let zero = CoinPreviewRotation(xAngle: 0, yAngle: 0)

    init(translation: CGSize) {
        let yAngle = Double(translation.width / 180) * .pi
        let xAngle = Double(-translation.height / 520) * .pi

        self.xAngle = min(max(xAngle, -.pi / 7), .pi / 7)
        self.yAngle = min(max(yAngle, -.pi), .pi)
    }

    init(xAngle: Double, yAngle: Double) {
        self.xAngle = xAngle
        self.yAngle = yAngle
    }
}

struct CoinPreviewInertia: Equatable {
    let initialRotation: CoinPreviewRotation
    let xAngle: Double
    let yAngle: Double
    let duration: TimeInterval

    static let zero = CoinPreviewInertia(initialRotation: .zero, xAngle: 0, yAngle: 0, duration: 0.6)

    init(
        translation: CGSize,
        duration: TimeInterval,
        initialRotation: CoinPreviewRotation = .zero
    ) {
        let safeDuration = max(duration, 0.08)
        let xVelocity = Double(translation.width) / safeDuration
        let yVelocity = Double(translation.height) / safeDuration
        let speed = hypot(xVelocity, yVelocity)

        self.initialRotation = initialRotation
        self.yAngle = min(max((xVelocity / 2_200) * (.pi * 2), -.pi * 2), .pi * 2)
        self.xAngle = min(max((-yVelocity / 2_800) * (.pi / 3), -.pi / 3), .pi / 3)
        self.duration = 0.5 + min(speed / 2_400, 1) * 0.3
    }

    init(
        initialRotation: CoinPreviewRotation = .zero,
        xAngle: Double,
        yAngle: Double,
        duration: TimeInterval
    ) {
        self.initialRotation = initialRotation
        self.xAngle = xAngle
        self.yAngle = yAngle
        self.duration = min(max(duration, 0.5), 0.8)
    }

    func rotation(at progress: Double) -> CoinPreviewRotation {
        let easedProgress = easeOutCubic(min(max(progress, 0), 1))
        return CoinPreviewRotation(
            xAngle: xAngle * easedProgress,
            yAngle: yAngle * easedProgress
        )
    }

    private func easeOutCubic(_ progress: Double) -> Double {
        1 - pow(1 - progress, 3)
    }
}

struct CoinTossMotion: Equatable {
    let peakOffset: CGFloat
    let settledOffset: CGFloat
    let riseDuration: TimeInterval
    let fallDuration: TimeInterval
    let rotationTurns: Double
    let result: TossResult
    let restingTargetSize: CGFloat
    let flightTargetSize: CGFloat

    init(event: TossGestureEvent, result: TossResult = .heads) {
        let gestureLift = event.verticalDistance * 1.45
        let cappedLift = min(max(gestureLift, 210), 320)
        let normalSwipeProgress = min(max((event.verticalDistance - 96) / 144, 0), 1)
        let longSwipeProgress = min(max((event.verticalDistance - 240) / 460, 0), 1)
        let targetRotationTurns = 3 + normalSwipeProgress * 2 + longSwipeProgress * 3

        peakOffset = -cappedLift
        settledOffset = 0
        riseDuration = 0.24
        fallDuration = 0.74
        self.result = result
        rotationTurns = result.compatibleRotationTurns(closestTo: targetRotationTurns)
        restingTargetSize = 0.90
        flightTargetSize = 0.82
    }

    var flightDuration: TimeInterval {
        riseDuration + fallDuration
    }

    var rotationDuration: TimeInterval {
        riseDuration + fallDuration * 0.72
    }

    var landingFeedbackLeadTime: TimeInterval {
        0.08
    }

    var landingFeedbackDelay: TimeInterval {
        max(flightDuration - landingFeedbackLeadTime, 0)
    }

    var flightScaleRatio: CGFloat {
        flightTargetSize / restingTargetSize
    }

    var scaleRecoveryDelay: TimeInterval {
        riseDuration + fallDuration * 0.66
    }

    var scaleRecoveryDuration: TimeInterval {
        min(fallDuration * 0.28, flightDuration - scaleRecoveryDelay)
    }

    var finalRotationAngle: Double {
        .pi * 2 * rotationTurns
    }

    var normalizedFinalRotationAngle: Double {
        result.finalAngleOffset
    }

    func rotationAngle(at progress: Double) -> Double {
        let clampedProgress = min(max(progress, 0), 1)
        let easedProgress: Double
        if clampedProgress < 0.58 {
            let releaseProgress = clampedProgress / 0.58
            easedProgress = 0.78 * easeOutCubic(releaseProgress)
        } else {
            let decelerationProgress = (clampedProgress - 0.58) / 0.42
            easedProgress = 0.78 + 0.22 * easeOutSine(decelerationProgress)
        }

        return finalRotationAngle * easedProgress + revealSettleOffset(at: clampedProgress)
    }

    func revealSettleOffset(at progress: Double) -> Double {
        let clampedProgress = min(max(progress, 0), 1)
        let settleStart = 0.84
        guard clampedProgress > settleStart, clampedProgress < 1 else { return 0 }

        let settleProgress = (clampedProgress - settleStart) / (1 - settleStart)
        let damping = 1 - settleProgress
        return sin(settleProgress * .pi * 2) * 0.085 * damping
    }

    private func easeOutCubic(_ progress: Double) -> Double {
        1 - pow(1 - progress, 3)
    }

    private func easeOutSine(_ progress: Double) -> Double {
        sin((progress * .pi) / 2)
    }

}

private extension TossResult {
    var finalAngleOffset: Double {
        switch self {
        case .heads:
            0
        case .tails:
            .pi
        }
    }

    func compatibleRotationTurns(closestTo targetTurns: Double) -> Double {
        switch self {
        case .heads:
            return min(max(targetTurns.rounded(), 3), 8)
        case .tails:
            let halfTurnAligned = (targetTurns - 0.5).rounded() + 0.5
            return min(max(halfTurnAligned, 3.5), 7.5)
        }
    }
}
