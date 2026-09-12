import StoreKit

enum DistributionProfileResolution: Equatable {
    case resolved(DistributionProfile)
    case requiresManualChoice
}

protocol StorefrontCountryCodeProviding {
    func currentCountryCode() async -> String?
}

struct StoreKitStorefrontCountryCodeProvider: StorefrontCountryCodeProviding {
    func currentCountryCode() async -> String? {
        await Storefront.current?.countryCode
    }
}

final class DistributionProfileResolver {
    private let store: DistributionProfileStore
    private let storefront: any StorefrontCountryCodeProviding

    init(
        store: DistributionProfileStore = DistributionProfileStore(),
        storefront: any StorefrontCountryCodeProviding = StoreKitStorefrontCountryCodeProvider()
    ) {
        self.store = store
        self.storefront = storefront
    }

    var storedProfile: DistributionProfile? {
        guard store.hasCurrentResolutionVersion else { return nil }
        return store.storedProfile
    }

    func resolve() async -> DistributionProfileResolution {
        if let storedProfile {
            return .resolved(storedProfile)
        }

        if store.storedProfile == .mainlandClassicOnly {
            store.save(.mainlandClassicOnly)
            return .resolved(.mainlandClassicOnly)
        }

        guard let countryCode = await storefront.currentCountryCode() else {
            return .requiresManualChoice
        }

        let profile: DistributionProfile = countryCode.uppercased() == "CHN"
            ? .mainlandClassicOnly
            : .globalOnline
        store.save(profile)
        return .resolved(profile)
    }

    @discardableResult
    func chooseManually(_ profile: DistributionProfile) -> DistributionProfile {
        store.save(profile)
        return profile
    }
}
