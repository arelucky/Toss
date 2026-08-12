import XCTest
@testable import Toss

final class CoinCatalogRepositoryTests: XCTestCase {
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
            cache: CoinCatalogCache(directoryURL: temporaryDirectory())
        )

        let catalog = try await repository.fetchPublishedCatalog()

        XCTAssertEqual(catalog.map(\.slug), ["alpha", "beta", "zinc"])
        XCTAssertEqual(catalog.first?.id, firstID)
        XCTAssertEqual(catalog.last?.id, secondID)
    }

    func testRejectsNonHTTPSModelOrPreviewURL() async {
        await assertInvalid(row: makeRow(modelURL: "http://example.invalid/model.usdz"))
        await assertInvalid(row: makeRow(previewURL: "http://example.invalid/preview.webp"))
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
        let cached = try makeRow(slug: "cached").catalogItem()
        try cache.save([cached])
        let repository = SupabaseCoinCatalogRepository(
            fetchRows: { throw CatalogTestError.remoteFailure },
            cache: cache
        )

        let catalog = try await repository.fetchPublishedCatalog()

        XCTAssertEqual(catalog, [cached])
    }

    private func assertInvalid(row: CoinCatalogRow) async {
        let repository = SupabaseCoinCatalogRepository(
            fetchRows: { [row] },
            cache: CoinCatalogCache(directoryURL: temporaryDirectory())
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
        modelURL: String = "https://example.invalid/model.usdz",
        previewURL: String = "https://example.invalid/preview.webp",
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
                modelURL: modelURL,
                previewURL: previewURL,
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
