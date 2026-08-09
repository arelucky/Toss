import Foundation
import Supabase

protocol SupabaseAuthBackend {
    func restoredUserIDValue() async throws -> UUID?
    func signIn(credentials: OpenIDConnectCredentials) async throws -> UUID
    func sessionChanges() -> AsyncStream<AccountAuthEvent>
    func signOut() async throws -> ServerSessionRevocation
}

final class SupabaseAccountAuthService: AccountAuthServicing, ClientEnvironmentBacked {
    let environment: AppEnvironment?
    private let backend: (any SupabaseAuthBackend)?
    private let operationLock = NSLock()
    private var inFlightLoginCount = 0

    var currentGenerationID: SupabaseClientGenerationID {
        environment?.generationProvider.current().id ?? .legacy
    }

    func isCurrentGeneration(_ generationID: SupabaseClientGenerationID) -> Bool {
        environment?.generationProvider.isCurrent(generationID) ?? (generationID == .legacy)
    }

    init(environment: AppEnvironment) {
        self.environment = environment
        backend = nil
    }

    init(backend: any SupabaseAuthBackend) {
        environment = nil
        self.backend = backend
    }

    func restoredSession() async throws -> GenerationAccountSession {
        try Task.checkCancellation()
        if let backend {
            let session = (try await backend.restoredUserIDValue())
                .map(AccountSession.authenticated(userID:)) ?? .guest
            return GenerationAccountSession(generationID: .legacy, session: session)
        }
        guard let provider = environment?.generationProvider else {
            throw AccountDependencyError.unavailable
        }
        let generation = provider.current()
        do {
            let userID = try await generation.client.auth.session.user.id
            guard provider.isCurrent(generation.id) else { throw CancellationError() }
            return GenerationAccountSession(
                generationID: generation.id,
                session: .authenticated(userID: userID)
            )
        } catch AuthError.sessionMissing {
            guard provider.isCurrent(generation.id) else { throw CancellationError() }
            return GenerationAccountSession(generationID: generation.id, session: .guest)
        }
    }

    func signInWithApple(identityToken: String, rawNonce: String) async throws -> GenerationAccountSession {
        try Task.checkCancellation()
        let credentials = OpenIDConnectCredentials(provider: .apple, idToken: identityToken, nonce: rawNonce)
        beginLoginAttempt()
        defer { finishLoginAttempt() }
        if let backend {
            return GenerationAccountSession(
                generationID: .legacy,
                session: .authenticated(userID: try await backend.signIn(credentials: credentials))
            )
        }
        guard let provider = environment?.generationProvider else { throw AccountDependencyError.unavailable }
        let outgoing = provider.current()
        let candidate = try provider.rotate(replacing: outgoing.id)
        do {
            let session = try await candidate.client.auth.signInWithIdToken(credentials: credentials)
            try Task.checkCancellation()
            guard provider.isCurrent(candidate.id) else { throw CancellationError() }
            return GenerationAccountSession(
                generationID: candidate.id,
                session: .authenticated(userID: session.user.id)
            )
        } catch let operationError {
            if provider.isCurrent(candidate.id) {
                do {
                    _ = try provider.retireFailedCandidate(expectedID: candidate.id)
                } catch let cleanupError {
                    throw cleanupError
                }
            }
            throw operationError
        }
    }

    func sessionChanges() -> AsyncStream<AccountAuthEvent> {
        if let backend { return backend.sessionChanges() }
        guard let generation = environment?.generationProvider.current() else {
            return AsyncStream { $0.finish() }
        }
        return LiveSupabaseAuthBackend(client: generation.client, generationID: generation.id).sessionChanges()
    }

    func signOut() async throws -> ServerSessionRevocation {
        let loginWasInFlight = hasInFlightLogin
        if let backend {
            let result = try await backend.signOut()
            return loginWasInFlight ? .deferred : result
        }
        guard let environment else { throw AccountDependencyError.unavailable }
        let provider = environment.generationProvider
        let generation = provider.current()
        _ = try provider.beginRetirement(expectedID: generation.id)
        let remoteResult: ServerSessionRevocation
        do {
            try await generation.client.auth.signOut()
            remoteResult = .revoked
        } catch {
            remoteResult = .deferred
        }
        if try environment.authStorage.retrieve(key: AppEnvironment.authStorageKey) != nil {
            try generation.authStorage.remove(key: AppEnvironment.authStorageKey)
        }
        try environment.authStorage.confirmSessionAbsent(key: AppEnvironment.authStorageKey)
        _ = try provider.finishRetirementAndActivateReplacement(expectedID: generation.id)
        return loginWasInFlight ? .deferred : remoteResult
    }

    private var hasInFlightLogin: Bool {
        operationLock.withLock { inFlightLoginCount > 0 }
    }

    private func beginLoginAttempt() {
        operationLock.withLock { inFlightLoginCount += 1 }
    }

    private func finishLoginAttempt() {
        operationLock.withLock { inFlightLoginCount -= 1 }
    }
}

private final class LiveSupabaseAuthBackend: SupabaseAuthBackend {
    private let client: SupabaseClient
    private let generationID: SupabaseClientGenerationID

    init(client: SupabaseClient, generationID: SupabaseClientGenerationID) {
        self.client = client
        self.generationID = generationID
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

    func sessionChanges() -> AsyncStream<AccountAuthEvent> {
        AsyncStream { continuation in
            let task = Task {
                for await (event, session) in client.auth.authStateChanges {
                    guard !Task.isCancelled else { break }
                    guard let kind = AccountAuthEventKind(supabaseEvent: event) else { continue }
                    continuation.yield(
                        AccountAuthEvent(
                            generationID: generationID,
                            kind: kind,
                            session: session.map { .authenticated(userID: $0.user.id) } ?? .guest
                        )
                    )
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func signOut() async throws -> ServerSessionRevocation {
        try await client.auth.signOut()
        return .revoked
    }
}

extension AccountAuthEventKind {
    init?(supabaseEvent: AuthChangeEvent) {
        switch supabaseEvent {
        case .initialSession: self = .initialSession
        case .signedIn: self = .signedIn
        case .signedOut: self = .signedOut
        case .tokenRefreshed: self = .tokenRefreshed
        case .userUpdated: self = .userUpdated
        default: return nil
        }
    }
}
