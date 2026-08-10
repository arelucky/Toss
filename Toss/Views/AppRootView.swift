import SwiftUI

private enum AppSheet: String, Identifiable {
    case account
    var id: String { rawValue }
}

@MainActor
struct AppRootView: View {
    @StateObject private var accountStore: AccountStore
    @StateObject private var accountViewModel: AccountViewModel
    @State private var presentedSheet: AppSheet?

    init(dependencies: AppDependencies) {
        let store = AccountStore(authService: dependencies.authService, initialSession: dependencies.session)
        let sync = dependencies.makeAccountSyncCoordinator(accountStore: store)
        _accountStore = StateObject(wrappedValue: store)
        _accountViewModel = StateObject(wrappedValue: AccountViewModel(
            accountStore: store,
            appleSignInService: dependencies.appleSignInService,
            deletionService: dependencies.deletionService,
            deletionRequestStore: dependencies.deletionRequestStore,
            profileRepository: dependencies.profileRepository,
            syncCoordinator: sync,
            localPreferences: dependencies.localPreferences,
            feedbackPreferences: dependencies.feedbackPreferences
        ))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ContentView()
            accountButton
                .padding(.top, 8)
                .padding(.trailing, 16)
        }
        .sheet(item: $presentedSheet) { _ in
            AccountSheetView(viewModel: accountViewModel)
        }
        .task {
            await accountViewModel.start()
        }
    }

    private var accountButton: some View {
        Button {
            presentedSheet = .account
        } label: {
            Image(systemName: accountIconName)
                .font(.system(size: 18, weight: .medium))
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary.opacity(0.82))
        .accessibilityLabel("Account and settings")
        .accessibilityHint("Opens account settings")
    }

    private var accountIconName: String {
        if case .authenticated = accountViewModel.presentation { "person.crop.circle.fill" } else { "person.crop.circle" }
    }
}
