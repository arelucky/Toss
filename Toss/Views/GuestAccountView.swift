import AuthenticationServices
import SwiftUI

struct GuestAccountView: View {
    @ObservedObject var viewModel: AccountViewModel

    var body: some View {
        Form {
            Section {
                Text("Sign in to keep your settings in sync across devices. Toss remains available without an account.")
                    .foregroundStyle(.secondary)
                appleSignInControl
            }
            feedbackSection
            noticeSection
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
        Section("Feedback") {
            Toggle("Sound", isOn: Binding(
                get: { viewModel.soundEnabled },
                set: { value in Task { await viewModel.setSoundEnabled(value) } }
            ))
            Toggle("Haptics", isOn: Binding(
                get: { viewModel.hapticEnabled },
                set: { value in Task { await viewModel.setHapticEnabled(value) } }
            ))
        }
    }

    @ViewBuilder
    private var noticeSection: some View {
        if let notice = viewModel.notice {
            Section {
                Text(notice.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
