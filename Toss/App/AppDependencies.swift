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
    let selectedCoinPreferenceRepository: any SelectedCoinPreferenceServicing
    let coinCatalogRepository: any CoinCatalogServicing
    let coinCatalogCache: CoinCatalogCache
    let deletionService: any AccountDeletionServicing
    let deletionRequestStore: AccountDeletionRequestStore
    let localPreferences: LocalPreferencesStore
    let feedbackPreferences: any FeedbackPreferenceApplying

    @MainActor
    static func live(configuration: SupabaseConfiguration?) -> Self {
        guard let configuration else { return offline() }
        let environment = AppEnvironment(configuration: configuration)
        let localPreferences = LocalPreferencesStore()
        let feedbackPreferences = AppFeedbackPreferencesController()
        let coinCatalogCache = CoinCatalogCache()
        return Self(
            session: .guest,
            environment: environment,
            authService: SupabaseAccountAuthService(environment: environment),
            appleSignInService: NativeAppleSignInService(),
            profileRepository: SupabaseUserProfileRepository(environment: environment),
            preferencesRepository: SupabaseUserPreferencesRepository(environment: environment),
            selectedCoinPreferenceRepository: SupabaseSelectedCoinPreferenceRepository(environment: environment),
            coinCatalogRepository: SupabaseCoinCatalogRepository(environment: environment, cache: coinCatalogCache),
            coinCatalogCache: coinCatalogCache,
            deletionService: SupabaseAccountDeletionService(environment: environment),
            deletionRequestStore: AccountDeletionRequestStore(),
            localPreferences: localPreferences,
            feedbackPreferences: feedbackPreferences
        )
    }

    @MainActor
    static func live(bundle: Bundle = .main) -> Self {
        live(configuration: try? SupabaseConfiguration.load(from: bundle))
    }

    var clientEnvironmentIdentities: [ObjectIdentifier] {
        [authService, profileRepository, preferencesRepository, selectedCoinPreferenceRepository, deletionService]
            .compactMap { ($0 as? any ClientEnvironmentBacked)?.environment }
            .map(ObjectIdentifier.init)
    }

    @MainActor
    func makeAccountSyncCoordinator(accountStore: AccountStore) -> AccountSyncCoordinator {
        AccountSyncCoordinator(
            profileRepository: profileRepository,
            preferencesRepository: preferencesRepository,
            localPreferences: localPreferences,
            feedback: feedbackPreferences,
            pendingNameStore: accountStore
        )
    }

    @MainActor
    private static func offline() -> Self {
        let service = OfflineAccountDependencies()
        let coinCatalogCache = CoinCatalogCache()
        return Self(session: .guest, environment: nil, authService: service, appleSignInService: service, profileRepository: service, preferencesRepository: service, selectedCoinPreferenceRepository: service, coinCatalogRepository: OfflineCoinCatalogService(cache: coinCatalogCache), coinCatalogCache: coinCatalogCache, deletionService: service, deletionRequestStore: AccountDeletionRequestStore(), localPreferences: LocalPreferencesStore(), feedbackPreferences: AppFeedbackPreferencesController())
    }
}

@MainActor
extension AppDependencies {
    func makeCoinLibraryViewModel(
        accountStore: AccountStore,
        tossViewModel: CoinTossViewModel
    ) -> CoinLibraryViewModel {
        let assets = CoinAssetCache()
        let selectionGenerationID = UUID()
        let selection = CoinSelectionStore(
            catalog: coinCatalogRepository,
            assets: assets,
            preferences: selectedCoinPreferenceRepository,
            isGenerationCurrent: { $0 == selectionGenerationID },
            isCoinIdle: { tossViewModel.state == .idle }
        )
        return CoinLibraryViewModel(
            cachedCatalog: coinCatalogCache.load,
            catalog: coinCatalogRepository,
            assets: assets,
            selection: selection,
            session: { accountStore.session },
            generationID: { selectionGenerationID },
            isOnline: { true },
            tossState: { tossViewModel.state }
        )
    }

    static func makeOfflineCoinLibraryViewModel() -> CoinLibraryViewModel {
        let cache = CoinCatalogCache()
        let catalog = OfflineCoinCatalogService(cache: cache)
        let assets = CoinAssetCache()
        let selection = CoinSelectionStore(catalog: catalog, assets: assets, preferences: OfflineAccountDependencies(), isGenerationCurrent: { _ in true }, isCoinIdle: { true })
        return CoinLibraryViewModel(cachedCatalog: cache.load, catalog: catalog, assets: assets, selection: selection, session: { .guest }, generationID: UUID.init, isOnline: { false }, tossState: { .idle })
    }
}

private struct OfflineCoinCatalogService: CoinCatalogServicing {
    let cache: CoinCatalogCache
    func fetchPublishedCatalog() async throws -> [CoinCatalogItem] { cache.load() }
}

private struct OfflineAccountDependencies: AccountAuthServicing, AppleSignInServicing, UserProfileRepository, UserPreferencesRepository, SelectedCoinPreferenceServicing, AccountDeletionServicing {
    func restoredSession() async throws -> GenerationAccountSession { throw AccountDependencyError.unavailable }
    func signInWithApple(identityToken: String, rawNonce: String) async throws -> GenerationAccountSession { throw AccountDependencyError.unavailable }
    func sessionChanges() -> AsyncStream<AccountAuthEvent> { AsyncStream { $0.finish() } }
    func signOut() async throws -> ServerSessionRevocation { throw AccountDependencyError.unavailable }
    func signIn() async throws -> AppleSignInCredential { throw AccountDependencyError.unavailable }
    func fetch(userID: UUID) async throws -> UserProfile { throw AccountDependencyError.unavailable }
    func saveInitialDisplayName(_ displayName: String, userID: UUID) async throws -> UserProfile { throw AccountDependencyError.unavailable }
    func fetch(userID: UUID) async throws -> UserPreferences { throw AccountDependencyError.unavailable }
    func update(_ preferences: UserPreferences) async throws -> UserPreferences { throw AccountDependencyError.unavailable }
    func bootstrap(userID: UUID, guestPreferences: LocalPreferences) async throws -> PreferenceBootstrapResult { throw AccountDependencyError.unavailable }
    func fetchSelectedCoinID(for userID: UUID, generationID: UUID) async throws -> UUID? { throw AccountDependencyError.unavailable }
    func updateSelectedCoinID(_ coinID: UUID?, for userID: UUID, generationID: UUID) async throws { throw AccountDependencyError.unavailable }
    func deleteAccount(authorizationCode: String, requestID: UUID) async throws -> AccountDeletionResult { throw AccountDependencyError.unavailable }
}
