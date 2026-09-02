import XCTest
@testable import Toss

final class ClassicSettingsViewModelTests: XCTestCase {
    @MainActor
    func testClassicSettingsPersistAndApplyFeedbackLocally() {
        let storage = SettingsKeyValueStore()
        let feedback = FeedbackDouble()
        let localPreferences = LocalPreferencesStore(store: storage)
        let model = ClassicSettingsViewModel(
            localPreferences: localPreferences,
            feedbackPreferences: feedback
        )

        model.setSoundEnabled(false)

        XCTAssertEqual(
            localPreferences.guestPreferences,
            .init(soundEnabled: false, hapticEnabled: true)
        )
        XCTAssertEqual(feedback.applied, .init(soundEnabled: false, hapticEnabled: true))

        model.setHapticEnabled(false)

        XCTAssertFalse(model.soundEnabled)
        XCTAssertFalse(model.hapticEnabled)
        XCTAssertEqual(
            localPreferences.guestPreferences,
            .init(soundEnabled: false, hapticEnabled: false)
        )
        XCTAssertEqual(feedback.applied, .init(soundEnabled: false, hapticEnabled: false))
    }
}

private final class SettingsKeyValueStore: PreferencesKeyValueStoring {
    private var values: [String: Any] = [:]

    func object(forKey key: String) -> Any? {
        values[key]
    }

    func set(_ value: Any?, forKey key: String) {
        values[key] = value
    }
}

@MainActor
private final class FeedbackDouble: FeedbackPreferenceApplying {
    private(set) var applied: LocalPreferences?

    func apply(_ preferences: LocalPreferences) {
        applied = preferences
    }
}
