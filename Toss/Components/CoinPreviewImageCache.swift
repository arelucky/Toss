import CoreGraphics
import Foundation
import ImageIO

@MainActor
final class CoinPreviewImageCache {
    typealias DataLoader = (URL) async throws -> Data
    typealias ImageDecoder = (Data) -> CGImage?

    static let shared = CoinPreviewImageCache(capacity: 24)

    private let capacity: Int
    private let loadData: DataLoader
    private let decode: ImageDecoder
    private var images: [URL: CGImage] = [:]
    private var usageOrder: [URL] = []
    private var inFlightTasks: [URL: Task<CGImage?, Never>] = [:]

    init(
        capacity: Int,
        loadData: @escaping DataLoader = CoinPreviewImageCache.loadData,
        decode: @escaping ImageDecoder = CoinPreviewImageCache.decodeImage
    ) {
        self.capacity = capacity
        self.loadData = loadData
        self.decode = decode
    }

    func image(for url: URL) -> CGImage? {
        let key = url.absoluteURL
        guard let image = images[key] else { return nil }

        markAsRecentlyUsed(key)
        return image
    }

    func loadImage(for url: URL) async -> CGImage? {
        let key = url.absoluteURL
        if let image = image(for: key) {
            return image
        }

        if let task = inFlightTasks[key] {
            return await task.value
        }

        let task = Task { [loadData, decode] in
            do {
                return decode(try await loadData(key))
            } catch {
                return nil
            }
        }
        inFlightTasks[key] = task

        let image = await task.value
        inFlightTasks.removeValue(forKey: key)

        if let image {
            store(image, for: key)
        }

        return image
    }

    private func store(_ image: CGImage, for url: URL) {
        images[url] = image
        markAsRecentlyUsed(url)

        while usageOrder.count > capacity,
              let leastRecentlyUsedURL = usageOrder.first {
            usageOrder.removeFirst()
            images.removeValue(forKey: leastRecentlyUsedURL)
        }
    }

    private func markAsRecentlyUsed(_ url: URL) {
        usageOrder.removeAll { $0 == url }
        usageOrder.append(url)
    }

    nonisolated private static func loadData(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    nonisolated private static func decodeImage(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
