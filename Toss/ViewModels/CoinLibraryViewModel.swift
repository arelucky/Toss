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
    @Published private(set) var preselectedID: CoinLibraryItemID = .classic
    @Published private(set) var downloadingIDs: Set<CoinLibraryItemID> = []
    @Published private(set) var downloadProgress: [CoinLibraryItemID: CoinFileDownloadProgress] = [:]
    @Published private(set) var cachedIDs: Set<CoinLibraryItemID> = [.classic]
    @Published private(set) var selectedModelSource: CoinModelSource = .bundledClassic
    @Published private(set) var preselectedModelSource: CoinModelSource = .bundledClassic
    @Published var notice: String?

    private let catalog: any CoinCatalogServicing
    private let assets: any CoinAssetCaching
    private let selection: any CoinSelecting
    private let session: () -> AccountSession
    private let generationID: () -> UUID
    private let isOnline: () -> Bool
    private var catalogItems: [CoinCatalogItem]
    private var cachedModelURLs: [UUID: URL] = [:]
    private var downloadTokens: [CoinLibraryItemID: UUID] = [:]

    var canApplyPreselection: Bool {
        let isAvailable = preselectedID == .classic || cachedIDs.contains(preselectedID)
        return isAvailable && !downloadingIDs.contains(preselectedID) && preselectedID != selectedID
    }

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
            catalogItems = remote
            items = Self.libraryItems(from: catalogItems)
            await updateAvailability()
            if case let .coin(preselectedCoinID) = preselectedID,
               !remote.contains(where: { $0.id == preselectedCoinID }) {
                preselectedID = .classic
                preselectedModelSource = .bundledClassic
            }
            if case let .coin(selectedCoinID) = selectedID,
               !remote.contains(where: { $0.id == selectedCoinID }) {
                await selection.selectClassic(session: session(), generationID: generationID())
                selectedID = .classic
                selectedModelSource = .bundledClassic
                preselectedID = .classic
                preselectedModelSource = .bundledClassic
            }
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

    @discardableResult
    func preselect(_ id: CoinLibraryItemID) async -> Bool {
        guard isEnabled(id), !downloadingIDs.contains(id) else { return false }
        if id == .classic {
            preselectedID = .classic
            preselectedModelSource = .bundledClassic
            return true
        }
        guard case let .coin(coinID) = id,
              let item = catalogItems.first(where: { $0.id == coinID }) else { return false }
        var localModelURL = cachedModelURLs[coinID]
        if localModelURL == nil {
            downloadingIDs.insert(id)
            let downloadToken = UUID()
            downloadTokens[id] = downloadToken
            defer {
                downloadingIDs.remove(id)
                downloadProgress[id] = nil
                downloadTokens[id] = nil
            }
            do {
                let downloadedURL = try await assets.downloadAndValidate(item) { [weak self] progress in
                    Task { @MainActor [weak self] in
                        guard self?.downloadTokens[id] == downloadToken else { return }
                        self?.downloadProgress[id] = progress
                    }
                }
                cachedIDs.insert(id)
                cachedModelURLs[coinID] = downloadedURL
                localModelURL = downloadedURL
            } catch {
                notice = "The coin could not be downloaded. Please try again."
                return false
            }
        }
        guard let localModelURL else { return false }
        preselectedID = id
        preselectedModelSource = .downloaded(localModelURL)
        return true
    }

    func applyPreselection() async {
        guard canApplyPreselection else { return }
        switch preselectedID {
        case .classic:
            await selection.selectClassic(session: session(), generationID: generationID())
            selectedID = .classic
            selectedModelSource = .bundledClassic
        case let .coin(coinID):
            guard let item = catalogItems.first(where: { $0.id == coinID }),
                  case let .downloaded(localModelURL) = preselectedModelSource else { return }
            await selection.select(item, session: session(), generationID: generationID())
            selectedID = .coin(coinID)
            selectedModelSource = .downloaded(localModelURL)
        }
    }

    func select(_ id: CoinLibraryItemID) async {
        guard await preselect(id) else { return }
        await applyPreselection()
    }

    private static func libraryItems(from catalog: [CoinCatalogItem]) -> [CoinLibraryItem] {
        let sorted = catalog.sorted { ($0.sortOrder, $0.slug) < ($1.sortOrder, $1.slug) }
        return [CoinLibraryItem(id: .classic, coin: nil)] + sorted.map { CoinLibraryItem(id: .coin($0.id), coin: $0) }
    }
}
