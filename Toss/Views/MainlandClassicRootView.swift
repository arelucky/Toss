import SwiftUI

@MainActor
struct MainlandClassicRootView: View {
    @StateObject private var tossViewModel: CoinTossViewModel
    @StateObject private var settingsViewModel: ClassicSettingsViewModel
    @State private var isSettingsPresented = false

    init() {
        _tossViewModel = StateObject(wrappedValue: CoinTossViewModel())
        _settingsViewModel = StateObject(wrappedValue: ClassicSettingsViewModel())
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ContentView(
                viewModel: tossViewModel,
                coinModelSource: .bundledClassic,
                onOpenCoinLibrary: nil
            )

            settingsButton
                .padding(.top, 8)
                .padding(.trailing, TossVisualStyle.pageHorizontalInset)
        }
        .sheet(isPresented: $isSettingsPresented) {
            ClassicSettingsSheetView(viewModel: settingsViewModel)
        }
    }

    private var settingsButton: some View {
        Button {
            isSettingsPresented = true
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 18, weight: .medium))
                .frame(width: TossVisualStyle.controlSize, height: TossVisualStyle.controlSize)
                .background(
                    TossVisualStyle.primaryText.swiftUIColor.opacity(TossVisualStyle.surfaceOpacity),
                    in: Circle()
                )
                .overlay {
                    Circle()
                        .stroke(
                            TossVisualStyle.primaryText.swiftUIColor.opacity(0.18),
                            lineWidth: 0.5
                        )
                }
        }
        .buttonStyle(.plain)
        .foregroundStyle(TossVisualStyle.primaryText.swiftUIColor)
        .accessibilityLabel("Settings")
        .accessibilityHint("Opens sound and haptic settings")
    }
}
