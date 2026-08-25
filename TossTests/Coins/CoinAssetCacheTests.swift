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

    func testRetriesNetworkConnectionLostOnceThenPublishesModel() async throws {
        let fixture = try Fixture(downloadErrorCodes: [.networkConnectionLost])
        let item = fixture.item(data: fixture.validUSDZ)

        let url = try await fixture.cache.downloadAndValidate(item)

        XCTAssertEqual(fixture.downloads.count, 2)
        XCTAssertEqual(url, fixture.modelURL(for: item))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testRetriesTimedOutOnceThenPublishesModel() async throws {
        let fixture = try Fixture(downloadErrorCodes: [.timedOut])
        let item = fixture.item(data: fixture.validUSDZ)

        let url = try await fixture.cache.downloadAndValidate(item)

        XCTAssertEqual(fixture.downloads.count, 2)
        XCTAssertEqual(url, fixture.modelURL(for: item))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testFailsAfterSecondNetworkConnectionLostWithoutPublishingOrLeavingPartial() async throws {
        let fixture = try Fixture(downloadErrorCodes: [.networkConnectionLost, .networkConnectionLost])
        let item = fixture.item(data: fixture.validUSDZ)

        await XCTAssertThrowsErrorAsync(try await fixture.cache.downloadAndValidate(item))

        XCTAssertEqual(fixture.downloads.count, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.modelURL(for: item).path))
        XCTAssertFalse(fixture.containsPartialFiles())
    }

    func testDoesNotRetryOtherNetworkErrors() async throws {
        let fixture = try Fixture(downloadErrorCodes: [.notConnectedToInternet])
        let item = fixture.item(data: fixture.validUSDZ)

        await XCTAssertThrowsErrorAsync(try await fixture.cache.downloadAndValidate(item))

        XCTAssertEqual(fixture.downloads.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.modelURL(for: item).path))
        XCTAssertFalse(fixture.containsPartialFiles())
    }

    func testDownloadProgressMapsReceivedBytesToPercentage() {
        XCTAssertEqual(
            CoinFileDownloadProgress.phase(receivedBytes: 0, expectedBytes: 100),
            .connecting
        )
        XCTAssertEqual(
            CoinFileDownloadProgress.phase(receivedBytes: 25, expectedBytes: 100),
            .downloading(percent: 25)
        )
        XCTAssertEqual(
            CoinFileDownloadProgress.phase(receivedBytes: 160, expectedBytes: 100),
            .downloading(percent: 100)
        )
    }

    func testConnectionLossWithResumeDataRecoversOnceAndPublishesModel() async throws {
        let fixture = try Fixture(
            downloadOutcomes: [
                .recoverable(.connectionLost(resumeData: Data([1]))),
                .success
            ]
        )
        let item = fixture.item(data: fixture.validUSDZ)

        let url = try await fixture.cache.downloadAndValidate(item)

        XCTAssertEqual(fixture.downloads.count, 2)
        XCTAssertEqual(fixture.downloads.resumeDataInputs, [nil, Data([1])])
        XCTAssertEqual(url, fixture.modelURL(for: item))
    }

    func testSecondNoProgressFailureDoesNotPublishOrLeavePartialFile() async throws {
        let fixture = try Fixture(
            downloadOutcomes: [
                .recoverable(.noProgress(resumeData: nil)),
                .recoverable(.noProgress(resumeData: nil))
            ],
            downloadPolicy: .init(inactivityInterval: .milliseconds(1))
        )
        let item = fixture.item(data: fixture.validUSDZ)

        await XCTAssertThrowsErrorAsync(try await fixture.cache.downloadAndValidate(item))

        XCTAssertEqual(fixture.downloads.count, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.modelURL(for: item).path))
        XCTAssertFalse(fixture.containsPartialFiles())
    }
}

private final class Fixture: @unchecked Sendable {
    let root: URL
    let validUSDZ = Data("valid-usdz-fixture".utf8)
    let downloads: DownloadRecorder
    let cache: CoinAssetCache
    private let coinID = UUID()

    init(
        statusCode: Int = 200,
        downloadedData: Data? = nil,
        preflightSucceeds: Bool = true,
        downloadDelayNanoseconds: UInt64 = 0,
        downloadErrorCodes: [URLError.Code] = [],
        downloadOutcomes: [ScriptedDownloadOutcome]? = nil,
        downloadPolicy: CoinFileDownloadPolicy = .live
    ) throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        downloads = DownloadRecorder(errorCodes: downloadErrorCodes)
        let recorder = downloads
        let payload = downloadedData ?? validUSDZ
        let preflight: CoinAssetPreflight = { url in
            recorder.recordPreflight(
                url,
                fileExists: FileManager.default.fileExists(atPath: url.path)
            )
            if !preflightSucceeds { throw TestFailure.preflight }
        }
        if let downloadOutcomes {
            cache = CoinAssetCache(
                directoryURL: root,
                fileDownloader: CoinFileDownloader(
                    attempt: ScriptedCoinFileDownloadAttempt(
                        outcomes: downloadOutcomes,
                        payload: payload,
                        statusCode: statusCode,
                        recorder: recorder
                    ),
                    policy: downloadPolicy
                ),
                preflight: preflight
            )
        } else {
            cache = CoinAssetCache(
                directoryURL: root,
                downloader: { _, destination in
                    if downloadDelayNanoseconds > 0 {
                        try await Task.sleep(nanoseconds: downloadDelayNanoseconds)
                    }
                    recorder.record(destination, resumeData: nil)
                    if let errorCode = recorder.nextErrorCode() {
                        throw URLError(errorCode)
                    }
                    try payload.write(to: destination)
                    return statusCode
                },
                downloadPolicy: downloadPolicy,
                preflight: preflight
            )
        }
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
        return enumerator?.compactMap { $0 as? URL }.contains {
            $0.lastPathComponent.hasSuffix(".partial.usdz")
        } ?? false
    }
}

private final class DownloadRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedDestinations: [URL] = []
    private var storedPreflightDestinations: [URL] = []
    private var storedPreflightFileExistence: [Bool] = []
    private var storedResumeDataInputs: [Data?] = []
    private var remainingErrorCodes: [URLError.Code]

    init(errorCodes: [URLError.Code] = []) {
        remainingErrorCodes = errorCodes
    }

    func record(_ destination: URL, resumeData: Data?) {
        lock.lock()
        storedDestinations.append(destination)
        storedResumeDataInputs.append(resumeData)
        lock.unlock()
    }

    func nextErrorCode() -> URLError.Code? {
        lock.lock()
        defer { lock.unlock() }
        guard !remainingErrorCodes.isEmpty else { return nil }
        return remainingErrorCodes.removeFirst()
    }

    var destinations: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return storedDestinations
    }

    var resumeDataInputs: [Data?] {
        lock.lock()
        defer { lock.unlock() }
        return storedResumeDataInputs
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

private enum ScriptedDownloadOutcome {
    case success
    case recoverable(CoinFileDownloadRecoveryError)
}

private final class ScriptedCoinFileDownloadAttempt: CoinFileDownloadAttempting, @unchecked Sendable {
    private let lock = NSLock()
    private var outcomes: [ScriptedDownloadOutcome]
    private let payload: Data
    private let statusCode: Int
    private let recorder: DownloadRecorder

    init(
        outcomes: [ScriptedDownloadOutcome],
        payload: Data,
        statusCode: Int,
        recorder: DownloadRecorder
    ) {
        self.outcomes = outcomes
        self.payload = payload
        self.statusCode = statusCode
        self.recorder = recorder
    }

    func download(
        from source: URL,
        to destination: URL,
        resumeData: Data?,
        expectedByteCount: Int64,
        policy: CoinFileDownloadPolicy,
        progress: @escaping @Sendable (CoinFileDownloadProgress) -> Void
    ) async throws -> CoinFileDownloadResponse {
        recorder.record(destination, resumeData: resumeData)
        let outcome = lock.withLock { outcomes.removeFirst() }
        switch outcome {
        case .success:
            progress(.phase(receivedBytes: expectedByteCount, expectedBytes: expectedByteCount))
            try payload.write(to: destination)
            return .init(statusCode: statusCode)
        case let .recoverable(error):
            throw error
        }
    }
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
