import SwiftUI

@MainActor
protocol OnlineRootBuilding {
    func makeOnlineDependencies() -> AppDependencies
}

enum LaunchProfileDestination: Equatable {
    case mainlandClassicOnly
    case globalOnline
    case requiresManualChoice
}

@MainActor
final class LaunchProfilePresentation: ObservableObject {
    @Published private(set) var destination: LaunchProfileDestination

    private let onlineFactory: any OnlineRootBuilding
    private let manualProfileChooser: (DistributionProfile) -> DistributionProfile
    private var cachedOnlineDependencies: AppDependencies?

    init(
        profile: DistributionProfile?,
        onlineFactory: any OnlineRootBuilding,
        manualProfileChooser: @escaping (DistributionProfile) -> DistributionProfile = { $0 }
    ) {
        destination = Self.destination(for: profile)
        self.onlineFactory = onlineFactory
        self.manualProfileChooser = manualProfileChooser
    }

    var onlineDependencies: AppDependencies {
        if let cachedOnlineDependencies {
            return cachedOnlineDependencies
        }

        let dependencies = onlineFactory.makeOnlineDependencies()
        cachedOnlineDependencies = dependencies
        return dependencies
    }

    func present(_ profile: DistributionProfile) {
        destination = Self.destination(for: profile)
    }

    func chooseManually(_ profile: DistributionProfile) {
        present(manualProfileChooser(profile))
    }

    private static func destination(for profile: DistributionProfile?) -> LaunchProfileDestination {
        switch profile {
        case .mainlandClassicOnly:
            .mainlandClassicOnly
        case .globalOnline:
            .globalOnline
        case nil:
            .requiresManualChoice
        }
    }
}

@MainActor
struct AppBootstrapView: View {
    private let resolver: DistributionProfileResolver
    @StateObject private var presentation: LaunchProfilePresentation
    @State private var resolutionStarted = false
    @State private var resolutionFinished = false

    init(
        resolver: DistributionProfileResolver,
        onlineFactory: any OnlineRootBuilding
    ) {
        self.resolver = resolver
        _presentation = StateObject(wrappedValue: LaunchProfilePresentation(
            profile: nil,
            onlineFactory: onlineFactory,
            manualProfileChooser: { resolver.chooseManually($0) }
        ))
    }

    @MainActor
    init() {
        self.init(
            resolver: DistributionProfileResolver(),
            onlineFactory: LiveOnlineRootBuilder()
        )
    }

    var body: some View {
        Group {
            if resolutionFinished {
                destinationView
            } else {
                ProgressView()
                    .accessibilityLabel("Preparing Toss")
            }
        }
        .task {
            await resolveProfileOnce()
        }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch presentation.destination {
        case .mainlandClassicOnly:
            MainlandClassicRootView()
        case .globalOnline:
            AppRootView(dependencies: presentation.onlineDependencies)
        case .requiresManualChoice:
            DistributionProfileChoiceView(onChoose: presentation.chooseManually)
        }
    }

    private func resolveProfileOnce() async {
        guard !resolutionStarted else { return }
        resolutionStarted = true

        switch await resolver.resolve() {
        case let .resolved(profile):
            presentation.present(profile)
        case .requiresManualChoice:
            break
        }

        resolutionFinished = true
    }
}
