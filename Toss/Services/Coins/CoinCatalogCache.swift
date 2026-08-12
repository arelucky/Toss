import Foundation

typealias CoinCatalogReplaceItem = @Sendable (_ original: URL, _ temporary: URL) throws -> Void

final class CoinCatalogCache: @unchecked Sendable {
    private let fileManager: FileManager
    private let catalogDirectoryURL: URL
    private let catalogURL: URL
    private let replaceItem: CoinCatalogReplaceItem
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        directoryURL: URL? = nil,
        fileManager: FileManager = .default,
        replaceItem: CoinCatalogReplaceItem? = nil
    ) {
        self.fileManager = fileManager
        let applicationSupportURL = directoryURL ?? fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        catalogDirectoryURL = applicationSupportURL
            .appendingPathComponent("CoinCatalog", isDirectory: true)
        catalogURL = catalogDirectoryURL.appendingPathComponent("catalog-v1.json")
        self.replaceItem = replaceItem ?? { original, temporary in
            _ = try fileManager.replaceItemAt(original, withItemAt: temporary)
        }
    }

    func load() -> [CoinCatalogItem] {
        guard let data = try? Data(contentsOf: catalogURL),
              let catalog = try? decoder.decode([CoinCatalogItem].self, from: data) else {
            return []
        }
        return catalog
    }

    func save(_ catalog: [CoinCatalogItem]) throws {
        try fileManager.createDirectory(
            at: catalogDirectoryURL,
            withIntermediateDirectories: true
        )
        let temporaryURL = catalogDirectoryURL
            .appendingPathComponent("catalog-v1-\(UUID().uuidString).tmp")
        do {
            try encoder.encode(catalog).write(to: temporaryURL)
            if fileManager.fileExists(atPath: catalogURL.path) {
                try replaceItem(catalogURL, temporaryURL)
            } else {
                try fileManager.moveItem(at: temporaryURL, to: catalogURL)
            }
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        }
    }
}
