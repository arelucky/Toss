import Foundation
import XCTest
@testable import Toss

@MainActor
final class CoinSelectionStoreTests: XCTestCase {
    func testGuestSelectionStaysLocalAndDoesNotCallAccountRepository() async throws {
        let subject = Subject()
        await subject.store.select(subject.coin, session: .guest, generationID: UUID())

        XCTAssertEqual(subject.store.selectedCoin, .downloaded(subject.coin, localModelURL: subject.localURL))
        XCTAssertEqual(subject.local.selectedCoinID, subject.coin.id)
        XCTAssertEqual(subject.preferences.updates.count, 0)
    }

    func testAuthenticatedCachedServerSelectionIsAdopted() async {
        let subject = Subject(serverSelection: .some(nil))
        subject.preferences.fetchResult = subject.coin.id

        await subject.store.synchronize(session: .authenticated(userID: subject.userID), generationID: subject.generationID)

        XCTAssertEqual(subject.store.selectedCoin, .downloaded(subject.coin, localModelURL: subject.localURL))
        XCTAssertEqual(subject.assets.downloadCount, 0)
    }

    func testUncachedServerSelectionKeepsGuestUntilDownloadCompletes() async {
        let subject = Subject(cached: false, suspendDownload: true)
        subject.preferences.fetchResult = subject.coin.id
        let sync = Task { await subject.store.synchronize(session: .authenticated(userID: subject.userID), generationID: subject.generationID) }
        await subject.assets.waitForDownload()

        XCTAssertEqual(subject.store.selectedCoin, .bundledClassic)
        subject.assets.completeDownload()
        await sync.value
        XCTAssertEqual(subject.store.selectedCoin, .downloaded(subject.coin, localModelURL: subject.localURL))
    }

    func testRetiredGenerationSelectionResultIsDiscarded() async {
        let subject = Subject(cached: false, suspendDownload: true)
        subject.preferences.fetchResult = subject.coin.id
        let sync = Task { await subject.store.synchronize(session: .authenticated(userID: subject.userID), generationID: subject.generationID) }
        await subject.assets.waitForDownload()
        subject.currentGeneration.value = UUID()
        subject.assets.completeDownload()
        await sync.value

        XCTAssertEqual(subject.store.selectedCoin, .bundledClassic)
    }

    func testLogoutRestoresGuestSelection() async {
        let subject = Subject()
        await subject.store.select(subject.coin, session: .guest, generationID: subject.generationID)
        subject.preferences.fetchResult = nil
        await subject.store.synchronize(session: .authenticated(userID: subject.userID), generationID: subject.generationID)

        await subject.store.synchronize(session: .guest, generationID: UUID())

        XCTAssertEqual(subject.store.selectedCoin, .downloaded(subject.coin, localModelURL: subject.localURL))
    }

    func testHiddenMissingAndCorruptSelectionsFallBackToClassic() async {
        let subject = Subject()
        subject.preferences.fetchResult = UUID()
        await subject.store.synchronize(session: .authenticated(userID: subject.userID), generationID: subject.generationID)
        XCTAssertEqual(subject.store.selectedCoin, .bundledClassic)

        subject.preferences.fetchResult = subject.coin.id
        subject.catalog.items = []
        await subject.store.synchronize(session: .authenticated(userID: subject.userID), generationID: subject.generationID)
        XCTAssertEqual(subject.store.selectedCoin, .bundledClassic)

        subject.catalog.items = [subject.coin]
        subject.assets.downloadError = TestError.expected
        subject.assets.cachedURL = nil
        await subject.store.synchronize(session: .authenticated(userID: subject.userID), generationID: subject.generationID)
        XCTAssertEqual(subject.store.selectedCoin, .bundledClassic)
    }

    func testSelectionPublishesOnlyWhenTossIsIdle() async {
        let subject = Subject(isIdle: false)
        await subject.store.select(subject.coin, session: .guest, generationID: subject.generationID)
        XCTAssertEqual(subject.store.selectedCoin, .bundledClassic)

        subject.idle.value = true
        subject.store.publishPendingSelectionIfIdle()
        XCTAssertEqual(subject.store.selectedCoin, .downloaded(subject.coin, localModelURL: subject.localURL))
    }

    func testAuthenticatedSelectionUsesDedicatedRepository() async {
        let subject = Subject()
        await subject.store.select(subject.coin, session: .authenticated(userID: subject.userID), generationID: subject.generationID)

        XCTAssertEqual(subject.preferences.updates, [.init(coinID: subject.coin.id, userID: subject.userID, generationID: subject.generationID)])
    }
}

@MainActor
private final class Subject {
    let userID = UUID()
    let generationID = UUID()
    let localURL = URL(fileURLWithPath: "/tmp/coin.usdz")
    let coin: CoinCatalogItem
    let local = LocalSelectionDouble()
    let preferences = SelectionPreferenceDouble()
    let catalog: CatalogDouble
    let assets: AssetCacheDouble
    let currentGeneration: LockedValue<UUID>
    let idle: LockedValue<Bool>
    let store: CoinSelectionStore

    init(cached: Bool = true, suspendDownload: Bool = false, isIdle: Bool = true, serverSelection: UUID?? = nil) {
        coin = Self.makeCoin()
        catalog = CatalogDouble(items: [coin])
        assets = AssetCacheDouble(cachedURL: cached ? localURL : nil, downloadedURL: localURL, suspendDownload: suspendDownload)
        currentGeneration = LockedValue(generationID)
        idle = LockedValue(isIdle)
        preferences.fetchResult = serverSelection ?? nil
        store = CoinSelectionStore(
            catalog: catalog,
            assets: assets,
            preferences: preferences,
            localSelection: local,
            isGenerationCurrent: { [currentGeneration] in currentGeneration.value == $0 },
            isCoinIdle: { [idle] in idle.value }
        )
    }

    private static func makeCoin() -> CoinCatalogItem {
        CoinCatalogItem(id: UUID(), slug: "silver", displayName: "Silver", description: nil, sortOrder: 0, isFeatured: true, version: .init(id: UUID(), versionNumber: 1, modelURL: URL(string: "https://example.invalid/model.usdz")!, previewURL: URL(string: "https://example.invalid/preview.webp")!, modelByteSize: 1, modelSHA256: String(repeating: "a", count: 64), minAppVersion: "1", assetSchemaVersion: 1))
    }
}

private final class LocalSelectionDouble: CoinLocalSelectionStoring, @unchecked Sendable {
    var selectedCoinID: UUID?
}

private final class SelectionPreferenceDouble: SelectedCoinPreferenceServicing, @unchecked Sendable {
    struct Update: Equatable { let coinID: UUID?; let userID: UUID; let generationID: UUID }
    var fetchResult: UUID?
    private(set) var updates: [Update] = []
    func fetchSelectedCoinID(for userID: UUID, generationID: UUID) async throws -> UUID? { fetchResult }
    func updateSelectedCoinID(_ coinID: UUID?, for userID: UUID, generationID: UUID) async throws { updates.append(.init(coinID: coinID, userID: userID, generationID: generationID)) }
}

private final class CatalogDouble: CoinCatalogServicing, @unchecked Sendable {
    var items: [CoinCatalogItem]
    init(items: [CoinCatalogItem]) { self.items = items }
    func fetchPublishedCatalog() async throws -> [CoinCatalogItem] { items }
}

private final class AssetCacheDouble: CoinAssetCaching, @unchecked Sendable {
    var cachedURL: URL?
    let downloadedURL: URL
    var downloadError: Error?
    private let gate = TestOperationGate()
    private let suspendDownload: Bool
    private(set) var downloadCount = 0
    init(cachedURL: URL?, downloadedURL: URL, suspendDownload: Bool) { self.cachedURL = cachedURL; self.downloadedURL = downloadedURL; self.suspendDownload = suspendDownload }
    func cachedModelURL(for item: CoinCatalogItem) async -> URL? { cachedURL }
    func downloadAndValidate(_ item: CoinCatalogItem) async throws -> URL { downloadCount += 1; if suspendDownload { await gate.suspend() }; if let downloadError { throw downloadError }; cachedURL = downloadedURL; return downloadedURL }
    func removeUnreferencedAssets(keeping items: [CoinCatalogItem]) async throws {}
    func waitForDownload() async { await gate.waitUntilStarted() }
    func completeDownload() { gate.complete() }
}

private final class LockedValue<Value>: @unchecked Sendable {
    private let lock = NSLock(); private var stored: Value
    init(_ value: Value) { stored = value }
    var value: Value { get { lock.withLock { stored } } set { lock.withLock { stored = newValue } } }
}

private enum TestError: Error { case expected }
