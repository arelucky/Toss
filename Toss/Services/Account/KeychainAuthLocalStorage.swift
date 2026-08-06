import Foundation
import Security
import Supabase

enum AuthSessionStorageError: Error, Equatable {
    case keychainFailure(OSStatus)
    case deletionNotAttempted
    case sessionStillPresent
    case writesBlocked
    case missingRetrievedData
}

struct AuthSessionDeletionCheckpoint: Equatable {
    fileprivate let generation: UInt64
}

protocol KeychainAccessing {
    func store(service: String, account: String, value: Data) -> OSStatus
    func retrieve(service: String, account: String) -> (OSStatus, Data?)
    func remove(service: String, account: String) -> OSStatus
}

struct SystemKeychainAccess: KeychainAccessing {
    func store(service: String, account: String, value: Data) -> OSStatus {
        let query = baseQuery(service: service, account: account)
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData: value] as CFDictionary
        )
        if updateStatus != errSecItemNotFound { return updateStatus }

        var addQuery = query
        addQuery[kSecValueData] = value
        addQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(addQuery as CFDictionary, nil)
    }

    func retrieve(service: String, account: String) -> (OSStatus, Data?) {
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return (status, result as? Data)
    }

    func remove(service: String, account: String) -> OSStatus {
        SecItemDelete(baseQuery(service: service, account: account) as CFDictionary)
    }

    private func baseQuery(service: String, account: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
    }
}

final class KeychainAuthLocalStorage: AuthLocalStorage, @unchecked Sendable {
    private struct DeletionState {
        var generation: UInt64 = 0
        var targetKey: String?
        var result: Result<Void, AuthSessionStorageError>?
        var writesBlocked = false
    }

    private let service: String
    private let backend: any KeychainAccessing
    private let lock = NSLock()
    private var deletionState = DeletionState()

    init(
        service: String = "com.zhaoheng.Toss.supabase.auth",
        backend: any KeychainAccessing = SystemKeychainAccess()
    ) {
        self.service = service
        self.backend = backend
    }

    func store(key: String, value: Data) throws {
        lock.lock()
        defer { lock.unlock() }
        guard !deletionState.writesBlocked else { throw AuthSessionStorageError.writesBlocked }
        try requireSuccess(backend.store(service: service, account: key, value: value))
    }

    func retrieve(key: String) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        let (status, data) = backend.retrieve(service: service, account: key)
        if status == errSecItemNotFound { return nil }
        try requireSuccess(status)
        guard let data else { throw AuthSessionStorageError.missingRetrievedData }
        return data
    }

    func remove(key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        let status = backend.remove(service: service, account: key)
        let result: Result<Void, AuthSessionStorageError>
        if status == errSecSuccess || status == errSecItemNotFound {
            result = .success(())
        } else {
            result = .failure(.keychainFailure(status))
        }

        if deletionState.targetKey == key { deletionState.result = result }
        try result.get()
    }

    func beginDeletionVerification(for key: String) -> AuthSessionDeletionCheckpoint {
        lock.lock()
        deletionState.generation &+= 1
        deletionState.targetKey = key
        deletionState.result = nil
        let checkpoint = AuthSessionDeletionCheckpoint(generation: deletionState.generation)
        lock.unlock()
        return checkpoint
    }

    func allowSessionWrites() {
        lock.lock()
        deletionState.writesBlocked = false
        lock.unlock()
    }

    var sessionWritesAreBlocked: Bool {
        lock.lock()
        defer { lock.unlock() }
        return deletionState.writesBlocked
    }

    func blockSessionWrites() {
        lock.lock()
        deletionState.writesBlocked = true
        lock.unlock()
    }

    func confirmDeletion(after checkpoint: AuthSessionDeletionCheckpoint, for key: String) throws {
        lock.lock()
        let state = deletionState
        lock.unlock()
        guard state.generation == checkpoint.generation, state.targetKey == key,
              let result = state.result else {
            throw AuthSessionStorageError.deletionNotAttempted
        }
        try result.get()
        try confirmSessionAbsent(key: key)
    }

    func confirmSessionAbsent(key: String) throws {
        guard try retrieve(key: key) == nil else {
            throw AuthSessionStorageError.sessionStillPresent
        }
    }

    private func requireSuccess(_ status: OSStatus) throws {
        guard status == errSecSuccess else {
            throw AuthSessionStorageError.keychainFailure(status)
        }
    }
}

struct VerifiedSessionSignOut {
    let storage: KeychainAuthLocalStorage
    let storageKey: String

    func perform(_ operation: () async throws -> Void) async throws -> ServerSessionRevocation {
        storage.blockSessionWrites()
        let sessionWasStored = try storage.retrieve(key: storageKey) != nil
        let checkpoint = storage.beginDeletionVerification(for: storageKey)
        let remoteResult: ServerSessionRevocation

        do {
            try await operation()
            remoteResult = .revoked
        } catch {
            remoteResult = .deferred
        }

        if sessionWasStored {
            try storage.confirmDeletion(after: checkpoint, for: storageKey)
        } else {
            try storage.confirmSessionAbsent(key: storageKey)
        }
        return remoteResult
    }
}
