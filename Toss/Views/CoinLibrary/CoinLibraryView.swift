import SwiftUI

struct CoinLibraryView: View {
    @ObservedObject var viewModel: CoinLibraryViewModel
    let dismiss: () -> Void
    @State private var previewRotation: CoinPreviewRotation = .zero
    @State private var previewInertia: CoinPreviewInertia?
    @State private var previewInertiaTrigger = 0
    @State private var dragStartTime: Date?
    @State private var heroPresentationState: CoinLibraryHeroPresentationState = .loading

    private let applyButtonHeight: CGFloat = 52
    private let bottomActionHeight: CGFloat = 88

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
                    let heroHeight = min(max(proxy.size.height * 0.38, 220), 272)

                    VStack(spacing: 0) {
                        selectedCoinStage(containerHeight: heroHeight)
                            .frame(height: heroHeight)
                        divider
                        libraryGrid
                            .frame(maxHeight: .infinity)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                }
                bottomActionBar
            }
        }
        .preferredColorScheme(.dark)
        .task { await viewModel.refresh() }
        .onChange(of: viewModel.preselectedID) { _, _ in
            heroPresentationState = .loading
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
        VStack(spacing: 5) {
            ZStack {
                Button(action: dismiss) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(TossVisualStyle.primaryText.swiftUIColor)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.055), in: Circle())
                }
                .accessibilityLabel("Back")
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("Coin Library")
                    .font(.system(size: 26, weight: .regular, design: .serif))
                    .foregroundStyle(TossVisualStyle.primaryText.swiftUIColor)
            }
            Text("Choose your coin.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(TossVisualStyle.secondaryText.swiftUIColor)
        }
        .padding(.horizontal, TossVisualStyle.pageHorizontalInset)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    private func selectedCoinStage(containerHeight: CGFloat) -> some View {
        selectedCoinPreview(size: min(226, max(190, containerHeight - 32)))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 14)
            .contentShape(Rectangle())
            .gesture(previewGesture)
    }

    @ViewBuilder
    private func selectedCoinPreview(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(TossVisualStyle.selectionGold.swiftUIColor.opacity(0.88), lineWidth: 1.25)
                .frame(width: size + 20, height: size + 20)

            Coin3DView(
                source: viewModel.preselectedModelSource,
                style: .libraryHero,
                previewRotation: previewRotation,
                previewInertia: previewInertia,
                previewInertiaTrigger: previewInertiaTrigger,
                onPresentationStateChange: { heroPresentationState = $0 }
            )
            .frame(width: size, height: size)
            .opacity(heroPresentationState == .displayed ? 1 : 0)
            .animation(.easeIn(duration: 0.2), value: heroPresentationState)

            if heroPresentationState.showsLoadingIndicator {
                ProgressView()
                    .controlSize(.regular)
                    .tint(TossVisualStyle.selectionGold.swiftUIColor)
            } else if heroPresentationState.showsUnavailableStatus {
                Text("Preview unavailable")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(TossVisualStyle.secondaryText.swiftUIColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.black.opacity(0.54), in: Capsule())
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
            LazyVGrid(columns: columns, spacing: 28) {
                ForEach(viewModel.items) { item in
                    Button {
                        Task { await viewModel.preselect(item.id) }
                    } label: {
                        CoinLibraryCard(
                            item: item,
                            isSelected: viewModel.preselectedID == item.id,
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
            .padding(.horizontal, 34)
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
    }

    private var bottomActionBar: some View {
        applyPreselectionButton
            .frame(height: bottomActionHeight)
            .background(TossVisualStyle.charcoalBottom.swiftUIColor.opacity(0.98))
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(.white.opacity(0.10))
                    .frame(height: 1)
            }
    }

    private var applyPreselectionButton: some View {
        let isEnabled = viewModel.canApplyPreselection

        return Button {
            Task {
                await viewModel.applyPreselection()
                dismiss()
            }
        } label: {
            Text("Use This Coin")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(
                    TossVisualStyle.selectionGold.swiftUIColor.opacity(isEnabled ? 1 : 0.58)
                )
                .frame(maxWidth: .infinity)
                .frame(height: applyButtonHeight)
                .background(.black.opacity(isEnabled ? 0.44 : 0.30), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(
                            TossVisualStyle.selectionGold.swiftUIColor.opacity(isEnabled ? 0.82 : 0.42),
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .padding(.horizontal, 24)
        .accessibilityLabel("Use This Coin")
    }
}
