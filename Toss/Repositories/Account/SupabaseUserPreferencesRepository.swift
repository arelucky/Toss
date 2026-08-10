import Foundation
import Supabase

final class SupabaseUserPreferencesRepository: UserPreferencesRepository, ClientEnvironmentBacked {
    let environment: AppEnvironment?
    private let provider: SupabaseClientGenerationProvider

    init(environment: AppEnvironment) {
        self.environment = environment
        provider = environment.generationProvider
    }

    func fetch(userID: UUID) async throws -> UserPreferences {
        let generation = try authenticatedGeneration(for: userID)
        return try await fetch(using: generation, userID: userID)
    }

    private func fetch(using generation: SupabaseClientGeneration, userID: UUID) async throws -> UserPreferences {
        let value: UserPreferences = try await generation.client
            .from("user_preferences")
            .select("user_id,sound_enabled,haptic_enabled,created_at,updated_at")
            .eq("user_id", value: userID)
            .single()
            .execute()
            .value
        try validate(generation, userID: userID)
        return value
    }

    func update(_ preferences: UserPreferences) async throws -> UserPreferences {
        let generation = try authenticatedGeneration(for: preferences.userID)
        let value: UserPreferences = try await generation.client
            .from("user_preferences")
            .update(PreferenceUpdate(soundEnabled: preferences.soundEnabled, hapticEnabled: preferences.hapticEnabled))
            .eq("user_id", value: preferences.userID)
            .select("user_id,sound_enabled,haptic_enabled,created_at,updated_at")
            .single()
            .execute()
            .value
        try validate(generation, userID: preferences.userID)
        return value
    }

    func bootstrap(userID: UUID, guestPreferences: LocalPreferences) async throws -> PreferenceBootstrapResult {
        let generation = try authenticatedGeneration(for: userID)
        let claimed: Bool = try await generation.client
            .rpc("claim_account_preference_bootstrap", params: BootstrapParameters(
                soundEnabled: guestPreferences.soundEnabled,
                hapticEnabled: guestPreferences.hapticEnabled
            ))
            .single()
            .execute()
            .value
        try validate(generation, userID: userID)
        let preferences = try await fetch(using: generation, userID: userID)
        return claimed ? .uploadedGuestPreferences(preferences) : .existingAccount(preferences)
    }

    private func authenticatedGeneration(for userID: UUID) throws -> SupabaseClientGeneration {
        let generation = provider.current()
        guard generation.client.auth.currentUser != nil else { throw AccountRepositoryError.unauthenticated }
        guard generation.client.auth.currentUser?.id == userID else { throw AccountRepositoryError.userMismatch }
        return generation
    }

    private func validate(_ generation: SupabaseClientGeneration, userID: UUID) throws {
        guard provider.isCurrent(generation.id) else { throw AccountRepositoryError.generationExpired }
        guard generation.client.auth.currentUser?.id == userID else { throw AccountRepositoryError.userMismatch }
    }
}

private struct PreferenceUpdate: Encodable {
    let soundEnabled: Bool
    let hapticEnabled: Bool
    enum CodingKeys: String, CodingKey {
        case soundEnabled = "sound_enabled"
        case hapticEnabled = "haptic_enabled"
    }
}

private struct BootstrapParameters: Encodable {
    let soundEnabled: Bool
    let hapticEnabled: Bool
    enum CodingKeys: String, CodingKey {
        case soundEnabled = "p_sound_enabled"
        case hapticEnabled = "p_haptic_enabled"
    }
}
