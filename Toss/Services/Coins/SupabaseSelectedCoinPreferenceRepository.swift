import Foundation
import Supabase

struct SelectedCoinPreferenceRecord: Decodable, Equatable, Sendable {
    let selectedCoinID: UUID?

    enum CodingKeys: String, CodingKey {
        case selectedCoinID = "selected_coin_id"
    }
}

struct SelectedCoinPreferenceUpdate: Encodable, Equatable, Sendable {
    let selectedCoinID: UUID?

    enum CodingKeys: String, CodingKey {
        case selectedCoinID = "selected_coin_id"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(selectedCoinID, forKey: .selectedCoinID)
    }
}

protocol SelectedCoinPreferenceBackend: Sendable {
    func fetchSelectedCoin(
        for userID: UUID,
        generationID: UUID
    ) async throws -> SelectedCoinPreferenceRecord

    func updateSelectedCoin(
        _ update: SelectedCoinPreferenceUpdate,
        for userID: UUID,
        generationID: UUID
    ) async throws
}

final class SupabaseSelectedCoinPreferenceRepository:
    SelectedCoinPreferenceServicing,
    ClientEnvironmentBacked,
    @unchecked Sendable
{
    let environment: AppEnvironment?
    private let backend: any SelectedCoinPreferenceBackend

    init(environment: AppEnvironment) {
        self.environment = environment
        backend = LiveSelectedCoinPreferenceBackend(environment: environment)
    }

    init(backend: any SelectedCoinPreferenceBackend) {
        environment = nil
        self.backend = backend
    }

    func fetchSelectedCoinID(
        for userID: UUID,
        generationID: UUID
    ) async throws -> UUID? {
        try await backend.fetchSelectedCoin(
            for: userID,
            generationID: generationID
        ).selectedCoinID
    }

    func updateSelectedCoinID(
        _ coinID: UUID?,
        for userID: UUID,
        generationID: UUID
    ) async throws {
        try await backend.updateSelectedCoin(
            SelectedCoinPreferenceUpdate(selectedCoinID: coinID),
            for: userID,
            generationID: generationID
        )
    }
}

private final class LiveSelectedCoinPreferenceBackend:
    SelectedCoinPreferenceBackend,
    @unchecked Sendable
{
    private let environment: AppEnvironment
    private var provider: SupabaseClientGenerationProvider {
        environment.generationProvider
    }

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func fetchSelectedCoin(
        for userID: UUID,
        generationID: UUID
    ) async throws -> SelectedCoinPreferenceRecord {
        let generation = try authenticatedGeneration(for: userID)
        let record: SelectedCoinPreferenceRecord = try await generation.client
            .from("user_preferences")
            .select("selected_coin_id")
            .eq("user_id", value: userID)
            .single()
            .execute()
            .value
        try validate(generation, userID: userID)
        return record
    }

    func updateSelectedCoin(
        _ update: SelectedCoinPreferenceUpdate,
        for userID: UUID,
        generationID: UUID
    ) async throws {
        let generation = try authenticatedGeneration(for: userID)
        try await generation.client
            .from("user_preferences")
            .update(update)
            .eq("user_id", value: userID)
            .execute()
        try validate(generation, userID: userID)
    }

    private func authenticatedGeneration(
        for userID: UUID
    ) throws -> SupabaseClientGeneration {
        let generation = provider.current()
        guard provider.isCurrent(generation.id) else {
            throw AccountRepositoryError.generationExpired
        }
        guard generation.client.auth.currentUser != nil else {
            throw AccountRepositoryError.unauthenticated
        }
        guard generation.client.auth.currentUser?.id == userID else {
            throw AccountRepositoryError.userMismatch
        }
        return generation
    }

    private func validate(
        _ generation: SupabaseClientGeneration,
        userID: UUID
    ) throws {
        guard provider.isCurrent(generation.id) else {
            throw AccountRepositoryError.generationExpired
        }
        guard generation.client.auth.currentUser?.id == userID else {
            throw AccountRepositoryError.userMismatch
        }
    }
}
