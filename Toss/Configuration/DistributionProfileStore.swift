import Foundation

final class DistributionProfileStore {
    private enum Key {
        static let profile = "distribution.profile"
    }

    private let store: any PreferencesKeyValueStoring

    init(store: any PreferencesKeyValueStoring = UserDefaults.standard) {
        self.store = store
    }

    var storedProfile: DistributionProfile? {
        guard let rawValue = store.object(forKey: Key.profile) as? String else {
            return nil
        }

        return DistributionProfile(rawValue: rawValue)
    }

    func save(_ profile: DistributionProfile) {
        store.set(profile.rawValue, forKey: Key.profile)
    }
}
