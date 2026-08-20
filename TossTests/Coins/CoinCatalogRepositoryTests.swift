import XCTest
@testable import Toss

final class CoinCatalogRepositoryTests: XCTestCase {
    func testDecodesStoragePathsAndBuildsPublicAssetURLs() throws {
        let row = try JSONDecoder().decode(
            CoinCatalogRow.self,
            from: Data(
                """
                {
                  "id": "10000000-0000-4000-8000-000000000001",
                  "slug": "gold",
                  "display_name": "Gold",
                  "description": null,
                  "sort_order": 0,
                  "is_featured": false,
                  "status": "published",
                  "active_version_id": "20000000-0000-4000-8000-000000000001",
                  "coin_versions": {
                    "id": "20000000-0000-4000-8000-000000000001",
                    "version_number": 1,
                    "model_path": "coins/gold/v1/model.usdz",
                    "preview_path": "coins/gold/v1/preview.webp",
                    "model_byte_size": 1024,
                    "model_sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                    "min_app_version": "1.0.0",
                    "asset_schema_version": 1,
                    "status": "published"
                  }
                }
                """.utf8
            )
        )

        let item = try row.catalogItem(supabaseBaseURL: URL(string: "https://project.supabase.co")!)

        XCTAssertEqual(
            item.version.modelURL.absoluteString,
            "https://project.supabase.co/storage/v1/object/public/coin-models-free/coins/gold/v1/model.usdz"
        )
        XCTAssertEqual(
            item.version.previewURL.absoluteString,
            "https://project.supabase.co/storage/v1/object/public/coin-previews/coins/gold/v1/preview.webp"
        )
    }

    func testAllowsHTTPSAndLocalLoopbackAssetURLsOnly() {
        for value in [
            "https://project.supabase.co/storage/v1/object/public/coin-models-free/model.usdz",
            "http://127.0.0.1:54321/storage/v1/object/public/coin-models-free/model.usdz",
            "http://localhost:54321/storage/v1/object/public/coin-models-free/model.usdz",
            "http://[::1]:54321/storage/v1/object/public/coin-models-free/model.usdz"
        ] {
            XCTAssertTrue(CoinAssetURLSafety.isAllowed(URL(string: value)!))
        }

        for value in [
            "http://example.invalid/model.usdz",
            "file:///tmp/model.usdz"
        ] {
            XCTAssertFalse(CoinAssetURLSafety.isAllowed(URL(string: value)!))
        }
    }

    func testMapsOnlyActivePublishedVersionsAndSortsByOrderThenSlug() async throws {
        let firstID = UUID()
        let secondID = UUID()
        let rows = [
            makeRow(id: secondID, slug: "zinc", sortOrder: 2),
            makeRow(id: UUID(), slug: "draft", sortOrder: 0, coinStatus: "draft"),
            makeRow(id: UUID(), slug: "inactive", sortOrder: 0, isActiveVersion: false),
            makeRow(id: UUID(), slug: "version-draft", sortOrder: 0, versionStatus: "draft"),
            makeRow(id: UUID(), slug: "beta", sortOrder: 1),
            makeRow(id: firstID, slug: "alpha", sortOrder: 1)
        ]
        let repository = SupabaseCoinCatalogRepository(
            fetchRows: { rows },
            cache: CoinCatalogCache(directoryURL: temporaryDirectory()),
            supabaseBaseURL: catalogBaseURL
        )

        let catalog = try await repository.fetchPublishedCatalog()

        XCTAssertEqual(catalog.map(\.slug), ["alpha", "beta", "zinc"])
        XCTAssertEqual(catalog.first?.id, firstID)
        XCTAssertEqual(catalog.last?.id, secondID)
    }

    func testRejectsRemoteHTTPAndFileSupabaseBases() async {
        await assertInvalid(supabaseBaseURL: URL(string: "http://example.invalid")!)
        await assertInvalid(supabaseBaseURL: URL(fileURLWithPath: "/tmp"))
    }

    func testRejectsMalformedSHA256() async {
        await assertInvalid(row: makeRow(modelSHA256: String(repeating: "A", count: 64)))
        await assertInvalid(row: makeRow(modelSHA256: String(repeating: "a", count: 63)))
    }

    func testRejectsNonPositiveFileSize() async {
        await assertInvalid(row: makeRow(modelByteSize: 0))
        await assertInvalid(row: makeRow(modelByteSize: -1))
    }

    func testRemoteFailureReturnsLastSuccessfulCache() async throws {
        let directory = temporaryDirectory()
        let cache = CoinCatalogCache(directoryURL: directory)
        let cached = try makeRow(slug: "cached").catalogItem(supabaseBaseURL: catalogBaseURL)
        try cache.save([cached])
        let repository = SupabaseCoinCatalogRepository(
            fetchRows: { throw CatalogTestError.remoteFailure },
            cache: cache,
            supabaseBaseURL: catalogBaseURL
        )

        let catalog = try await repository.fetchPublishedCatalog()

        XCTAssertEqual(catalog, [cached])
    }

    private var catalogBaseURL: URL { URL(string: "https://example.invalid")! }

    private func assertInvalid(
        row: CoinCatalogRow? = nil,
        supabaseBaseURL: URL? = nil
    ) async {
        let resolvedRow = row ?? makeRow()
        let repository = SupabaseCoinCatalogRepository(
            fetchRows: { [resolvedRow] },
            cache: CoinCatalogCache(directoryURL: temporaryDirectory()),
            supabaseBaseURL: supabaseBaseURL ?? catalogBaseURL
        )

        do {
            _ = try await repository.fetchPublishedCatalog()
            XCTFail("Expected invalid catalog data")
        } catch {
            XCTAssertEqual(error as? CoinCatalogError, .invalidCatalogData)
        }
    }

    private func makeRow(
        id: UUID = UUID(),
        slug: String = "classic",
        sortOrder: Int = 0,
        coinStatus: String = "published",
        isActiveVersion: Bool = true,
        versionStatus: String = "published",
        modelPath: String = "coins/classic/v1/model.usdz",
        previewPath: String = "coins/classic/v1/preview.webp",
        modelByteSize: Int64 = 1024,
        modelSHA256: String = String(repeating: "a", count: 64)
    ) -> CoinCatalogRow {
        let versionID = UUID()
        return CoinCatalogRow(
            id: id,
            slug: slug,
            displayName: slug.capitalized,
            description: nil,
            sortOrder: sortOrder,
            isFeatured: false,
            status: coinStatus,
            activeVersionID: isActiveVersion ? versionID : UUID(),
            version: .init(
                id: versionID,
                versionNumber: 1,
                modelPath: modelPath,
                previewPath: previewPath,
                modelByteSize: modelByteSize,
                modelSHA256: modelSHA256,
                minAppVersion: "1.0.0",
                assetSchemaVersion: 1,
                status: versionStatus
            )
        )
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}

private enum CatalogTestError: Error { case remoteFailure }
