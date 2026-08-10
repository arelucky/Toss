import Foundation

final class AccountDeletionRequestStore {
    private static let key = "account.deletion.requestID"
    private let store: any PreferencesKeyValueStoring
    private let makeID: () -> UUID

    init(
        store: any PreferencesKeyValueStoring = UserDefaults.standard,
        makeID: @escaping () -> UUID = UUID.init
    ) {
        self.store = store
        self.makeID = makeID
    }

    var current: UUID? {
        guard let value = store.object(forKey: Self.key) as? String else { return nil }
        return UUID(uuidString: value)
    }

    func currentOrCreate() -> UUID {
        if let current { return current }
        let requestID = makeID()
        store.set(requestID.uuidString.lowercased(), forKey: Self.key)
        return requestID
    }

    func clear() {
        store.set(nil, forKey: Self.key)
    }
}
