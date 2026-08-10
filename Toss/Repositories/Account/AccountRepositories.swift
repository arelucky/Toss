import Foundation

enum AccountRepositoryError: Error, Equatable {
    case unauthenticated
    case userMismatch
    case generationExpired
}

protocol UserProfileRepository {
    func fetch(userID: UUID) async throws -> UserProfile
    func saveInitialDisplayName(_ displayName: String, userID: UUID) async throws -> UserProfile
}

protocol UserPreferencesRepository {
    func fetch(userID: UUID) async throws -> UserPreferences
    func update(_ preferences: UserPreferences) async throws -> UserPreferences
    func bootstrap(userID: UUID, guestPreferences: LocalPreferences) async throws -> PreferenceBootstrapResult
}

enum PreferenceBootstrapResult: Equatable {
    case uploadedGuestPreferences(UserPreferences)
    case existingAccount(UserPreferences)
}

protocol PendingDisplayNameStoring: AnyObject {
    func pendingDisplayName(for userID: UUID) -> PendingDisplayNameCandidate?
    func markPendingDisplayNameConsumed(_ candidate: PendingDisplayNameCandidate)
}
