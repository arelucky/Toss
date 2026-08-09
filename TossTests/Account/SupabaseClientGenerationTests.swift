import Foundation
import Supabase
import XCTest
@testable import Toss

final class SupabaseClientGenerationTests: XCTestCase {
    func testActiveGenerationCanRemoveInvalidSession() throws {
        let backend = InMemoryAuthLocalStorage()
        let authority = SupabaseClientGenerationAuthority()
        let generationID = SupabaseClientGenerationID()
        let storage = GenerationBoundAuthLocalStorage(
            generationID: generationID,
            backend: backend,
            authority: authority
        )
        try authority.activate(generationID)
        try storage.store(key: "session", value: Data("invalid-session".utf8))

        try storage.remove(key: "session")

        XCTAssertNil(try backend.retrieve(key: "session"))
        XCTAssertEqual(authority.lifecycle(of: generationID), .active)
    }

    func testRetiredGenerationCannotOverwriteReplacementSession() throws {
        let backend = InMemoryAuthLocalStorage()
        let authority = SupabaseClientGenerationAuthority()
        let oldID = SupabaseClientGenerationID()
        let oldStorage = GenerationBoundAuthLocalStorage(
            generationID: oldID,
            backend: backend,
            authority: authority
        )
        try authority.activate(oldID)
        try oldStorage.store(key: "session", value: Data("old-session".utf8))

        try authority.beginRetirement(of: oldID)
        try oldStorage.remove(key: "session")
        try authority.finishRetirement(of: oldID)

        let newID = SupabaseClientGenerationID()
        let newStorage = GenerationBoundAuthLocalStorage(
            generationID: newID,
            backend: backend,
            authority: authority
        )
        try authority.activate(newID)
        try newStorage.store(key: "session", value: Data("new-session".utf8))

        XCTAssertThrowsError(
            try oldStorage.store(key: "session", value: Data("late-old-refresh".utf8))
        ) { error in
            XCTAssertEqual(error as? SupabaseClientGenerationError, .generationNotWritable)
        }
        XCTAssertEqual(try backend.retrieve(key: "session"), Data("new-session".utf8))
        XCTAssertEqual(authority.lifecycle(of: oldID), .retired)
        XCTAssertEqual(authority.lifecycle(of: newID), .active)
        XCTAssertEqual(authority.writableGenerationCount, 1)
    }

    func testRetiredGenerationCannotDeleteReplacementSession() throws {
        let backend = InMemoryAuthLocalStorage()
        let authority = SupabaseClientGenerationAuthority()
        let oldID = SupabaseClientGenerationID()
        let oldStorage = GenerationBoundAuthLocalStorage(generationID: oldID, backend: backend, authority: authority)
        try authority.activate(oldID)
        try authority.beginRetirement(of: oldID)
        try oldStorage.remove(key: "session")
        try authority.finishRetirement(of: oldID)

        let newID = SupabaseClientGenerationID()
        let newStorage = GenerationBoundAuthLocalStorage(generationID: newID, backend: backend, authority: authority)
        try authority.activate(newID)
        try newStorage.store(key: "session", value: Data("replacement".utf8))

        XCTAssertThrowsError(try oldStorage.remove(key: "session")) { error in
            XCTAssertEqual(error as? SupabaseClientGenerationError, .generationCannotRemove)
        }
        XCTAssertEqual(try backend.retrieve(key: "session"), Data("replacement".utf8))
    }

    func testRetiredGenerationCanNeverBeReactivated() throws {
        let authority = SupabaseClientGenerationAuthority()
        let generationID = SupabaseClientGenerationID()
        try authority.activate(generationID)
        try authority.beginRetirement(of: generationID)
        try authority.finishRetirement(of: generationID)

        XCTAssertThrowsError(try authority.activate(generationID)) { error in
            XCTAssertEqual(error as? SupabaseClientGenerationError, .retiredGeneration)
        }
        XCTAssertEqual(authority.writableGenerationCount, 0)
    }

    func testProviderNeverReturnsRetiredGenerationAsCurrent() throws {
        let configuration = try SupabaseConfiguration(
            url: XCTUnwrap(URL(string: "http://127.0.0.1:54321")),
            publishableKey: "public-test-key"
        )
        let backend = InMemoryAuthLocalStorage()
        let provider = SupabaseClientGenerationProvider(
            configuration: configuration,
            storageBackend: backend
        )
        let first = provider.current()

        let second = try provider.rotate(replacing: first.id)

        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(first.lifecycle, .retired)
        XCTAssertEqual(provider.current().id, second.id)
        XCTAssertEqual(second.lifecycle, .active)
        XCTAssertEqual(provider.writableGenerationCount, 1)
    }

    func testFailedLoginCandidateIsRetiredAndCannotWriteLateSession() throws {
        let configuration = try SupabaseConfiguration(
            url: XCTUnwrap(URL(string: "http://127.0.0.1:54321")),
            publishableKey: "public-test-key"
        )
        let backend = InMemoryAuthLocalStorage()
        let provider = SupabaseClientGenerationProvider(configuration: configuration, storageBackend: backend)
        let initial = provider.current()
        let candidate = try provider.rotate(replacing: initial.id)
        try candidate.authStorage.store(key: AppEnvironment.authStorageKey, value: Data("candidate".utf8))

        let replacement = try provider.retireFailedCandidate(expectedID: candidate.id)

        XCTAssertEqual(candidate.lifecycle, .retired)
        XCTAssertEqual(replacement.lifecycle, .active)
        XCTAssertNil(try backend.retrieve(key: AppEnvironment.authStorageKey))
        XCTAssertThrowsError(
            try candidate.authStorage.store(
                key: AppEnvironment.authStorageKey,
                value: Data("late-candidate".utf8)
            )
        )
    }

    func testRestoreGenerationReplacedByLoginCannotOverwriteNewSession() throws {
        let configuration = try SupabaseConfiguration(
            url: XCTUnwrap(URL(string: "http://127.0.0.1:54321")),
            publishableKey: "public-test-key"
        )
        let backend = InMemoryAuthLocalStorage()
        let provider = SupabaseClientGenerationProvider(configuration: configuration, storageBackend: backend)
        let restoreGeneration = provider.current()
        let loginGeneration = try provider.rotate(replacing: restoreGeneration.id)
        try loginGeneration.authStorage.store(
            key: AppEnvironment.authStorageKey,
            value: Data("new-login".utf8)
        )

        XCTAssertThrowsError(
            try restoreGeneration.authStorage.store(
                key: AppEnvironment.authStorageKey,
                value: Data("late-restore".utf8)
            )
        )
        XCTAssertEqual(
            try backend.retrieve(key: AppEnvironment.authStorageKey),
            Data("new-login".utf8)
        )
    }

    func testSameUserCanSignInAgainThroughFreshGeneration() throws {
        let (provider, backend) = try makeProvider()
        let first = provider.current()
        try first.authStorage.store(key: AppEnvironment.authStorageKey, value: Data("same-user-old".utf8))
        let second = try provider.rotate(replacing: first.id)
        try second.authStorage.store(key: AppEnvironment.authStorageKey, value: Data("same-user-new".utf8))

        XCTAssertEqual(try backend.retrieve(key: AppEnvironment.authStorageKey), Data("same-user-new".utf8))
        XCTAssertEqual(second.lifecycle, .active)
    }

    func testUserALateRefreshCannotOverwriteUserBSession() throws {
        let (provider, backend) = try makeProvider()
        let userAGeneration = provider.current()
        let userBGeneration = try provider.rotate(replacing: userAGeneration.id)
        try userBGeneration.authStorage.store(key: AppEnvironment.authStorageKey, value: Data("user-b".utf8))

        XCTAssertThrowsError(
            try userAGeneration.authStorage.store(
                key: AppEnvironment.authStorageKey,
                value: Data("user-a-late-refresh".utf8)
            )
        )
        XCTAssertEqual(try backend.retrieve(key: AppEnvironment.authStorageKey), Data("user-b".utf8))
    }

    func testCancelledLoginCandidateIsRetiredBeforeLateCompletion() throws {
        let (provider, backend) = try makeProvider()
        let candidate = try provider.rotate(replacing: provider.current().id)
        _ = try provider.retireFailedCandidate(expectedID: candidate.id)

        XCTAssertThrowsError(
            try candidate.authStorage.store(
                key: AppEnvironment.authStorageKey,
                value: Data("cancelled-login-late-result".utf8)
            )
        )
        XCTAssertNil(try backend.retrieve(key: AppEnvironment.authStorageKey))
        XCTAssertEqual(candidate.lifecycle, .retired)
    }

    func testLateOldRefreshAndFailedNewLoginCannotRestoreSessionOnColdStart() throws {
        let (provider, backend) = try makeProvider()
        let oldRefreshGeneration = provider.current()
        try oldRefreshGeneration.authStorage.store(
            key: AppEnvironment.authStorageKey,
            value: Data("old-session".utf8)
        )

        let loginCandidate = try provider.rotate(replacing: oldRefreshGeneration.id)
        XCTAssertNil(try backend.retrieve(key: AppEnvironment.authStorageKey))
        XCTAssertThrowsError(
            try oldRefreshGeneration.authStorage.store(
                key: AppEnvironment.authStorageKey,
                value: Data("late-old-refresh".utf8)
            )
        )

        _ = try provider.retireFailedCandidate(expectedID: loginCandidate.id)
        let coldStartStorage = InMemoryAuthLocalStorage(snapshotOf: backend)

        XCTAssertEqual(oldRefreshGeneration.lifecycle, .retired)
        XCTAssertEqual(loginCandidate.lifecycle, .retired)
        XCTAssertNil(try coldStartStorage.retrieve(key: AppEnvironment.authStorageKey))
    }

    func testRetirementCanRetryAfterTransientDeletionFailure() throws {
        let backend = FailOnceRemoveAuthLocalStorage()
        let provider = SupabaseClientGenerationProvider(
            configuration: try makeConfiguration(),
            storageBackend: backend
        )
        let generation = provider.current()
        try generation.authStorage.store(
            key: AppEnvironment.authStorageKey,
            value: Data("session".utf8)
        )

        XCTAssertThrowsError(try provider.rotate(replacing: generation.id))
        XCTAssertEqual(generation.lifecycle, .retiring)
        XCTAssertEqual(provider.writableGenerationCount, 0)

        let replacement = try provider.rotate(replacing: generation.id)

        XCTAssertEqual(generation.lifecycle, .retired)
        XCTAssertEqual(replacement.lifecycle, .active)
    }

    func testClientFactoryCanReenterProviderDuringRotation() throws {
        let configuration = try makeConfiguration()
        let backend = InMemoryAuthLocalStorage()
        var provider: SupabaseClientGenerationProvider?
        var didReenter = false
        provider = SupabaseClientGenerationProvider(
            configuration: configuration,
            storageBackend: backend,
            clientFactory: { configuration, storage in
                if provider != nil {
                    _ = provider?.current()
                    didReenter = true
                }
                return SupabaseClient(
                    supabaseURL: configuration.url,
                    supabaseKey: configuration.publishableKey,
                    options: .init(auth: .init(storage: storage, storageKey: AppEnvironment.authStorageKey))
                )
            }
        )

        let currentID = try XCTUnwrap(provider?.current().id)
        _ = try provider?.rotate(replacing: currentID)

        XCTAssertTrue(didReenter)
        XCTAssertEqual(provider?.writableGenerationCount, 1)
    }

    private func makeProvider() throws -> (SupabaseClientGenerationProvider, InMemoryAuthLocalStorage) {
        let configuration = try makeConfiguration()
        let backend = InMemoryAuthLocalStorage()
        return (
            SupabaseClientGenerationProvider(configuration: configuration, storageBackend: backend),
            backend
        )
    }

    private func makeConfiguration() throws -> SupabaseConfiguration {
        try SupabaseConfiguration(
            url: XCTUnwrap(URL(string: "http://127.0.0.1:54321")),
            publishableKey: "public-test-key"
        )
    }
}

private final class InMemoryAuthLocalStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]

    init() {}

    init(snapshotOf other: InMemoryAuthLocalStorage) {
        values = other.lock.withLock { other.values }
    }

    func store(key: String, value: Data) throws {
        lock.withLock { values[key] = value }
    }

    func retrieve(key: String) throws -> Data? {
        lock.withLock { values[key] }
    }

    func remove(key: String) throws {
        lock.withLock { values[key] = nil }
    }
}

private final class FailOnceRemoveAuthLocalStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var value: Data?
    private var shouldFailRemove = true

    func store(key: String, value: Data) throws {
        lock.withLock { self.value = value }
    }

    func retrieve(key: String) throws -> Data? {
        lock.withLock { value }
    }

    func remove(key: String) throws {
        try lock.withLock {
            if shouldFailRemove {
                shouldFailRemove = false
                throw TestAccountError.expected
            }
            value = nil
        }
    }
}
