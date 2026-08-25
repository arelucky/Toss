import Foundation

protocol CoinAssetCaching: Sendable {
    func cachedModelURL(for item: CoinCatalogItem) async -> URL?
    func downloadAndValidate(
        _ item: CoinCatalogItem,
        progress: @escaping @Sendable (CoinFileDownloadProgress) -> Void
    ) async throws -> URL
    func removeUnreferencedAssets(keeping items: [CoinCatalogItem]) async throws
}

extension CoinAssetCaching {
    func downloadAndValidate(_ item: CoinCatalogItem) async throws -> URL {
        try await downloadAndValidate(item, progress: { _ in })
    }
}
