import Foundation
import Supabase

enum CoinCatalogError: Error, Equatable {
    case invalidCatalogData
}

struct CoinCatalogVersionRow: Decodable, Equatable, Sendable {
    let id: UUID
    let versionNumber: Int
    let modelPath: String
    let previewPath: String
    let modelByteSize: Int64
    let modelSHA256: String
    let minAppVersion: String
    let assetSchemaVersion: Int
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case versionNumber = "version_number"
        case modelPath = "model_path"
        case previewPath = "preview_path"
        case modelByteSize = "model_byte_size"
        case modelSHA256 = "model_sha256"
        case minAppVersion = "min_app_version"
        case assetSchemaVersion = "asset_schema_version"
        case status
    }
}

struct CoinCatalogRow: Decodable, Equatable, Sendable {
    let id: UUID
    let slug: String
    let displayName: String
    let description: String?
    let sortOrder: Int
    let isFeatured: Bool
    let status: String
    let activeVersionID: UUID?
    let version: CoinCatalogVersionRow

    enum CodingKeys: String, CodingKey {
        case id
        case slug
        case displayName = "display_name"
        case description
        case sortOrder = "sort_order"
        case isFeatured = "is_featured"
        case status
        case activeVersionID = "active_version_id"
        case version = "coin_versions"
    }

    func catalogItem(supabaseBaseURL: URL) throws -> CoinCatalogItem {
        guard status == "published",
              version.status == "published",
              activeVersionID == version.id,
              version.modelByteSize > 0,
              version.modelSHA256.range(
                of: "^[0-9a-f]{64}$",
                options: .regularExpression
              ) != nil,
              let modelURL = CoinAssetURLSafety.publicStorageURL(
                supabaseBaseURL: supabaseBaseURL,
                bucket: CoinAssetURLSafety.modelBucket,
                path: version.modelPath
              ),
              let previewURL = CoinAssetURLSafety.publicStorageURL(
                supabaseBaseURL: supabaseBaseURL,
                bucket: CoinAssetURLSafety.previewBucket,
                path: version.previewPath
              ) else {
            throw CoinCatalogError.invalidCatalogData
        }
        return CoinCatalogItem(
            id: id,
            slug: slug,
            displayName: displayName,
            description: description,
            sortOrder: sortOrder,
            isFeatured: isFeatured,
            version: CoinAssetVersion(
                id: version.id,
                versionNumber: version.versionNumber,
                modelURL: modelURL,
                previewURL: previewURL,
                modelByteSize: version.modelByteSize,
                modelSHA256: version.modelSHA256,
                minAppVersion: version.minAppVersion,
                assetSchemaVersion: version.assetSchemaVersion
            )
        )
    }
}

typealias CoinCatalogFetchRows = @Sendable () async throws -> [CoinCatalogRow]

final class SupabaseCoinCatalogRepository: CoinCatalogServicing, @unchecked Sendable {
    private let fetchRows: CoinCatalogFetchRows
    private let cache: CoinCatalogCache
    private let supabaseBaseURL: URL

    init(environment: AppEnvironment, cache: CoinCatalogCache) {
        let client = environment.supabaseClient
        supabaseBaseURL = environment.supabaseBaseURL
        fetchRows = {
            try await client
                .from("coins")
                .select(
                    "id,slug,display_name,description,sort_order,is_featured,status,active_version_id,coin_versions!coins_active_version_id_fkey(id,version_number,model_path,preview_path,model_byte_size,model_sha256,min_app_version,asset_schema_version,status)"
                )
                .execute()
                .value
        }
        self.cache = cache
    }

    init(
        fetchRows: @escaping CoinCatalogFetchRows,
        cache: CoinCatalogCache,
        supabaseBaseURL: URL
    ) {
        self.fetchRows = fetchRows
        self.cache = cache
        self.supabaseBaseURL = supabaseBaseURL
    }

    func fetchPublishedCatalog() async throws -> [CoinCatalogItem] {
        let rows: [CoinCatalogRow]
        do {
            rows = try await fetchRows()
        } catch {
            return cache.load()
        }
        let catalog = try rows
            .filter {
                $0.status == "published"
                    && $0.version.status == "published"
                    && $0.activeVersionID == $0.version.id
            }
            .map { try $0.catalogItem(supabaseBaseURL: supabaseBaseURL) }
            .sorted {
                ($0.sortOrder, $0.slug) < ($1.sortOrder, $1.slug)
            }
        try cache.save(catalog)
        return catalog
    }
}
