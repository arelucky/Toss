import Combine
import Foundation

enum AccountStoreError: Error, Equatable {
    case restorationFailed
    case signInFailed
    case signOutFailed
}

private struct PendingDisplayName: Equatable {
    let userID: UUID
    let displayName: String
}

@MainActor
final class AccountStore: ObservableObject {
    private enum LifecycleState: Equatable {
        case idle
        case restoring(UInt64)
        case signingIn(UInt64)
        case signingOut(UInt64)
        case signedOut(UInt64)
    }

    @Published private(set) var session: AccountSession
    @Published private(set) var error: AccountStoreError?
    private var pendingDisplayName: PendingDisplayName?

    private let authService: any AccountAuthServicing
    private var authObservationTask: Task<Void, Never>?
    private var lifecycleState = LifecycleState.idle
    private var nextOperationID: UInt64 = 0

    init(authService: any AccountAuthServicing, initialSession: AccountSession = .guest) {
        self.authService = authService
        session = initialSession
    }

    deinit {
        authObservationTask?.cancel()
    }

    func restoreSession() async {
        if case .restoring = lifecycleState { return }
        let operationID = beginOperation { .restoring($0) }
        session = .restoring
        error = nil
        do {
            let restoredSession = try await authService.restoredSession()
            guard lifecycleState == .restoring(operationID) else { return }
            session = restoredSession
            lifecycleState = .idle
        } catch is CancellationError {
            guard lifecycleState == .restoring(operationID) else { return }
            session = .guest
            lifecycleState = .idle
        } catch {
            guard lifecycleState == .restoring(operationID) else { return }
            session = .guest
            self.error = .restorationFailed
            lifecycleState = .idle
        }
    }

    func signInWithApple(using appleService: any AppleSignInServicing) async {
        if case .signingIn = lifecycleState { return }
        let operationID = beginOperation { .signingIn($0) }
        let previousSession = session
        pendingDisplayName = nil
        error = nil
        do {
            let credential = try await appleService.signIn()
            try Task.checkCancellation()
            let authenticatedSession = try await authService.signInWithApple(
                identityToken: credential.identityToken,
                rawNonce: credential.rawNonce
            )
            guard lifecycleState == .signingIn(operationID) else { return }
            if case let .authenticated(userID) = authenticatedSession,
               let displayName = credential.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
               !displayName.isEmpty {
                pendingDisplayName = PendingDisplayName(userID: userID, displayName: displayName)
            }
            session = authenticatedSession
            lifecycleState = .idle
        } catch AppleSignInError.cancelled {
            guard lifecycleState == .signingIn(operationID) else { return }
            session = previousSession
            lifecycleState = .idle
        } catch is CancellationError {
            guard lifecycleState == .signingIn(operationID) else { return }
            session = previousSession
            lifecycleState = .idle
        } catch {
            guard lifecycleState == .signingIn(operationID) else { return }
            session = previousSession
            self.error = .signInFailed
            lifecycleState = .idle
        }
    }

    func startObservingAuthState() {
        stopObservingAuthState()
        let changes = authService.sessionChanges()
        authObservationTask = Task { [weak self] in
            for await session in changes {
                guard !Task.isCancelled else { break }
                guard let self else { break }
                if case .signingOut = self.lifecycleState { continue }
                if case .signedOut = self.lifecycleState, session != .guest { continue }
                self.discardPendingDisplayName(ifItDoesNotMatch: session)
                self.session = session
            }
        }
    }

    func stopObservingAuthState() {
        authObservationTask?.cancel()
        authObservationTask = nil
    }

    func signOut() async {
        if case .signingOut = lifecycleState { return }
        let operationID = beginOperation { .signingOut($0) }
        error = nil
        do {
            _ = try await authService.signOut()
            guard lifecycleState == .signingOut(operationID) else { return }
            pendingDisplayName = nil
            session = .guest
            lifecycleState = .signedOut(operationID)
        } catch is CancellationError {
            guard lifecycleState == .signingOut(operationID) else { return }
            lifecycleState = .idle
        } catch {
            guard lifecycleState == .signingOut(operationID) else { return }
            self.error = .signOutFailed
            lifecycleState = .idle
        }
    }

    private func beginOperation(_ state: (UInt64) -> LifecycleState) -> UInt64 {
        nextOperationID &+= 1
        lifecycleState = state(nextOperationID)
        return nextOperationID
    }

    func consumePendingDisplayName(for userID: UUID) -> String? {
        guard pendingDisplayName?.userID == userID else { return nil }
        defer { pendingDisplayName = nil }
        return pendingDisplayName?.displayName
    }

    private func discardPendingDisplayName(ifItDoesNotMatch session: AccountSession) {
        guard let pendingDisplayName else { return }
        guard case let .authenticated(userID) = session, userID == pendingDisplayName.userID else {
            self.pendingDisplayName = nil
            return
        }
    }
}
