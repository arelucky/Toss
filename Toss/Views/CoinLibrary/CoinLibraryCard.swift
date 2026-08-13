import SwiftUI

enum CoinLibraryPreviewSource: Equatable {
    case bundledClassic
    case remote(URL)

    init(item: CoinLibraryItem) {
        if item.id == .classic {
            self = .bundledClassic
        } else if let previewURL = item.coin?.version.previewURL {
            self = .remote(previewURL)
        } else {
            self = .bundledClassic
        }
    }
}

struct CoinLibraryCard: View {
    let item: CoinLibraryItem
    let isSelected: Bool
    let isCached: Bool
    let isDownloading: Bool
    let isEnabled: Bool

    private let previewSize: CGFloat = 126
    private let selectionGold = Color(red: 0.94, green: 0.70, blue: 0.35)

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                if isSelected {
                    Circle()
                        .stroke(selectionGold, lineWidth: 1.5)
                        .frame(width: previewSize + 16, height: previewSize + 16)
                }

                coinPreview
                    .frame(width: previewSize, height: previewSize)

                statusOverlay
            }

            HStack(spacing: 6) {
                Text(item.name)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selectionGold)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .opacity(isEnabled ? 1 : 0.42)
    }

    @ViewBuilder
    private var coinPreview: some View {
        switch CoinLibraryPreviewSource(item: item) {
        case .bundledClassic:
            Image("ClassicCoinPreview")
                .resizable()
                .scaledToFit()
        case let .remote(previewURL):
            AsyncImage(url: previewURL) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Circle()
                    .fill(.white.opacity(0.06))
                    .overlay { ProgressView().tint(.white.opacity(0.8)) }
            }
            .clipShape(Circle())
        }
    }

    @ViewBuilder
    private var statusOverlay: some View {
        if isDownloading {
            Circle()
                .fill(.black.opacity(0.48))
                .frame(width: 44, height: 44)
                .overlay { ProgressView().tint(.white) }
        } else if !isCached {
            Circle()
                .fill(.black.opacity(0.62))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(isEnabled ? 0.94 : 0.58))
                }
                .offset(x: 43, y: 43)
        }
    }
}
