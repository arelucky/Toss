import CoreGraphics
import XCTest
@testable import Toss

final class CoinPreviewImageCacheTests: XCTestCase {
    @MainActor
    func testSameURLLoadsAndDecodesOnlyOnce() async {
        var loadCount = 0
        var decodeCount = 0
        let cache = CoinPreviewImageCache(
            capacity: 24,
            loadData: { _ in
                loadCount += 1
                return Data([1])
            },
            decode: { _ in
                decodeCount += 1
                return Self.makeImage()
            }
        )
        let url = URL(string: "https://example.com/preview.webp")!

        let first = await cache.loadImage(for: url)
        let second = await cache.loadImage(for: url)

        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        XCTAssertEqual(first?.width, second?.width)
        XCTAssertEqual(loadCount, 1)
        XCTAssertEqual(decodeCount, 1)
    }

    @MainActor
    func testDifferentURLsLoadSeparately() async {
        var loadCount = 0
        let cache = CoinPreviewImageCache(
            capacity: 24,
            loadData: { _ in
                loadCount += 1
                return Data([1])
            },
            decode: { _ in Self.makeImage() }
        )

        _ = await cache.loadImage(for: URL(string: "https://example.com/one.webp")!)
        _ = await cache.loadImage(for: URL(string: "https://example.com/two.webp")!)

        XCTAssertEqual(loadCount, 2)
    }

    @MainActor
    func testConcurrentRequestsForSameURLShareOneLoad() async {
        var loadCount = 0
        let cache = CoinPreviewImageCache(
            capacity: 24,
            loadData: { _ in
                loadCount += 1
                await Task.yield()
                return Data([1])
            },
            decode: { _ in Self.makeImage() }
        )
        let url = URL(string: "https://example.com/preview.webp")!

        async let first = cache.loadImage(for: url)
        async let second = cache.loadImage(for: url)
        let images = await (first, second)

        XCTAssertNotNil(images.0)
        XCTAssertNotNil(images.1)
        XCTAssertEqual(loadCount, 1)
    }

    @MainActor
    func testEvictsLeastRecentlyUsedPreviewAfterTwentyFourEntries() async {
        var loadsByURL: [URL: Int] = [:]
        let cache = CoinPreviewImageCache(
            capacity: 24,
            loadData: { url in
                loadsByURL[url, default: 0] += 1
                return Data([1])
            },
            decode: { _ in Self.makeImage() }
        )
        let urls = (0 ... 24).map { URL(string: "https://example.com/\($0).webp")! }

        for url in urls.dropLast() {
            _ = await cache.loadImage(for: url)
        }
        _ = await cache.loadImage(for: urls[0])
        _ = await cache.loadImage(for: urls[24])
        _ = await cache.loadImage(for: urls[1])

        XCTAssertEqual(loadsByURL[urls[0]], 1)
        XCTAssertEqual(loadsByURL[urls[1]], 2)
    }

    @MainActor
    func testDecodeFailureDoesNotEnterCache() async {
        var loadCount = 0
        let cache = CoinPreviewImageCache(
            capacity: 24,
            loadData: { _ in
                loadCount += 1
                return Data([1])
            },
            decode: { _ in nil }
        )
        let url = URL(string: "https://example.com/invalid.webp")!

        let first = await cache.loadImage(for: url)
        let second = await cache.loadImage(for: url)

        XCTAssertNil(first)
        XCTAssertNil(second)
        XCTAssertNil(cache.image(for: url))
        XCTAssertEqual(loadCount, 2)
    }

    private static func makeImage() -> CGImage {
        let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return context.makeImage()!
    }
}
