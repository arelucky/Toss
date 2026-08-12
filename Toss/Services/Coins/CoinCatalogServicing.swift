protocol CoinCatalogServicing: Sendable {
    func fetchPublishedCatalog() async throws -> [CoinCatalogItem]
}
