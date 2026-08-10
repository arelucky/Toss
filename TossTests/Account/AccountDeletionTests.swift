import XCTest
@testable import Toss

@MainActor
final class AccountDeletionTests: XCTestCase {
    func testCancelledReauthenticationDoesNotCallDeletionBackend() async {
        let subject = makeSubject(apple: .failure(AppleSignInError.cancelled))

        let result = await subject.store.deleteAccount(
            using: subject.apple,
            deletionService: subject.deletion,
            requestID: UUID()
        )

        XCTAssertNil(result)
        XCTAssertEqual(subject.store.session, .authenticated(userID: subject.userID))
        XCTAssertEqual(subject.deletion.callCount, 0)
    }

    func testSuccessfulDeletionRequiresMatchingReauthenticationAndEntersGuest() async {
        let subject = makeSubject(deletionResult: .init(deleted: true, appleRevocation: .revoked))

        let result = await subject.store.deleteAccount(
            using: subject.apple,
            deletionService: subject.deletion,
            requestID: UUID()
        )

        XCTAssertEqual(result?.appleRevocation, .revoked)
        XCTAssertEqual(subject.store.session, .guest)
        XCTAssertEqual(subject.deletion.callCount, 1)
    }

    func testDeletionFailureKeepsAuthenticatedAccount() async {
        let subject = makeSubject(deletionError: DeletionTestError.expected)

        _ = await subject.store.deleteAccount(
            using: subject.apple,
            deletionService: subject.deletion,
            requestID: UUID()
        )

        XCTAssertEqual(subject.store.session, .authenticated(userID: subject.userID))
        XCTAssertEqual(subject.store.error, .deletionFailed)
    }

    func testRequestIDIsReusedAfterFailureAndClearedAfterSuccess() {
        let backing = DeletionKeyValueStore()
        let store = AccountDeletionRequestStore(store: backing, makeID: { UUID(uuidString: "11111111-1111-1111-1111-111111111111")! })

        let first = store.currentOrCreate()
        XCTAssertEqual(store.currentOrCreate(), first)
        store.clear()
        XCTAssertNil(store.current)
    }

    func testAccountCacheRemovalDoesNotAffectAnotherUser() {
        let backing = DeletionKeyValueStore()
        let store = LocalPreferencesStore(store: backing)
        let userA = UUID()
        let userB = UUID()
        store.cache(.init(soundEnabled: false, hapticEnabled: false), for: userA)
        store.cache(.init(soundEnabled: true, hapticEnabled: false), for: userB)

        store.removeCachedPreferences(for: userA)

        XCTAssertNil(store.cachedPreferences(for: userA))
        XCTAssertNotNil(store.cachedPreferences(for: userB))
    }

    func testConcreteServiceDiscardsLateResponseFromOldGeneration() async {
        let backend = DeletionBackendDouble()
        let service = SupabaseAccountDeletionService(backend: backend)
        backend.rotateBeforeReturning = true

        do {
            _ = try await service.deleteAccount(authorizationCode: "fictional-code", requestID: backend.requestID)
            XCTFail("Expected stale generation")
        } catch {
            XCTAssertEqual(error as? AccountDeletionServiceError, .staleGeneration)
        }
        XCTAssertEqual(backend.clearCount, 0)
    }

    func testConcreteServiceDoesNotReportSuccessWhenLocalSessionCleanupFails() async {
        let backend = DeletionBackendDouble()
        backend.cleanupError = DeletionTestError.expected
        let service = SupabaseAccountDeletionService(backend: backend)

        do {
            _ = try await service.deleteAccount(authorizationCode: "fictional-code", requestID: backend.requestID)
            XCTFail("Expected local cleanup failure")
        } catch {
            XCTAssertEqual(error as? AccountDeletionServiceError, .localSessionCleanupFailed)
        }
    }

    private func makeSubject(
        apple: Result<AppleSignInCredential, Error>? = nil,
        deletionResult: AccountDeletionResult = .init(deleted: true, appleRevocation: .revoked),
        deletionError: Error? = nil
    ) -> DeletionSubject {
        let userID = UUID()
        let auth = AccountAuthServiceDouble(signInResult: .success(.authenticated(userID: userID)))
        let appleService = DeletionAppleService(result: apple ?? .success(.init(
            identityToken: "fictional-identity-token",
            authorizationCode: "fictional-authorization-code",
            rawNonce: "fictional-raw-nonce",
            displayName: nil
        )))
        let deletion = DeletionServiceDouble(result: deletionResult, error: deletionError)
        return DeletionSubject(
            userID: userID,
            store: AccountStore(authService: auth, initialSession: .authenticated(userID: userID)),
            apple: appleService,
            deletion: deletion
        )
    }
}

private struct DeletionSubject {
    let userID: UUID
    let store: AccountStore
    let apple: DeletionAppleService
    let deletion: DeletionServiceDouble
}

private enum DeletionTestError: Error { case expected }

@MainActor
private final class DeletionAppleService: AppleSignInServicing {
    let result: Result<AppleSignInCredential, Error>
    init(result: Result<AppleSignInCredential, Error>) { self.result = result }
    func signIn() async throws -> AppleSignInCredential { try result.get() }
}

private final class DeletionServiceDouble: AccountDeletionServicing {
    let result: AccountDeletionResult
    let error: Error?
    private(set) var callCount = 0
    init(result: AccountDeletionResult, error: Error?) { self.result = result; self.error = error }
    func deleteAccount(authorizationCode: String, requestID: UUID) async throws -> AccountDeletionResult {
        callCount += 1
        if let error { throw error }
        return result
    }
}

private final class DeletionKeyValueStore: PreferencesKeyValueStoring {
    private var values: [String: Any] = [:]
    func object(forKey key: String) -> Any? { values[key] }
    func set(_ value: Any?, forKey key: String) { values[key] = value }
}

private final class DeletionBackendDouble: AccountDeletionBackend {
    let requestID = UUID()
    private(set) var generationID = SupabaseClientGenerationID()
    var currentGenerationID: SupabaseClientGenerationID { generationID }
    var rotateBeforeReturning = false
    var cleanupError: Error?
    private(set) var clearCount = 0

    func isCurrent(_ generationID: SupabaseClientGenerationID) -> Bool { self.generationID == generationID }

    func invoke(authorizationCode: String, requestID: UUID, generationID: SupabaseClientGenerationID) async throws -> AccountDeletionServerResponse {
        if rotateBeforeReturning { self.generationID = SupabaseClientGenerationID() }
        return .init(
            requestID: requestID,
            result: .init(deleted: true, appleRevocation: .revoked)
        )
    }

    func clearLocalSession(generationID: SupabaseClientGenerationID) throws {
        clearCount += 1
        if let cleanupError { throw cleanupError }
    }
}
