import Foundation

protocol SelectedCoinPreferenceServicing: Sendable {
    func fetchSelectedCoinID(for userID: UUID, generationID: UUID) async throws -> UUID?
    func updateSelectedCoinID(
        _ coinID: UUID?,
        for userID: UUID,
        generationID: UUID
    ) async throws
}
