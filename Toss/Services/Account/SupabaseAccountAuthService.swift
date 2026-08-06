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
    private let lifecycleLock = AsyncOperationLock()
    private let authStorage: KeychainAuthLocalStorage?

    init(environment: AppEnvironment) {
        self.environment = environment
        authStorage = environment.authStorage
        backend = LiveSupabaseAuthBackend(
            client: environment.supabaseClient,
            signOutVerifier: VerifiedSessionSignOut(
                storage: environment.authStorage,
                storageKey: AppEnvironment.authStorageKey
            )
        )
    }

    init(backend: any SupabaseAuthBackend) {
        environment = nil
        authStorage = nil
        self.backend = backend
    }

    func restoredSession() async throws -> AccountSession {
        try await lifecycleLock.withLock {
            try Task.checkCancellation()
            let restoreBlockedWritesOnFailure = authStorage?.sessionWritesAreBlocked == true
            authStorage?.allowSessionWrites()
            do {
                guard let userID = try await backend.restoredUserIDValue() else { return .guest }
                return .authenticated(userID: userID)
            } catch {
                if restoreBlockedWritesOnFailure { authStorage?.blockSessionWrites() }
                throw error
            }
        }
    }

    func signInWithApple(identityToken: String, rawNonce: String) async throws -> AccountSession {
        try await lifecycleLock.withLock {
            try Task.checkCancellation()
            let restoreBlockedWritesOnFailure = authStorage?.sessionWritesAreBlocked == true
            authStorage?.allowSessionWrites()
            do {
                let credentials = OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: identityToken,
                    nonce: rawNonce
                )
                let userID = try await backend.signIn(credentials: credentials)
                return .authenticated(userID: userID)
            } catch {
                if restoreBlockedWritesOnFailure { authStorage?.blockSessionWrites() }
                throw error
            }
        }
    }

    func sessionChanges() -> AsyncStream<AccountSession> {
        backend.sessionChanges()
    }

    func signOut() async throws -> ServerSessionRevocation {
        try await lifecycleLock.withLock {
            try await backend.signOut()
        }
    }
}

private actor AsyncOperationLock {
    private var isLocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func withLock<Value>(_ operation: () async throws -> Value) async rethrows -> Value {
        await acquire()
        defer { release() }
        return try await operation()
    }

    private func acquire() async {
        guard isLocked else {
            isLocked = true
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    private func release() {
        guard !waiters.isEmpty else {
            isLocked = false
            return
        }
        waiters.removeFirst().resume()
    }
}

private final class LiveSupabaseAuthBackend: SupabaseAuthBackend {
    private let client: SupabaseClient
    private let signOutVerifier: VerifiedSessionSignOut

    init(client: SupabaseClient, signOutVerifier: VerifiedSessionSignOut) {
        self.client = client
        self.signOutVerifier = signOutVerifier
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
        try await signOutVerifier.perform {
            try await client.auth.signOut()
        }
    }
}
