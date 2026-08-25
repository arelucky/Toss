import SwiftUI

struct AuthenticatedAccountView: View {
    @ObservedObject var viewModel: AccountViewModel
    let displayName: String
    @State private var confirmsSignOut = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                identitySection
                feedbackSection
                noticeSection
                dangerSection
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

    private var identitySection: some View {
        HStack(spacing: 16) {
            Text(String(displayName.prefix(1)).uppercased())
                .font(.system(size: 25, weight: .medium, design: .serif))
                .foregroundStyle(TossVisualStyle.selectionGold.swiftUIColor)
                .frame(width: 62, height: 62)
                .background(.white.opacity(0.06), in: Circle())
                .overlay { Circle().stroke(TossVisualStyle.selectionGold.swiftUIColor.opacity(0.55), lineWidth: 1) }
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .foregroundStyle(TossVisualStyle.primaryText.swiftUIColor)
                Text("Toss Account")
                    .font(.footnote)
                    .foregroundStyle(TossVisualStyle.secondaryText.swiftUIColor)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.white.opacity(TossVisualStyle.surfaceOpacity + 0.04), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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

    private var dangerSection: some View {
        AccountSettingsSection("Danger Zone") {
            Button("Sign Out", role: .destructive) { confirmsSignOut = true }
                .disabled(viewModel.isSigningOut)
            if viewModel.isSigningOut {
                ProgressView("Signing out securely…")
                    .tint(TossVisualStyle.selectionGold.swiftUIColor)
            }

            Divider().overlay(.white.opacity(0.12))

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
