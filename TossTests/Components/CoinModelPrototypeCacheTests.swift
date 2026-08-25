import RealityKit
import XCTest
@testable import Toss

final class CoinModelPrototypeCacheTests: XCTestCase {
    @MainActor
    func testSameURLLoadsOnceAndReturnsIndependentClones() throws {
        let cache = CoinModelPrototypeCache(dynamicCapacity: 3)
        let url = URL(fileURLWithPath: "/tmp/dynamic.usdz")
        var loadCount = 0

        let first = try cache.clone(for: url, isClassic: false) {
            loadCount += 1
            return Entity()
        }
        let second = try cache.clone(for: url, isClassic: false) {
            loadCount += 1
            return Entity()
        }

        XCTAssertEqual(loadCount, 1)
        XCTAssertFalse(first === second)
    }

    @MainActor
    func testDifferentURLsLoadSeparately() throws {
        let cache = CoinModelPrototypeCache(dynamicCapacity: 3)
        var loadCount = 0

        _ = try cache.clone(for: URL(fileURLWithPath: "/tmp/first.usdz"), isClassic: false) {
            loadCount += 1
            return Entity()
        }
        _ = try cache.clone(for: URL(fileURLWithPath: "/tmp/second.usdz"), isClassic: false) {
            loadCount += 1
            return Entity()
        }

        XCTAssertEqual(loadCount, 2)
    }

    @MainActor
    func testEvictsLeastRecentlyUsedDynamicPrototypeWhileKeepingClassic() throws {
        let cache = CoinModelPrototypeCache(dynamicCapacity: 3)
        let classicURL = URL(fileURLWithPath: "/tmp/classic.usdz")
        let firstURL = URL(fileURLWithPath: "/tmp/first.usdz")
        let secondURL = URL(fileURLWithPath: "/tmp/second.usdz")
        let thirdURL = URL(fileURLWithPath: "/tmp/third.usdz")
        let fourthURL = URL(fileURLWithPath: "/tmp/fourth.usdz")
        var loadsByURL: [URL: Int] = [:]

        func clone(_ url: URL, isClassic: Bool = false) throws -> Entity {
            try cache.clone(for: url, isClassic: isClassic) {
                loadsByURL[url, default: 0] += 1
                return Entity()
            }
        }

        _ = try clone(classicURL, isClassic: true)
        _ = try clone(firstURL)
        _ = try clone(secondURL)
        _ = try clone(thirdURL)
        _ = try clone(firstURL)
        _ = try clone(fourthURL)
        _ = try clone(secondURL)
        _ = try clone(classicURL, isClassic: true)

        XCTAssertEqual(loadsByURL[classicURL], 1)
        XCTAssertEqual(loadsByURL[firstURL], 1)
        XCTAssertEqual(loadsByURL[secondURL], 2)
        XCTAssertEqual(loadsByURL[thirdURL], 1)
        XCTAssertEqual(loadsByURL[fourthURL], 1)
    }
}
