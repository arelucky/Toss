import SwiftUI

@MainActor
struct LiveOnlineRootBuilder: OnlineRootBuilding {
    func makeOnlineDependencies() -> AppDependencies {
        .live()
    }
}

private enum AppSheet: String, Identifiable {
    case account
    var id: String { rawValue }
}

@MainActor
struct AppRootView: View {
    @StateObject private var accountStore: AccountStore
    @StateObject private var accountViewModel: AccountViewModel
    @StateObject private var tossViewModel: CoinTossViewModel
    @StateObject private var coinLibraryViewModel: CoinLibraryViewModel
    @State private var presentedSheet: AppSheet?
    @State private var isCoinLibraryPresented = false

    init(dependencies: AppDependencies) {
        let store = AccountStore(authService: dependencies.authService, initialSession: dependencies.session)
        let sync = dependencies.makeAccountSyncCoordinator(accountStore: store)
        let toss = CoinTossViewModel()
        let coinLibrary = dependencies.makeCoinLibraryViewModel(
            accountStore: store,
            tossViewModel: toss
        )
        _accountStore = StateObject(wrappedValue: store)
        _tossViewModel = StateObject(wrappedValue: toss)
        _coinLibraryViewModel = StateObject(wrappedValue: coinLibrary)
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
            ContentView(
                viewModel: tossViewModel,
                coinModelSource: coinLibraryViewModel.selectedModelSource,
                onOpenCoinLibrary: { isCoinLibraryPresented = true }
            )
            accountButton
                .padding(.top, 8)
                .padding(.trailing, TossVisualStyle.pageHorizontalInset)
        }
        .sheet(item: $presentedSheet) { _ in
            AccountSheetView(viewModel: accountViewModel)
        }
        .fullScreenCover(isPresented: $isCoinLibraryPresented) {
            CoinLibraryView(viewModel: coinLibraryViewModel) {
                isCoinLibraryPresented = false
            }
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
                .frame(width: TossVisualStyle.controlSize, height: TossVisualStyle.controlSize)
                .background(
                    TossVisualStyle.primaryText.swiftUIColor.opacity(TossVisualStyle.surfaceOpacity),
                    in: Circle()
                )
                .overlay {
                    Circle()
                        .stroke(TossVisualStyle.primaryText.swiftUIColor.opacity(0.18), lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
        .foregroundStyle(TossVisualStyle.primaryText.swiftUIColor)
        .accessibilityLabel("Account and settings")
        .accessibilityHint("Opens account settings")
    }

    private var accountIconName: String {
        if case .authenticated = accountViewModel.presentation { "person.crop.circle.fill" } else { "person.crop.circle" }
    }
}
