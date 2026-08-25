import AuthenticationServices
import SwiftUI

struct GuestAccountView: View {
    @ObservedObject var viewModel: AccountViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                AccountSettingsSection {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Sign in to keep your settings in sync across devices. Toss remains available without an account.")
                            .font(.system(size: 16))
                            .foregroundStyle(TossVisualStyle.secondaryText.swiftUIColor)
                        appleSignInControl
                    }
                }
                feedbackSection
                noticeSection
            }
            .padding(.horizontal, TossVisualStyle.pageHorizontalInset)
            .padding(.vertical, 24)
        }
    }

    private var appleSignInControl: some View {
        ZStack {
            SignInWithAppleButton(.signIn, onRequest: { _ in }, onCompletion: { _ in })
                .signInWithAppleButtonStyle(.black)
                .allowsHitTesting(false)
            Button {
                Task { await viewModel.signIn() }
            } label: {
                Color.clear
            }
            .accessibilityLabel("Sign in with Apple")
        }
        .frame(height: 50)
        .disabled(viewModel.isSigningIn)
        .overlay {
            if viewModel.isSigningIn {
                ProgressView()
                    .tint(.white)
                    .accessibilityLabel("Signing in")
            }
        }
    }

    private var feedbackSection: some View {
        AccountSettingsSection("Feedback") {
            Toggle("Sound", isOn: Binding(
                get: { viewModel.soundEnabled },
                set: { value in Task { await viewModel.setSoundEnabled(value) } }
            ))
            .tint(TossVisualStyle.selectionGold.swiftUIColor)

            Divider().overlay(.white.opacity(0.12))

            Toggle("Haptics", isOn: Binding(
                get: { viewModel.hapticEnabled },
                set: { value in Task { await viewModel.setHapticEnabled(value) } }
            ))
            .tint(TossVisualStyle.selectionGold.swiftUIColor)
        }
    }

    @ViewBuilder
    private var noticeSection: some View {
        if let notice = viewModel.notice {
            AccountSettingsSection {
                Text(notice.message)
                    .font(.footnote)
                    .foregroundStyle(TossVisualStyle.secondaryText.swiftUIColor)
            }
        }
    }
}
