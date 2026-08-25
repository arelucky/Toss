import Foundation
import XCTest
@testable import Toss

@MainActor
final class CoinLibraryViewModelTests: XCTestCase {
    func testStartsWithClassicFirst() {
        let subject = Subject()
        XCTAssertEqual(subject.viewModel.items.map(\.id), [.classic])
        XCTAssertEqual(subject.viewModel.selectedModelSource, .bundledClassic)
    }

    func testSuccessfulRefreshReplacesCachedDynamicCatalog() async {
        let cached = makeItem(name: "Cached", order: 2)
        let remote = makeItem(name: "Remote", order: 1)
        let subject = Subject(cached: [cached], remote: [remote])
        XCTAssertEqual(subject.viewModel.items.map(\.id), [.classic, .coin(cached.id)])

        await subject.viewModel.refresh()

        XCTAssertEqual(subject.viewModel.items.map(\.id), [.classic, .coin(remote.id)])
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
        XCTAssertEqual(
            subject.viewModel.selectedModelSource,
            .downloaded(URL(fileURLWithPath: "/tmp/\(coin.id).usdz"))
        )
    }

    func testPreselectingDownloadedCoinDoesNotApplyIt() async {
        let coin = makeItem()
        let subject = Subject(cached: [coin])

        await subject.viewModel.preselect(.coin(coin.id))

        XCTAssertEqual(subject.selection.selectedItems, [])
        XCTAssertEqual(subject.viewModel.selectedID, .classic)
        XCTAssertEqual(subject.viewModel.selectedModelSource, .bundledClassic)
        XCTAssertEqual(subject.viewModel.preselectedID, .coin(coin.id))
        XCTAssertEqual(
            subject.viewModel.preselectedModelSource,
            .downloaded(URL(fileURLWithPath: "/tmp/\(coin.id).usdz"))
        )
        XCTAssertTrue(subject.viewModel.canApplyPreselection)
    }

    func testPreselectingCachedCoinDoesNotDownloadOrPersistSelection() async {
        let coin = makeItem()
        let subject = Subject(cached: [coin], cachedAssetIDs: [coin.id])
        await subject.viewModel.updateAvailability()

        await subject.viewModel.preselect(.coin(coin.id))

        XCTAssertEqual(subject.assets.downloadCount, 0)
        XCTAssertEqual(subject.selection.selectedItems, [])
        XCTAssertEqual(subject.viewModel.preselectedID, .coin(coin.id))
    }

    func testPreselectionCannotBeAppliedAfterCachedModelIsRemoved() async {
        let coin = makeItem()
        let subject = Subject(cached: [coin], cachedAssetIDs: [coin.id])
        await subject.viewModel.updateAvailability()
        await subject.viewModel.preselect(.coin(coin.id))

        subject.assets.cachedIDs.remove(coin.id)
        await subject.viewModel.updateAvailability()

        XCTAssertFalse(subject.viewModel.canApplyPreselection)
    }

    func testApplyPreselectionCommitsPreselectedCoin() async {
        let coin = makeItem()
        let subject = Subject(cached: [coin])
        await subject.viewModel.preselect(.coin(coin.id))

        await subject.viewModel.applyPreselection()

        XCTAssertEqual(subject.selection.selectedItems, [coin.id])
        XCTAssertEqual(subject.viewModel.selectedID, .coin(coin.id))
        XCTAssertEqual(
            subject.viewModel.selectedModelSource,
            .downloaded(URL(fileURLWithPath: "/tmp/\(coin.id).usdz"))
        )
        XCTAssertFalse(subject.viewModel.canApplyPreselection)
    }

    func testFailedDownloadKeepsExistingPreselection() async {
        let coin = makeItem()
        let subject = Subject(cached: [coin], downloadError: TestError.expected)

        await subject.viewModel.preselect(.coin(coin.id))

        XCTAssertEqual(subject.viewModel.preselectedID, .classic)
        XCTAssertEqual(subject.viewModel.preselectedModelSource, .bundledClassic)
        XCTAssertEqual(subject.selection.selectedItems, [])
        XCTAssertNotNil(subject.viewModel.notice)
    }

    func testCachedRemoteSelectionUsesCachedLocalModelURL() async {
        let coin = makeItem()
        let subject = Subject(cached: [coin], cachedAssetIDs: [coin.id])
        await subject.viewModel.updateAvailability()

        await subject.viewModel.select(.coin(coin.id))

        XCTAssertEqual(
            subject.viewModel.selectedModelSource,
            .downloaded(URL(fileURLWithPath: "/tmp/\(coin.id).usdz"))
        )
    }

    func testFailedRemoteDownloadKeepsCurrentModelSource() async {
        let coin = makeItem()
        let subject = Subject(cached: [coin], downloadError: TestError.expected)

        await subject.viewModel.select(.coin(coin.id))

        XCTAssertEqual(subject.viewModel.selectedModelSource, .bundledClassic)
    }

    func testLibraryPreviewSourceUsesStaticClassicAndRemotePreviewURL() {
        let coin = makeItem()

        XCTAssertEqual(CoinLibraryPreviewSource(item: .init(id: .classic, coin: nil)), .bundledClassic)
        XCTAssertEqual(
            CoinLibraryPreviewSource(item: .init(id: .coin(coin.id), coin: coin)),
            .remote(coin.version.previewURL)
        )
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

    func testSuccessfulRefreshRemovesHiddenSelectedCoinWithoutDeletingCachedAssets() async {
        let hidden = makeItem(name: "Hidden")
        let remote = makeItem(name: "Remote")
        let subject = Subject(cached: [hidden], remote: [remote], cachedAssetIDs: [hidden.id])
        await subject.viewModel.updateAvailability()
        await subject.viewModel.select(.coin(hidden.id))

        await subject.viewModel.refresh()

        XCTAssertEqual(subject.viewModel.items.map(\.id), [.classic, .coin(remote.id)])
        XCTAssertEqual(subject.viewModel.selectedID, .classic)
        XCTAssertEqual(subject.viewModel.selectedModelSource, .bundledClassic)
        XCTAssertEqual(subject.viewModel.preselectedID, .classic)
        XCTAssertEqual(subject.viewModel.preselectedModelSource, .bundledClassic)
        XCTAssertEqual(subject.selection.classicSelections, 1)
        XCTAssertEqual(subject.assets.removeUnreferencedAssetsCount, 0)
    }

    func testFailedRefreshKeepsCachedCatalogAndCurrentSelection() async {
        let cached = makeItem(name: "Cached")
        let subject = Subject(cached: [cached], cachedAssetIDs: [cached.id])
        await subject.viewModel.updateAvailability()
        await subject.viewModel.select(.coin(cached.id))
        subject.catalog.error = TestError.expected

        await subject.viewModel.refresh()

        XCTAssertEqual(subject.viewModel.items.map(\.id), [.classic, .coin(cached.id)])
        XCTAssertEqual(subject.viewModel.selectedID, .coin(cached.id))
        XCTAssertEqual(subject.viewModel.selectedModelSource, .downloaded(subject.assets.localURL(for: cached)))
        XCTAssertEqual(subject.selection.classicSelections, 0)
        XCTAssertEqual(subject.assets.removeUnreferencedAssetsCount, 0)
    }

    func testProductionDependenciesBuildLiveLibraryThatRefreshesInjectedCatalog() async {
        let remote = makeItem(name: "Live")
        let catalog = LibraryCatalogDouble(items: [remote])
        let dependencies = makeDependencies(catalog: catalog)
        let accountStore = AccountStore(authService: dependencies.authService)
        let tossViewModel = CoinTossViewModel()

        let viewModel = dependencies.makeCoinLibraryViewModel(
            accountStore: accountStore,
            tossViewModel: tossViewModel
        )
        await viewModel.refresh()

        XCTAssertEqual(viewModel.items.map(\.id), [.classic, .coin(remote.id)])
    }

    func testContentViewUsesSelectedDownloadedModelSource() async {
        let coin = makeItem()
        let subject = Subject(cached: [coin])
        await subject.viewModel.select(.coin(coin.id))

        let contentView = ContentView(
            viewModel: CoinTossViewModel(),
            coinLibraryViewModel: subject.viewModel
        )

        XCTAssertEqual(
            contentView.displayedCoinModelSource,
            .downloaded(URL(fileURLWithPath: "/tmp/\(coin.id).usdz"))
        )
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

private final class LibraryCatalogDouble: CoinCatalogServicing, @unchecked Sendable { var items: [CoinCatalogItem]; var error: Error?; init(items: [CoinCatalogItem]) { self.items = items }; func fetchPublishedCatalog() async throws -> [CoinCatalogItem] { if let error { throw error }; return items } }
private final class LibraryAssetDouble: CoinAssetCaching, @unchecked Sendable {
    var cachedIDs: Set<UUID>; let suspendDownload: Bool; let error: Error?; let gate = TestOperationGate(); private(set) var downloadCount = 0; private(set) var removeUnreferencedAssetsCount = 0
    init(cachedIDs: Set<UUID>, suspendDownload: Bool, error: Error?) { self.cachedIDs = cachedIDs; self.suspendDownload = suspendDownload; self.error = error }
    func cachedModelURL(for item: CoinCatalogItem) async -> URL? { cachedIDs.contains(item.id) ? localURL(for: item) : nil }
    func downloadAndValidate(_ item: CoinCatalogItem, progress: @escaping @Sendable (CoinFileDownloadProgress) -> Void) async throws -> URL { downloadCount += 1; if suspendDownload { await gate.suspend() }; if let error { throw error }; cachedIDs.insert(item.id); return URL(fileURLWithPath: "/tmp/\(item.id).usdz") }
    func removeUnreferencedAssets(keeping items: [CoinCatalogItem]) async throws { removeUnreferencedAssetsCount += 1 }
    func localURL(for item: CoinCatalogItem) -> URL { URL(fileURLWithPath: "/tmp/\(item.id).usdz") }
    func waitForDownload() async { await gate.waitUntilStarted() }; func completeDownload() { gate.complete() }
}
@MainActor private final class LibrarySelectionDouble: CoinSelecting { private(set) var selectedItems: [UUID] = []; private(set) var classicSelections = 0; func select(_ item: CoinCatalogItem, session: AccountSession, generationID: UUID) async { selectedItems.append(item.id) }; func selectClassic(session: AccountSession, generationID: UUID) async { classicSelections += 1 } }
private final class LibraryPreferenceDouble: SelectedCoinPreferenceServicing, @unchecked Sendable {
    func fetchSelectedCoinID(for userID: UUID, generationID: UUID) async throws -> UUID? { nil }
    func updateSelectedCoinID(_ coinID: UUID?, for userID: UUID, generationID: UUID) async throws {}
}
private final class LockedBox<Value>: @unchecked Sendable { private let lock = NSLock(); private var stored: Value; init(_ value: Value) { stored = value }; var value: Value { lock.withLock { stored } } }
private enum TestError: Error { case expected }

@MainActor
private func makeDependencies(catalog: any CoinCatalogServicing) -> AppDependencies {
    AppDependencies(
        session: .guest,
        environment: nil,
        authService: AccountAuthServiceDouble(),
        appleSignInService: AppleSignInServiceDouble(result: .failure(TestAccountError.expected)),
        profileRepository: UserProfileRepositoryDouble(),
        preferencesRepository: UserPreferencesRepositoryDouble(),
        selectedCoinPreferenceRepository: LibraryPreferenceDouble(),
        coinCatalogRepository: catalog,
        coinCatalogCache: CoinCatalogCache(directoryURL: FileManager.default.temporaryDirectory),
        deletionService: AccountDeletionServiceDouble(),
        deletionRequestStore: AccountDeletionRequestStore(),
        localPreferences: LocalPreferencesStore(),
        feedbackPreferences: AppFeedbackPreferencesController()
    )
}
