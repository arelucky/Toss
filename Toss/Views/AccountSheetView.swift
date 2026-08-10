import SwiftUI

struct AccountSheetView: View {
    @ObservedObject var viewModel: AccountViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.presentation {
                case .guest:
                    GuestAccountView(viewModel: viewModel)
                case .restoring:
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Restoring account…")
                            .foregroundStyle(.secondary)
                    }
                case let .authenticated(displayName):
                    AuthenticatedAccountView(viewModel: viewModel, displayName: displayName)
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
