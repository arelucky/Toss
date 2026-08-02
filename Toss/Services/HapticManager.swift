import CoreGraphics
import Foundation
import UIKit

enum TossHapticFeedbackStyle: Equatable {
    case light
    case medium
    case rigid
    case soft
    case heavy

    var uiKitStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .light:
            .light
        case .medium:
            .medium
        case .rigid:
            .rigid
        case .soft:
            .soft
        case .heavy:
            .heavy
        }
    }
}

final class HapticManager {
    static let shared = HapticManager()

    let previewSpinSpeedThreshold: CGFloat = 455
    let previewSpinMinimumInterval: TimeInterval = 0.12
    let previewSpinFeedbackStyle: TossHapticFeedbackStyle = .rigid
    let previewSpinIntensity: CGFloat = 0.72
    let tossStartFeedbackStyle: TossHapticFeedbackStyle = .medium
    let tossStartIntensity: CGFloat = 0.82
    let tossFlightInitialDelay: TimeInterval = 0.1
    let tossFlightPulseInterval: TimeInterval = 0.2

    private let isEnabled: Bool
    private var lastPreviewSpinDate: Date?
    private var tossFlightGeneration = 0
    private lazy var previewGenerator = UIImpactFeedbackGenerator(style: previewSpinFeedbackStyle.uiKitStyle)
    private lazy var tossStartGenerator = UIImpactFeedbackGenerator(style: tossStartFeedbackStyle.uiKitStyle)
    private lazy var tossFlightGenerator = UIImpactFeedbackGenerator(style: .soft)
    private lazy var landingGenerator = UIImpactFeedbackGenerator(style: .heavy)

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    func prepare() {
        guard isEnabled else { return }

        previewGenerator.prepare()
        tossStartGenerator.prepare()
        tossFlightGenerator.prepare()
        landingGenerator.prepare()
    }

    @discardableResult
    func triggerPreviewSpinIfNeeded(speed: CGFloat, now: Date = Date()) -> Bool {
        guard speed >= previewSpinSpeedThreshold else { return false }

        if let lastPreviewSpinDate,
           now.timeIntervalSince(lastPreviewSpinDate) < previewSpinMinimumInterval {
            return false
        }

        lastPreviewSpinDate = now
        guard isEnabled else { return true }

        previewGenerator.impactOccurred(intensity: previewSpinIntensity)
        previewGenerator.prepare()
        return true
    }

    func triggerTossStartImpact() {
        guard isEnabled else { return }

        tossStartGenerator.impactOccurred(intensity: tossStartIntensity)
        tossStartGenerator.prepare()
    }

    func startTossFlightFeedback(duration: TimeInterval) {
        guard isEnabled else { return }

        tossFlightGeneration += 1
        let generation = tossFlightGeneration
        let interval = tossFlightPulseInterval
        let pulseCount = max(2, Int(duration / interval))

        for index in 0..<pulseCount {
            let delay = tossFlightInitialDelay + interval * Double(index)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.tossFlightGeneration == generation else { return }
                self.tossFlightGenerator.impactOccurred(intensity: 0.2)
                self.tossFlightGenerator.prepare()
            }
        }
    }

    func stopTossFlightFeedback() {
        tossFlightGeneration += 1
    }

    func triggerLandingImpact() {
        stopTossFlightFeedback()
        guard isEnabled else { return }

        landingGenerator.impactOccurred(intensity: 0.95)
        landingGenerator.prepare()
    }
}
