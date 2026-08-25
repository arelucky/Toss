import CryptoKit
import Foundation
import RealityKit

typealias CoinAssetDownloader = @Sendable (_ source: URL, _ destination: URL) async throws -> Int
typealias CoinAssetPreflight = @Sendable (_ modelURL: URL) async throws -> Void

enum CoinAssetCacheError: Error, Equatable {
    case insecureURL
    case invalidHTTPStatus(Int)
    case invalidByteCount
    case invalidSHA256
}

actor CoinAssetCache: CoinAssetCaching {
    private let fileManager: FileManager
    private let assetsDirectoryURL: URL
    private let downloader: any CoinFileDownloading
    private let preflight: CoinAssetPreflight
    private var downloadsInProgress: [AssetKey: Task<URL, Error>] = [:]

    init(
        directoryURL: URL? = nil,
        fileManager: FileManager = .default,
        downloader: CoinAssetDownloader? = nil,
        fileDownloader: (any CoinFileDownloading)? = nil,
        downloadPolicy: CoinFileDownloadPolicy = .live,
        preflight: CoinAssetPreflight? = nil
    ) {
        self.fileManager = fileManager
        let applicationSupportURL = directoryURL ?? fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        assetsDirectoryURL = applicationSupportURL.appendingPathComponent("CoinAssets", isDirectory: true)
        if let fileDownloader {
            self.downloader = fileDownloader
        } else if let downloader {
            self.downloader = CoinFileDownloader(
                attempt: ClosureCoinFileDownloadAttempt(downloader: downloader),
                policy: downloadPolicy
            )
        } else {
            self.downloader = CoinFileDownloader(
                attempt: URLSessionCoinFileDownloadAttempt(),
                policy: downloadPolicy
            )
        }
        self.preflight = preflight ?? { modelURL in
            try await Task.detached(priority: .utility) {
                _ = try await Entity.load(contentsOf: modelURL)
            }.value
        }
    }

    func cachedModelURL(for item: CoinCatalogItem) -> URL? {
        let url = modelURL(for: item)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    func downloadAndValidate(
        _ item: CoinCatalogItem,
        progress: @escaping @Sendable (CoinFileDownloadProgress) -> Void
    ) async throws -> URL {
        guard CoinAssetURLSafety.isAllowed(item.version.modelURL) else {
            throw CoinAssetCacheError.insecureURL
        }
        if let cached = cachedModelURL(for: item) {
            return cached
        }

        let key = AssetKey(item: item)
        if let download = downloadsInProgress[key] {
            return try await download.value
        }

        let destination = modelURL(for: item)
        let partial = destination.deletingLastPathComponent()
            .appendingPathComponent("\(UUID().uuidString).partial.usdz")
        let fileManager = self.fileManager
        let downloader = self.downloader
        let preflight = self.preflight
        let task = Task<URL, Error> {
            try await Self.performDownload(
                item: item,
                destination: destination,
                partial: partial,
                fileManager: fileManager,
                downloader: downloader,
                preflight: preflight,
                progress: progress
            )
        }
        downloadsInProgress[key] = task

        do {
            let url = try await task.value
            downloadsInProgress[key] = nil
            return url
        } catch {
            downloadsInProgress[key] = nil
            throw error
        }
    }

    func removeUnreferencedAssets(keeping items: [CoinCatalogItem]) throws {
        guard fileManager.fileExists(atPath: assetsDirectoryURL.path) else { return }
        let kept = Set(items.map { AssetKey(item: $0) })
        let coinDirectories = try fileManager.contentsOfDirectory(
            at: assetsDirectoryURL,
            includingPropertiesForKeys: [.isDirectoryKey]
        )
        for coinDirectory in coinDirectories {
            let versions = try fileManager.contentsOfDirectory(
                at: coinDirectory,
                includingPropertiesForKeys: [.isDirectoryKey]
            )
            for version in versions {
                let number = Int(version.lastPathComponent.dropFirst())
                let coinID = UUID(uuidString: coinDirectory.lastPathComponent)
                if let coinID, let number, !kept.contains(AssetKey(coinID: coinID, versionNumber: number)) {
                    try fileManager.removeItem(at: version)
                }
            }
        }
    }

    private func modelURL(for item: CoinCatalogItem) -> URL {
        assetsDirectoryURL
            .appendingPathComponent(item.id.uuidString, isDirectory: true)
            .appendingPathComponent("v\(item.version.versionNumber)", isDirectory: true)
            .appendingPathComponent("model.usdz")
    }

    private static func performDownload(
        item: CoinCatalogItem,
        destination: URL,
        partial: URL,
        fileManager: FileManager,
        downloader: any CoinFileDownloading,
        preflight: CoinAssetPreflight,
        progress: @escaping @Sendable (CoinFileDownloadProgress) -> Void
    ) async throws -> URL {
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: partial) }

        let response = try await downloader.download(
            from: item.version.modelURL,
            to: partial,
            expectedByteCount: item.version.modelByteSize,
            progress: progress
        )
        guard (200 ... 299).contains(response.statusCode) else {
            throw CoinAssetCacheError.invalidHTTPStatus(response.statusCode)
        }
        progress(.verifying)
        let values = try partial.resourceValues(forKeys: [.fileSizeKey])
        guard Int64(values.fileSize ?? -1) == item.version.modelByteSize else {
            throw CoinAssetCacheError.invalidByteCount
        }
        let digest = try await Task.detached(priority: .utility) {
            SHA256.hash(data: try Data(contentsOf: partial))
                .map { String(format: "%02x", $0) }
                .joined()
        }.value
        guard digest.caseInsensitiveCompare(item.version.modelSHA256) == .orderedSame else {
            throw CoinAssetCacheError.invalidSHA256
        }
        try await preflight(partial)
        try fileManager.moveItem(at: partial, to: destination)
        return destination
    }

}

private struct ClosureCoinFileDownloadAttempt: CoinFileDownloadAttempting {
    let downloader: CoinAssetDownloader

    func download(
        from source: URL,
        to destination: URL,
        resumeData: Data?,
        expectedByteCount: Int64,
        policy: CoinFileDownloadPolicy,
        progress: @escaping @Sendable (CoinFileDownloadProgress) -> Void
    ) async throws -> CoinFileDownloadResponse {
        let statusCode = try await downloader(source, destination)
        return .init(statusCode: statusCode)
    }
}

private struct AssetKey: Hashable, Sendable {
    let coinID: UUID
    let versionNumber: Int

    init(item: CoinCatalogItem) {
        coinID = item.id
        versionNumber = item.version.versionNumber
    }

    init(coinID: UUID, versionNumber: Int) {
        self.coinID = coinID
        self.versionNumber = versionNumber
    }
}
