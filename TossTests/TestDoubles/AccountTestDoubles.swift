import Foundation
@testable import Toss

final class AccountAuthServiceDouble: AccountAuthServicing {
    func restoredSession() async throws -> AccountSession { .guest }
    func signInWithApple(identityToken: String, rawNonce: String) async throws -> AccountSession { .guest }
    func signOut() async throws -> ServerSessionRevocation { .revoked }
}

final class UserProfileRepositoryDouble: UserProfileRepository {
    private(set) var callCount = 0
    func fetch(userID: UUID) async throws -> UserProfile { callCount += 1; throw AccountDependencyError.unavailable }
    func updateDisplayName(_ displayName: String?, userID: UUID) async throws -> UserProfile { callCount += 1; throw AccountDependencyError.unavailable }
}

final class UserPreferencesRepositoryDouble: UserPreferencesRepository {
    private(set) var callCount = 0
    func fetch(userID: UUID) async throws -> UserPreferences { callCount += 1; throw AccountDependencyError.unavailable }
    func update(_ preferences: UserPreferences) async throws -> UserPreferences { callCount += 1; throw AccountDependencyError.unavailable }
    func bootstrap(userID: UUID, guestPreferences: LocalPreferences) async throws -> PreferenceBootstrapResult { callCount += 1; throw AccountDependencyError.unavailable }
}

final class AccountDeletionServiceDouble: AccountDeletionServicing {
    private(set) var callCount = 0
    func deleteAccount(authorizationCode: String, requestID: UUID) async throws -> AccountDeletionResult { callCount += 1; throw AccountDependencyError.unavailable }
}

struct AccountTestDoubles {
    let authService = AccountAuthServiceDouble()
    let profileRepository = UserProfileRepositoryDouble()
    let preferencesRepository = UserPreferencesRepositoryDouble()
    let deletionService = AccountDeletionServiceDouble()
}
