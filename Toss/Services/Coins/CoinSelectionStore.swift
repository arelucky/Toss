import Combine
import Foundation

enum SelectedCoin: Equatable, Sendable {
    case bundledClassic
    case downloaded(CoinCatalogItem, localModelURL: URL)
}

protocol CoinLocalSelectionStoring: Sendable {
    var selectedCoinID: UUID? { get set }
}

final class UserDefaultsCoinLocalSelectionStore: CoinLocalSelectionStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "guestSelectedCoinID") {
        self.defaults = defaults
        self.key = key
    }

    var selectedCoinID: UUID? {
        get { defaults.string(forKey: key).flatMap(UUID.init(uuidString:)) }
        set { defaults.set(newValue?.uuidString, forKey: key) }
    }
}

@MainActor
final class CoinSelectionStore: ObservableObject {
    @Published private(set) var selectedCoin: SelectedCoin = .bundledClassic

    private let catalog: any CoinCatalogServicing
    private let assets: any CoinAssetCaching
    private let preferences: any SelectedCoinPreferenceServicing
    private var localSelection: any CoinLocalSelectionStoring
    private let isGenerationCurrent: @Sendable (UUID) -> Bool
    private let isCoinIdle: @Sendable () -> Bool
    private var pendingSelection: SelectedCoin?

    init(
        catalog: any CoinCatalogServicing,
        assets: any CoinAssetCaching,
        preferences: any SelectedCoinPreferenceServicing,
        localSelection: any CoinLocalSelectionStoring = UserDefaultsCoinLocalSelectionStore(),
        isGenerationCurrent: @escaping @Sendable (UUID) -> Bool,
        isCoinIdle: @escaping @Sendable () -> Bool
    ) {
        self.catalog = catalog
        self.assets = assets
        self.preferences = preferences
        self.localSelection = localSelection
        self.isGenerationCurrent = isGenerationCurrent
        self.isCoinIdle = isCoinIdle
    }

    func select(_ item: CoinCatalogItem, session: AccountSession, generationID: UUID) async {
        switch session {
        case .guest, .restoring:
            localSelection.selectedCoinID = item.id
        case let .authenticated(userID):
            guard isGenerationCurrent(generationID) else { return }
            do {
                try await preferences.updateSelectedCoinID(
                    item.id,
                    for: userID,
                    generationID: generationID
                )
            } catch {
                return
            }
            guard isGenerationCurrent(generationID) else { return }
        }
        await resolveAndPublish(item, generationID: session.isAuthenticated ? generationID : nil)
    }

    func selectClassic(session: AccountSession, generationID: UUID) async {
        switch session {
        case .guest, .restoring:
            localSelection.selectedCoinID = nil
        case let .authenticated(userID):
            guard isGenerationCurrent(generationID) else { return }
            do {
                try await preferences.updateSelectedCoinID(
                    nil,
                    for: userID,
                    generationID: generationID
                )
            } catch {
                // The current display still falls back safely to Classic.
            }
            guard isGenerationCurrent(generationID) else { return }
        }
        publish(.bundledClassic)
    }

    func synchronize(session: AccountSession, generationID: UUID) async {
        do {
            let items = try await catalog.fetchPublishedCatalog()
            let selectedID: UUID?
            switch session {
            case .guest, .restoring:
                selectedID = localSelection.selectedCoinID
            case let .authenticated(userID):
                guard isGenerationCurrent(generationID) else { return }
                selectedID = try await preferences.fetchSelectedCoinID(
                    for: userID,
                    generationID: generationID
                )
                guard isGenerationCurrent(generationID) else { return }
            }
            guard let selectedID,
                  let item = items.first(where: { $0.id == selectedID }) else {
                publish(.bundledClassic)
                return
            }
            await resolveAndPublish(
                item,
                generationID: session.isAuthenticated ? generationID : nil
            )
        } catch {
            publish(.bundledClassic)
        }
    }

    func publishPendingSelectionIfIdle() {
        guard isCoinIdle(), let pendingSelection else { return }
        selectedCoin = pendingSelection
        self.pendingSelection = nil
    }

    private func resolveAndPublish(_ item: CoinCatalogItem, generationID: UUID?) async {
        if let localURL = await assets.cachedModelURL(for: item) {
            guard generationID.map(isGenerationCurrent) ?? true else { return }
            publish(.downloaded(item, localModelURL: localURL))
            return
        }
        do {
            let localURL = try await assets.downloadAndValidate(item)
            guard generationID.map(isGenerationCurrent) ?? true else { return }
            publish(.downloaded(item, localModelURL: localURL))
        } catch {
            guard generationID.map(isGenerationCurrent) ?? true else { return }
            publish(.bundledClassic)
        }
    }

    private func publish(_ selection: SelectedCoin) {
        guard isCoinIdle() else {
            pendingSelection = selection
            return
        }
        selectedCoin = selection
        pendingSelection = nil
    }
}

private extension AccountSession {
    var isAuthenticated: Bool {
        if case .authenticated = self { return true }
        return false
    }
}
