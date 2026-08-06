import Foundation
import Supabase

protocol SupabaseAuthBackend {
    func restoredUserIDValue() async throws -> UUID?
    func signIn(credentials: OpenIDConnectCredentials) async throws -> UUID
    func sessionChanges() -> AsyncStream<AccountSession>
    func signOut() async throws -> ServerSessionRevocation
}

final class SupabaseAccountAuthService: AccountAuthServicing, ClientEnvironmentBacked {
    let environment: AppEnvironment?
    private let backend: any SupabaseAuthBackend

    init(environment: AppEnvironment) {
        self.environment = environment
        backend = LiveSupabaseAuthBackend(client: environment.supabaseClient)
    }

    init(backend: any SupabaseAuthBackend) {
        environment = nil
        self.backend = backend
    }

    func restoredSession() async throws -> AccountSession {
        guard let userID = try await backend.restoredUserIDValue() else { return .guest }
        return .authenticated(userID: userID)
    }

    func signInWithApple(identityToken: String, rawNonce: String) async throws -> AccountSession {
        let credentials = OpenIDConnectCredentials(
            provider: .apple,
            idToken: identityToken,
            nonce: rawNonce
        )
        let userID = try await backend.signIn(credentials: credentials)
        return .authenticated(userID: userID)
    }

    func sessionChanges() -> AsyncStream<AccountSession> {
        backend.sessionChanges()
    }

    func signOut() async throws -> ServerSessionRevocation {
        try await backend.signOut()
    }
}

private final class LiveSupabaseAuthBackend: SupabaseAuthBackend {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func restoredUserIDValue() async throws -> UUID? {
        do {
            return try await client.auth.session.user.id
        } catch AuthError.sessionMissing {
            return nil
        }
    }

    func signIn(credentials: OpenIDConnectCredentials) async throws -> UUID {
        let session = try await client.auth.signInWithIdToken(credentials: credentials)
        return session.user.id
    }

    func sessionChanges() -> AsyncStream<AccountSession> {
        AsyncStream { continuation in
            let task = Task {
                for await (_, session) in client.auth.authStateChanges {
                    guard !Task.isCancelled else { break }
                    if let userID = session?.user.id {
                        continuation.yield(.authenticated(userID: userID))
                    } else {
                        continuation.yield(.guest)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func signOut() async throws -> ServerSessionRevocation {
        do {
            try await client.auth.signOut()
            guard client.auth.currentSession == nil else {
                throw AccountAuthError.localSessionNotCleared
            }
            return .revoked
        } catch {
            guard client.auth.currentSession == nil else {
                throw AccountAuthError.localSessionNotCleared
            }
            return .deferred
        }
    }
}

enum AccountAuthError: Error, Equatable {
    case localSessionNotCleared
}
