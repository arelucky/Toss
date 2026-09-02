struct DistributionProfileCapabilities: Equatable, Sendable {
    let showsCoinLibrary: Bool
    let showsAccount: Bool
    let usesOnlineServices: Bool
}

enum DistributionProfile: String, Equatable, Sendable {
    case globalOnline
    case mainlandClassicOnly

    var capabilities: DistributionProfileCapabilities {
        switch self {
        case .globalOnline:
            DistributionProfileCapabilities(
                showsCoinLibrary: true,
                showsAccount: true,
                usesOnlineServices: true
            )
        case .mainlandClassicOnly:
            DistributionProfileCapabilities(
                showsCoinLibrary: false,
                showsAccount: false,
                usesOnlineServices: false
            )
        }
    }
}
