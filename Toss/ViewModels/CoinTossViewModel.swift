import SwiftUI

final class CoinTossViewModel: ObservableObject {
    let tossTriggerThreshold: CGFloat = -80
    private let resultProvider: () -> TossResult

    @Published private(set) var state: CoinTossState = .idle
    @Published private(set) var latestGestureEvent: TossGestureEvent?
    @Published private(set) var lastTossEvent: TossGestureEvent?
    @Published private(set) var lastTossResult: TossResult?

    init(resultProvider: @escaping () -> TossResult = TossResult.random) {
        self.resultProvider = resultProvider
    }

    var canStartRotation: Bool {
        state == .spinning
    }

    func updateDragTranslation(_ translation: CGSize) {
        guard canStartToss else { return }
        debugLog("drag translation received: \(translation)")
    }

    func endDrag(
        translation: CGSize,
        duration: TimeInterval,
        onToss: (TossGestureEvent) -> Void = { _ in }
    ) {
        guard canStartToss else { return }

        let event = TossGestureEvent(translation: translation, duration: duration)
        latestGestureEvent = event
        debugLog(
            "gesture event direction=\(event.direction) distance=\(event.distance) speed=\(event.speed)"
        )

        if event.isSuccessfulUpwardToss(threshold: tossTriggerThreshold) {
            let result = resultProvider()
            state = .tossing
            lastTossEvent = event
            lastTossResult = result
            debugLog("toss accepted result=\(result)")
            onToss(event)
        } else {
            debugLog("toss rejected")
        }
    }

    func completeTossMotion() {
        guard state == .tossing else { return }
        state = .resultHolding
        debugLog("motion completed")
    }

    private var canStartToss: Bool {
        state == .idle || state == .resultHolding
    }

    private func debugLog(_ message: String) {
        TossDebugLog.log("CoinTossViewModel", message)
    }
}
