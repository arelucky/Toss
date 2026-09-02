import Combine
import Foundation

@MainActor
final class ClassicSettingsViewModel: ObservableObject {
    @Published private(set) var soundEnabled: Bool
    @Published private(set) var hapticEnabled: Bool

    private let localPreferences: LocalPreferencesStore
    private let feedbackPreferences: any FeedbackPreferenceApplying

    init(
        localPreferences: LocalPreferencesStore,
        feedbackPreferences: any FeedbackPreferenceApplying
    ) {
        self.localPreferences = localPreferences
        self.feedbackPreferences = feedbackPreferences

        let preferences = localPreferences.guestPreferences
        soundEnabled = preferences.soundEnabled
        hapticEnabled = preferences.hapticEnabled
        feedbackPreferences.apply(preferences)
    }

    convenience init() {
        self.init(
            localPreferences: LocalPreferencesStore(),
            feedbackPreferences: AppFeedbackPreferencesController()
        )
    }

    func setSoundEnabled(_ isEnabled: Bool) {
        soundEnabled = isEnabled
        persistAndApply()
    }

    func setHapticEnabled(_ isEnabled: Bool) {
        hapticEnabled = isEnabled
        persistAndApply()
    }

    private func persistAndApply() {
        let preferences = LocalPreferences(
            soundEnabled: soundEnabled,
            hapticEnabled: hapticEnabled
        )
        localPreferences.saveGuest(preferences)
        feedbackPreferences.apply(preferences)
    }
}
