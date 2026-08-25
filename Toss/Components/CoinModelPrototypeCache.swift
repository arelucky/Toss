import Foundation
import RealityKit

@MainActor
final class CoinModelPrototypeCache {
    static let shared = CoinModelPrototypeCache(dynamicCapacity: 3)

    private let dynamicCapacity: Int
    private var classicPrototype: (url: URL, entity: Entity)?
    private var dynamicPrototypes: [URL: Entity] = [:]
    private var dynamicUsageOrder: [URL] = []

    init(dynamicCapacity: Int) {
        self.dynamicCapacity = dynamicCapacity
    }

    func clone(
        for modelURL: URL,
        isClassic: Bool,
        load: () throws -> Entity
    ) throws -> Entity {
        let cacheKey = modelURL.standardizedFileURL

        if isClassic {
            if let classicPrototype, classicPrototype.url == cacheKey {
                return classicPrototype.entity.clone(recursive: true)
            }

            let prototype = try load()
            classicPrototype = (cacheKey, prototype)
            return prototype.clone(recursive: true)
        }

        if let prototype = dynamicPrototypes[cacheKey] {
            markDynamicPrototypeAsRecentlyUsed(cacheKey)
            return prototype.clone(recursive: true)
        }

        let prototype = try load()
        dynamicPrototypes[cacheKey] = prototype
        markDynamicPrototypeAsRecentlyUsed(cacheKey)
        evictLeastRecentlyUsedDynamicPrototypesIfNeeded()
        return prototype.clone(recursive: true)
    }

    private func markDynamicPrototypeAsRecentlyUsed(_ url: URL) {
        dynamicUsageOrder.removeAll { $0 == url }
        dynamicUsageOrder.append(url)
    }

    private func evictLeastRecentlyUsedDynamicPrototypesIfNeeded() {
        while dynamicUsageOrder.count > dynamicCapacity,
              let leastRecentlyUsedURL = dynamicUsageOrder.first {
            dynamicUsageOrder.removeFirst()
            dynamicPrototypes.removeValue(forKey: leastRecentlyUsedURL)
        }
    }
}
