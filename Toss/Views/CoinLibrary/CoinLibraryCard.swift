import CoreGraphics
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
    let downloadProgress: CoinFileDownloadProgress?
    let isEnabled: Bool

    private let previewSize: CGFloat = 126

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                if isSelected {
                    Circle()
                        .stroke(TossVisualStyle.selectionGold.swiftUIColor, lineWidth: 1.5)
                        .frame(width: previewSize + 16, height: previewSize + 16)
                }

                coinPreview
                    .frame(width: previewSize, height: previewSize)
                    .clipShape(Circle())

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
                        .foregroundStyle(TossVisualStyle.selectionGold.swiftUIColor)
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
            CoinRemotePreviewImage(url: previewURL)
        }
    }

    @ViewBuilder
    private var statusOverlay: some View {
        if isDownloading {
            Circle()
                .fill(.black.opacity(0.58))
                .frame(width: 86, height: 86)
                .overlay {
                    VStack(spacing: 5) {
                        ProgressView().tint(.white)
                        Text(downloadProgressText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(6)
                }
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

    private var downloadProgressText: String {
        switch downloadProgress {
        case .connecting, nil:
            "正在连接…"
        case let .downloading(percent):
            "正在下载 \(percent)%"
        case .verifying:
            "正在验证模型…"
        }
    }
}

@MainActor
struct CoinRemotePreviewImage: View {
    let url: URL

    @State private var loadedImage: CGImage?

    var body: some View {
        Group {
            if let image = loadedImage ?? CoinPreviewImageCache.shared.image(for: url) {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFit()
            } else {
                Circle()
                    .fill(.white.opacity(0.06))
                    .overlay { ProgressView().tint(.white.opacity(0.8)) }
                    .task(id: url) {
                        loadedImage = await CoinPreviewImageCache.shared.loadImage(for: url)
                    }
            }
        }
    }
}
