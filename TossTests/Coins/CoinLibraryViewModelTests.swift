import Foundation
import XCTest
@testable import Toss

@MainActor
final class CoinLibraryViewModelTests: XCTestCase {
    func testStartsWithClassicFirst() {
        let subject = Subject()
        XCTAssertEqual(subject.viewModel.items.map(\.id), [.classic])
    }

    func testShowsCachedCatalogBeforeMergingRemoteRefresh() async {
        let cached = makeItem(name: "Cached", order: 2)
        let remote = makeItem(name: "Remote", order: 1)
        let subject = Subject(cached: [cached], remote: [remote])
        XCTAssertEqual(subject.viewModel.items.map(\.id), [.classic, .coin(cached.id)])

        await subject.viewModel.refresh()

        XCTAssertEqual(subject.viewModel.items.map(\.id), [.classic, .coin(remote.id), .coin(cached.id)])
    }

    func testOfflineUncachedCardIsDisabled() async {
        let coin = makeItem()
        let subject = Subject(cached: [coin], online: false, cachedAssetIDs: [])
        await subject.viewModel.updateAvailability()
        XCTAssertFalse(subject.viewModel.isEnabled(.coin(coin.id)))
    }

    func testDownloadPreventsDuplicateSelection() async {
        let coin = makeItem()
        let subject = Subject(cached: [coin], suspendDownload: true)
        let first = Task { await subject.viewModel.select(.coin(coin.id)) }
        await subject.assets.waitForDownload()
        await subject.viewModel.select(.coin(coin.id))
        XCTAssertEqual(subject.assets.downloadCount, 1)
        subject.assets.completeDownload()
        await first.value
    }

    func testSuccessfulDownloadSelectsCoin() async {
        let coin = makeItem()
        let subject = Subject(cached: [coin])
        await subject.viewModel.select(.coin(coin.id))
        XCTAssertEqual(subject.selection.selectedItems, [coin.id])
        XCTAssertEqual(subject.viewModel.selectedID, .coin(coin.id))
    }

    func testDownloadFailureShowsNonBlockingMessage() async {
        let coin = makeItem()
        let subject = Subject(cached: [coin], downloadError: TestError.expected)
        await subject.viewModel.select(.coin(coin.id))
        XCTAssertNotNil(subject.viewModel.notice)
        XCTAssertEqual(subject.viewModel.selectedID, .classic)
    }

    func testRefreshDoesNotChangeTossState() async {
        let state = LockedBox(CoinTossState.tossing)
        let subject = Subject(tossState: state)
        await subject.viewModel.refresh()
        XCTAssertEqual(state.value, .tossing)
    }

    func testClassicRemainsFirstAfterRefresh() async {
        let subject = Subject(remote: [makeItem(name: "First", order: -10)])
        await subject.viewModel.refresh()
        XCTAssertEqual(subject.viewModel.items.first?.id, .classic)
    }
}

@MainActor
private final class Subject {
    let catalog: LibraryCatalogDouble
    let assets: LibraryAssetDouble
    let selection = LibrarySelectionDouble()
    let viewModel: CoinLibraryViewModel

    init(cached: [CoinCatalogItem] = [], remote: [CoinCatalogItem] = [], online: Bool = true, cachedAssetIDs: Set<UUID> = [], suspendDownload: Bool = false, downloadError: Error? = nil, tossState: LockedBox<CoinTossState> = LockedBox(.idle)) {
        catalog = LibraryCatalogDouble(items: remote)
        assets = LibraryAssetDouble(cachedIDs: cachedAssetIDs, suspendDownload: suspendDownload, error: downloadError)
        viewModel = CoinLibraryViewModel(cachedCatalog: { cached }, catalog: catalog, assets: assets, selection: selection, session: { .guest }, generationID: { UUID() }, isOnline: { online }, tossState: { tossState.value })
    }
}

private func makeItem(name: String = "Silver", order: Int = 0) -> CoinCatalogItem {
    CoinCatalogItem(id: UUID(), slug: name.lowercased(), displayName: name, description: nil, sortOrder: order, isFeatured: false, version: .init(id: UUID(), versionNumber: 1, modelURL: URL(string: "https://example.invalid/model.usdz")!, previewURL: URL(string: "https://example.invalid/preview.webp")!, modelByteSize: 1, modelSHA256: String(repeating: "a", count: 64), minAppVersion: "1", assetSchemaVersion: 1))
}

private final class LibraryCatalogDouble: CoinCatalogServicing, @unchecked Sendable { var items: [CoinCatalogItem]; init(items: [CoinCatalogItem]) { self.items = items }; func fetchPublishedCatalog() async throws -> [CoinCatalogItem] { items } }
private final class LibraryAssetDouble: CoinAssetCaching, @unchecked Sendable {
    var cachedIDs: Set<UUID>; let suspendDownload: Bool; let error: Error?; let gate = TestOperationGate(); private(set) var downloadCount = 0
    init(cachedIDs: Set<UUID>, suspendDownload: Bool, error: Error?) { self.cachedIDs = cachedIDs; self.suspendDownload = suspendDownload; self.error = error }
    func cachedModelURL(for item: CoinCatalogItem) async -> URL? { cachedIDs.contains(item.id) ? URL(fileURLWithPath: "/tmp/\(item.id).usdz") : nil }
    func downloadAndValidate(_ item: CoinCatalogItem) async throws -> URL { downloadCount += 1; if suspendDownload { await gate.suspend() }; if let error { throw error }; cachedIDs.insert(item.id); return URL(fileURLWithPath: "/tmp/\(item.id).usdz") }
    func removeUnreferencedAssets(keeping items: [CoinCatalogItem]) async throws {}
    func waitForDownload() async { await gate.waitUntilStarted() }; func completeDownload() { gate.complete() }
}
@MainActor private final class LibrarySelectionDouble: CoinSelecting { private(set) var selectedItems: [UUID] = []; func select(_ item: CoinCatalogItem, session: AccountSession, generationID: UUID) async { selectedItems.append(item.id) }; func selectClassic(session: AccountSession, generationID: UUID) async {} }
private final class LockedBox<Value>: @unchecked Sendable { private let lock = NSLock(); private var stored: Value; init(_ value: Value) { stored = value }; var value: Value { lock.withLock { stored } } }
private enum TestError: Error { case expected }
