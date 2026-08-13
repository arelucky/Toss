import Combine
import Foundation

enum CoinLibraryItemID: Hashable, Sendable {
    case classic
    case coin(UUID)
}

struct CoinLibraryItem: Identifiable, Equatable, Sendable {
    let id: CoinLibraryItemID
    let coin: CoinCatalogItem?
    var name: String { coin?.displayName ?? "Classic" }
}

@MainActor
protocol CoinSelecting: AnyObject {
    func select(_ item: CoinCatalogItem, session: AccountSession, generationID: UUID) async
    func selectClassic(session: AccountSession, generationID: UUID) async
}

extension CoinSelecting {
    func selectClassic(session: AccountSession, generationID: UUID) async {}
}

extension CoinSelectionStore: CoinSelecting {}

@MainActor
final class CoinLibraryViewModel: ObservableObject {
    @Published private(set) var items: [CoinLibraryItem]
    @Published private(set) var selectedID: CoinLibraryItemID = .classic
    @Published private(set) var downloadingIDs: Set<CoinLibraryItemID> = []
    @Published private(set) var cachedIDs: Set<CoinLibraryItemID> = [.classic]
    @Published private(set) var selectedModelSource: CoinModelSource = .bundledClassic
    @Published var notice: String?

    private let catalog: any CoinCatalogServicing
    private let assets: any CoinAssetCaching
    private let selection: any CoinSelecting
    private let session: () -> AccountSession
    private let generationID: () -> UUID
    private let isOnline: () -> Bool
    private var catalogItems: [CoinCatalogItem]
    private var cachedModelURLs: [UUID: URL] = [:]

    init(cachedCatalog: () -> [CoinCatalogItem], catalog: any CoinCatalogServicing, assets: any CoinAssetCaching, selection: any CoinSelecting, session: @escaping () -> AccountSession, generationID: @escaping () -> UUID, isOnline: @escaping () -> Bool, tossState: @escaping () -> CoinTossState) {
        let cached = cachedCatalog()
        catalogItems = cached
        items = Self.libraryItems(from: cached)
        self.catalog = catalog
        self.assets = assets
        self.selection = selection
        self.session = session
        self.generationID = generationID
        self.isOnline = isOnline
        _ = tossState
    }

    func refresh() async {
        do {
            let remote = try await catalog.fetchPublishedCatalog()
            var merged = Dictionary(uniqueKeysWithValues: catalogItems.map { ($0.id, $0) })
            remote.forEach { merged[$0.id] = $0 }
            catalogItems = Array(merged.values)
            items = Self.libraryItems(from: catalogItems)
            await updateAvailability()
        } catch {
            await updateAvailability()
        }
    }

    func updateAvailability() async {
        var available: Set<CoinLibraryItemID> = [.classic]
        var localURLs: [UUID: URL] = [:]
        for item in catalogItems {
            if let localURL = await assets.cachedModelURL(for: item) {
                available.insert(.coin(item.id))
                localURLs[item.id] = localURL
            }
        }
        cachedIDs = available
        cachedModelURLs = localURLs
    }

    func isEnabled(_ id: CoinLibraryItemID) -> Bool {
        id == .classic || cachedIDs.contains(id) || isOnline()
    }

    func select(_ id: CoinLibraryItemID) async {
        guard isEnabled(id), !downloadingIDs.contains(id) else { return }
        if id == .classic {
            await selection.selectClassic(session: session(), generationID: generationID())
            selectedID = .classic
            selectedModelSource = .bundledClassic
            return
        }
        guard case let .coin(coinID) = id,
              let item = catalogItems.first(where: { $0.id == coinID }) else { return }
        var localModelURL = cachedModelURLs[coinID]
        if localModelURL == nil {
            downloadingIDs.insert(id)
            defer { downloadingIDs.remove(id) }
            do {
                let downloadedURL = try await assets.downloadAndValidate(item)
                cachedIDs.insert(id)
                cachedModelURLs[coinID] = downloadedURL
                localModelURL = downloadedURL
            } catch {
                notice = "The coin could not be downloaded. Please try again."
                return
            }
        }
        guard let localModelURL else { return }
        await selection.select(item, session: session(), generationID: generationID())
        selectedID = id
        selectedModelSource = .downloaded(localModelURL)
    }

    private static func libraryItems(from catalog: [CoinCatalogItem]) -> [CoinLibraryItem] {
        let sorted = catalog.sorted { ($0.sortOrder, $0.slug) < ($1.sortOrder, $1.slug) }
        return [CoinLibraryItem(id: .classic, coin: nil)] + sorted.map { CoinLibraryItem(id: .coin($0.id), coin: $0) }
    }
}
