import SwiftUI

struct AuthenticatedAccountView: View {
    @ObservedObject var viewModel: AccountViewModel
    let displayName: String
    @State private var confirmsSignOut = false

    var body: some View {
        Form {
            Section("Signed in") {
                Label(displayName, systemImage: "person.crop.circle.fill")
            }
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
            if let notice = viewModel.notice {
                Section {
                    Text(notice.message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                Button("Sign Out", role: .destructive) { confirmsSignOut = true }
                    .disabled(viewModel.isSigningOut)
                if viewModel.isSigningOut {
                    ProgressView("Signing out securely…")
                }
            }
            Section {
                Button("Delete Account", role: .destructive) { viewModel.requestAccountDeletion() }
                    .disabled(viewModel.isDeleting || viewModel.isSigningOut)
                    .accessibilityHint("Permanently deletes your Toss account after Apple reauthentication")
                if viewModel.isDeleting {
                    ProgressView("Deleting account securely…")
                }
            } footer: {
                Text("This permanently deletes your Toss account and synced settings.")
            }
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
}
