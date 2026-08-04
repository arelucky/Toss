import Foundation

enum AccountDependencyError: Error, Equatable { case unavailable }

private protocol ClientEnvironmentBacked { var environment: AppEnvironment { get } }

struct AppDependencies {
    let session: AccountSession
    let environment: AppEnvironment?
    let authService: any AccountAuthServicing
    let profileRepository: any UserProfileRepository
    let preferencesRepository: any UserPreferencesRepository
    let deletionService: any AccountDeletionServicing

    static func live(configuration: SupabaseConfiguration?) -> Self {
        guard let configuration else { return offline() }
        let environment = AppEnvironment(configuration: configuration)
        return Self(
            session: .guest,
            environment: environment,
            authService: ClientBackedAccountAuthService(environment: environment),
            profileRepository: ClientBackedUserProfileRepository(environment: environment),
            preferencesRepository: ClientBackedUserPreferencesRepository(environment: environment),
            deletionService: ClientBackedAccountDeletionService(environment: environment)
        )
    }

    static func live(bundle: Bundle = .main) -> Self {
        live(configuration: try? SupabaseConfiguration.load(from: bundle))
    }

    var clientEnvironmentIdentities: [ObjectIdentifier] {
        [authService, profileRepository, preferencesRepository, deletionService]
            .compactMap { ($0 as? any ClientEnvironmentBacked).map { ObjectIdentifier($0.environment) } }
    }

    private static func offline() -> Self {
        let service = OfflineAccountDependencies()
        return Self(session: .guest, environment: nil, authService: service, profileRepository: service, preferencesRepository: service, deletionService: service)
    }
}

private struct ClientBackedAccountAuthService: AccountAuthServicing, ClientEnvironmentBacked {
    let environment: AppEnvironment
    func restoredSession() async throws -> AccountSession { throw AccountDependencyError.unavailable }
    func signInWithApple(identityToken: String, rawNonce: String) async throws -> AccountSession { throw AccountDependencyError.unavailable }
    func signOut() async throws -> ServerSessionRevocation { throw AccountDependencyError.unavailable }
}

private struct ClientBackedUserProfileRepository: UserProfileRepository, ClientEnvironmentBacked {
    let environment: AppEnvironment
    func fetch(userID: UUID) async throws -> UserProfile { throw AccountDependencyError.unavailable }
    func updateDisplayName(_ displayName: String?, userID: UUID) async throws -> UserProfile { throw AccountDependencyError.unavailable }
}

private struct ClientBackedUserPreferencesRepository: UserPreferencesRepository, ClientEnvironmentBacked {
    let environment: AppEnvironment
    func fetch(userID: UUID) async throws -> UserPreferences { throw AccountDependencyError.unavailable }
    func update(_ preferences: UserPreferences) async throws -> UserPreferences { throw AccountDependencyError.unavailable }
    func bootstrap(userID: UUID, guestPreferences: LocalPreferences) async throws -> PreferenceBootstrapResult { throw AccountDependencyError.unavailable }
}

private struct ClientBackedAccountDeletionService: AccountDeletionServicing, ClientEnvironmentBacked {
    let environment: AppEnvironment
    func deleteAccount(authorizationCode: String, requestID: UUID) async throws -> AccountDeletionResult { throw AccountDependencyError.unavailable }
}

private struct OfflineAccountDependencies: AccountAuthServicing, UserProfileRepository, UserPreferencesRepository, AccountDeletionServicing {
    func restoredSession() async throws -> AccountSession { throw AccountDependencyError.unavailable }
    func signInWithApple(identityToken: String, rawNonce: String) async throws -> AccountSession { throw AccountDependencyError.unavailable }
    func signOut() async throws -> ServerSessionRevocation { throw AccountDependencyError.unavailable }
    func fetch(userID: UUID) async throws -> UserProfile { throw AccountDependencyError.unavailable }
    func updateDisplayName(_ displayName: String?, userID: UUID) async throws -> UserProfile { throw AccountDependencyError.unavailable }
    func fetch(userID: UUID) async throws -> UserPreferences { throw AccountDependencyError.unavailable }
    func update(_ preferences: UserPreferences) async throws -> UserPreferences { throw AccountDependencyError.unavailable }
    func bootstrap(userID: UUID, guestPreferences: LocalPreferences) async throws -> PreferenceBootstrapResult { throw AccountDependencyError.unavailable }
    func deleteAccount(authorizationCode: String, requestID: UUID) async throws -> AccountDeletionResult { throw AccountDependencyError.unavailable }
}
