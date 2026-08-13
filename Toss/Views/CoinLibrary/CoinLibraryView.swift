import SwiftUI

struct CoinLibraryView: View {
    @ObservedObject var viewModel: CoinLibraryViewModel
    let dismiss: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 36),
        GridItem(.flexible(), spacing: 36)
    ]

    var body: some View {
        ZStack {
            immersiveBackground

            VStack(spacing: 0) {
                navigationHeader
                selectedCoinStage
                divider
                libraryGrid
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .preferredColorScheme(.dark)
        .task { await viewModel.refresh() }
        .alert(
            "Download unavailable",
            isPresented: Binding(
                get: { viewModel.notice != nil },
                set: { if !$0 { viewModel.notice = nil } }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.notice = nil }
        } message: {
            Text(viewModel.notice ?? "")
        }
    }

    private var immersiveBackground: some View {
        RadialGradient(
            colors: [
                Color(red: 0.12, green: 0.13, blue: 0.14),
                Color(red: 0.055, green: 0.06, blue: 0.065),
                .black
            ],
            center: UnitPoint(x: 0.5, y: 0.34),
            startRadius: 20,
            endRadius: 520
        )
        .ignoresSafeArea()
    }

    private var navigationHeader: some View {
        ZStack {
            Text("Coin Library")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)

            HStack {
                Button(action: dismiss) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Back")

                Spacer()
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .frame(height: 58)
    }

    private var selectedCoinStage: some View {
        selectedCoinPreview
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minHeight: 360)
            .padding(.bottom, 14)
    }

    @ViewBuilder
    private var selectedCoinPreview: some View {
        if viewModel.selectedID == .classic {
            CoinView()
                .scaleEffect(1.28)
                .frame(width: 292, height: 292)
        } else if let selectedItem = viewModel.items.first(where: { $0.id == viewModel.selectedID }),
                  let previewURL = selectedItem.coin?.version.previewURL {
            AsyncImage(url: previewURL) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                ProgressView().tint(.white)
            }
            .frame(width: 292, height: 292)
            .clipShape(Circle())
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.12))
            .frame(height: 1)
    }

    private var libraryGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 34) {
                ForEach(viewModel.items) { item in
                    Button {
                        Task { await viewModel.select(item.id) }
                    } label: {
                        CoinLibraryCard(
                            item: item,
                            isSelected: viewModel.selectedID == item.id,
                            isCached: viewModel.cachedIDs.contains(item.id),
                            isDownloading: viewModel.downloadingIDs.contains(item.id),
                            isEnabled: viewModel.isEnabled(item.id)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(
                        !viewModel.isEnabled(item.id)
                            || viewModel.downloadingIDs.contains(item.id)
                    )
                }
            }
            .padding(.horizontal, 38)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .frame(maxHeight: 330)
    }
}
