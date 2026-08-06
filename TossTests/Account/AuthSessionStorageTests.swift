import Foundation
import Security
import XCTest
@testable import Toss

final class AuthSessionStorageTests: XCTestCase {
    func testStoredValueCanBeReadByANewStorageInstance() throws {
        let namespace = TestKeychainNamespace()
        defer { namespace.cleanup() }
        let first = KeychainAuthLocalStorage(service: namespace.service)
        let second = KeychainAuthLocalStorage(service: namespace.service)
        let value = Data("fictional-session".utf8)

        try first.store(key: namespace.account, value: value)

        XCTAssertEqual(try second.retrieve(key: namespace.account), value)
    }

    func testSuccessfulRemovalCannotBeRestoredByANewStorageInstance() throws {
        let namespace = TestKeychainNamespace()
        defer { namespace.cleanup() }
        let first = KeychainAuthLocalStorage(service: namespace.service)
        try first.store(key: namespace.account, value: Data("fictional-session".utf8))

        try first.remove(key: namespace.account)

        let second = KeychainAuthLocalStorage(service: namespace.service)
        XCTAssertNil(try second.retrieve(key: namespace.account))
    }

    func testRemovingMissingItemSucceeds() throws {
        let namespace = TestKeychainNamespace()
        defer { namespace.cleanup() }

        XCTAssertNoThrow(try KeychainAuthLocalStorage(service: namespace.service).remove(key: namespace.account))
    }

    func testDeletionFailureIsRecordedForCurrentLogoutAttempt() throws {
        let backend = KeychainBackendDouble(removeStatus: errSecInteractionNotAllowed)
        let storage = KeychainAuthLocalStorage(service: "test", backend: backend)
        let checkpoint = storage.beginDeletionVerification(for: "session")

        XCTAssertThrowsError(try storage.remove(key: "session"))
        XCTAssertThrowsError(try storage.confirmDeletion(after: checkpoint, for: "session")) { error in
            XCTAssertEqual(error as? AuthSessionStorageError, .keychainFailure(errSecInteractionNotAllowed))
        }
    }

    func testRetrievalFailureCannotConfirmSessionAbsence() {
        let backend = KeychainBackendDouble(retrieveStatus: errSecInteractionNotAllowed)
        let storage = KeychainAuthLocalStorage(service: "test", backend: backend)

        XCTAssertThrowsError(try storage.confirmSessionAbsent(key: "session")) { error in
            XCTAssertEqual(error as? AuthSessionStorageError, .keychainFailure(errSecInteractionNotAllowed))
        }
    }

    func testSuccessfulKeychainStatusWithoutDataCannotConfirmAbsence() {
        let backend = KeychainBackendDouble(value: nil, retrieveStatus: errSecSuccess)
        let storage = KeychainAuthLocalStorage(service: "test", backend: backend)

        XCTAssertThrowsError(try storage.confirmSessionAbsent(key: "session")) { error in
            XCTAssertEqual(error as? AuthSessionStorageError, .missingRetrievedData)
        }
    }

    func testLogoutDoesNotCompleteWhenSDKDeletionFails() async {
        let backend = KeychainBackendDouble(
            value: Data("fictional-session".utf8),
            removeStatus: errSecInteractionNotAllowed
        )
        let storage = KeychainAuthLocalStorage(service: "test", backend: backend)
        let logout = VerifiedSessionSignOut(storage: storage, storageKey: "session")

        do {
            _ = try await logout.perform {
                try? storage.remove(key: "session")
            }
            XCTFail("Expected durable local deletion to fail")
        } catch {
            XCTAssertEqual(error as? AuthSessionStorageError, .keychainFailure(errSecInteractionNotAllowed))
        }
    }

    func testLogoutDoesNotTreatRetrievalFailureAsConfirmedAbsence() async {
        let backend = KeychainBackendDouble(retrieveStatus: errSecInteractionNotAllowed)
        let storage = KeychainAuthLocalStorage(service: "test", backend: backend)
        let logout = VerifiedSessionSignOut(storage: storage, storageKey: "session")
        var operationCalled = false

        do {
            _ = try await logout.perform { operationCalled = true }
            XCTFail("Expected retrieval failure")
        } catch {
            XCTAssertEqual(error as? AuthSessionStorageError, .keychainFailure(errSecInteractionNotAllowed))
            XCTAssertFalse(operationCalled)
        }
    }

    func testRemoteFailureAfterConfirmedLocalDeletionIsDeferred() async throws {
        let backend = KeychainBackendDouble(value: Data("fictional-session".utf8))
        let storage = KeychainAuthLocalStorage(service: "test", backend: backend)
        let logout = VerifiedSessionSignOut(storage: storage, storageKey: "session")

        let result = try await logout.perform {
            try storage.remove(key: "session")
            throw TestAccountError.expected
        }

        XCTAssertEqual(result, .deferred)
        XCTAssertNil(try storage.retrieve(key: "session"))
    }

    func testLateRefreshCannotPersistAfterLogout() async throws {
        let backend = KeychainBackendDouble(value: Data("old-session".utf8))
        let storage = KeychainAuthLocalStorage(service: "test", backend: backend)
        let logout = VerifiedSessionSignOut(storage: storage, storageKey: "session")
        _ = try await logout.perform { try storage.remove(key: "session") }

        XCTAssertThrowsError(try storage.store(key: "session", value: Data("late-refresh".utf8))) { error in
            XCTAssertEqual(error as? AuthSessionStorageError, .writesBlocked)
        }
        XCTAssertNil(try storage.retrieve(key: "session"))
    }
}

private struct TestKeychainNamespace {
    let service = "com.zhaoheng.TossTests.auth.\(UUID().uuidString)"
    let account = "session"

    func cleanup() {
        try? KeychainAuthLocalStorage(service: service).remove(key: account)
    }
}

private final class KeychainBackendDouble: KeychainAccessing {
    var value: Data?
    var retrieveStatus: OSStatus
    var removeStatus: OSStatus

    init(
        value: Data? = nil,
        retrieveStatus: OSStatus? = nil,
        removeStatus: OSStatus = errSecSuccess
    ) {
        self.value = value
        self.retrieveStatus = retrieveStatus ?? (value == nil ? errSecItemNotFound : errSecSuccess)
        self.removeStatus = removeStatus
    }

    func store(service: String, account: String, value: Data) -> OSStatus {
        self.value = value
        return errSecSuccess
    }

    func retrieve(service: String, account: String) -> (OSStatus, Data?) {
        (retrieveStatus, value)
    }

    func remove(service: String, account: String) -> OSStatus {
        if removeStatus == errSecSuccess {
            value = nil
            retrieveStatus = errSecItemNotFound
        }
        return removeStatus
    }
}
