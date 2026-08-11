import XCTest
@testable import Toss

final class SelectedCoinPreferenceRepositoryTests: XCTestCase {
    func testFetchMapsNullSelectionAndCarriesGeneration() async throws {
        let backend = SelectedCoinPreferenceBackendDouble(fetchResult: .init(selectedCoinID: nil))
        let repository = SupabaseSelectedCoinPreferenceRepository(backend: backend)
        let userID = UUID()
        let generationID = UUID()

        let selection = try await repository.fetchSelectedCoinID(
            for: userID,
            generationID: generationID
        )

        XCTAssertNil(selection)
        XCTAssertEqual(backend.fetchCalls, [.init(userID: userID, generationID: generationID)])
    }

    func testFetchMapsSelectedCoinUUID() async throws {
        let coinID = UUID()
        let backend = SelectedCoinPreferenceBackendDouble(fetchResult: .init(selectedCoinID: coinID))
        let repository = SupabaseSelectedCoinPreferenceRepository(backend: backend)

        let selection = try await repository.fetchSelectedCoinID(
            for: UUID(),
            generationID: UUID()
        )

        XCTAssertEqual(selection, coinID)
    }

    func testUpdateCarriesSelectionUserAndGeneration() async throws {
        let backend = SelectedCoinPreferenceBackendDouble(fetchResult: .init(selectedCoinID: nil))
        let repository = SupabaseSelectedCoinPreferenceRepository(backend: backend)
        let coinID = UUID()
        let userID = UUID()
        let generationID = UUID()

        try await repository.updateSelectedCoinID(
            coinID,
            for: userID,
            generationID: generationID
        )

        XCTAssertEqual(
            backend.updateCalls,
            [.init(coinID: coinID, userID: userID, generationID: generationID)]
        )
    }

    func testUpdatePayloadContainsOnlySelectedCoinID() throws {
        let coinID = UUID()
        let payload = SelectedCoinPreferenceUpdate(selectedCoinID: coinID)

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as? [String: Any]
        )

        XCTAssertEqual(Set(object.keys), ["selected_coin_id"])
        XCTAssertEqual(object["selected_coin_id"] as? String, coinID.uuidString)
        XCTAssertNil(object["sound_enabled"])
        XCTAssertNil(object["haptic_enabled"])
    }

    func testNilUpdatePayloadExplicitlyClearsSelectedCoinID() throws {
        let payload = SelectedCoinPreferenceUpdate(selectedCoinID: nil)

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as? [String: Any]
        )

        XCTAssertEqual(Set(object.keys), ["selected_coin_id"])
        XCTAssertTrue(object["selected_coin_id"] is NSNull)
    }
}

private final class SelectedCoinPreferenceBackendDouble: SelectedCoinPreferenceBackend, @unchecked Sendable {
    struct FetchCall: Equatable {
        let userID: UUID
        let generationID: UUID
    }

    struct UpdateCall: Equatable {
        let coinID: UUID?
        let userID: UUID
        let generationID: UUID
    }

    let fetchResult: SelectedCoinPreferenceRecord
    private(set) var fetchCalls: [FetchCall] = []
    private(set) var updateCalls: [UpdateCall] = []

    init(fetchResult: SelectedCoinPreferenceRecord) {
        self.fetchResult = fetchResult
    }

    func fetchSelectedCoin(
        for userID: UUID,
        generationID: UUID
    ) async throws -> SelectedCoinPreferenceRecord {
        fetchCalls.append(.init(userID: userID, generationID: generationID))
        return fetchResult
    }

    func updateSelectedCoin(
        _ update: SelectedCoinPreferenceUpdate,
        for userID: UUID,
        generationID: UUID
    ) async throws {
        updateCalls.append(.init(
            coinID: update.selectedCoinID,
            userID: userID,
            generationID: generationID
        ))
    }
}
