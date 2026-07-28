import SwiftUI
import RealityKit

struct Coin3DView: View {
    var body: some View {
        CoinRealityView()
            .background(Color(red: 0.02, green: 0.02, blue: 0.03))
            .ignoresSafeArea()
    }
}

private struct CoinRealityView: UIViewRepresentable {
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

        addLighting(to: sceneAnchor)
        addCamera(to: sceneAnchor)
        loadCoin(into: sceneAnchor, coordinator: context.coordinator)

        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        coordinator.stopRotation()
    }

    private func loadCoin(into anchor: AnchorEntity, coordinator: Coordinator) {
        guard let modelURL = Bundle.main.url(
            forResource: "TossCoin",
            withExtension: "usdz",
            subdirectory: "Models"
        ) else {
            return
        }

        do {
            let coin = try Entity.load(contentsOf: modelURL)
            prepareCoin(coin)
            anchor.addChild(coin)
            coordinator.startRotation(for: coin)
        } catch {
            assertionFailure("Failed to load TossCoin.usdz: \(error.localizedDescription)")
        }
    }

    private func prepareCoin(_ coin: Entity) {
        let bounds = coin.visualBounds(relativeTo: nil)
        let extents = bounds.extents
        let largestDimension = max(extents.x, extents.y, extents.z)
        let targetSize: Float = 0.515
        let scale = largestDimension > 0 ? targetSize / largestDimension : 1

        coin.scale = SIMD3<Float>(repeating: scale)
        coin.position = -bounds.center * scale

        let faceTilt = simd_quatf(angle: -.pi / 18, axis: SIMD3<Float>(1, 0, 0))
        let edgeReveal = simd_quatf(angle: -.pi / 32, axis: SIMD3<Float>(0, 1, 0))
        coin.orientation = edgeReveal * faceTilt
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

    final class Coordinator {
        private weak var coin: Entity?
        private var timer: Timer?

        func startRotation(for coin: Entity) {
            self.coin = coin
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                self?.rotateCoin()
            }
        }

        func stopRotation() {
            timer?.invalidate()
            timer = nil
        }

        private func rotateCoin() {
            let rotation = simd_quatf(angle: .pi / 3600, axis: SIMD3<Float>(0, 1, 0))
            coin?.orientation = rotation * (coin?.orientation ?? simd_quatf())
        }
    }
}

struct Coin3DView_Previews: PreviewProvider {
    static var previews: some View {
        Coin3DView()
    }
}
