import Foundation

struct UserProfile: Equatable { let id: UUID; let displayName: String? }
struct UserPreferences: Equatable { let userID: UUID; let soundEnabled: Bool; let hapticEnabled: Bool }
struct LocalPreferences: Equatable { let soundEnabled: Bool; let hapticEnabled: Bool }
enum PreferenceBootstrapResult: Equatable { case uploadedGuestPreferences(UserPreferences); case existingAccount(UserPreferences) }

protocol UserProfileRepository {
    func fetch(userID: UUID) async throws -> UserProfile
    func updateDisplayName(_ displayName: String?, userID: UUID) async throws -> UserProfile
}

protocol UserPreferencesRepository {
    func fetch(userID: UUID) async throws -> UserPreferences
    func update(_ preferences: UserPreferences) async throws -> UserPreferences
    func bootstrap(userID: UUID, guestPreferences: LocalPreferences) async throws -> PreferenceBootstrapResult
}
