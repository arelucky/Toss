import Foundation
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

struct AppDistributionEnvironment {
    let receiptURL: URL?

    init(receiptURL: URL? = Bundle.main.appStoreReceiptURL) {
        self.receiptURL = receiptURL
    }

    var isTestFlight: Bool {
        receiptURL?.lastPathComponent == "sandboxReceipt"
    }
}

final class DistributionProfileResolver {
    private let storefront: any StorefrontCountryCodeProviding
    private let isTestFlight: Bool

    init(
        storefront: any StorefrontCountryCodeProviding = StoreKitStorefrontCountryCodeProvider(),
        isTestFlight: Bool = AppDistributionEnvironment().isTestFlight
    ) {
        self.storefront = storefront
        self.isTestFlight = isTestFlight
    }

    func resolve() async -> DistributionProfileResolution {
        if isTestFlight {
            return .requiresManualChoice
        }

        let profile: DistributionProfile
        switch await storefront.currentCountryCode()?.uppercased() {
        case "CHN", nil:
            profile = .mainlandClassicOnly
        default:
            profile = .globalOnline
        }
        return .resolved(profile)
    }

    @discardableResult
    func chooseManually(_ profile: DistributionProfile) -> DistributionProfile {
        profile
    }
}
