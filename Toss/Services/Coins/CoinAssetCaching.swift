import Foundation

protocol CoinAssetCaching: Sendable {
    func cachedModelURL(for item: CoinCatalogItem) async -> URL?
    func downloadAndValidate(_ item: CoinCatalogItem) async throws -> URL
    func removeUnreferencedAssets(keeping items: [CoinCatalogItem]) async throws
}
