import SwiftUI
import RealityKit
import UIKit

enum CoinModelSource: Equatable, Sendable {
    case bundledClassic
    case downloaded(URL)
}

@MainActor
struct CoinLoadStateNotifier {
    let callback: ((Bool) -> Void)?

    func notifyLoaded(
        _ source: CoinModelSource,
        currentSource: @escaping @MainActor () -> CoinModelSource?
    ) {
        let loadStateCallback = callback
        Task { @MainActor in
            guard currentSource() == source else { return }
            loadStateCallback?(true)
        }
    }
}

struct Coin3DView: View {
    let source: CoinModelSource
    let style: Coin3DViewStyle
    let tossMotion: CoinTossMotion?
    let tossMotionTrigger: Int
    let previewRotation: CoinPreviewRotation
    let previewInertia: CoinPreviewInertia?
    let previewInertiaTrigger: Int
    let onLoadStateChange: ((Bool) -> Void)?

    init(
        source: CoinModelSource = .bundledClassic,
        style: Coin3DViewStyle = .home,
        tossMotion: CoinTossMotion? = nil,
        tossMotionTrigger: Int = 0,
        previewRotation: CoinPreviewRotation = .zero,
        previewInertia: CoinPreviewInertia? = nil,
        previewInertiaTrigger: Int = 0,
        onLoadStateChange: ((Bool) -> Void)? = nil
    ) {
        self.source = source
        self.style = style
        self.tossMotion = tossMotion
        self.tossMotionTrigger = tossMotionTrigger
        self.previewRotation = previewRotation
        self.previewInertia = previewInertia
        self.previewInertiaTrigger = previewInertiaTrigger
        self.onLoadStateChange = onLoadStateChange
    }

    var body: some View {
        CoinRealityView(
            source: source,
            style: style,
            tossMotion: tossMotion,
            tossMotionTrigger: tossMotionTrigger,
            previewRotation: previewRotation,
            previewInertia: previewInertia,
            previewInertiaTrigger: previewInertiaTrigger,
            onLoadStateChange: onLoadStateChange
        )
            .allowsHitTesting(false)
            .onAppear {
                debugLog("appeared")
            }
    }

    private func debugLog(_ message: String) {
        TossDebugLog.log("Coin3DView", message)
    }
}

struct Coin3DViewStyle {
    let targetSize: Float
    let faceTilt: Float
    let edgeReveal: Float
    let autoRotates: Bool
    let rotationStep: Float
    let materialStyle: Coin3DMaterialStyle

    static let home = Coin3DViewStyle(
        targetSize: 0.90,
        faceTilt: -.pi / 18,
        edgeReveal: -.pi / 32,
        autoRotates: false,
        rotationStep: .pi / 3600,
        materialStyle: .champagneGold
    )

    static let libraryHero = Coin3DViewStyle(
        targetSize: 1.62,
        faceTilt: -.pi / 18,
        edgeReveal: -.pi / 32,
        autoRotates: false,
        rotationStep: .pi / 3600,
        materialStyle: .champagneGold
    )
}

struct Coin3DMaterialStyle: Equatable {
    let baseColor: SIMD4<Float>
    let metallic: Float
    let roughness: Float

    static let champagneGold = Coin3DMaterialStyle(
        baseColor: SIMD4<Float>(0.93, 0.76, 0.46, 1),
        metallic: 1,
        roughness: 0.28
    )

    func makeRealityKitMaterial() -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: UIColor(
            red: CGFloat(baseColor.x),
            green: CGFloat(baseColor.y),
            blue: CGFloat(baseColor.z),
            alpha: CGFloat(baseColor.w)
        ))
        material.metallic = .init(floatLiteral: metallic)
        material.roughness = .init(floatLiteral: roughness)
        return material
    }
}

@MainActor
private struct CoinRealityView: UIViewRepresentable {
    let source: CoinModelSource
    let style: Coin3DViewStyle
    let tossMotion: CoinTossMotion?
    let tossMotionTrigger: Int
    let previewRotation: CoinPreviewRotation
    let previewInertia: CoinPreviewInertia?
    let previewInertiaTrigger: Int
    let onLoadStateChange: ((Bool) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.backgroundColor = .clear
        view.environment.background = .color(.clear)
        view.renderOptions.insert(.disableMotionBlur)

        let sceneAnchor = AnchorEntity(world: .zero)
        view.scene.addAnchor(sceneAnchor)
        context.coordinator.setAnchor(sceneAnchor)

        addLighting(to: sceneAnchor)
        addCamera(to: sceneAnchor)
        loadCoin(source: source, into: sceneAnchor, coordinator: context.coordinator)

        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        if context.coordinator.source != source {
            loadCoin(source: source, into: context.coordinator.anchor, coordinator: context.coordinator)
        }
        context.coordinator.applyPreviewRotation(previewRotation)
        if let previewInertia {
            context.coordinator.playPreviewInertia(
                previewInertia,
                trigger: previewInertiaTrigger
            )
        }

        if let tossMotion {
            context.coordinator.playTossRotation(
                motion: tossMotion,
                trigger: tossMotionTrigger
            )
        }
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        coordinator.stopRotation()
    }

    private func loadCoin(source: CoinModelSource, into anchor: AnchorEntity?, coordinator: Coordinator) {
        guard let anchor, let modelURL = modelURL(for: source) else { return }

        do {
            let coin = try Entity.load(contentsOf: modelURL)
            prepareCoin(coin)
            applyMaterialOverride(to: coin)
            coordinator.prepareToReplaceCoin()
            anchor.addChild(coin)
            coordinator.setCoin(coin, source: source)
            CoinLoadStateNotifier(callback: onLoadStateChange).notifyLoaded(
                source,
                currentSource: { [weak coordinator] in
                    guard coordinator?.isDisplaying(source) == true else { return nil }
                    return source
                }
            )
            if style.autoRotates {
                coordinator.startRotation(for: coin, step: style.rotationStep)
            }
        } catch {
            assertionFailure("Failed to load TossCoin.usdz: \(error.localizedDescription)")
        }
    }

    private func modelURL(for source: CoinModelSource) -> URL? {
        switch source {
        case .bundledClassic:
            return Bundle.main.url(
                forResource: "TossCoin",
                withExtension: "usdz",
                subdirectory: "Models"
            )
        case let .downloaded(url):
            return url.isFileURL ? url : nil
        }
    }

    private func prepareCoin(_ coin: Entity) {
        let bounds = coin.visualBounds(relativeTo: nil)
        let extents = bounds.extents
        let largestDimension = max(extents.x, extents.y, extents.z)
        let scale = largestDimension > 0 ? style.targetSize / largestDimension : 1

        coin.scale = SIMD3<Float>(repeating: scale)
        coin.position = -bounds.center * scale

        let faceTilt = simd_quatf(angle: style.faceTilt, axis: SIMD3<Float>(1, 0, 0))
        let edgeReveal = simd_quatf(angle: style.edgeReveal, axis: SIMD3<Float>(0, 1, 0))
        coin.orientation = edgeReveal * faceTilt
    }

    private func applyMaterialOverride(to entity: Entity) {
        if let modelEntity = entity as? ModelEntity,
           let model = modelEntity.model {
            let material = style.materialStyle.makeRealityKitMaterial()
            modelEntity.model?.materials = Array(
                repeating: material,
                count: max(model.materials.count, 1)
            )
        }

        for child in entity.children {
            applyMaterialOverride(to: child)
        }
    }

    private func addLighting(to anchor: AnchorEntity) {
        let keyLight = DirectionalLight()
        keyLight.light.intensity = 4700
        keyLight.light.color = .init(red: 1.0, green: 0.91, blue: 0.72, alpha: 1)
        keyLight.look(at: .zero, from: SIMD3<Float>(-0.65, 1.15, 1.45), relativeTo: nil)

        let fillLight = PointLight()
        fillLight.light.intensity = 960
        fillLight.light.color = .init(red: 0.88, green: 0.92, blue: 1.0, alpha: 1)
        fillLight.position = SIMD3<Float>(0.85, 0.38, 1.15)

        let rimLight = DirectionalLight()
        rimLight.light.intensity = 1280
        rimLight.light.color = .init(red: 1.0, green: 0.82, blue: 0.58, alpha: 1)
        rimLight.look(at: .zero, from: SIMD3<Float>(0.95, 0.58, -0.7), relativeTo: nil)

        anchor.addChild(keyLight)
        anchor.addChild(fillLight)
        anchor.addChild(rimLight)
    }

    private func addCamera(to anchor: AnchorEntity) {
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 42
        camera.look(at: .zero, from: SIMD3<Float>(0, 0, 3.0), relativeTo: nil)
        anchor.addChild(camera)
    }

    @MainActor
    final class Coordinator {
        init() {}
        private(set) weak var anchor: AnchorEntity?
        private(set) var source: CoinModelSource?
        private weak var coin: Entity?
        private var timer: Timer?
        private var rotationStep: Float = 0
        private var baseTransform = Transform()
        private var restingXRotationAngle: Double = 0
        private var settledPreviewRotation: CoinPreviewRotation = .zero
        private var previewRotation: CoinPreviewRotation = .zero
        private var isPreviewDragging = false
        private var previewInertiaRotation: CoinPreviewRotation = .zero
        private var previewInertia: CoinPreviewInertia?
        private var previewInertiaStartDate: Date?
        private var previewInertiaTimer: Timer?
        private var activePreviewInertiaTrigger = 0
        private var activeTossTrigger = 0
        private var tossRotationStartDate: Date?
        private var tossRotationMotion: CoinTossMotion?

        func setAnchor(_ anchor: AnchorEntity) {
            self.anchor = anchor
        }

        func prepareToReplaceCoin() {
            stopRotation()
            coin?.removeFromParent()
            coin = nil
            source = nil
        }

        func setCoin(_ coin: Entity, source: CoinModelSource) {
            self.coin = coin
            self.source = source
            baseTransform = coin.transform
            applyDisplayRotation()
        }

        func isDisplaying(_ source: CoinModelSource) -> Bool {
            self.source == source
        }

        func startRotation(for coin: Entity, step: Float) {
            self.coin = coin
            baseTransform = coin.transform
            applyDisplayRotation()
            rotationStep = step
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                self?.rotateCoin()
            }
        }

        func playTossRotation(motion: CoinTossMotion, trigger: Int) {
            guard trigger != activeTossTrigger else { return }
            guard let coin else { return }

            activeTossTrigger = trigger
            tossRotationStartDate = Date()
            tossRotationMotion = motion
            timer?.invalidate()
            stopPreviewInertia(holdsFinalRotation: false)
            settledPreviewRotation = .zero
            previewRotation = .zero
            isPreviewDragging = false
            restingXRotationAngle = 0
            coin.transform = baseTransform
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                self?.rotateTossCoin()
            }
            TossDebugLog.log(
                "Coin3DView",
                "play RealityKit rotation result=\(motion.result) turns=\(motion.rotationTurns) duration=\(motion.rotationDuration)"
            )
        }

        func stopRotation() {
            timer?.invalidate()
            timer = nil
            tossRotationStartDate = nil
            tossRotationMotion = nil
            stopPreviewInertia(holdsFinalRotation: true)
        }

        func applyPreviewRotation(_ rotation: CoinPreviewRotation) {
            guard tossRotationMotion == nil else { return }
            guard previewRotation != rotation else { return }

            if rotation != .zero {
                if !isPreviewDragging {
                    stopPreviewInertia(holdsFinalRotation: true)
                    isPreviewDragging = true
                }
            } else {
                isPreviewDragging = false
            }
            previewRotation = rotation
            applyDisplayRotation()
        }

        func playPreviewInertia(_ inertia: CoinPreviewInertia, trigger: Int) {
            guard tossRotationMotion == nil else { return }
            guard trigger != activePreviewInertiaTrigger else { return }

            activePreviewInertiaTrigger = trigger
            previewInertiaTimer?.invalidate()
            isPreviewDragging = false
            previewRotation = inertia.initialRotation
            previewInertiaRotation = .zero
            previewInertia = inertia
            previewInertiaStartDate = Date()
            previewInertiaTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                self?.rotatePreviewInertia()
            }
        }

        private func rotateCoin() {
            let rotation = simd_quatf(angle: rotationStep, axis: SIMD3<Float>(0, 1, 0))
            coin?.orientation = rotation * (coin?.orientation ?? simd_quatf())
        }

        private func applyDisplayRotation() {
            guard let coin else { return }

            let restingRotation = simd_quatf(
                angle: Float(restingXRotationAngle),
                axis: SIMD3<Float>(1, 0, 0)
            )
            let previewXRotation = simd_quatf(
                angle: Float(previewRotation.xAngle),
                axis: SIMD3<Float>(1, 0, 0)
            )
            let previewYRotation = simd_quatf(
                angle: Float(previewRotation.yAngle),
                axis: SIMD3<Float>(0, 1, 0)
            )
            let inertiaXRotation = simd_quatf(
                angle: Float(previewInertiaRotation.xAngle),
                axis: SIMD3<Float>(1, 0, 0)
            )
            let inertiaYRotation = simd_quatf(
                angle: Float(previewInertiaRotation.yAngle),
                axis: SIMD3<Float>(0, 1, 0)
            )
            let settledXRotation = simd_quatf(
                angle: Float(settledPreviewRotation.xAngle),
                axis: SIMD3<Float>(1, 0, 0)
            )
            let settledYRotation = simd_quatf(
                angle: Float(settledPreviewRotation.yAngle),
                axis: SIMD3<Float>(0, 1, 0)
            )

            var transform = baseTransform
            transform.rotation = baseTransform.rotation *
                restingRotation *
                settledYRotation *
                settledXRotation *
                previewYRotation *
                previewXRotation *
                inertiaYRotation *
                inertiaXRotation
            coin.transform = transform
        }

        private func rotatePreviewInertia() {
            guard let previewInertia, let previewInertiaStartDate else { return }

            let elapsed = Date().timeIntervalSince(previewInertiaStartDate)
            let progress = elapsed / previewInertia.duration
            previewInertiaRotation = previewInertia.rotation(at: progress)
            applyDisplayRotation()

            if progress >= 1 {
                stopPreviewInertia(holdsFinalRotation: true)
            }
        }

        private func stopPreviewInertia(holdsFinalRotation: Bool) {
            if holdsFinalRotation {
                settledPreviewRotation = CoinPreviewRotation(
                    xAngle: normalizedAngle(
                        settledPreviewRotation.xAngle +
                        previewRotation.xAngle +
                        previewInertiaRotation.xAngle
                    ),
                    yAngle: normalizedAngle(
                        settledPreviewRotation.yAngle +
                        previewRotation.yAngle +
                        previewInertiaRotation.yAngle
                    )
                )
            }

            previewInertiaTimer?.invalidate()
            previewInertiaTimer = nil
            previewInertiaStartDate = nil
            previewInertia = nil
            isPreviewDragging = false
            previewRotation = .zero
            previewInertiaRotation = .zero
            applyDisplayRotation()
        }

        private func normalizedAngle(_ angle: Double) -> Double {
            let fullTurn = Double.pi * 2
            var normalized = angle.truncatingRemainder(dividingBy: fullTurn)
            if normalized < 0 {
                normalized += fullTurn
            }
            return normalized
        }

        private func rotateTossCoin() {
            guard let coin, let tossRotationStartDate, let tossRotationMotion else { return }

            let elapsed = Date().timeIntervalSince(tossRotationStartDate)
            let progress = elapsed / tossRotationMotion.rotationDuration
            let angle: Float
            if progress >= 1 {
                angle = Float(tossRotationMotion.normalizedFinalRotationAngle)
            } else {
                angle = Float(tossRotationMotion.rotationAngle(at: progress))
            }
            let rotation = simd_quatf(angle: angle, axis: SIMD3<Float>(1, 0, 0))
            var transform = baseTransform
            transform.rotation = baseTransform.rotation * rotation
            coin.transform = transform

            if progress >= 1 {
                restingXRotationAngle = tossRotationMotion.normalizedFinalRotationAngle
                previewRotation = .zero
                applyDisplayRotation()
                stopRotation()
            }
        }
    }
}

struct Coin3DView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color(red: 0.02, green: 0.02, blue: 0.03)
                .ignoresSafeArea()
            Coin3DView()
                .frame(width: 360, height: 430)
        }
    }
}
