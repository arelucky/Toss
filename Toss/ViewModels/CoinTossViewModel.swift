import SwiftUI

final class CoinTossViewModel: ObservableObject {
    let tossTriggerThreshold: CGFloat = -80
    let tossFlightOffset: CGFloat = -180
    let tossFlightDuration: TimeInterval = 0.42

    @Published private(set) var state: CoinTossState = .idle
    @Published private(set) var verticalOffset: CGFloat = 0

    var canStartRotation: Bool {
        state == .spinning
    }

    func updateDragTranslation(_ translation: CGSize) {
        guard state == .idle else { return }
        verticalOffset = min(0, translation.height * 0.35)
    }

    func endDrag(translation: CGSize) {
        guard state == .idle else { return }

        if translation.height <= tossTriggerThreshold {
            state = .tossing
            verticalOffset = tossFlightOffset
        } else {
            verticalOffset = 0
        }
    }

    func completeTossFlight() {
        guard state == .tossing else { return }
        state = .spinning
    }
}
