import SwiftUI

enum CoinDisplayMode: Equatable {
    case realityKit3D
    case swiftUI

    static let current: CoinDisplayMode = .realityKit3D

    static func resolved(arguments: [String] = ProcessInfo.processInfo.arguments) -> CoinDisplayMode {
        #if DEBUG
        if arguments.contains("-showSwiftUICoin") {
            return .swiftUI
        }

        if arguments.contains("-showCoin3D") {
            return .realityKit3D
        }
        #endif

        return current
    }
}

struct CoinDisplayLayer: View {
    let mode: CoinDisplayMode
    let coinSide: CoinSide
    let rotationDegrees: Double
    let tossMotion: CoinTossMotion?
    let tossMotionTrigger: Int
    let previewRotation: CoinPreviewRotation
    let previewInertia: CoinPreviewInertia?
    let previewInertiaTrigger: Int
    let source: CoinModelSource

    init(
        mode: CoinDisplayMode = .resolved(),
        coinSide: CoinSide = .front,
        rotationDegrees: Double = 0,
        tossMotion: CoinTossMotion? = nil,
        tossMotionTrigger: Int = 0,
        previewRotation: CoinPreviewRotation = .zero,
        previewInertia: CoinPreviewInertia? = nil,
        previewInertiaTrigger: Int = 0,
        source: CoinModelSource = .bundledClassic
    ) {
        self.mode = mode
        self.coinSide = coinSide
        self.rotationDegrees = rotationDegrees
        self.tossMotion = tossMotion
        self.tossMotionTrigger = tossMotionTrigger
        self.previewRotation = previewRotation
        self.previewInertia = previewInertia
        self.previewInertiaTrigger = previewInertiaTrigger
        self.source = source
    }

    var body: some View {
        switch mode {
        case .realityKit3D:
            Coin3DView(
                source: source,
                style: .home,
                tossMotion: tossMotion,
                tossMotionTrigger: tossMotionTrigger,
                previewRotation: previewRotation,
                previewInertia: previewInertia,
                previewInertiaTrigger: previewInertiaTrigger
            )
                .frame(width: 360, height: 430)
                .accessibilityLabel("Toss 3D coin")
        case .swiftUI:
            CoinView(side: coinSide, rotationDegrees: rotationDegrees)
        }
    }
}

struct CoinDisplayLayer_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Group {
                CoinDisplayLayer(mode: .realityKit3D)
                CoinDisplayLayer(mode: .swiftUI)
            }
        }
    }
}
