import XCTest
@testable import Toss

final class DistributionProfileResolverTests: XCTestCase {
    func testSandboxReceiptIdentifiesTestFlight() {
        let environment = AppDistributionEnvironment(
            receiptURL: URL(fileURLWithPath: "/app/StoreKit/sandboxReceipt")
        )

        XCTAssertTrue(environment.isTestFlight)
    }

    func testProductionReceiptDoesNotIdentifyTestFlight() {
        let environment = AppDistributionEnvironment(
            receiptURL: URL(fileURLWithPath: "/app/StoreKit/receipt")
        )

        XCTAssertFalse(environment.isTestFlight)
    }

    func testCHNStorefrontResolvesClassicOnly() async {
        let resolver = DistributionProfileResolver(
            storefront: StorefrontCountryCodeDouble(countryCode: "CHN"),
            isTestFlight: false
        )

        let resolution = await resolver.resolve()

        XCTAssertEqual(resolution, .resolved(.mainlandClassicOnly))
        XCTAssertFalse(DistributionProfile.mainlandClassicOnly.capabilities.showsCoinLibrary)
        XCTAssertFalse(DistributionProfile.mainlandClassicOnly.capabilities.showsAccount)
        XCTAssertFalse(DistributionProfile.mainlandClassicOnly.capabilities.usesOnlineServices)
    }

    func testNonCHNStorefrontResolvesGlobalOnline() async {
        let resolver = DistributionProfileResolver(
            storefront: StorefrontCountryCodeDouble(countryCode: "USA"),
            isTestFlight: false
        )

        let resolution = await resolver.resolve()

        XCTAssertEqual(resolution, .resolved(.globalOnline))
    }

    func testProductionRechecksStorefrontForEachLaunch() async {
        let storefront = StorefrontCountryCodeDouble(countryCode: "USA")
        let firstResolver = DistributionProfileResolver(
            storefront: storefront,
            isTestFlight: false
        )

        let firstResolution = await firstResolver.resolve()
        storefront.countryCode = "CHN"
        let relaunchedResolver = DistributionProfileResolver(
            storefront: storefront,
            isTestFlight: false
        )
        let relaunchedResolution = await relaunchedResolver.resolve()

        XCTAssertEqual(firstResolution, .resolved(.globalOnline))
        XCTAssertEqual(relaunchedResolution, .resolved(.mainlandClassicOnly))
        XCTAssertEqual(storefront.callCount, 2)
    }

    func testProductionWithoutStorefrontDefaultsToClassicOnly() async {
        let storefront = StorefrontCountryCodeDouble(countryCode: nil)
        let resolver = DistributionProfileResolver(
            storefront: storefront,
            isTestFlight: false
        )

        let resolution = await resolver.resolve()

        XCTAssertEqual(resolution, .resolved(.mainlandClassicOnly))
        XCTAssertEqual(storefront.callCount, 1)
    }

    func testTestFlightRequiresManualChoiceWithoutReadingStorefront() async {
        let storefront = StorefrontCountryCodeDouble(countryCode: "USA")
        let resolver = DistributionProfileResolver(
            storefront: storefront,
            isTestFlight: true
        )

        let resolution = await resolver.resolve()

        XCTAssertEqual(resolution, .requiresManualChoice)
        XCTAssertEqual(storefront.callCount, 0)
    }

    @MainActor
    func testCoordinatorStartsResolvingBeforeProductionStorefrontCheck() {
        let coordinator = AppLaunchCoordinator(
            resolver: DistributionProfileResolver(
                storefront: StorefrontCountryCodeDouble(countryCode: "CHN"),
                isTestFlight: false
            )
        )

        XCTAssertEqual(coordinator.state, .resolving)
    }
}

private final class StorefrontCountryCodeDouble: StorefrontCountryCodeProviding {
    var countryCode: String?
    private(set) var callCount = 0

    init(countryCode: String?) {
        self.countryCode = countryCode
    }

    func currentCountryCode() async -> String? {
        callCount += 1
        return countryCode
    }
}
