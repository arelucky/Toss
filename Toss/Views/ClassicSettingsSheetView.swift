import SwiftUI

struct ClassicSettingsSheetView: View {
    @ObservedObject var viewModel: ClassicSettingsViewModel
    let filingDisclosure: MainlandAppFilingDisclosure?
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

                VStack(spacing: 20) {
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

                    if let filingDisclosure {
                        filingDisclosureSection(filingDisclosure)
                    }
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

    private func filingDisclosureSection(
        _ disclosure: MainlandAppFilingDisclosure
    ) -> some View {
        VStack(spacing: 6) {
            Text("ICP备案号")
                .font(.footnote.weight(.medium))
                .foregroundStyle(TossVisualStyle.secondaryText.swiftUIColor)

            Text(disclosure.number)
                .font(.footnote)
                .foregroundStyle(TossVisualStyle.primaryText.swiftUIColor)

            Link("备案查询", destination: disclosure.verificationURL)
                .font(.footnote)
                .foregroundStyle(TossVisualStyle.selectionGold.swiftUIColor)
                .accessibilityLabel("查询 \(disclosure.number) 备案信息")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
}
