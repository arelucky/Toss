import SwiftUI

struct ClassicSettingsSheetView: View {
    @ObservedObject var viewModel: ClassicSettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        TossVisualStyle.charcoalTop.swiftUIColor,
                        TossVisualStyle.charcoalBottom.swiftUIColor
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                AccountSettingsSection("Feedback") {
                    AccountPreferenceRow(
                        title: "Sound",
                        icon: "speaker.wave.2",
                        isOn: Binding(
                            get: { viewModel.soundEnabled },
                            set: viewModel.setSoundEnabled
                        )
                    )

                    Divider().overlay(.white.opacity(0.12))

                    AccountPreferenceRow(
                        title: "Haptics",
                        icon: "circle.dotted",
                        isOn: Binding(
                            get: { viewModel.hapticEnabled },
                            set: viewModel.setHapticEnabled
                        )
                    )
                }
                .padding(TossVisualStyle.pageHorizontalInset)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(TossVisualStyle.charcoalTop.swiftUIColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(TossVisualStyle.selectionGold.swiftUIColor)
                }
            }
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }
}
