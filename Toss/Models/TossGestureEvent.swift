import CoreGraphics
import Foundation

enum TossSwipeDirection: Equatable {
    case up
    case down
    case left
    case right
    case undetermined
}

struct TossGestureEvent: Equatable {
    let translation: CGSize
    let duration: TimeInterval
    let direction: TossSwipeDirection
    let distance: CGFloat
    let verticalDistance: CGFloat
    let velocity: CGSize
    let speed: CGFloat

    init(translation: CGSize, duration: TimeInterval) {
        let safeDuration = max(duration, 0.001)
        let velocity = CGSize(
            width: translation.width / safeDuration,
            height: translation.height / safeDuration
        )

        self.translation = translation
        self.duration = safeDuration
        self.direction = TossGestureEvent.direction(for: translation)
        self.distance = hypot(translation.width, translation.height)
        self.verticalDistance = abs(translation.height)
        self.velocity = velocity
        self.speed = hypot(velocity.width, velocity.height)
    }

    func isSuccessfulUpwardToss(threshold: CGFloat) -> Bool {
        direction == .up && translation.height <= threshold
    }

    private static func direction(for translation: CGSize) -> TossSwipeDirection {
        guard translation != .zero else { return .undetermined }

        if abs(translation.height) >= abs(translation.width) {
            return translation.height < 0 ? .up : .down
        } else {
            return translation.width < 0 ? .left : .right
        }
    }
}
