import AuthenticationServices
import SwiftUI

struct GuestAccountView: View {
    @ObservedObject var viewModel: AccountViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                guestIdentitySection
                feedbackSection
                noticeSection
            }
            .padding(.horizontal, TossVisualStyle.pageHorizontalInset)
            .padding(.vertical, 24)
        }
    }

    private var guestIdentitySection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 35, weight: .light))
                    .foregroundStyle(TossVisualStyle.selectionGold.swiftUIColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Toss Account")
                        .font(.system(size: 22, weight: .regular, design: .serif))
                        .foregroundStyle(TossVisualStyle.primaryText.swiftUIColor)
                    Text("Keep your settings with you.")
                        .font(.footnote)
                        .foregroundStyle(TossVisualStyle.secondaryText.swiftUIColor)
                }
            }
            Text("Sign in to keep your settings in sync across devices. Toss remains available without an account.")
                .font(.system(size: 16))
                .foregroundStyle(TossVisualStyle.secondaryText.swiftUIColor)
            appleSignInControl
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.white.opacity(TossVisualStyle.surfaceOpacity + 0.04), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
            AccountPreferenceRow(title: "Sound", icon: "speaker.wave.2", isOn: Binding(
                get: { viewModel.soundEnabled },
                set: { value in Task { await viewModel.setSoundEnabled(value) } }
            ))

            Divider().overlay(.white.opacity(0.12))

            AccountPreferenceRow(title: "Haptics", icon: "circle.dotted", isOn: Binding(
                get: { viewModel.hapticEnabled },
                set: { value in Task { await viewModel.setHapticEnabled(value) } }
            ))
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
