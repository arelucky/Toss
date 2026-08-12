import Foundation

struct CoinCatalogItem: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let slug: String
    let displayName: String
    let description: String?
    let sortOrder: Int
    let isFeatured: Bool
    let version: CoinAssetVersion
}

struct CoinAssetVersion: Codable, Equatable, Sendable {
    let id: UUID
    let versionNumber: Int
    let modelURL: URL
    let previewURL: URL
    let modelByteSize: Int64
    let modelSHA256: String
    let minAppVersion: String
    let assetSchemaVersion: Int
}
