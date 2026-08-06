import Supabase
import XCTest
@testable import Toss

final class SupabaseAccountAuthServiceTests: XCTestCase {
    func testSignInUsesAppleProviderAndOriginalNonce() async throws {
        let userID = UUID()
        let backend = SupabaseAuthBackendDouble(signInUserID: userID)
        let service = SupabaseAccountAuthService(backend: backend)

        let session = try await service.signInWithApple(
            identityToken: "identity-token",
            rawNonce: "raw-nonce"
        )

        XCTAssertEqual(session, .authenticated(userID: userID))
        XCTAssertEqual(backend.receivedCredentials?.provider, .apple)
        XCTAssertEqual(backend.receivedCredentials?.idToken, "identity-token")
        XCTAssertEqual(backend.receivedCredentials?.nonce, "raw-nonce")
    }

    func testRestoredUserMapsToAuthenticated() async throws {
        let userID = UUID()
        let service = SupabaseAccountAuthService(
            backend: SupabaseAuthBackendDouble(restoredUserID: userID)
        )

        let session = try await service.restoredSession()

        XCTAssertEqual(session, .authenticated(userID: userID))
    }

    func testMissingRestoredUserMapsToGuest() async throws {
        let service = SupabaseAccountAuthService(
            backend: SupabaseAuthBackendDouble(restoredUserID: nil)
        )

        let session = try await service.restoredSession()

        XCTAssertEqual(session, .guest)
    }

    func testSessionChangesAreForwarded() async {
        let userID = UUID()
        let backend = SupabaseAuthBackendDouble()
        let service = SupabaseAccountAuthService(backend: backend)
        var iterator = service.sessionChanges().makeAsyncIterator()

        backend.yield(.authenticated(userID: userID))
        let session = await iterator.next()

        XCTAssertEqual(session, .authenticated(userID: userID))
    }

    func testCancellingSessionChangesStopsBackendObservation() async {
        let backend = SupabaseAuthBackendDouble()
        let service = SupabaseAccountAuthService(backend: backend)
        let task = Task {
            for await _ in service.sessionChanges() {}
        }

        await Task.yield()
        task.cancel()
        _ = await task.result

        XCTAssertEqual(backend.activeObservationCount, 0)
    }

    func testSignOutReturnsBackendRevocationResult() async throws {
        let backend = SupabaseAuthBackendDouble(signOutResult: .deferred)
        let service = SupabaseAccountAuthService(backend: backend)

        let result = try await service.signOut()

        XCTAssertEqual(result, .deferred)
    }
}

private final class SupabaseAuthBackendDouble: SupabaseAuthBackend {
    var restoredUserID: UUID?
    var signInUserID: UUID
    var signOutResult: ServerSessionRevocation
    private(set) var receivedCredentials: OpenIDConnectCredentials?
    private(set) var activeObservationCount = 0
    private var continuations: [UUID: AsyncStream<AccountSession>.Continuation] = [:]

    init(
        restoredUserID: UUID? = nil,
        signInUserID: UUID = UUID(),
        signOutResult: ServerSessionRevocation = .revoked
    ) {
        self.restoredUserID = restoredUserID
        self.signInUserID = signInUserID
        self.signOutResult = signOutResult
    }

    func restoredUserIDValue() async throws -> UUID? { restoredUserID }

    func signIn(credentials: OpenIDConnectCredentials) async throws -> UUID {
        receivedCredentials = credentials
        return signInUserID
    }

    func sessionChanges() -> AsyncStream<AccountSession> {
        let id = UUID()
        return AsyncStream { continuation in
            activeObservationCount += 1
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                self?.continuations[id] = nil
                self?.activeObservationCount -= 1
            }
        }
    }

    func signOut() async throws -> ServerSessionRevocation { signOutResult }

    func yield(_ session: AccountSession) {
        continuations.values.forEach { $0.yield(session) }
    }
}
