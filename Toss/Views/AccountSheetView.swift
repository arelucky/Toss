import SwiftUI

struct AccountSheetView: View {
    @ObservedObject var viewModel: AccountViewModel
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

                Group {
                    switch viewModel.presentation {
                    case .guest:
                        GuestAccountView(viewModel: viewModel)
                    case .restoring:
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(TossVisualStyle.selectionGold.swiftUIColor)
                            Text("Restoring account…")
                                .foregroundStyle(TossVisualStyle.secondaryText.swiftUIColor)
                        }
                    case let .authenticated(displayName):
                        AuthenticatedAccountView(viewModel: viewModel, displayName: displayName)
                    }
                }
            }
            .navigationTitle("Account")
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
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }
}

struct AccountSettingsSection<Content: View>: View {
    let title: String?
    @ViewBuilder let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TossVisualStyle.secondaryText.swiftUIColor)
                    .textCase(.uppercase)
                    .padding(.horizontal, 4)
            }

            VStack(alignment: .leading, spacing: 14) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(.white.opacity(TossVisualStyle.surfaceOpacity), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}
