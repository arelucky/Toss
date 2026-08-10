import XCTest
@testable import Toss

@MainActor
final class AccountViewModelTests: XCTestCase {
    func testGuestAndAuthenticatedPresentationUsesCloudNameAndFallback() async {
        let guest = makeSubject()
        XCTAssertEqual(guest.viewModel.presentation, .guest)

        let named = makeSubject(session: .authenticated(userID: guest.userID), profileName: "Ada")
        await named.viewModel.refreshAuthenticatedAccount()
        XCTAssertEqual(named.viewModel.presentation, .authenticated(displayName: "Ada"))

        let fallback = makeSubject(session: .authenticated(userID: guest.userID), profileName: nil)
        await fallback.viewModel.refreshAuthenticatedAccount()
        XCTAssertEqual(fallback.viewModel.presentation, .authenticated(displayName: "Toss Account"))
    }

    func testCancelledLoginKeepsGuestWithoutNotice() async {
        let subject = makeSubject(appleResult: .failure(AppleSignInError.cancelled))
        await subject.viewModel.signIn()
        XCTAssertEqual(subject.viewModel.presentation, .guest)
        XCTAssertNil(subject.viewModel.notice)
    }

    func testFailedLoginKeepsGuestAndShowsInlineNotice() async {
        let subject = makeSubject(authSignIn: .failure(ViewModelTestError.expected))
        await subject.viewModel.signIn()
        XCTAssertEqual(subject.viewModel.presentation, .guest)
        XCTAssertEqual(subject.viewModel.notice, .signInFailed)
    }

    func testRepeatedLoginIsIgnoredWhileFirstIsInFlight() async {
        let subject = makeSubject()
        subject.auth.shouldSuspendSignIn = true
        let first = Task { await subject.viewModel.signIn() }
        await subject.auth.waitForSignInCall()
        await subject.viewModel.signIn()
        XCTAssertEqual(subject.auth.signInCallCount, 1)
        subject.auth.completeSignIn()
        await first.value
    }

    func testPreferenceTogglesApplyThroughCorrectDependency() async {
        let subject = makeSubject(session: .authenticated(userID: UUID()))
        await subject.viewModel.setSoundEnabled(false)
        await subject.viewModel.setHapticEnabled(false)
        XCTAssertEqual(subject.feedback.applied.last, .init(soundEnabled: false, hapticEnabled: false))
        XCTAssertEqual(subject.preferences.updated.last?.soundEnabled, false)
        XCTAssertEqual(subject.preferences.updated.last?.hapticEnabled, false)
    }

    func testSuccessfulAndDeferredLogoutEnterGuestAndRestoreGuestPreferences() async {
        for result in [ServerSessionRevocation.revoked, .deferred] {
            let subject = makeSubject(session: .authenticated(userID: UUID()), signOut: .success(result))
            subject.local.saveGuest(.init(soundEnabled: false, hapticEnabled: true))
            await subject.viewModel.signOut()
            XCTAssertEqual(subject.viewModel.presentation, .guest)
            XCTAssertEqual(subject.feedback.applied.last, .init(soundEnabled: false, hapticEnabled: true))
            XCTAssertEqual(subject.viewModel.notice, result == .deferred ? .remoteSignOutDeferred : nil)
        }
    }

    func testUnsafeLogoutFailureKeepsAuthenticatedState() async {
        let userID = UUID()
        let subject = makeSubject(session: .authenticated(userID: userID), signOut: .failure(ViewModelTestError.expected))
        await subject.viewModel.signOut()
        XCTAssertEqual(subject.viewModel.presentation, .authenticated(displayName: "Toss Account"))
        XCTAssertEqual(subject.viewModel.notice, .signOutFailed)
    }

    func testStartRunsRestoreAndObservationOnlyOnce() async {
        let subject = makeSubject()
        subject.auth.shouldSuspendRestore = true
        let first = Task { await subject.viewModel.start() }
        await subject.auth.waitForRestoreCall()
        await subject.viewModel.start()
        XCTAssertEqual(subject.auth.restoreCallCount, 1)
        subject.auth.completeRestore()
        await first.value
        XCTAssertEqual(subject.auth.observationCreationCount, 1)
    }

    func testRetiredGenerationEventCannotChangePresentation() {
        let userID = UUID()
        let subject = makeSubject(session: .authenticated(userID: userID))
        subject.accountStore.applyAuthEvent(.init(generationID: .init(), kind: .signedOut, session: .guest))
        XCTAssertEqual(subject.viewModel.presentation, .authenticated(displayName: "Toss Account"))
    }

    func testDeletionConfirmationCanBeCancelledWithoutCallingServices() {
        let subject = makeSubject(session: .authenticated(userID: UUID()))
        subject.viewModel.requestAccountDeletion()
        XCTAssertTrue(subject.viewModel.isDeleteConfirmationPresented)

        subject.viewModel.cancelAccountDeletion()

        XCTAssertFalse(subject.viewModel.isDeleteConfirmationPresented)
        XCTAssertEqual(subject.deletion.callCount, 0)
    }

    func testManualRequiredDeletionEntersGuestClearsRequestAndRestoresGuestPreferences() async {
        let userID = UUID()
        let subject = makeSubject(
            session: .authenticated(userID: userID),
            deletion: .success(.init(deleted: true, appleRevocation: .manualRequired))
        )
        subject.local.saveGuest(.init(soundEnabled: false, hapticEnabled: true))
        subject.local.cache(.init(soundEnabled: true, hapticEnabled: false), for: userID)

        await subject.viewModel.confirmAccountDeletion()

        XCTAssertEqual(subject.viewModel.presentation, .guest)
        XCTAssertEqual(subject.viewModel.notice, .appleRevocationManualRequired)
        XCTAssertNil(subject.requestStore.current)
        XCTAssertNil(subject.local.cachedPreferences(for: userID))
        XCTAssertEqual(subject.feedback.applied.last, .init(soundEnabled: false, hapticEnabled: true))
    }

    func testFailedDeletionKeepsAccountAndReusesRequestID() async {
        let userID = UUID()
        let subject = makeSubject(
            session: .authenticated(userID: userID),
            deletion: .failure(ViewModelTestError.expected)
        )

        await subject.viewModel.confirmAccountDeletion()
        let firstRequestID = subject.requestStore.current
        await subject.viewModel.confirmAccountDeletion()

        XCTAssertEqual(subject.viewModel.presentation, .authenticated(displayName: "Toss Account"))
        XCTAssertEqual(subject.viewModel.notice, .accountDeletionFailed)
        XCTAssertEqual(subject.deletion.requestIDs, [firstRequestID, firstRequestID].compactMap { $0 })
    }

    private func makeSubject(
        session: AccountSession = .guest,
        profileName: String? = nil,
        appleResult: Result<AppleSignInCredential, Error> = .success(.init(
            identityToken: "fictional-identity-token",
            authorizationCode: "fictional-authorization-code",
            rawNonce: "fictional-raw-nonce",
            displayName: nil
        )),
        authSignIn: Result<AccountSession, Error>? = nil,
        signOut: Result<ServerSessionRevocation, Error> = .success(.revoked),
        deletion: Result<AccountDeletionResult, Error> = .failure(AccountDependencyError.unavailable)
    ) -> Subject {
        let userID = UUID()
        let resolvedSession = authSignIn ?? .success(.authenticated(userID: session.userID ?? userID))
        let auth = AccountAuthServiceDouble(signInResult: resolvedSession, signOutResult: signOut)
        let accountStore = AccountStore(authService: auth, initialSession: session)
        let profile = ViewModelProfileRepository(userID: session.userID ?? userID, displayName: profileName)
        let preferences = ViewModelPreferencesRepository(userID: session.userID ?? userID)
        let local = LocalPreferencesStore(store: ViewModelKeyValueStore())
        let feedback = ViewModelFeedback()
        let deletionService = AccountDeletionServiceDouble(result: deletion)
        let requestStore = AccountDeletionRequestStore(store: ViewModelKeyValueStore())
        let sync = AccountSyncCoordinator(
            profileRepository: profile,
            preferencesRepository: preferences,
            localPreferences: local,
            feedback: feedback,
            pendingNameStore: accountStore
        )
        let viewModel = AccountViewModel(
            accountStore: accountStore,
            appleSignInService: AppleSignInServiceDouble(result: appleResult),
            deletionService: deletionService,
            deletionRequestStore: requestStore,
            profileRepository: profile,
            syncCoordinator: sync,
            localPreferences: local,
            feedbackPreferences: feedback
        )
        return Subject(userID: userID, auth: auth, accountStore: accountStore, profile: profile, preferences: preferences, deletion: deletionService, requestStore: requestStore, local: local, feedback: feedback, viewModel: viewModel)
    }
}

private struct Subject {
    let userID: UUID
    let auth: AccountAuthServiceDouble
    let accountStore: AccountStore
    let profile: ViewModelProfileRepository
    let preferences: ViewModelPreferencesRepository
    let deletion: AccountDeletionServiceDouble
    let requestStore: AccountDeletionRequestStore
    let local: LocalPreferencesStore
    let feedback: ViewModelFeedback
    let viewModel: AccountViewModel
}

private enum ViewModelTestError: Error { case expected }

private final class ViewModelProfileRepository: UserProfileRepository {
    let userID: UUID
    let displayName: String?
    init(userID: UUID, displayName: String?) { self.userID = userID; self.displayName = displayName }
    func fetch(userID: UUID) async throws -> UserProfile {
        .init(id: userID, displayName: displayName, status: .active, createdAt: .distantPast, updatedAt: .distantPast)
    }
    func saveInitialDisplayName(_ displayName: String, userID: UUID) async throws -> UserProfile { try await fetch(userID: userID) }
}

private final class ViewModelPreferencesRepository: UserPreferencesRepository {
    let userID: UUID
    var updated: [UserPreferences] = []
    init(userID: UUID) { self.userID = userID }
    func fetch(userID: UUID) async throws -> UserPreferences { fixture(userID: userID) }
    func update(_ preferences: UserPreferences) async throws -> UserPreferences { updated.append(preferences); return preferences }
    func bootstrap(userID: UUID, guestPreferences: LocalPreferences) async throws -> PreferenceBootstrapResult { .existingAccount(fixture(userID: userID)) }
    private func fixture(userID: UUID) -> UserPreferences { .init(userID: userID, soundEnabled: true, hapticEnabled: true, createdAt: .distantPast, updatedAt: .distantPast) }
}

@MainActor
private final class ViewModelFeedback: FeedbackPreferenceApplying {
    var applied: [LocalPreferences] = []
    func apply(_ preferences: LocalPreferences) { applied.append(preferences) }
}

private final class ViewModelKeyValueStore: PreferencesKeyValueStoring {
    var values: [String: Any] = [:]
    func object(forKey key: String) -> Any? { values[key] }
    func set(_ value: Any?, forKey key: String) { values[key] = value }
}

private extension AccountSession {
    var userID: UUID? { if case let .authenticated(userID) = self { userID } else { nil } }
}
