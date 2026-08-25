import SwiftUI

struct AuthenticatedAccountView: View {
    @ObservedObject var viewModel: AccountViewModel
    let displayName: String
    @State private var confirmsSignOut = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                AccountSettingsSection("Signed in") {
                Label(displayName, systemImage: "person.crop.circle.fill")
                        .foregroundStyle(TossVisualStyle.primaryText.swiftUIColor)
                }
                feedbackSection
                noticeSection
                signOutSection
                deletionSection
            }
            .padding(.horizontal, TossVisualStyle.pageHorizontalInset)
            .padding(.vertical, 24)
        }
        .confirmationDialog("Sign out of Toss?", isPresented: $confirmsSignOut) {
            Button("Sign Out", role: .destructive) {
                Task { await viewModel.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your guest sound and haptic settings will be restored on this device.")
        }
        .confirmationDialog("Permanently delete your Toss account?", isPresented: $viewModel.isDeleteConfirmationPresented) {
            Button("Delete Account", role: .destructive) {
                Task { await viewModel.confirmAccountDeletion() }
            }
            Button("Cancel", role: .cancel) { viewModel.cancelAccountDeletion() }
        } message: {
            Text("You’ll be asked to reauthenticate with Apple. This action cannot be undone.")
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

    private var signOutSection: some View {
        AccountSettingsSection {
            Button("Sign Out", role: .destructive) { confirmsSignOut = true }
                .disabled(viewModel.isSigningOut)
            if viewModel.isSigningOut {
                ProgressView("Signing out securely…")
                    .tint(TossVisualStyle.selectionGold.swiftUIColor)
            }
        }
    }

    private var deletionSection: some View {
        AccountSettingsSection {
            Button("Delete Account", role: .destructive) { viewModel.requestAccountDeletion() }
                .disabled(viewModel.isDeleting || viewModel.isSigningOut)
                .accessibilityHint("Permanently deletes your Toss account after Apple reauthentication")
            if viewModel.isDeleting {
                ProgressView("Deleting account securely…")
                    .tint(TossVisualStyle.selectionGold.swiftUIColor)
            }
            Text("This permanently deletes your Toss account and synced settings.")
                .font(.footnote)
                .foregroundStyle(TossVisualStyle.secondaryText.swiftUIColor)
        }
    }
}
