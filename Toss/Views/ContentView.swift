//
//  ContentView.swift
//  Toss
//
//  Created by henry on 2026/7/9.
//

import SwiftUI

struct ContentView: View {
    let coinSide: CoinSide
    let coinDisplayMode: CoinDisplayMode
    let coinModelSource: CoinModelSource
    let onOpenCoinLibrary: (() -> Void)?
    let onToss: (TossGestureEvent) -> Void
    @State private var rotationDegrees = 0.0
    @State private var tossOffset: CGFloat = 0
    @State private var coinScale: CGFloat = 1
    @State private var tossMotion: CoinTossMotion?
    @State private var tossMotionTrigger = 0
    @State private var previewRotation: CoinPreviewRotation = .zero
    @State private var previewInertia: CoinPreviewInertia?
    @State private var previewInertiaTrigger = 0
    @State private var dragStartTime: Date?
    @StateObject private var viewModel: CoinTossViewModel

    @MainActor
    init(
        coinSide: CoinSide = .front,
        coinDisplayMode: CoinDisplayMode = .resolved(),
        viewModel: CoinTossViewModel = CoinTossViewModel(),
        coinModelSource: CoinModelSource = .bundledClassic,
        onOpenCoinLibrary: (() -> Void)? = nil,
        onToss: @escaping (TossGestureEvent) -> Void = { _ in }
    ) {
        self.coinSide = coinSide
        self.coinDisplayMode = coinDisplayMode
        self.coinModelSource = coinModelSource
        self.onOpenCoinLibrary = onOpenCoinLibrary
        self.onToss = onToss
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            TossBackground()

            GeometryReader { proxy in
                ZStack {
                    coinInputLayer
                        .offset(y: tossOffset)

                    idleTossAffordance
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(y: -proxy.size.height * 0.06)
            }

            VStack {
                HStack {
                    if let onOpenCoinLibrary {
                        coinLibraryButton(action: onOpenCoinLibrary)
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding(.top, 8)
            .padding(.leading, TossVisualStyle.pageHorizontalInset)
        }
        .onChange(of: viewModel.state) { _, state in
            debugLog("state changed: \(state)")
        }
        .onChange(of: tossOffset) { _, offset in
            debugLog("coin offset changed: \(offset)")
        }
        .onAppear {
            SoundManager.shared.prepare()
            HapticManager.shared.prepare()
        }
    }

    private func coinLibraryButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "circle.grid.2x2.fill")
                .font(.system(size: 18, weight: .medium))
                .frame(width: TossVisualStyle.controlSize, height: TossVisualStyle.controlSize)
                .background(
                    TossVisualStyle.primaryText.swiftUIColor.opacity(TossVisualStyle.surfaceOpacity),
                    in: Circle()
                )
                .overlay {
                    Circle()
                        .stroke(TossVisualStyle.primaryText.swiftUIColor.opacity(0.18), lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
        .foregroundStyle(TossVisualStyle.primaryText.swiftUIColor)
        .accessibilityLabel("Coins")
        .accessibilityHint("Opens the coin library")
    }

    private var coinInputLayer: some View {
        ZStack {
            Color.clear
            CoinDisplayLayer(
                mode: coinDisplayMode,
                coinSide: coinSide,
                rotationDegrees: rotationDegrees,
                tossMotion: tossMotion,
                tossMotionTrigger: tossMotionTrigger,
                previewRotation: previewRotation,
                previewInertia: previewInertia,
                previewInertiaTrigger: previewInertiaTrigger,
                source: displayedCoinModelSource
            )
                .scaleEffect(coinScale)
        }
        .frame(width: 360, height: 430)
        .contentShape(Rectangle())
        .gesture(tossGesture)
    }

    var displayedCoinModelSource: CoinModelSource {
        coinModelSource
    }

    var showsCoinLibraryControl: Bool {
        onOpenCoinLibrary != nil
    }

    var idleTossAffordanceOpacity: Double {
        viewModel.state == .idle && dragStartTime == nil ? 1 : 0
    }

    private var idleTossAffordance: some View {
        VStack(spacing: 6) {
            Image(systemName: "arrow.up")
                .font(.system(size: 13, weight: .medium))
            Text("Swipe up to toss")
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(TossVisualStyle.secondaryText.swiftUIColor)
        .opacity(idleTossAffordanceOpacity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .offset(y: 232)
    }

    private var tossGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                if dragStartTime == nil {
                    dragStartTime = value.time
                    debugLog("drag began")
                }

                viewModel.updateDragTranslation(value.translation)
                updatePreviewRotation(for: value.translation)
                triggerPreviewHapticIfNeeded(
                    translation: value.translation,
                    duration: value.time.timeIntervalSince(dragStartTime ?? value.time)
                )
                debugLog(
                    "drag changed translation=(\(value.translation.width), \(value.translation.height))"
                )
            }
            .onEnded { value in
                let duration = value.time.timeIntervalSince(dragStartTime ?? value.time)
                debugLog(
                    "drag ended translation=(\(value.translation.width), \(value.translation.height)) duration=\(duration)"
                )

                viewModel.endDrag(
                    translation: value.translation,
                    duration: duration,
                    onToss: handleToss
                )
                finishPreviewRotation(
                    translation: value.translation,
                    duration: duration
                )
                dragStartTime = nil
            }
    }

    private func handleToss(_ event: TossGestureEvent) {
        debugLog(
            "toss callback direction=\(event.direction) distance=\(event.distance) speed=\(event.speed)"
        )
        let result = viewModel.lastTossResult ?? .heads
        let motion = CoinTossMotion(event: event, result: result)
        SoundManager.shared.play(.coinThrow)
        SoundManager.shared.play(.coinAirSpin)
        HapticManager.shared.triggerTossStartImpact()
        HapticManager.shared.startTossFlightFeedback(duration: motion.rotationDuration)
        onToss(event)
        previewRotation = .zero
        previewInertia = nil
        playTossMotion(motion)
    }

    private func updatePreviewRotation(for translation: CGSize) {
        guard canPreviewRotation else { return }
        guard !isLikelyTossGesture(translation) else {
            previewRotation = .zero
            return
        }

        previewRotation = CoinPreviewRotation(translation: translation)
    }

    private func triggerPreviewHapticIfNeeded(translation: CGSize, duration: TimeInterval) {
        guard canPreviewRotation else { return }
        guard !isLikelyTossGesture(translation) else { return }

        let event = TossGestureEvent(translation: translation, duration: duration)
        guard event.distance >= 44 else { return }
        HapticManager.shared.triggerPreviewSpinIfNeeded(speed: event.speed)
    }

    private func resetPreviewRotation() {
        guard previewRotation != .zero else { return }

        withAnimation(.easeOut(duration: 0.22)) {
            previewRotation = .zero
        }
    }

    private func finishPreviewRotation(translation: CGSize, duration: TimeInterval) {
        guard canPreviewRotation else {
            resetPreviewRotation()
            return
        }
        guard !isLikelyTossGesture(translation) else {
            resetPreviewRotation()
            return
        }

        previewInertia = CoinPreviewInertia(
            translation: translation,
            duration: duration,
            initialRotation: previewRotation
        )
        previewInertiaTrigger += 1
        previewRotation = .zero
    }

    private var canPreviewRotation: Bool {
        viewModel.state == .idle || viewModel.state == .resultHolding
    }

    private func isLikelyTossGesture(_ translation: CGSize) -> Bool {
        translation.height <= viewModel.tossTriggerThreshold &&
        abs(translation.height) >= abs(translation.width)
    }

    private func playTossMotion(_ motion: CoinTossMotion) {
        debugLog(
            "play motion peakOffset=\(motion.peakOffset) rise=\(motion.riseDuration) fall=\(motion.fallDuration)"
        )
        tossMotion = motion
        tossMotionTrigger += 1

        withAnimation(.easeOut(duration: 0.14)) {
            coinScale = motion.flightScaleRatio
        }

        withAnimation(.easeOut(duration: motion.riseDuration)) {
            tossOffset = motion.peakOffset
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + motion.riseDuration) {
            withAnimation(.spring(response: motion.fallDuration, dampingFraction: 0.86)) {
                tossOffset = motion.settledOffset
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + motion.scaleRecoveryDelay) {
            withAnimation(.easeOut(duration: motion.scaleRecoveryDuration)) {
                coinScale = 1
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + motion.flightDuration) {
            HapticManager.shared.triggerLandingImpact()
            coinScale = 1
            viewModel.completeTossMotion()
        }
    }

    private func debugLog(_ message: String) {
        TossDebugLog.log("ContentView", message)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView(
                coinDisplayMode: .realityKit3D
            )
            ContentView(
                coinSide: .back,
                coinDisplayMode: .swiftUI
            )
        }
    }
}
