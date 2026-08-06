import Foundation
@testable import Toss

enum TestAccountError: Error { case expected }

final class AccountAuthServiceDouble: AccountAuthServicing {
    var restoredSessionResult: Result<AccountSession, Error>
    var signInResult: Result<AccountSession, Error>
    var signOutResult: Result<ServerSessionRevocation, Error>
    var shouldSuspendRestore = false
    private(set) var restoreCallCount = 0
    private(set) var signInCallCount = 0
    private(set) var receivedIdentityToken: String?
    private(set) var receivedRawNonce: String?
    private(set) var activeObservationCount = 0
    private var restoreContinuation: CheckedContinuation<Void, Never>?
    private var restoreCalledContinuation: CheckedContinuation<Void, Never>?
    private var observationContinuations: [UUID: AsyncStream<AccountSession>.Continuation] = [:]

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
        if shouldSuspendRestore {
            await withCheckedContinuation {
                restoreContinuation = $0
                signalRestoreStarted()
            }
        } else {
            signalRestoreStarted()
        }
        return try restoredSessionResult.get()
    }

    func signInWithApple(identityToken: String, rawNonce: String) async throws -> AccountSession {
        signInCallCount += 1
        receivedIdentityToken = identityToken
        receivedRawNonce = rawNonce
        return try signInResult.get()
    }

    func sessionChanges() -> AsyncStream<AccountSession> {
        let id = UUID()
        return AsyncStream { continuation in
            activeObservationCount += 1
            observationContinuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                self?.observationContinuations[id] = nil
                self?.activeObservationCount -= 1
            }
        }
    }

    func signOut() async throws -> ServerSessionRevocation { try signOutResult.get() }

    func waitForRestoreCall() async {
        if restoreCallCount > 0 { return }
        await withCheckedContinuation { restoreCalledContinuation = $0 }
    }

    func completeRestore() {
        restoreContinuation?.resume()
        restoreContinuation = nil
    }

    func yield(_ session: AccountSession) {
        observationContinuations.values.forEach { $0.yield(session) }
    }

    private func signalRestoreStarted() {
        restoreCalledContinuation?.resume()
        restoreCalledContinuation = nil
    }
}

struct AppleSignInServiceDouble: AppleSignInServicing {
    let result: Result<AppleSignInCredential, Error>
    func signIn() async throws -> AppleSignInCredential { try result.get() }
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
