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

        XCTAssertEqual(session.session, .authenticated(userID: userID))
        XCTAssertEqual(session.generationID, .legacy)
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

        XCTAssertEqual(session.session, .authenticated(userID: userID))
    }

    func testMissingRestoredUserMapsToGuest() async throws {
        let service = SupabaseAccountAuthService(
            backend: SupabaseAuthBackendDouble(restoredUserID: nil)
        )

        let session = try await service.restoredSession()

        XCTAssertEqual(session.session, .guest)
    }

    func testSessionChangesAreForwarded() async {
        let userID = UUID()
        let backend = SupabaseAuthBackendDouble()
        let service = SupabaseAccountAuthService(backend: backend)
        var iterator = service.sessionChanges().makeAsyncIterator()
        let event = AccountAuthEvent(
            generationID: service.currentGenerationID,
            kind: .tokenRefreshed,
            session: .authenticated(userID: userID)
        )

        backend.yield(event)
        let receivedEvent = await iterator.next()

        XCTAssertEqual(receivedEvent, event)
    }

    func testSupabaseAuthKindsMapWithoutGuessingFromSession() {
        XCTAssertEqual(AccountAuthEventKind(supabaseEvent: .initialSession), .initialSession)
        XCTAssertEqual(AccountAuthEventKind(supabaseEvent: .signedIn), .signedIn)
        XCTAssertEqual(AccountAuthEventKind(supabaseEvent: .signedOut), .signedOut)
        XCTAssertEqual(AccountAuthEventKind(supabaseEvent: .tokenRefreshed), .tokenRefreshed)
        XCTAssertEqual(AccountAuthEventKind(supabaseEvent: .userUpdated), .userUpdated)
        XCTAssertNil(AccountAuthEventKind(supabaseEvent: .passwordRecovery))
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

    func testLogoutDoesNotWaitForInFlightLogin() async throws {
        let backend = SupabaseAuthBackendDouble(signInUserID: UUID())
        backend.shouldSuspendSignIn = true
        let service = SupabaseAccountAuthService(backend: backend)
        let login = Task {
            try await service.signInWithApple(identityToken: "fictional-token", rawNonce: "fictional-nonce")
        }
        await backend.waitForSignInCall()

        let logout = Task { try await service.signOut() }
        let logoutResult = try await logout.value
        XCTAssertEqual(logoutResult, .deferred)
        XCTAssertEqual(backend.operationLog, ["login-start", "logout-start", "logout-finish"])

        backend.completeSignIn()
        _ = try await login.value

        XCTAssertEqual(
            backend.operationLog,
            ["login-start", "logout-start", "logout-finish", "login-finish"]
        )
    }

    func testBackendDoubleExposesOneLockedStateSnapshot() {
        let backend = SupabaseAuthBackendDouble()

        let snapshot = backend.snapshot

        XCTAssertEqual(snapshot.activeObservationCount, 0)
        XCTAssertTrue(snapshot.operationLog.isEmpty)
        XCTAssertNil(snapshot.receivedCredentials)
    }
}

private final class SupabaseAuthBackendDouble: SupabaseAuthBackend {
    struct Snapshot {
        let receivedCredentials: OpenIDConnectCredentials?
        let activeObservationCount: Int
        let operationLog: [String]
    }

    let restoredUserID: UUID?
    let signInUserID: UUID
    let signOutResult: ServerSessionRevocation
    private let lock = NSLock()
    private var storedReceivedCredentials: OpenIDConnectCredentials?
    private var storedActiveObservationCount = 0
    private var storedOperationLog: [String] = []
    private var storedShouldSuspendSignIn = false
    private let signInGate = TestOperationGate()
    private var continuations: [UUID: AsyncStream<AccountAuthEvent>.Continuation] = [:]

    var receivedCredentials: OpenIDConnectCredentials? { lock.withLock { storedReceivedCredentials } }
    var activeObservationCount: Int { lock.withLock { storedActiveObservationCount } }
    var operationLog: [String] { lock.withLock { storedOperationLog } }
    var shouldSuspendSignIn: Bool {
        get { lock.withLock { storedShouldSuspendSignIn } }
        set { lock.withLock { storedShouldSuspendSignIn = newValue } }
    }
    var snapshot: Snapshot {
        lock.withLock {
            Snapshot(
                receivedCredentials: storedReceivedCredentials,
                activeObservationCount: storedActiveObservationCount,
                operationLog: storedOperationLog
            )
        }
    }

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
        let shouldSuspend = lock.withLock {
            storedOperationLog.append("login-start")
            storedReceivedCredentials = credentials
            return storedShouldSuspendSignIn
        }
        if shouldSuspend {
            await signInGate.suspend()
        }
        lock.withLock { storedOperationLog.append("login-finish") }
        return signInUserID
    }

    func sessionChanges() -> AsyncStream<AccountAuthEvent> {
        let id = UUID()
        return AsyncStream { continuation in
            lock.withLock {
                storedActiveObservationCount += 1
                continuations[id] = continuation
            }
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.lock.withLock {
                    guard self.continuations.removeValue(forKey: id) != nil else { return }
                    self.storedActiveObservationCount -= 1
                }
            }
        }
    }

    func signOut() async throws -> ServerSessionRevocation {
        lock.withLock {
            storedOperationLog.append("logout-start")
            storedOperationLog.append("logout-finish")
        }
        return signOutResult
    }

    func waitForSignInCall() async {
        await signInGate.waitUntilStarted()
    }

    func completeSignIn() {
        signInGate.complete()
    }

    func yield(_ event: AccountAuthEvent) {
        let currentContinuations = lock.withLock { Array(continuations.values) }
        currentContinuations.forEach { $0.yield(event) }
    }
}
