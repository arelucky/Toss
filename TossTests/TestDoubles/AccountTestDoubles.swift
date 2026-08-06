import Foundation
@testable import Toss

enum TestAccountError: Error { case expected }

final class AccountAuthServiceDouble: AccountAuthServicing {
    var restoredSessionResult: Result<AccountSession, Error>
    var signInResult: Result<AccountSession, Error>
    var signOutResult: Result<ServerSessionRevocation, Error>
    var shouldSuspendRestore = false
    var shouldSuspendSignIn = false
    var shouldSuspendSignOut = false
    private(set) var restoreCallCount = 0
    private(set) var signInCallCount = 0
    private(set) var signOutCallCount = 0
    private(set) var operationLog: [String] = []
    private(set) var receivedIdentityToken: String?
    private(set) var receivedRawNonce: String?
    private let observationLock = NSLock()
    private var storedActiveObservationCount = 0
    private var restoreContinuation: CheckedContinuation<Void, Never>?
    private var restoreCalledContinuation: CheckedContinuation<Void, Never>?
    private var signInContinuations: [CheckedContinuation<Void, Never>] = []
    private var signInCalledContinuation: CheckedContinuation<Void, Never>?
    private var signOutContinuation: CheckedContinuation<Void, Never>?
    private var signOutCalledContinuation: CheckedContinuation<Void, Never>?
    private var observationContinuations: [UUID: AsyncStream<AccountSession>.Continuation] = [:]
    private var observationCountWaiters: [UUID: (expected: Int, continuation: CheckedContinuation<Void, Never>)] = [:]

    var activeObservationCount: Int {
        observationLock.withLock { storedActiveObservationCount }
    }

    init(
        restoredSessionResult: Result<AccountSession, Error> = .success(.guest),
        signInResult: Result<AccountSession, Error> = .success(.guest),
        signOutResult: Result<ServerSessionRevocation, Error> = .success(.revoked)
    ) {
        self.restoredSessionResult = restoredSessionResult
        self.signInResult = signInResult
        self.signOutResult = signOutResult
    }

    func restoredSession() async throws -> AccountSession {
        restoreCallCount += 1
        operationLog.append("restore-start")
        if shouldSuspendRestore {
            await withCheckedContinuation {
                restoreContinuation = $0
                signalRestoreStarted()
            }
        } else {
            signalRestoreStarted()
        }
        operationLog.append("restore-finish")
        return try restoredSessionResult.get()
    }

    func signInWithApple(identityToken: String, rawNonce: String) async throws -> AccountSession {
        signInCallCount += 1
        operationLog.append("login-start")
        receivedIdentityToken = identityToken
        receivedRawNonce = rawNonce
        signalSignInStarted()
        if shouldSuspendSignIn {
            await withCheckedContinuation { signInContinuations.append($0) }
        }
        operationLog.append("login-finish")
        return try signInResult.get()
    }

    func sessionChanges() -> AsyncStream<AccountSession> {
        let id = UUID()
        return AsyncStream { continuation in
            updateObservations {
                storedActiveObservationCount += 1
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

    func signOut() async throws -> ServerSessionRevocation {
        signOutCallCount += 1
        operationLog.append("logout-start")
        signalSignOutStarted()
        if shouldSuspendSignOut {
            await withCheckedContinuation { signOutContinuation = $0 }
        }
        operationLog.append("logout-finish")
        return try signOutResult.get()
    }

    func waitForRestoreCall() async {
        if restoreCallCount > 0 { return }
        await withCheckedContinuation { restoreCalledContinuation = $0 }
    }

    func completeRestore() {
        restoreContinuation?.resume()
        restoreContinuation = nil
    }

    func waitForSignInCall() async {
        if signInCallCount > 0 { return }
        await withCheckedContinuation { signInCalledContinuation = $0 }
    }

    func completeSignIn() {
        let continuations = signInContinuations
        signInContinuations.removeAll()
        continuations.forEach { $0.resume() }
    }

    func waitForSignOutCall() async {
        if signOutCallCount > 0 { return }
        await withCheckedContinuation { signOutCalledContinuation = $0 }
    }

    func completeSignOut() {
        signOutContinuation?.resume()
        signOutContinuation = nil
    }

    func waitForObservation() async {
        await waitForObservationCount(1)
    }

    func waitForObservationCount(_ expected: Int) async {
        if activeObservationCount == expected { return }
        await withCheckedContinuation { continuation in
            let id = UUID()
            var resumeImmediately = false
            observationLock.withLock {
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
        let continuations = observationLock.withLock { Array(observationContinuations.values) }
        continuations.forEach { $0.yield(session) }
    }

    private func signalRestoreStarted() {
        restoreCalledContinuation?.resume()
        restoreCalledContinuation = nil
    }

    private func signalSignInStarted() {
        signInCalledContinuation?.resume()
        signInCalledContinuation = nil
    }

    private func signalSignOutStarted() {
        signOutCalledContinuation?.resume()
        signOutCalledContinuation = nil
    }

    private func updateObservations(_ update: () -> Void) {
        let continuations: [CheckedContinuation<Void, Never>] = observationLock.withLock {
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
