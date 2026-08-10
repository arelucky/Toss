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
        }
        .confirmationDialog("Sign out of Toss?", isPresented: $confirmsSignOut) {
            Button("Sign Out", role: .destructive) {
                Task { await viewModel.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your guest sound and haptic settings will be restored on this device.")
        }
    }
}
