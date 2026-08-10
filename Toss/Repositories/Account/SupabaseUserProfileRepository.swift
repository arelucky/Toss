import Foundation
import Supabase

typealias ProfileFetchOperation = (SupabaseClientGeneration, UUID) async throws -> UserProfile

final class SupabaseUserProfileRepository: UserProfileRepository, ClientEnvironmentBacked {
    let environment: AppEnvironment?
    private let provider: SupabaseClientGenerationProvider
    private let fetchOperation: ProfileFetchOperation
    private let authenticatedUserID: (SupabaseClientGeneration) -> UUID?

    init(environment: AppEnvironment) {
        self.environment = environment
        provider = environment.generationProvider
        fetchOperation = Self.liveFetch
        authenticatedUserID = { $0.client.auth.currentUser?.id }
    }

    init(
        provider: SupabaseClientGenerationProvider,
        authenticatedUserID: @escaping (SupabaseClientGeneration) -> UUID? = { $0.client.auth.currentUser?.id },
        fetchOperation: @escaping ProfileFetchOperation = SupabaseUserProfileRepository.liveFetch
    ) {
        environment = nil
        self.provider = provider
        self.authenticatedUserID = authenticatedUserID
        self.fetchOperation = fetchOperation
    }

    func fetch(userID: UUID) async throws -> UserProfile {
        let generation = try authenticatedGeneration(for: userID)
        let profile = try await fetchOperation(generation, userID)
        try validate(generation, userID: userID)
        return profile
    }

    func saveInitialDisplayName(_ displayName: String, userID: UUID) async throws -> UserProfile {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return try await fetch(userID: userID) }
        let generation = try authenticatedGeneration(for: userID)
        let rows: [UserProfile] = try await generation.client
            .from("user_profiles")
            .update(["display_name": name])
            .eq("id", value: userID)
            .is("display_name", value: nil)
            .select("id,display_name,status,created_at,updated_at")
            .execute()
            .value
        try validate(generation, userID: userID)
        if let updated = rows.first { return updated }
        return try await fetchAfterEmptyUpdate(generation: generation, userID: userID)
    }

    private func fetchAfterEmptyUpdate(generation: SupabaseClientGeneration, userID: UUID) async throws -> UserProfile {
        let profile = try await fetchOperation(generation, userID)
        try validate(generation, userID: userID)
        return profile
    }

    private func authenticatedGeneration(for userID: UUID) throws -> SupabaseClientGeneration {
        let generation = provider.current()
        guard authenticatedUserID(generation) != nil else { throw AccountRepositoryError.unauthenticated }
        guard authenticatedUserID(generation) == userID else { throw AccountRepositoryError.userMismatch }
        return generation
    }

    private func validate(_ generation: SupabaseClientGeneration, userID: UUID) throws {
        guard provider.isCurrent(generation.id) else { throw AccountRepositoryError.generationExpired }
        guard authenticatedUserID(generation) == userID else { throw AccountRepositoryError.userMismatch }
    }

    static func liveFetch(_ generation: SupabaseClientGeneration, _ userID: UUID) async throws -> UserProfile {
        try await generation.client
            .from("user_profiles")
            .select("id,display_name,status,created_at,updated_at")
            .eq("id", value: userID)
            .single()
            .execute()
            .value
    }
}
