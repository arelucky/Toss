import SwiftUI

struct CoinLibraryView: View {
    @ObservedObject var viewModel: CoinLibraryViewModel
    let dismiss: () -> Void
    @State private var previewRotation: CoinPreviewRotation = .zero
    @State private var previewInertia: CoinPreviewInertia?
    @State private var previewInertiaTrigger = 0
    @State private var dragStartTime: Date?
    @State private var isHeroLoaded = false

    private let columns = [
        GridItem(.flexible(), spacing: 36),
        GridItem(.flexible(), spacing: 36)
    ]

    var body: some View {
        ZStack {
            immersiveBackground

            VStack(spacing: 0) {
                navigationHeader
                GeometryReader { proxy in
                    let heroHeight = min(max(proxy.size.height * 0.48, 270), 360)

                    VStack(spacing: 0) {
                        selectedCoinStage(containerHeight: heroHeight)
                            .frame(height: heroHeight)
                        divider
                        libraryGrid
                            .frame(maxHeight: .infinity)
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .preferredColorScheme(.dark)
        .task { await viewModel.refresh() }
        .onChange(of: viewModel.selectedID) { _, _ in
            isHeroLoaded = false
            resetPreview()
        }
        .onDisappear(perform: resetPreview)
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

    private func selectedCoinStage(containerHeight: CGFloat) -> some View {
        selectedCoinPreview(size: min(292, max(250, containerHeight - 28)))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 14)
            .contentShape(Rectangle())
            .gesture(previewGesture)
    }

    @ViewBuilder
    private func selectedCoinPreview(size: CGFloat) -> some View {
        ZStack {
            Coin3DView(
                source: viewModel.selectedModelSource,
                style: .libraryHero,
                previewRotation: previewRotation,
                previewInertia: previewInertia,
                previewInertiaTrigger: previewInertiaTrigger,
                onLoadStateChange: { isHeroLoaded = $0 }
            )
            .frame(width: size, height: size)

            if !isHeroLoaded {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white.opacity(0.78))
            }
        }
    }

    private var previewGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                if dragStartTime == nil {
                    dragStartTime = value.time
                    previewInertia = nil
                }
                previewRotation = CoinPreviewRotation(translation: value.translation)
            }
            .onEnded { value in
                let duration = value.time.timeIntervalSince(dragStartTime ?? value.time)
                previewInertia = CoinPreviewInertia(
                    translation: value.translation,
                    duration: duration,
                    initialRotation: previewRotation
                )
                previewInertiaTrigger += 1
                previewRotation = .zero
                dragStartTime = nil
            }
    }

    private func resetPreview() {
        previewRotation = .zero
        previewInertia = nil
        previewInertiaTrigger += 1
        dragStartTime = nil
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
                            downloadProgress: viewModel.downloadProgress[item.id],
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
    }
}
