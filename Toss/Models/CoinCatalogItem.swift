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

enum CoinAssetURLSafety {
    static let modelBucket = "coin-models-free"
    static let previewBucket = "coin-previews"

    static func isAllowed(_ url: URL) -> Bool {
        switch url.scheme?.lowercased() {
        case "https":
            return true
        case "http":
            guard let host = url.host?.lowercased() else { return false }
            return ["127.0.0.1", "localhost", "::1", "[::1]"].contains(host)
        default:
            return false
        }
    }

    static func publicStorageURL(
        supabaseBaseURL: URL,
        bucket: String,
        path: String
    ) -> URL? {
        guard isAllowed(supabaseBaseURL),
              [modelBucket, previewBucket].contains(bucket),
              !path.isEmpty,
              !path.hasPrefix("/") else {
            return nil
        }

        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.isEmpty,
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            return nil
        }

        return components.reduce(
            supabaseBaseURL
                .appendingPathComponent("storage", isDirectory: true)
                .appendingPathComponent("v1", isDirectory: true)
                .appendingPathComponent("object", isDirectory: true)
                .appendingPathComponent("public", isDirectory: true)
                .appendingPathComponent(bucket, isDirectory: true)
        ) { url, component in
            url.appendingPathComponent(String(component), isDirectory: false)
        }
    }
}
