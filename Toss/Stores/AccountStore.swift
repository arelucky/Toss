import Combine
import Foundation

enum AccountStoreError: Error, Equatable {
    case restorationFailed
    case signInFailed
    case signOutFailed
}

@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var session: AccountSession
    @Published private(set) var error: AccountStoreError?
    private(set) var pendingDisplayName: String?

    private let authService: any AccountAuthServicing
    private var authObservationTask: Task<Void, Never>?

    init(authService: any AccountAuthServicing, initialSession: AccountSession = .guest) {
        self.authService = authService
        session = initialSession
    }

    deinit {
        authObservationTask?.cancel()
    }

    func restoreSession() async {
        guard session != .restoring else { return }
        session = .restoring
        error = nil
        do {
            session = try await authService.restoredSession()
        } catch is CancellationError {
            session = .guest
        } catch {
            session = .guest
            self.error = .restorationFailed
        }
    }

    func signInWithApple(using appleService: any AppleSignInServicing) async {
        let previousSession = session
        error = nil
        do {
            let credential = try await appleService.signIn()
            let authenticatedSession = try await authService.signInWithApple(
                identityToken: credential.identityToken,
                rawNonce: credential.rawNonce
            )
            pendingDisplayName = credential.displayName
            session = authenticatedSession
        } catch AppleSignInError.cancelled {
            session = previousSession
        } catch is CancellationError {
            session = previousSession
        } catch {
            session = previousSession
            self.error = .signInFailed
        }
    }

    func startObservingAuthState() {
        stopObservingAuthState()
        let changes = authService.sessionChanges()
        authObservationTask = Task { [weak self] in
            for await session in changes {
                guard !Task.isCancelled else { break }
                self?.session = session
            }
        }
    }

    func stopObservingAuthState() {
        authObservationTask?.cancel()
        authObservationTask = nil
    }

    func signOut() async {
        error = nil
        do {
            _ = try await authService.signOut()
            pendingDisplayName = nil
            session = .guest
        } catch {
            self.error = .signOutFailed
        }
    }
}
