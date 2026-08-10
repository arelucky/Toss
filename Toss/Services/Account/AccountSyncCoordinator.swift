import Foundation

@MainActor
protocol FeedbackPreferenceApplying: AnyObject {
    func apply(_ preferences: LocalPreferences)
}

@MainActor
final class AccountSyncCoordinator {
    private let profileRepository: any UserProfileRepository
    private let preferencesRepository: any UserPreferencesRepository
    private let localPreferences: LocalPreferencesStore
    private let feedback: any FeedbackPreferenceApplying
    private weak var pendingNameStore: (any PendingDisplayNameStoring)?
    private var preferenceWriteTask: Task<Void, Never>?
    private(set) var preferencesSyncFailed = false

    init(
        profileRepository: any UserProfileRepository,
        preferencesRepository: any UserPreferencesRepository,
        localPreferences: LocalPreferencesStore,
        feedback: any FeedbackPreferenceApplying,
        pendingNameStore: any PendingDisplayNameStoring
    ) {
        self.profileRepository = profileRepository
        self.preferencesRepository = preferencesRepository
        self.localPreferences = localPreferences
        self.feedback = feedback
        self.pendingNameStore = pendingNameStore
    }

    func synchronize(for userID: UUID) async {
        await synchronizeProfile(for: userID)
        await synchronizePreferences(for: userID)
    }

    func synchronizeProfile(for userID: UUID) async {
        guard let candidate = pendingNameStore?.pendingDisplayName(for: userID) else { return }
        let name = candidate.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        do {
            _ = try await profileRepository.saveInitialDisplayName(name, userID: userID)
            pendingNameStore?.markPendingDisplayNameConsumed(candidate)
        } catch {
            // A transient failure deliberately leaves the in-memory candidate available for retry.
        }
    }

    func synchronizePreferences(for userID: UUID) async {
        let guest = localPreferences.guestPreferences
        do {
            let result = try await preferencesRepository.bootstrap(userID: userID, guestPreferences: guest)
            let value: UserPreferences
            switch result {
            case let .uploadedGuestPreferences(preferences), let .existingAccount(preferences):
                value = preferences
            }
            localPreferences.cache(value.localValue, for: userID)
            feedback.apply(value.localValue)
            preferencesSyncFailed = false
        } catch {
            feedback.apply(localPreferences.cachedPreferences(for: userID) ?? guest)
            preferencesSyncFailed = true
        }
    }

    func updatePreferences(_ preferences: LocalPreferences, for userID: UUID) async {
        feedback.apply(preferences)
        localPreferences.cache(preferences, for: userID)
        let previousWrite = preferenceWriteTask
        let repository = preferencesRepository
        let task = Task { @MainActor [weak self] in
            await previousWrite?.value
            do {
                let current = try await repository.fetch(userID: userID)
                let requested = UserPreferences(
                    userID: userID,
                    soundEnabled: preferences.soundEnabled,
                    hapticEnabled: preferences.hapticEnabled,
                    createdAt: current.createdAt,
                    updatedAt: current.updatedAt
                )
                let saved = try await repository.update(requested)
                self?.localPreferences.cache(saved.localValue, for: userID)
                self?.preferencesSyncFailed = false
            } catch {
                self?.preferencesSyncFailed = true
            }
        }
        preferenceWriteTask = task
        await task.value
    }

    func didSignOut() {
        preferenceWriteTask?.cancel()
        preferenceWriteTask = nil
        feedback.apply(localPreferences.guestPreferences)
    }

    func didDelete(userID: UUID) {
        preferenceWriteTask?.cancel()
        preferenceWriteTask = nil
        localPreferences.removeCachedPreferences(for: userID)
        feedback.apply(localPreferences.guestPreferences)
    }
}

@MainActor
final class AppFeedbackPreferencesController: FeedbackPreferenceApplying {
    private let hapticManager: HapticManager
    private let soundManager: SoundManager

    init(hapticManager: HapticManager = .shared, soundManager: SoundManager = .shared) {
        self.hapticManager = hapticManager
        self.soundManager = soundManager
    }

    func apply(_ preferences: LocalPreferences) {
        hapticManager.setEnabled(preferences.hapticEnabled)
        soundManager.setEnabled(preferences.soundEnabled)
    }
}
