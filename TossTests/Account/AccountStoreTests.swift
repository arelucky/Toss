import Combine
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
        XCTAssertEqual(store.consumePendingDisplayName(for: userID), "Ada Lovelace")
        XCTAssertNil(store.consumePendingDisplayName(for: userID))
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
        await authService.waitForObservation()
        let sessionChanged = expectation(description: "Auth event updates the account session")
        let observation = store.$session
            .dropFirst()
            .first { $0 == .authenticated(userID: userID) }
            .sink { _ in sessionChanged.fulfill() }
        authService.yield(.authenticated(userID: userID))
        await fulfillment(of: [sessionChanged], timeout: 1)
        withExtendedLifetime(observation) {}

        XCTAssertEqual(store.session, .authenticated(userID: userID))
        store.stopObservingAuthState()
    }

    @MainActor
    func testStartingObservationTwiceKeepsOnlyOneConsumer() async {
        let authService = AccountAuthServiceDouble()
        let store = AccountStore(authService: authService)

        store.startObservingAuthState()
        await authService.waitForObservationCount(1)
        store.startObservingAuthState()
        await authService.waitForObservationCount(1)

        XCTAssertEqual(authService.activeObservationCount, 1)
        store.stopObservingAuthState()
        await authService.waitForObservationCount(0)
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

    @MainActor
    func testLateRestoreCannotOverwriteNewerLogin() async {
        let restoredUserID = UUID()
        let loginUserID = UUID()
        let authService = AccountAuthServiceDouble(
            restoredSessionResult: .success(.authenticated(userID: restoredUserID)),
            signInResult: .success(.authenticated(userID: loginUserID))
        )
        authService.shouldSuspendRestore = true
        let store = AccountStore(authService: authService)
        let restore = Task { await store.restoreSession() }
        await authService.waitForRestoreCall()

        await store.signInWithApple(using: AppleSignInServiceDouble(result: .success(.fixture())))
        authService.completeRestore()
        await restore.value

        XCTAssertEqual(store.session, .authenticated(userID: loginUserID))
    }

    @MainActor
    func testLogoutRequestedDuringLoginRemainsFinalGuest() async {
        let authService = AccountAuthServiceDouble(
            signInResult: .success(.authenticated(userID: UUID())),
            signOutResult: .success(.revoked)
        )
        authService.shouldSuspendSignIn = true
        let store = AccountStore(authService: authService)
        let login = Task { await store.signInWithApple(using: AppleSignInServiceDouble(result: .success(.fixture()))) }
        await authService.waitForSignInCall()

        await store.signOut()
        authService.completeSignIn()
        await login.value

        XCTAssertEqual(store.session, .guest)
        XCTAssertEqual(authService.operationLog.last, "login-finish")
    }

    @MainActor
    func testLateRestoreCannotOverwriteCompletedLogout() async {
        let authService = AccountAuthServiceDouble(
            restoredSessionResult: .success(.authenticated(userID: UUID())),
            signOutResult: .success(.revoked)
        )
        authService.shouldSuspendRestore = true
        let store = AccountStore(authService: authService, initialSession: .authenticated(userID: UUID()))
        let restore = Task { await store.restoreSession() }
        await authService.waitForRestoreCall()

        await store.signOut()
        authService.completeRestore()
        await restore.value

        XCTAssertEqual(store.session, .guest)
    }

    @MainActor
    func testLateAuthenticatedEventAfterLogoutIsIgnored() async {
        let authService = AccountAuthServiceDouble(signOutResult: .success(.revoked))
        let store = AccountStore(authService: authService, initialSession: .authenticated(userID: UUID()))
        store.startObservingAuthState()
        await authService.waitForObservation()

        await store.signOut()
        authService.yield(.authenticated(userID: UUID()))
        await Task.yield()

        XCTAssertEqual(store.session, .guest)
    }

    @MainActor
    func testAuthenticatedEventDuringLogoutCannotChangeSession() async {
        let originalUserID = UUID()
        let authService = AccountAuthServiceDouble(signOutResult: .success(.revoked))
        authService.shouldSuspendSignOut = true
        let store = AccountStore(authService: authService, initialSession: .authenticated(userID: originalUserID))
        store.startObservingAuthState()
        await authService.waitForObservation()
        let logout = Task { await store.signOut() }
        await authService.waitForSignOutCall()

        authService.yield(.authenticated(userID: UUID()))
        await Task.yield()
        XCTAssertEqual(store.session, .authenticated(userID: originalUserID))

        authService.completeSignOut()
        await logout.value
        XCTAssertEqual(store.session, .guest)
    }

    @MainActor
    func testRepeatedLoginDoesNotCreateCompetingCalls() async {
        let authService = AccountAuthServiceDouble(signInResult: .success(.authenticated(userID: UUID())))
        authService.shouldSuspendSignIn = true
        let store = AccountStore(authService: authService)
        let first = Task { await store.signInWithApple(using: AppleSignInServiceDouble(result: .success(.fixture()))) }
        await authService.waitForSignInCall()

        let second = Task { await store.signInWithApple(using: AppleSignInServiceDouble(result: .success(.fixture()))) }
        await Task.yield()
        XCTAssertEqual(authService.signInCallCount, 1)

        authService.completeSignIn()
        await first.value
        await second.value
    }

    @MainActor
    func testPendingNameCannotBeConsumedByDifferentUser() async {
        let userID = UUID()
        let authService = AccountAuthServiceDouble(signInResult: .success(.authenticated(userID: userID)))
        let store = AccountStore(authService: authService)
        await store.signInWithApple(
            using: AppleSignInServiceDouble(result: .success(.fixture(displayName: " Ada ")))
        )

        XCTAssertNil(store.consumePendingDisplayName(for: UUID()))
        XCTAssertEqual(store.consumePendingDisplayName(for: userID), "Ada")
    }

    @MainActor
    func testLaterAuthorizationWithoutNameDoesNotReusePreviousName() async {
        let userID = UUID()
        let authService = AccountAuthServiceDouble(signInResult: .success(.authenticated(userID: userID)))
        let store = AccountStore(authService: authService)
        await store.signInWithApple(
            using: AppleSignInServiceDouble(result: .success(.fixture(displayName: "Ada")))
        )

        await store.signInWithApple(using: AppleSignInServiceDouble(result: .success(.fixture(displayName: nil))))

        XCTAssertNil(store.consumePendingDisplayName(for: userID))
    }

    @MainActor
    func testCancelledLoginClearsPreviousPendingName() async {
        let userID = UUID()
        let authService = AccountAuthServiceDouble(signInResult: .success(.authenticated(userID: userID)))
        let store = AccountStore(authService: authService)
        await store.signInWithApple(
            using: AppleSignInServiceDouble(result: .success(.fixture(displayName: "Ada")))
        )

        await store.signInWithApple(using: AppleSignInServiceDouble(result: .failure(AppleSignInError.cancelled)))

        XCTAssertNil(store.consumePendingDisplayName(for: userID))
    }

    @MainActor
    func testAuthStreamAccountSwitchInvalidatesPendingName() async {
        let userID = UUID()
        let authService = AccountAuthServiceDouble(signInResult: .success(.authenticated(userID: userID)))
        let store = AccountStore(authService: authService)
        await store.signInWithApple(
            using: AppleSignInServiceDouble(result: .success(.fixture(displayName: "Ada")))
        )
        store.startObservingAuthState()
        await authService.waitForObservation()

        let replacementUserID = UUID()
        let sessionChanged = expectation(description: "Auth event updates the account session")
        let observation = store.$session
            .dropFirst()
            .first { $0 == .authenticated(userID: replacementUserID) }
            .sink { _ in sessionChanged.fulfill() }
        authService.yield(.authenticated(userID: replacementUserID))
        await fulfillment(of: [sessionChanged], timeout: 1)
        withExtendedLifetime(observation) {}

        XCTAssertNil(store.consumePendingDisplayName(for: userID))
    }

    @MainActor
    func testCancellationAfterAppleCredentialDoesNotCallAuthBackend() async {
        let authService = AccountAuthServiceDouble()
        let store = AccountStore(authService: authService)
        let task = Task {
            await store.signInWithApple(
                using: CancellingAppleSignInServiceDouble(credential: .fixture(displayName: "Ada"))
            )
        }

        await task.value

        XCTAssertEqual(authService.signInCallCount, 0)
        XCTAssertEqual(store.session, .guest)
        XCTAssertNil(store.error)
        XCTAssertNil(store.consumePendingDisplayName(for: UUID()))
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

private extension AppleSignInCredential {
    static func fixture(displayName: String? = nil) -> Self {
        Self(
            identityToken: "fictional-identity-token",
            authorizationCode: "fictional-authorization-code",
            rawNonce: "fictional-raw-nonce",
            displayName: displayName
        )
    }
}
