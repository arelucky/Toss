import XCTest
@testable import Toss

final class CoinCatalogCacheTests: XCTestCase {
    func testRoundTripsCatalogAtFixedApplicationSupportPath() throws {
        let directory = temporaryDirectory()
        let cache = CoinCatalogCache(directoryURL: directory)
        let item = makeItem()

        try cache.save([item])

        XCTAssertEqual(cache.load(), [item])
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: directory
                .appendingPathComponent("CoinCatalog", isDirectory: true)
                .appendingPathComponent("catalog-v1.json")
                .path
        ))
    }

    func testCorruptCacheReturnsEmptyCatalog() throws {
        let directory = temporaryDirectory()
        let catalogDirectory = directory.appendingPathComponent("CoinCatalog", isDirectory: true)
        try FileManager.default.createDirectory(at: catalogDirectory, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: catalogDirectory.appendingPathComponent("catalog-v1.json"))

        let catalog = CoinCatalogCache(directoryURL: directory).load()

        XCTAssertEqual(catalog, [])
    }

    func testExistingCacheIsPublishedWithAtomicReplacement() throws {
        let directory = temporaryDirectory()
        let initialCache = CoinCatalogCache(directoryURL: directory)
        try initialCache.save([makeItem(name: "Old")])
        let recorder = ReplacementRecorder()
        let cache = CoinCatalogCache(
            directoryURL: directory,
            replaceItem: { original, temporary in
                recorder.record(original: original, temporary: temporary)
                _ = try FileManager.default.replaceItemAt(original, withItemAt: temporary)
            }
        )

        try cache.save([makeItem(name: "New")])

        let replacement = recorder.replacement
        XCTAssertEqual(replacement?.original.lastPathComponent, "catalog-v1.json")
        XCTAssertNotEqual(replacement?.temporary, replacement?.original)
        XCTAssertEqual(cache.load().first?.displayName, "New")
    }

    private func makeItem(name: String = "Classic") -> CoinCatalogItem {
        CoinCatalogItem(
            id: UUID(),
            slug: name.lowercased(),
            displayName: name,
            description: nil,
            sortOrder: 0,
            isFeatured: false,
            version: CoinAssetVersion(
                id: UUID(),
                versionNumber: 1,
                modelURL: URL(string: "https://example.invalid/model.usdz")!,
                previewURL: URL(string: "https://example.invalid/preview.webp")!,
                modelByteSize: 1024,
                modelSHA256: String(repeating: "a", count: 64),
                minAppVersion: "1.0.0",
                assetSchemaVersion: 1
            )
        )
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}

private final class ReplacementRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedReplacement: (original: URL, temporary: URL)?

    func record(original: URL, temporary: URL) {
        lock.lock()
        storedReplacement = (original, temporary)
        lock.unlock()
    }

    var replacement: (original: URL, temporary: URL)? {
        lock.lock()
        defer { lock.unlock() }
        return storedReplacement
    }
}
