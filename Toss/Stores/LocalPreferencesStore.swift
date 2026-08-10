import Foundation

protocol PreferencesKeyValueStoring: AnyObject {
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
}

extension UserDefaults: PreferencesKeyValueStoring {}

final class LocalPreferencesStore {
    private enum Keys {
        static let guestSound = "guest.soundEnabled"
        static let guestHaptic = "guest.hapticEnabled"
        static func account(_ userID: UUID) -> String { "account.preferences.\(userID.uuidString.lowercased())" }
    }

    private let store: any PreferencesKeyValueStoring
    private let defaults: LocalPreferences

    init(store: any PreferencesKeyValueStoring = UserDefaults.standard, defaults: LocalPreferences = .defaults) {
        self.store = store
        self.defaults = defaults
    }

    var guestPreferences: LocalPreferences {
        LocalPreferences(
            soundEnabled: store.object(forKey: Keys.guestSound) as? Bool ?? defaults.soundEnabled,
            hapticEnabled: store.object(forKey: Keys.guestHaptic) as? Bool ?? defaults.hapticEnabled
        )
    }

    func saveGuest(_ preferences: LocalPreferences) {
        store.set(preferences.soundEnabled, forKey: Keys.guestSound)
        store.set(preferences.hapticEnabled, forKey: Keys.guestHaptic)
    }

    func cache(_ preferences: LocalPreferences, for userID: UUID) {
        store.set(try? JSONEncoder().encode(preferences), forKey: Keys.account(userID))
    }

    func cachedPreferences(for userID: UUID) -> LocalPreferences? {
        guard let data = store.object(forKey: Keys.account(userID)) as? Data else { return nil }
        return try? JSONDecoder().decode(LocalPreferences.self, from: data)
    }
}
