import Foundation

enum AccountDependencyError: Error, Equatable { case unavailable }

protocol ClientEnvironmentBacked { var environment: AppEnvironment? { get } }

struct AppDependencies {
    let session: AccountSession
    let environment: AppEnvironment?
    let authService: any AccountAuthServicing
    let appleSignInService: any AppleSignInServicing
    let profileRepository: any UserProfileRepository
    let preferencesRepository: any UserPreferencesRepository
    let deletionService: any AccountDeletionServicing

    @MainActor
    static func live(configuration: SupabaseConfiguration?) -> Self {
        guard let configuration else { return offline() }
        let environment = AppEnvironment(configuration: configuration)
        return Self(
            session: .guest,
            environment: environment,
            authService: SupabaseAccountAuthService(environment: environment),
            appleSignInService: NativeAppleSignInService(),
            profileRepository: ClientBackedUserProfileRepository(environment: environment),
            preferencesRepository: ClientBackedUserPreferencesRepository(environment: environment),
            deletionService: ClientBackedAccountDeletionService(environment: environment)
        )
    }

    @MainActor
    static func live(bundle: Bundle = .main) -> Self {
        live(configuration: try? SupabaseConfiguration.load(from: bundle))
    }

    var clientEnvironmentIdentities: [ObjectIdentifier] {
        [authService, profileRepository, preferencesRepository, deletionService]
            .compactMap { ($0 as? any ClientEnvironmentBacked)?.environment }
            .map(ObjectIdentifier.init)
    }

    @MainActor
    private static func offline() -> Self {
        let service = OfflineAccountDependencies()
        return Self(session: .guest, environment: nil, authService: service, appleSignInService: service, profileRepository: service, preferencesRepository: service, deletionService: service)
    }
}

private struct ClientBackedUserProfileRepository: UserProfileRepository, ClientEnvironmentBacked {
    let environment: AppEnvironment?
    func fetch(userID: UUID) async throws -> UserProfile { throw AccountDependencyError.unavailable }
    func updateDisplayName(_ displayName: String?, userID: UUID) async throws -> UserProfile { throw AccountDependencyError.unavailable }
}

private struct ClientBackedUserPreferencesRepository: UserPreferencesRepository, ClientEnvironmentBacked {
    let environment: AppEnvironment?
    func fetch(userID: UUID) async throws -> UserPreferences { throw AccountDependencyError.unavailable }
    func update(_ preferences: UserPreferences) async throws -> UserPreferences { throw AccountDependencyError.unavailable }
    func bootstrap(userID: UUID, guestPreferences: LocalPreferences) async throws -> PreferenceBootstrapResult { throw AccountDependencyError.unavailable }
}

private struct ClientBackedAccountDeletionService: AccountDeletionServicing, ClientEnvironmentBacked {
    let environment: AppEnvironment?
    func deleteAccount(authorizationCode: String, requestID: UUID) async throws -> AccountDeletionResult { throw AccountDependencyError.unavailable }
}

private struct OfflineAccountDependencies: AccountAuthServicing, AppleSignInServicing, UserProfileRepository, UserPreferencesRepository, AccountDeletionServicing {
    func restoredSession() async throws -> GenerationAccountSession { throw AccountDependencyError.unavailable }
    func signInWithApple(identityToken: String, rawNonce: String) async throws -> GenerationAccountSession { throw AccountDependencyError.unavailable }
    func sessionChanges() -> AsyncStream<AccountAuthEvent> { AsyncStream { $0.finish() } }
    func signOut() async throws -> ServerSessionRevocation { throw AccountDependencyError.unavailable }
    func signIn() async throws -> AppleSignInCredential { throw AccountDependencyError.unavailable }
    func fetch(userID: UUID) async throws -> UserProfile { throw AccountDependencyError.unavailable }
    func updateDisplayName(_ displayName: String?, userID: UUID) async throws -> UserProfile { throw AccountDependencyError.unavailable }
    func fetch(userID: UUID) async throws -> UserPreferences { throw AccountDependencyError.unavailable }
    func update(_ preferences: UserPreferences) async throws -> UserPreferences { throw AccountDependencyError.unavailable }
    func bootstrap(userID: UUID, guestPreferences: LocalPreferences) async throws -> PreferenceBootstrapResult { throw AccountDependencyError.unavailable }
    func deleteAccount(authorizationCode: String, requestID: UUID) async throws -> AccountDeletionResult { throw AccountDependencyError.unavailable }
}
