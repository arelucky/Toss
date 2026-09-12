import XCTest
@testable import Toss

final class DistributionProfileResolverTests: XCTestCase {
    func testCHNStorefrontResolvesAndPersistsClassicOnly() async {
        let store = DistributionProfileStore(store: ProfileKeyValueStore())
        let resolver = DistributionProfileResolver(
            store: store,
            storefront: StorefrontCountryCodeDouble(countryCode: "CHN")
        )

        let resolution = await resolver.resolve()

        XCTAssertEqual(resolution, .resolved(.mainlandClassicOnly))
        XCTAssertEqual(store.storedProfile, .mainlandClassicOnly)
        XCTAssertFalse(DistributionProfile.mainlandClassicOnly.capabilities.showsCoinLibrary)
        XCTAssertFalse(DistributionProfile.mainlandClassicOnly.capabilities.showsAccount)
        XCTAssertFalse(DistributionProfile.mainlandClassicOnly.capabilities.usesOnlineServices)
    }

    func testNonCHNStorefrontResolvesAndPersistsGlobalOnline() async {
        let store = DistributionProfileStore(store: ProfileKeyValueStore())
        let resolver = DistributionProfileResolver(
            store: store,
            storefront: StorefrontCountryCodeDouble(countryCode: "USA")
        )

        let resolution = await resolver.resolve()

        XCTAssertEqual(resolution, .resolved(.globalOnline))
        XCTAssertEqual(store.storedProfile, .globalOnline)
    }

    func testStoredProfileWinsOverChangedStorefront() async {
        let store = DistributionProfileStore(store: ProfileKeyValueStore())
        store.save(.globalOnline)
        let storefront = StorefrontCountryCodeDouble(countryCode: "CHN")
        let resolver = DistributionProfileResolver(
            store: store,
            storefront: storefront
        )

        let resolution = await resolver.resolve()

        XCTAssertEqual(resolution, .resolved(.globalOnline))
        XCTAssertEqual(storefront.callCount, 0)
    }

    func testLegacyGlobalProfileRechecksCHNStorefrontAndMigratesToClassicOnly() async {
        let storage = ProfileKeyValueStore()
        storage.set(DistributionProfile.globalOnline.rawValue, forKey: "distribution.profile")
        let store = DistributionProfileStore(store: storage)
        let storefront = StorefrontCountryCodeDouble(countryCode: "CHN")
        let resolver = DistributionProfileResolver(
            store: store,
            storefront: storefront
        )

        let resolution = await resolver.resolve()

        XCTAssertEqual(resolution, .resolved(.mainlandClassicOnly))
        XCTAssertEqual(store.storedProfile, .mainlandClassicOnly)
        XCTAssertEqual(storefront.callCount, 1)
    }

    func testLegacyGlobalProfileRechecksNonCHNStorefrontAndMigratesOnce() async {
        let storage = ProfileKeyValueStore()
        storage.set(DistributionProfile.globalOnline.rawValue, forKey: "distribution.profile")
        let store = DistributionProfileStore(store: storage)
        let storefront = StorefrontCountryCodeDouble(countryCode: "USA")
        let resolver = DistributionProfileResolver(store: store, storefront: storefront)

        let firstResolution = await resolver.resolve()

        XCTAssertEqual(firstResolution, .resolved(.globalOnline))
        XCTAssertEqual(storefront.callCount, 1)

        let changedStorefront = StorefrontCountryCodeDouble(countryCode: "CHN")
        let relaunchedResolver = DistributionProfileResolver(
            store: store,
            storefront: changedStorefront
        )

        let relaunchedResolution = await relaunchedResolver.resolve()

        XCTAssertEqual(relaunchedResolution, .resolved(.globalOnline))
        XCTAssertEqual(changedStorefront.callCount, 0)
    }

    func testLegacyGlobalProfileWithoutStorefrontRequiresManualChoice() async {
        let storage = ProfileKeyValueStore()
        storage.set(DistributionProfile.globalOnline.rawValue, forKey: "distribution.profile")
        let storefront = StorefrontCountryCodeDouble(countryCode: nil)
        let resolver = DistributionProfileResolver(
            store: DistributionProfileStore(store: storage),
            storefront: storefront
        )

        let resolution = await resolver.resolve()

        XCTAssertEqual(resolution, .requiresManualChoice)
        XCTAssertEqual(storefront.callCount, 1)
    }

    @MainActor
    func testLegacyGlobalProfileIsNotReadyBeforeMigration() {
        let storage = ProfileKeyValueStore()
        storage.set(DistributionProfile.globalOnline.rawValue, forKey: "distribution.profile")
        let coordinator = AppLaunchCoordinator(
            resolver: DistributionProfileResolver(
                store: DistributionProfileStore(store: storage),
                storefront: StorefrontCountryCodeDouble(countryCode: "CHN")
            )
        )

        XCTAssertEqual(coordinator.state, .resolving)
    }

    func testUnknownStorefrontRequiresManualChoiceAndPersistsIt() async {
        let store = DistributionProfileStore(store: ProfileKeyValueStore())
        let resolver = DistributionProfileResolver(
            store: store,
            storefront: StorefrontCountryCodeDouble(countryCode: nil)
        )

        let resolution = await resolver.resolve()

        XCTAssertEqual(resolution, .requiresManualChoice)
        XCTAssertEqual(resolver.chooseManually(.mainlandClassicOnly), .mainlandClassicOnly)
        XCTAssertEqual(store.storedProfile, .mainlandClassicOnly)
    }

    @MainActor
    func testSavedProfileIsReadyBeforeStorefrontResolutionStarts() {
        let store = DistributionProfileStore(store: ProfileKeyValueStore())
        store.save(.mainlandClassicOnly)
        let storefront = StorefrontCountryCodeDouble(countryCode: "USA")
        let coordinator = AppLaunchCoordinator(
            resolver: DistributionProfileResolver(
                store: store,
                storefront: storefront
            )
        )

        XCTAssertEqual(coordinator.state, .resolved(.mainlandClassicOnly))
        XCTAssertEqual(storefront.callCount, 0)
    }
}

private final class ProfileKeyValueStore: PreferencesKeyValueStoring {
    private var values: [String: Any] = [:]

    func object(forKey key: String) -> Any? {
        values[key]
    }

    func set(_ value: Any?, forKey key: String) {
        values[key] = value
    }
}

private final class StorefrontCountryCodeDouble: StorefrontCountryCodeProviding {
    let countryCode: String?
    private(set) var callCount = 0

    init(countryCode: String?) {
        self.countryCode = countryCode
    }

    func currentCountryCode() async -> String? {
        callCount += 1
        return countryCode
    }
}
