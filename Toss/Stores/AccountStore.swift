import Combine
import Foundation

enum AccountStoreError: Error, Equatable {
    case restorationFailed
    case signInFailed
    case signOutFailed
}

private struct PendingDisplayName: Equatable {
    let userID: UUID
    let generationID: SupabaseClientGenerationID
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
            let result = try await authService.restoredSession()
            guard lifecycleState == .restoring(operationID) else { return }
            guard authService.isCurrentGeneration(result.generationID) else {
                session = .guest
                lifecycleState = .idle
                return
            }
            session = result.session
            lifecycleState = .idle
            startObservingAuthState()
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
            let result = try await authService.signInWithApple(
                identityToken: credential.identityToken,
                rawNonce: credential.rawNonce
            )
            guard lifecycleState == .signingIn(operationID) else { return }
            guard authService.isCurrentGeneration(result.generationID) else {
                pendingDisplayName = nil
                session = previousSession
                lifecycleState = .idle
                return
            }
            if case let .authenticated(userID) = result.session,
               let displayName = credential.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
               !displayName.isEmpty {
                pendingDisplayName = PendingDisplayName(
                    userID: userID,
                    generationID: result.generationID,
                    displayName: displayName
                )
            }
            session = result.session
            lifecycleState = .idle
            startObservingAuthState()
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
            for await event in changes {
                guard !Task.isCancelled else { break }
                guard let self else { break }
                self.applyAuthEvent(event)
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
        stopObservingAuthState()
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
        guard pendingDisplayName?.userID == userID,
              let generationID = pendingDisplayName?.generationID,
              authService.isCurrentGeneration(generationID) else { return nil }
        defer { pendingDisplayName = nil }
        return pendingDisplayName?.displayName
    }

    func applyAuthEvent(_ event: AccountAuthEvent) {
        guard authService.isCurrentGeneration(event.generationID),
              let eventSession = event.session else { return }
        if case .signingOut = lifecycleState { return }
        if case .signedOut = lifecycleState, eventSession != .guest { return }
        discardPendingDisplayName(ifItDoesNotMatch: eventSession)
        session = eventSession
    }

    private func discardPendingDisplayName(ifItDoesNotMatch session: AccountSession) {
        guard let pendingDisplayName else { return }
        guard case let .authenticated(userID) = session, userID == pendingDisplayName.userID else {
            self.pendingDisplayName = nil
            return
        }
    }
}
