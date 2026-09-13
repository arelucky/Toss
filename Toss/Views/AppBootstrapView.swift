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

struct LaunchProfileLoadingPresentation {
    static let backgroundColor = TossVisualStyle.charcoalTop
    static let title = "命运的一掷"
    static let subtitle = "A toss of fate"
}

private struct LaunchProfileLoadingView: View {
    var body: some View {
        ZStack {
            LaunchProfileLoadingPresentation.backgroundColor.swiftUIColor
                .ignoresSafeArea()

            VStack(spacing: 10) {
                Text(LaunchProfileLoadingPresentation.title)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(TossVisualStyle.primaryText.swiftUIColor)

                Text(LaunchProfileLoadingPresentation.subtitle)
                    .font(.system(size: 17))
                    .foregroundStyle(TossVisualStyle.secondaryText.swiftUIColor)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preparing Toss")
    }
}

@MainActor
final class AppLaunchCoordinator: ObservableObject {
    enum State: Equatable {
        case resolving
        case resolved(DistributionProfile)
        case requiresManualChoice
    }

    @Published private(set) var state: State

    private let resolver: DistributionProfileResolver

    init(resolver: DistributionProfileResolver = DistributionProfileResolver()) {
        self.resolver = resolver

        state = .resolving
        Task { [weak self] in
            await self?.resolveProfile()
        }
    }

    @discardableResult
    func chooseManually(_ profile: DistributionProfile) -> DistributionProfile {
        let selectedProfile = resolver.chooseManually(profile)
        state = .resolved(selectedProfile)
        return selectedProfile
    }

    private func resolveProfile() async {
        switch await resolver.resolve() {
        case let .resolved(profile):
            state = .resolved(profile)
        case .requiresManualChoice:
            state = .requiresManualChoice
        }
    }
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
    @ObservedObject private var coordinator: AppLaunchCoordinator
    @StateObject private var presentation: LaunchProfilePresentation

    init(
        coordinator: AppLaunchCoordinator,
        onlineFactory: any OnlineRootBuilding
    ) {
        _coordinator = ObservedObject(wrappedValue: coordinator)
        _presentation = StateObject(wrappedValue: LaunchProfilePresentation(
            profile: coordinator.resolvedProfile,
            onlineFactory: onlineFactory,
            manualProfileChooser: { coordinator.chooseManually($0) }
        ))
    }

    @MainActor
    init(coordinator: AppLaunchCoordinator) {
        self.init(
            coordinator: coordinator,
            onlineFactory: LiveOnlineRootBuilder()
        )
    }

    var body: some View {
        Group {
            switch coordinator.state {
            case .resolving:
                LaunchProfileLoadingView()
            case .resolved:
                destinationView
            case .requiresManualChoice:
                DistributionProfileChoiceView(onChoose: presentation.chooseManually)
            }
        }
        .onChange(of: coordinator.state) { _, state in
            if case let .resolved(profile) = state {
                presentation.present(profile)
            }
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
            EmptyView()
        }
    }
}

private extension AppLaunchCoordinator {
    var resolvedProfile: DistributionProfile? {
        guard case let .resolved(profile) = state else { return nil }
        return profile
    }
}
