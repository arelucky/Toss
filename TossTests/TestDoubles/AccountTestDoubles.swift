import Foundation
@testable import Toss

enum TestAccountError: Error { case expected }

final class TestOperationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var suspension: CheckedContinuation<Void, Never>?
    private var startedWaiters: [CheckedContinuation<Void, Never>] = []
    private var storedIsCompleted = false

    var hasInstalledSuspension: Bool {
        lock.withLock { suspension != nil }
    }

    var isCompleted: Bool {
        lock.withLock { storedIsCompleted }
    }

    func suspend() async {
        await withCheckedContinuation { continuation in
            let result: (resumeOperation: Bool, started: [CheckedContinuation<Void, Never>]) = lock.withLock {
                if storedIsCompleted {
                    return (true, startedWaiters.removeAllAndReturn())
                }
                suspension = continuation
                return (false, startedWaiters.removeAllAndReturn())
            }
            result.started.forEach { $0.resume() }
            if result.resumeOperation { continuation.resume() }
        }
    }

    func waitUntilStarted() async {
        if lock.withLock({ suspension != nil }) { return }
        await withCheckedContinuation { continuation in
            let resumeImmediately = lock.withLock {
                if suspension != nil { return true }
                startedWaiters.append(continuation)
                return false
            }
            if resumeImmediately { continuation.resume() }
        }
    }

    func complete() {
        let continuation = lock.withLock { () -> CheckedContinuation<Void, Never>? in
            storedIsCompleted = true
            defer { suspension = nil }
            return suspension
        }
        continuation?.resume()
    }

    func tearDown() {
        complete()
        let waiters = lock.withLock { startedWaiters.removeAllAndReturn() }
        waiters.forEach { $0.resume() }
    }

    deinit {
        tearDown()
    }
}

private extension Array {
    mutating func removeAllAndReturn() -> [Element] {
        defer { removeAll() }
        return self
    }
}

final class AccountAuthServiceDouble: AccountAuthServicing {
    struct Snapshot {
        let restoreCallCount: Int
        let signInCallCount: Int
        let signOutCallCount: Int
        let activeObservationCount: Int
        let observationCreationCount: Int
        let operationLog: [String]
    }

    private var storedGenerationID = SupabaseClientGenerationID()
    var generationID: SupabaseClientGenerationID {
        get { stateLock.withLock { storedGenerationID } }
        set { stateLock.withLock { storedGenerationID = newValue } }
    }
    var currentGenerationID: SupabaseClientGenerationID { generationID }
    private let restoredSessionResult: Result<AccountSession, Error>
    private let generationRestoredSessionResult: Result<GenerationAccountSession, Error>?
    let signInResult: Result<AccountSession, Error>
    let signOutResult: Result<ServerSessionRevocation, Error>
    private let stateLock = NSLock()
    private var storedShouldSuspendRestore = false
    private var storedShouldSuspendSignIn = false
    private var storedShouldSuspendSignOut = false
    private var storedRestoreCallCount = 0
    private var storedSignInCallCount = 0
    private var storedSignOutCallCount = 0
    private var storedOperationLog: [String] = []
    private var storedReceivedIdentityToken: String?
    private var storedReceivedRawNonce: String?
    private var storedActiveObservationCount = 0
    private var storedObservationCreationCount = 0
    private let restoreGate = TestOperationGate()
    private let signInGate = TestOperationGate()
    private let signOutGate = TestOperationGate()
    private var observationContinuations: [UUID: AsyncStream<AccountAuthEvent>.Continuation] = [:]
    private var observationCountWaiters: [UUID: (expected: Int, continuation: CheckedContinuation<Void, Never>)] = [:]

    var activeObservationCount: Int {
        stateLock.withLock { storedActiveObservationCount }
    }
    var observationCreationCount: Int {
        stateLock.withLock { storedObservationCreationCount }
    }

    var shouldSuspendRestore: Bool {
        get { stateLock.withLock { storedShouldSuspendRestore } }
        set { stateLock.withLock { storedShouldSuspendRestore = newValue } }
    }
    var shouldSuspendSignIn: Bool {
        get { stateLock.withLock { storedShouldSuspendSignIn } }
        set { stateLock.withLock { storedShouldSuspendSignIn = newValue } }
    }
    var shouldSuspendSignOut: Bool {
        get { stateLock.withLock { storedShouldSuspendSignOut } }
        set { stateLock.withLock { storedShouldSuspendSignOut = newValue } }
    }
    var restoreCallCount: Int { stateLock.withLock { storedRestoreCallCount } }
    var signInCallCount: Int { stateLock.withLock { storedSignInCallCount } }
    var signOutCallCount: Int { stateLock.withLock { storedSignOutCallCount } }
    var operationLog: [String] { stateLock.withLock { storedOperationLog } }
    var receivedIdentityToken: String? { stateLock.withLock { storedReceivedIdentityToken } }
    var receivedRawNonce: String? { stateLock.withLock { storedReceivedRawNonce } }
    var snapshot: Snapshot {
        stateLock.withLock {
            Snapshot(
                restoreCallCount: storedRestoreCallCount,
                signInCallCount: storedSignInCallCount,
                signOutCallCount: storedSignOutCallCount,
                activeObservationCount: storedActiveObservationCount,
                observationCreationCount: storedObservationCreationCount,
                operationLog: storedOperationLog
            )
        }
    }

    init(
        restoredSessionResult: Result<AccountSession, Error> = .success(.guest),
        signInResult: Result<AccountSession, Error> = .success(.guest),
        signOutResult: Result<ServerSessionRevocation, Error> = .success(.revoked)
    ) {
        self.restoredSessionResult = restoredSessionResult
        generationRestoredSessionResult = nil
        self.signInResult = signInResult
        self.signOutResult = signOutResult
    }

    init(
        generationRestoredSessionResult: Result<GenerationAccountSession, Error>,
        signInResult: Result<AccountSession, Error> = .success(.guest),
        signOutResult: Result<ServerSessionRevocation, Error> = .success(.revoked)
    ) {
        restoredSessionResult = .success(.guest)
        self.generationRestoredSessionResult = generationRestoredSessionResult
        self.signInResult = signInResult
        self.signOutResult = signOutResult
    }

    func restoredSession() async throws -> GenerationAccountSession {
        let shouldSuspend = stateLock.withLock {
            storedRestoreCallCount += 1
            storedOperationLog.append("restore-start")
            return storedShouldSuspendRestore
        }
        if shouldSuspend { await restoreGate.suspend() }
        stateLock.withLock { storedOperationLog.append("restore-finish") }
        if let generationRestoredSessionResult {
            return try generationRestoredSessionResult.get()
        }
        return GenerationAccountSession(
            generationID: generationID,
            session: try restoredSessionResult.get()
        )
    }

    func signInWithApple(identityToken: String, rawNonce: String) async throws -> GenerationAccountSession {
        let shouldSuspend = stateLock.withLock {
            storedSignInCallCount += 1
            storedOperationLog.append("login-start")
            storedReceivedIdentityToken = identityToken
            storedReceivedRawNonce = rawNonce
            return storedShouldSuspendSignIn
        }
        if shouldSuspend { await signInGate.suspend() }
        stateLock.withLock { storedOperationLog.append("login-finish") }
        return GenerationAccountSession(
            generationID: generationID,
            session: try signInResult.get()
        )
    }

    func sessionChanges() -> AsyncStream<AccountAuthEvent> {
        let id = UUID()
        return AsyncStream { continuation in
            updateObservations {
                storedActiveObservationCount += 1
                storedObservationCreationCount += 1
                observationContinuations[id] = continuation
            }
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.updateObservations {
                    guard self.observationContinuations.removeValue(forKey: id) != nil else { return }
                    self.storedActiveObservationCount -= 1
                }
            }
        }
    }

    func isCurrentGeneration(_ generationID: SupabaseClientGenerationID) -> Bool {
        self.generationID == generationID
    }

    func signOut() async throws -> ServerSessionRevocation {
        let shouldSuspend = stateLock.withLock {
            storedSignOutCallCount += 1
            storedOperationLog.append("logout-start")
            return storedShouldSuspendSignOut
        }
        if shouldSuspend { await signOutGate.suspend() }
        stateLock.withLock { storedOperationLog.append("logout-finish") }
        return try signOutResult.get()
    }

    func waitForRestoreCall() async {
        if restoreCallCount > 0, !shouldSuspendRestore { return }
        await restoreGate.waitUntilStarted()
    }

    func completeRestore() {
        restoreGate.complete()
    }

    func waitForSignInCall() async {
        if signInCallCount > 0, !shouldSuspendSignIn { return }
        await signInGate.waitUntilStarted()
    }

    func completeSignIn() {
        signInGate.complete()
    }

    func waitForSignOutCall() async {
        if signOutCallCount > 0, !shouldSuspendSignOut { return }
        await signOutGate.waitUntilStarted()
    }

    func completeSignOut() {
        signOutGate.complete()
    }

    func waitForObservation() async {
        await waitForObservationCount(1)
    }

    func waitForObservationCount(_ expected: Int) async {
        if activeObservationCount == expected { return }
        await withCheckedContinuation { continuation in
            let id = UUID()
            var resumeImmediately = false
            stateLock.withLock {
                if storedActiveObservationCount == expected {
                    resumeImmediately = true
                } else {
                    observationCountWaiters[id] = (expected, continuation)
                }
            }
            if resumeImmediately { continuation.resume() }
        }
    }

    func yield(_ session: AccountSession) {
        let kind: AccountAuthEventKind = session == .guest ? .signedOut : .userUpdated
        yield(AccountAuthEvent(generationID: generationID, kind: kind, session: session))
    }

    func yield(_ event: AccountAuthEvent) {
        let continuations = stateLock.withLock { Array(observationContinuations.values) }
        continuations.forEach { $0.yield(event) }
    }

    private func updateObservations(_ update: () -> Void) {
        let continuations: [CheckedContinuation<Void, Never>] = stateLock.withLock {
            update()
            let matchingIDs = observationCountWaiters.compactMap { id, waiter in
                waiter.expected == storedActiveObservationCount ? id : nil
            }
            return matchingIDs.compactMap { observationCountWaiters.removeValue(forKey: $0)?.continuation }
        }
        continuations.forEach { $0.resume() }
    }
}

struct AppleSignInServiceDouble: AppleSignInServicing {
    let result: Result<AppleSignInCredential, Error>
    func signIn() async throws -> AppleSignInCredential { try result.get() }
}

struct CancellingAppleSignInServiceDouble: AppleSignInServicing {
    let credential: AppleSignInCredential

    func signIn() async throws -> AppleSignInCredential {
        withUnsafeCurrentTask { $0?.cancel() }
        return credential
    }
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
