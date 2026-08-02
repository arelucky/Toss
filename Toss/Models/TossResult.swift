import Foundation

enum TossResult: CaseIterable, Equatable {
    case heads
    case tails

    static func random() -> TossResult {
        Bool.random() ? .heads : .tails
    }
}
