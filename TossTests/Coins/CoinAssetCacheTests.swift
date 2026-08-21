import CryptoKit
import Foundation
import XCTest
@testable import Toss

final class CoinAssetCacheTests: XCTestCase {
    func testCacheHitDoesNotDownloadAgain() async throws {
        let fixture = try Fixture()
        let item = fixture.item(data: fixture.validUSDZ)
        try fixture.installCached(fixture.validUSDZ, for: item)

        let url = try await fixture.cache.downloadAndValidate(item)

        XCTAssertEqual(url, fixture.modelURL(for: item))
        XCTAssertEqual(fixture.downloads.count, 0)
    }

    func testAllowsLocalLoopbackHTTPURL() async throws {
        let fixture = try Fixture()
        let item = fixture.item(
            data: fixture.validUSDZ,
            modelURL: URL(string: "http://127.0.0.1:54321/model.usdz")!
        )

        _ = try await fixture.cache.downloadAndValidate(item)

        XCTAssertEqual(fixture.downloads.count, 1)
    }

    func testRejectsRemoteHTTPAndFileURLs() async throws {
        for scheme in ["http", "file"] {
            let fixture = try Fixture()
            let item = fixture.item(data: fixture.validUSDZ, modelURL: URL(string: "\(scheme)://example.invalid/model.usdz")!)

            await XCTAssertThrowsErrorAsync(try await fixture.cache.downloadAndValidate(item))
            XCTAssertEqual(fixture.downloads.count, 0)
        }
    }

    func testDownloadUsesPartialFile() async throws {
        let fixture = try Fixture()
        let item = fixture.item(data: fixture.validUSDZ)

        _ = try await fixture.cache.downloadAndValidate(item)

        XCTAssertEqual(fixture.downloads.destinations.map(\.pathExtension), ["usdz"])
        XCTAssertTrue(fixture.downloads.destinations.allSatisfy {
            $0.lastPathComponent.hasSuffix(".partial.usdz")
        })
    }

    func testDownloadAndPreflightUseTemporaryUSDZFile() async throws {
        let fixture = try Fixture()
        let item = fixture.item(data: fixture.validUSDZ)

        let finalURL = try await fixture.cache.downloadAndValidate(item)
        let temporaryURL = try XCTUnwrap(fixture.downloads.destinations.first)

        XCTAssertEqual(temporaryURL.pathExtension, "usdz")
        XCTAssertTrue(temporaryURL.lastPathComponent.hasSuffix(".partial.usdz"))
        XCTAssertEqual(fixture.downloads.preflightDestinations, [temporaryURL])
        XCTAssertEqual(fixture.downloads.preflightFileExistence, [true])
        XCTAssertNotEqual(temporaryURL, finalURL)
        XCTAssertEqual(finalURL, fixture.modelURL(for: item))
    }

    func testRejectsUnsuccessfulHTTPStatus() async throws {
        let fixture = try Fixture(statusCode: 404)
        let item = fixture.item(data: fixture.validUSDZ)

        await XCTAssertThrowsErrorAsync(try await fixture.cache.downloadAndValidate(item))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.modelURL(for: item).path))
    }

    func testRejectsWrongByteCount() async throws {
        let fixture = try Fixture(downloadedData: Data("short".utf8))
        let item = fixture.item(data: fixture.validUSDZ)

        await XCTAssertThrowsErrorAsync(try await fixture.cache.downloadAndValidate(item))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.modelURL(for: item).path))
    }

    func testRejectsWrongSHA256() async throws {
        let fixture = try Fixture()
        let item = fixture.item(data: fixture.validUSDZ, sha256: String(repeating: "0", count: 64))

        await XCTAssertThrowsErrorAsync(try await fixture.cache.downloadAndValidate(item))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.modelURL(for: item).path))
    }

    func testRejectsRealityKitPreflightFailure() async throws {
        let fixture = try Fixture(preflightSucceeds: false)
        let item = fixture.item(data: fixture.validUSDZ)

        await XCTAssertThrowsErrorAsync(try await fixture.cache.downloadAndValidate(item))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.modelURL(for: item).path))
    }

    func testSuccessfulDownloadPublishesAtFixedPath() async throws {
        let fixture = try Fixture()
        let item = fixture.item(data: fixture.validUSDZ)

        let url = try await fixture.cache.downloadAndValidate(item)

        XCTAssertEqual(url, fixture.modelURL(for: item))
        XCTAssertEqual(try Data(contentsOf: url), fixture.validUSDZ)
        XCTAssertFalse(fixture.containsPartialFiles())
    }

    func testFailurePreservesExistingVersion() async throws {
        let fixture = try Fixture(statusCode: 500)
        let oldItem = fixture.item(data: fixture.validUSDZ, versionNumber: 1)
        let newItem = fixture.item(data: fixture.validUSDZ, versionNumber: 2)
        try fixture.installCached(fixture.validUSDZ, for: oldItem)

        await XCTAssertThrowsErrorAsync(try await fixture.cache.downloadAndValidate(newItem))

        XCTAssertEqual(try Data(contentsOf: fixture.modelURL(for: oldItem)), fixture.validUSDZ)
        XCTAssertFalse(fixture.containsPartialFiles())
    }

    func testConcurrentRequestsForSameVersionDownloadOnce() async throws {
        let fixture = try Fixture(downloadDelayNanoseconds: 100_000_000)
        let item = fixture.item(data: fixture.validUSDZ)

        async let first = fixture.cache.downloadAndValidate(item)
        async let second = fixture.cache.downloadAndValidate(item)
        let urls = try await [first, second]

        XCTAssertEqual(urls[0], urls[1])
        XCTAssertEqual(fixture.downloads.count, 1)
    }
}

private final class Fixture: @unchecked Sendable {
    let root: URL
    let validUSDZ = Data("valid-usdz-fixture".utf8)
    let downloads = DownloadRecorder()
    let cache: CoinAssetCache
    private let coinID = UUID()

    init(
        statusCode: Int = 200,
        downloadedData: Data? = nil,
        preflightSucceeds: Bool = true,
        downloadDelayNanoseconds: UInt64 = 0
    ) throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let recorder = downloads
        let payload = downloadedData ?? validUSDZ
        cache = CoinAssetCache(
            directoryURL: root,
            downloader: { _, destination in
                if downloadDelayNanoseconds > 0 {
                    try await Task.sleep(nanoseconds: downloadDelayNanoseconds)
                }
                recorder.record(destination)
                try payload.write(to: destination)
                return statusCode
            },
            preflight: { url in
                recorder.recordPreflight(
                    url,
                    fileExists: FileManager.default.fileExists(atPath: url.path)
                )
                if !preflightSucceeds { throw TestFailure.preflight }
            }
        )
    }

    func item(
        data: Data,
        modelURL: URL = URL(string: "https://example.invalid/model.usdz")!,
        sha256: String? = nil,
        versionNumber: Int = 1
    ) -> CoinCatalogItem {
        CoinCatalogItem(
            id: coinID,
            slug: "classic",
            displayName: "Classic",
            description: nil,
            sortOrder: 0,
            isFeatured: false,
            version: CoinAssetVersion(
                id: UUID(),
                versionNumber: versionNumber,
                modelURL: modelURL,
                previewURL: URL(string: "https://example.invalid/preview.webp")!,
                modelByteSize: Int64(data.count),
                modelSHA256: sha256 ?? SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
                minAppVersion: "1.0.0",
                assetSchemaVersion: 1
            )
        )
    }

    func modelURL(for item: CoinCatalogItem) -> URL {
        root.appendingPathComponent("CoinAssets", isDirectory: true)
            .appendingPathComponent(item.id.uuidString, isDirectory: true)
            .appendingPathComponent("v\(item.version.versionNumber)", isDirectory: true)
            .appendingPathComponent("model.usdz")
    }

    func installCached(_ data: Data, for item: CoinCatalogItem) throws {
        let url = modelURL(for: item)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }

    func containsPartialFiles() -> Bool {
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        return enumerator?.compactMap { $0 as? URL }.contains { $0.pathExtension == "partial" } ?? false
    }
}

private final class DownloadRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedDestinations: [URL] = []
    private var storedPreflightDestinations: [URL] = []
    private var storedPreflightFileExistence: [Bool] = []

    func record(_ destination: URL) {
        lock.lock()
        storedDestinations.append(destination)
        lock.unlock()
    }

    var destinations: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return storedDestinations
    }

    func recordPreflight(_ destination: URL, fileExists: Bool) {
        lock.lock()
        storedPreflightDestinations.append(destination)
        storedPreflightFileExistence.append(fileExists)
        lock.unlock()
    }

    var preflightDestinations: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return storedPreflightDestinations
    }

    var preflightFileExistence: [Bool] {
        lock.lock()
        defer { lock.unlock() }
        return storedPreflightFileExistence
    }

    var count: Int { destinations.count }
}

private enum TestFailure: Error {
    case preflight
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error", file: file, line: line)
    } catch {}
}
