import XCTest
@testable import Toss

final class AccountStoreTests: XCTestCase {
    @MainActor
    func testValidConfigurationBuildsOneSharedClientBackedGraph() throws {
        let configuration = SupabaseConfiguration(
            url: try XCTUnwrap(URL(string: "http://127.0.0.1:54321")),
            publishableKey: "public-test-key"
        )

        let dependencies = AppDependencies.live(configuration: configuration)

        XCTAssertNotNil(dependencies.environment)
        XCTAssertEqual(dependencies.session, .guest)
        XCTAssertEqual(Set(dependencies.clientEnvironmentIdentities).count, 1)
        XCTAssertEqual(dependencies.clientEnvironmentIdentities.count, 4)
    }

    @MainActor
    func testMissingConfigurationBuildsOfflineGuestGraph() {
        let dependencies = AppDependencies.live(configuration: nil)

        XCTAssertNil(dependencies.environment)
        XCTAssertEqual(dependencies.session, .guest)
    }

    @MainActor
    func testBlankConfigurationBuildsOfflineGuestGraph() throws {
        let bundle = try makeBundle(info: [
            "TossSupabaseURL": "   ",
            "TossSupabasePublishableKey": "public-test-key"
        ])

        let dependencies = AppDependencies.live(bundle: bundle)

        XCTAssertNil(dependencies.environment)
        XCTAssertEqual(dependencies.session, .guest)
    }

    @MainActor
    func testOfflineDependenciesFailOnlyWhenAnOperationIsRequested() async {
        let dependencies = AppDependencies.live(configuration: nil)

        do {
            _ = try await dependencies.authService.restoredSession()
            XCTFail("Expected the offline account dependency to be unavailable")
        } catch {
            XCTAssertEqual(error as? AccountDependencyError, .unavailable)
        }
    }

    @MainActor
    func testAccountTestDoublesConformWithoutNetworking() async throws {
        let doubles = AccountTestDoubles()

        let restoredSession = try await doubles.authService.restoredSession()

        XCTAssertEqual(restoredSession, .guest)
        XCTAssertEqual(doubles.profileRepository.callCount, 0)
        XCTAssertEqual(doubles.preferencesRepository.callCount, 0)
        XCTAssertEqual(doubles.deletionService.callCount, 0)
    }

    @MainActor
    func testRestoreTransitionsFromGuestThroughRestoringToAuthenticated() async {
        let userID = UUID()
        let authService = AccountAuthServiceDouble(restoredSessionResult: .success(.authenticated(userID: userID)))
        authService.shouldSuspendRestore = true
        let store = AccountStore(authService: authService)

        let task = Task { await store.restoreSession() }
        await authService.waitForRestoreCall()

        XCTAssertEqual(store.session, .restoring)
        authService.completeRestore()
        await task.value
        XCTAssertEqual(store.session, .authenticated(userID: userID))
    }

    @MainActor
    func testRestoreFailureReturnsToGuestWithDiagnosticError() async {
        let authService = AccountAuthServiceDouble(restoredSessionResult: .failure(TestAccountError.expected))
        authService.shouldSuspendRestore = false
        let store = AccountStore(authService: authService)

        await store.restoreSession()

        XCTAssertEqual(store.session, .guest)
        XCTAssertEqual(store.error, .restorationFailed)
    }

    @MainActor
    func testRepeatedRestoreDoesNotCreateCompetingCalls() async {
        let authService = AccountAuthServiceDouble(restoredSessionResult: .success(.guest))
        authService.shouldSuspendRestore = true
        let store = AccountStore(authService: authService)

        let first = Task { await store.restoreSession() }
        await authService.waitForRestoreCall()
        await store.restoreSession()

        XCTAssertEqual(authService.restoreCallCount, 1)
        authService.completeRestore()
        await first.value
    }

    @MainActor
    func testAppleCancellationLeavesGuestWithoutError() async {
        let authService = AccountAuthServiceDouble()
        let appleService = AppleSignInServiceDouble(result: .failure(AppleSignInError.cancelled))
        let store = AccountStore(authService: authService)

        await store.signInWithApple(using: appleService)

        XCTAssertEqual(store.session, .guest)
        XCTAssertNil(store.error)
        XCTAssertEqual(authService.signInCallCount, 0)
    }

    @MainActor
    func testLoginSuccessUsesCredentialAndAuthenticates() async {
        let userID = UUID()
        let authService = AccountAuthServiceDouble(signInResult: .success(.authenticated(userID: userID)))
        let credential = AppleSignInCredential(
            identityToken: "identity-token",
            authorizationCode: "authorization-code",
            rawNonce: "raw-nonce",
            displayName: "Ada Lovelace"
        )
        let store = AccountStore(authService: authService)

        await store.signInWithApple(using: AppleSignInServiceDouble(result: .success(credential)))

        XCTAssertEqual(store.session, .authenticated(userID: userID))
        XCTAssertEqual(authService.receivedIdentityToken, "identity-token")
        XCTAssertEqual(authService.receivedRawNonce, "raw-nonce")
        XCTAssertEqual(store.pendingDisplayName, "Ada Lovelace")
    }

    @MainActor
    func testLoginFailureReturnsToGuestWithDiagnosticError() async {
        let authService = AccountAuthServiceDouble(signInResult: .failure(TestAccountError.expected))
        let credential = AppleSignInCredential(identityToken: "token", authorizationCode: "code", rawNonce: "nonce", displayName: nil)
        let store = AccountStore(authService: authService)

        await store.signInWithApple(using: AppleSignInServiceDouble(result: .success(credential)))

        XCTAssertEqual(store.session, .guest)
        XCTAssertEqual(store.error, .signInFailed)
    }

    @MainActor
    func testAuthEventUpdatesSession() async {
        let authService = AccountAuthServiceDouble()
        let store = AccountStore(authService: authService)
        let userID = UUID()

        store.startObservingAuthState()
        await Task.yield()
        authService.yield(.authenticated(userID: userID))
        await Task.yield()

        XCTAssertEqual(store.session, .authenticated(userID: userID))
        store.stopObservingAuthState()
    }

    @MainActor
    func testStartingObservationTwiceKeepsOnlyOneConsumer() async {
        let authService = AccountAuthServiceDouble()
        let store = AccountStore(authService: authService)

        store.startObservingAuthState()
        await Task.yield()
        store.startObservingAuthState()
        await Task.yield()

        XCTAssertEqual(authService.activeObservationCount, 1)
        store.stopObservingAuthState()
        await Task.yield()
        XCTAssertEqual(authService.activeObservationCount, 0)
    }

    @MainActor
    func testSignOutSuccessReturnsToGuest() async {
        let authService = AccountAuthServiceDouble(signOutResult: .success(.deferred))
        let store = AccountStore(authService: authService, initialSession: .authenticated(userID: UUID()))

        await store.signOut()

        XCTAssertEqual(store.session, .guest)
        XCTAssertNil(store.error)
    }

    @MainActor
    func testSignOutFailureKeepsAuthenticatedSession() async {
        let userID = UUID()
        let authService = AccountAuthServiceDouble(signOutResult: .failure(TestAccountError.expected))
        let store = AccountStore(authService: authService, initialSession: .authenticated(userID: userID))

        await store.signOut()

        XCTAssertEqual(store.session, .authenticated(userID: userID))
        XCTAssertEqual(store.error, .signOutFailed)
    }

    private func makeBundle(info: [String: String]) throws -> Bundle {
        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("bundle")
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(
            fromPropertyList: info,
            format: .xml,
            options: 0
        )
        try data.write(to: bundleURL.appendingPathComponent("Info.plist"))
        addTeardownBlock { try? FileManager.default.removeItem(at: bundleURL) }
        return try XCTUnwrap(Bundle(url: bundleURL))
    }
}
