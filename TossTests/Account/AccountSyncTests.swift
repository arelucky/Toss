import Supabase
import XCTest
@testable import Toss

@MainActor
final class AccountSyncTests: XCTestCase {
    func testFirstAppleNameIsSavedToEmptyProfile() async {
        let userID = UUID()
        let profile = ProfileRepositoryDouble()
        let pendingName = PendingNameStoreDouble(userID: userID, name: "  Ada  ")
        let coordinator = makeCoordinator(profile: profile, pendingName: pendingName)

        await coordinator.synchronizeProfile(for: userID)

        XCTAssertEqual(profile.savedNames, ["Ada"])
        XCTAssertEqual(pendingName.consumeCount, 1)
    }

    func testFailedNameWriteIsRetriedAndConsumedOnlyAfterSuccess() async {
        let userID = UUID()
        let profile = ProfileRepositoryDouble()
        profile.saveResults = [.failure(SyncTestError.expected), .success(.fixture(userID: userID, name: "Ada"))]
        let pendingName = PendingNameStoreDouble(userID: userID, name: "Ada")
        let coordinator = makeCoordinator(profile: profile, pendingName: pendingName)

        await coordinator.synchronizeProfile(for: userID)
        XCTAssertEqual(pendingName.consumeCount, 0)
        await coordinator.synchronizeProfile(for: userID)

        XCTAssertEqual(profile.savedNames, ["Ada", "Ada"])
        XCTAssertEqual(pendingName.consumeCount, 1)
    }

    func testEmptyNameAndExistingServerNameAreNotOverwritten() async {
        let userID = UUID()
        let profile = ProfileRepositoryDouble()
        profile.currentProfile = .fixture(userID: userID, name: "Existing")
        let pendingName = PendingNameStoreDouble(userID: userID, name: "   ")
        let coordinator = makeCoordinator(profile: profile, pendingName: pendingName)

        await coordinator.synchronizeProfile(for: userID)

        XCTAssertTrue(profile.savedNames.isEmpty)
        XCTAssertEqual(pendingName.consumeCount, 0)

        pendingName.candidate = .init(userID: userID, generationID: .init(), displayName: "New Name")
        await coordinator.synchronizeProfile(for: userID)
        XCTAssertTrue(profile.savedNames.isEmpty)
        XCTAssertEqual(pendingName.consumeCount, 1)
    }

    func testNewAccountBootstrapsWithGuestPreferences() async {
        let userID = UUID()
        let preferences = PreferencesRepositoryDouble()
        preferences.bootstrapResult = .uploadedGuestPreferences(.fixture(userID: userID, sound: false, haptic: true))
        let local = LocalPreferencesStore(store: InMemoryKeyValueStore(), defaults: .init(soundEnabled: false, hapticEnabled: true))
        let feedback = FeedbackDouble()
        let coordinator = makeCoordinator(preferences: preferences, local: local, feedback: feedback)

        await coordinator.synchronizePreferences(for: userID)

        XCTAssertEqual(preferences.bootstrapGuests, [.init(soundEnabled: false, hapticEnabled: true)])
        XCTAssertEqual(feedback.applied.last, .init(soundEnabled: false, hapticEnabled: true))
    }

    func testExistingAccountUsesServerPreferences() async {
        let userID = UUID()
        let preferences = PreferencesRepositoryDouble()
        preferences.bootstrapResult = .existingAccount(.fixture(userID: userID, sound: true, haptic: false))
        let local = LocalPreferencesStore(store: InMemoryKeyValueStore(), defaults: .init(soundEnabled: false, hapticEnabled: true))
        let feedback = FeedbackDouble()
        let coordinator = makeCoordinator(preferences: preferences, local: local, feedback: feedback)

        await coordinator.synchronizePreferences(for: userID)

        XCTAssertEqual(local.guestPreferences, .init(soundEnabled: false, hapticEnabled: true))
        XCTAssertEqual(feedback.applied.last, .init(soundEnabled: true, hapticEnabled: false))
    }

    func testAccountCacheIsIsolatedByUserID() {
        let local = LocalPreferencesStore(store: InMemoryKeyValueStore())
        let userA = UUID()
        let userB = UUID()
        local.cache(.init(soundEnabled: false, hapticEnabled: true), for: userA)
        local.cache(.init(soundEnabled: true, hapticEnabled: false), for: userB)

        XCTAssertEqual(local.cachedPreferences(for: userA), .init(soundEnabled: false, hapticEnabled: true))
        XCTAssertEqual(local.cachedPreferences(for: userB), .init(soundEnabled: true, hapticEnabled: false))
    }

    func testOfflineUsesMatchingCacheAndOtherwiseKeepsGuest() async {
        let cachedUser = UUID()
        let uncachedUser = UUID()
        let preferences = PreferencesRepositoryDouble()
        preferences.bootstrapError = SyncTestError.expected
        let local = LocalPreferencesStore(store: InMemoryKeyValueStore(), defaults: .init(soundEnabled: true, hapticEnabled: true))
        local.cache(.init(soundEnabled: false, hapticEnabled: false), for: cachedUser)
        let feedback = FeedbackDouble()
        let coordinator = makeCoordinator(preferences: preferences, local: local, feedback: feedback)

        await coordinator.synchronizePreferences(for: cachedUser)
        XCTAssertEqual(feedback.applied.last, .init(soundEnabled: false, hapticEnabled: false))
        await coordinator.synchronizePreferences(for: uncachedUser)
        XCTAssertEqual(feedback.applied.last, .init(soundEnabled: true, hapticEnabled: true))
    }

    func testLogoutRestoresGuestPreferences() {
        let local = LocalPreferencesStore(store: InMemoryKeyValueStore(), defaults: .init(soundEnabled: false, hapticEnabled: true))
        let feedback = FeedbackDouble()
        let coordinator = makeCoordinator(local: local, feedback: feedback)

        coordinator.didSignOut()

        XCTAssertEqual(feedback.applied.last, .init(soundEnabled: false, hapticEnabled: true))
    }

    func testRepositoryRejectsResultFromRetiredGeneration() async throws {
        let storage = RepositoryStorageDouble()
        let provider = SupabaseClientGenerationProvider(
            configuration: .init(url: URL(string: "http://127.0.0.1:54321")!, publishableKey: "public-test-key"),
            storageBackend: storage
        )
        let userID = UUID()
        let operation = TestOperationGate()
        let repository = SupabaseUserProfileRepository(provider: provider, authenticatedUserID: { _ in userID }) { _, _ in
            await operation.suspend()
            return .fixture(userID: userID, name: nil)
        }

        let task = Task { try await repository.fetch(userID: userID) }
        await operation.waitUntilStarted()
        let oldID = provider.current().id
        _ = try provider.rotate(replacing: oldID)
        operation.complete()

        do {
            _ = try await task.value
            XCTFail("Expected retired generation result to be rejected")
        } catch {
            XCTAssertEqual(error as? AccountRepositoryError, .generationExpired)
        }
    }

    func testFeedbackManagersCanBeDisabledAndReenabled() {
        let haptic = HapticManager(isEnabled: true)
        let sound = SoundManager(bundle: .main, isEnabled: true)

        haptic.setEnabled(false)
        sound.setEnabled(false)
        XCTAssertFalse(haptic.isEnabled)
        XCTAssertFalse(sound.isEnabled)
        haptic.setEnabled(true)
        sound.setEnabled(true)
        XCTAssertTrue(haptic.isEnabled)
        XCTAssertTrue(sound.isEnabled)
    }

    private func makeCoordinator(
        profile: ProfileRepositoryDouble = ProfileRepositoryDouble(),
        preferences: PreferencesRepositoryDouble = PreferencesRepositoryDouble(),
        local: LocalPreferencesStore = LocalPreferencesStore(store: InMemoryKeyValueStore()),
        feedback: FeedbackDouble? = nil,
        pendingName: PendingNameStoreDouble = PendingNameStoreDouble()
    ) -> AccountSyncCoordinator {
        AccountSyncCoordinator(
            profileRepository: profile,
            preferencesRepository: preferences,
            localPreferences: local,
            feedback: feedback ?? FeedbackDouble(),
            pendingNameStore: pendingName
        )
    }
}

private enum SyncTestError: Error { case expected }

private final class ProfileRepositoryDouble: UserProfileRepository {
    var currentProfile = UserProfile.fixture(userID: UUID(), name: nil)
    var savedNames: [String] = []
    var saveResults: [Result<UserProfile, Error>] = []
    func fetch(userID: UUID) async throws -> UserProfile { currentProfile }
    func saveInitialDisplayName(_ displayName: String, userID: UUID) async throws -> UserProfile {
        if currentProfile.id == userID, currentProfile.displayName != nil { return currentProfile }
        savedNames.append(displayName)
        if !saveResults.isEmpty { return try saveResults.removeFirst().get() }
        return .fixture(userID: userID, name: displayName)
    }
}

private final class PreferencesRepositoryDouble: UserPreferencesRepository {
    var bootstrapResult = PreferenceBootstrapResult.existingAccount(.fixture(userID: UUID(), sound: true, haptic: true))
    var bootstrapError: Error?
    var bootstrapGuests: [LocalPreferences] = []
    func fetch(userID: UUID) async throws -> UserPreferences { try bootstrapResult.preferences }
    func update(_ preferences: UserPreferences) async throws -> UserPreferences { preferences }
    func bootstrap(userID: UUID, guestPreferences: LocalPreferences) async throws -> PreferenceBootstrapResult {
        bootstrapGuests.append(guestPreferences)
        if let bootstrapError { throw bootstrapError }
        return bootstrapResult
    }
}

private final class PendingNameStoreDouble: PendingDisplayNameStoring {
    var candidate: PendingDisplayNameCandidate?
    var consumeCount = 0
    init(userID: UUID? = nil, name: String? = nil) {
        if let userID, let name { candidate = .init(userID: userID, generationID: .init(), displayName: name) }
    }
    func pendingDisplayName(for userID: UUID) -> PendingDisplayNameCandidate? { candidate?.userID == userID ? candidate : nil }
    func markPendingDisplayNameConsumed(_ candidate: PendingDisplayNameCandidate) { self.candidate = nil; consumeCount += 1 }
}

private final class FeedbackDouble: FeedbackPreferenceApplying {
    var applied: [LocalPreferences] = []
    func apply(_ preferences: LocalPreferences) { applied.append(preferences) }
}

private final class InMemoryKeyValueStore: PreferencesKeyValueStoring {
    private var values: [String: Any] = [:]
    func object(forKey key: String) -> Any? { values[key] }
    func set(_ value: Any?, forKey key: String) { values[key] = value }
}

private final class RepositoryStorageDouble: AuthLocalStorage, @unchecked Sendable {
    private var values: [String: Data] = [:]
    func store(key: String, value: Data) throws { values[key] = value }
    func retrieve(key: String) throws -> Data? { values[key] }
    func remove(key: String) throws { values[key] = nil }
}

private extension UserProfile {
    static func fixture(userID: UUID, name: String?) -> UserProfile {
        .init(id: userID, displayName: name, status: .active, createdAt: .distantPast, updatedAt: .distantPast)
    }
}

private extension UserPreferences {
    static func fixture(userID: UUID, sound: Bool, haptic: Bool) -> UserPreferences {
        .init(userID: userID, soundEnabled: sound, hapticEnabled: haptic, createdAt: .distantPast, updatedAt: .distantPast)
    }
}

private extension PreferenceBootstrapResult {
    var preferences: UserPreferences {
        switch self { case let .uploadedGuestPreferences(value), let .existingAccount(value): value }
    }
}
