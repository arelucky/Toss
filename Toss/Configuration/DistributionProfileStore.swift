import Foundation

final class DistributionProfileStore {
    private enum Key {
        static let profile = "distribution.profile"
        static let resolutionVersion = "distribution.profile.resolution-version"
    }

    private static let currentResolutionVersion = 1

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

    var hasCurrentResolutionVersion: Bool {
        (store.object(forKey: Key.resolutionVersion) as? Int) == Self.currentResolutionVersion
    }

    func save(_ profile: DistributionProfile) {
        store.set(profile.rawValue, forKey: Key.profile)
        store.set(Self.currentResolutionVersion, forKey: Key.resolutionVersion)
    }
}
