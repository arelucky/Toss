import SwiftUI

struct CoinView: View {
    let side: CoinSide
    let theme: CoinTheme
    let rotationDegrees: Double

    init(side: CoinSide = .front, theme: CoinTheme = .defaultGold, rotationDegrees: Double = 0) {
        self.side = side
        self.theme = theme
        self.rotationDegrees = rotationDegrees
    }

    var body: some View {
        ZStack {
            CoinShadow(theme: theme)
            CoinBack(theme: theme)
                .frame(width: theme.defaultSize, height: theme.defaultSize)
                .rotation3DEffect(
                    .degrees(effectiveRotationDegrees + 180),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: 0.86
                )
                .zIndex(backFaceDepth)
            CoinThickness(theme: theme)
                .zIndex(edgeDepth)
            CoinFront(theme: theme)
                .frame(width: theme.defaultSize, height: theme.defaultSize)
                .rotation3DEffect(
                    .degrees(effectiveRotationDegrees),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: 0.86
                )
                .zIndex(frontFaceDepth)
        }
        .frame(width: theme.defaultSize, height: theme.defaultSize)
        .frame(width: theme.defaultSize, height: theme.defaultSize * 1.18)
        .accessibilityLabel(side == .front ? "Toss coin front" : "Toss coin back")
    }

    private var effectiveRotationDegrees: Double {
        rotationDegrees + side.restingRotationDegrees
    }

    private var frontFaceDepth: Double {
        cos(rotationRadians)
    }

    private var backFaceDepth: Double {
        -cos(rotationRadians)
    }

    private var edgeDepth: Double {
        abs(sin(rotationRadians)) + 0.2
    }

    private var rotationRadians: Double {
        effectiveRotationDegrees * .pi / 180
    }
}

private extension CoinSide {
    var restingRotationDegrees: Double {
        switch self {
        case .front:
            0
        case .back:
            180
        }
    }
}

private struct CoinThickness: View {
    let theme: CoinTheme

    var body: some View {
        VStack(spacing: 0) {
            edgeHighlightStrip
            edgeCore
            edgeShadeStrip
        }
        .frame(width: theme.defaultSize * 0.98, height: edgeHeight)
        .clipShape(Capsule())
        .overlay(edgeRim)
        .shadow(color: theme.shadowGold.opacity(0.26), radius: 3, x: 0, y: 1)
        .allowsHitTesting(false)
    }

    private var edgeHeight: CGFloat {
        theme.defaultSize * 0.16
    }

    private var edgeHighlightStrip: some View {
        Rectangle()
            .fill(theme.paleGold.opacity(0.76))
            .frame(height: edgeHeight * 0.22)
    }

    private var edgeCore: some View {
        Rectangle()
            .fill(edgeGradient)
    }

    private var edgeShadeStrip: some View {
        Rectangle()
            .fill(theme.deepGold.opacity(0.74))
            .frame(height: edgeHeight * 0.26)
    }

    private var edgeGradient: LinearGradient {
        LinearGradient(
            colors: [
                theme.deepGold.opacity(0.88),
                theme.highlightGold.opacity(0.80),
                theme.warmGold,
                theme.baseGold,
                theme.deepGold.opacity(0.92)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var edgeRim: some View {
        Capsule()
            .strokeBorder(
                LinearGradient(
                    colors: [
                        theme.coolReflection.opacity(0.28),
                        theme.highlightGold.opacity(0.42),
                        theme.shadowGold.opacity(0.38)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1.2
            )
    }
}

struct CoinRings: View {
    let theme: CoinTheme

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(outerRingGradient, lineWidth: theme.outerRingLineWidth)
                .padding(theme.outerRingLineWidth * 0.55)

            Circle()
                .strokeBorder(theme.highlightGold.opacity(0.42), lineWidth: theme.innerRingLineWidth)
                .padding(theme.defaultSize * 0.13)

            Circle()
                .strokeBorder(theme.shadowGold.opacity(0.24), lineWidth: 1)
                .padding(theme.defaultSize * 0.17)
        }
    }

    private var outerRingGradient: LinearGradient {
        LinearGradient(
            colors: [
                theme.highlightGold.opacity(0.70),
                theme.warmGold.opacity(0.84),
                theme.deepGold.opacity(0.70)
            ],
            startPoint: UnitPoint(x: 0.72, y: 0.08),
            endPoint: UnitPoint(x: 0.16, y: 0.92)
        )
    }
}

struct TossMonogramMark: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let barHeight = height * 0.24
        let shoulderInset = width * 0.05
        let shoulderDrop = barHeight * 0.26
        let chamfer = min(width, height) * 0.07
        let stemTopWidth = width * 0.42
        let stemBottomWidth = width * 0.32

        var path = Path()
        path.move(to: CGPoint(x: shoulderInset + chamfer, y: 0))
        path.addLine(to: CGPoint(x: width - shoulderInset - chamfer, y: 0))
        path.addLine(to: CGPoint(x: width - shoulderInset, y: chamfer))
        path.addLine(to: CGPoint(x: width - shoulderInset - chamfer * 0.55, y: barHeight - shoulderDrop))
        path.addLine(to: CGPoint(x: width * 0.5 + stemTopWidth * 0.5, y: barHeight))
        path.addLine(to: CGPoint(x: width * 0.5 + stemBottomWidth * 0.5, y: height - chamfer))
        path.addLine(to: CGPoint(x: width * 0.5 + stemBottomWidth * 0.5 - chamfer * 0.55, y: height))
        path.addLine(to: CGPoint(x: width * 0.5 - stemBottomWidth * 0.5 + chamfer * 0.55, y: height))
        path.addLine(to: CGPoint(x: width * 0.5 - stemBottomWidth * 0.5, y: height - chamfer))
        path.addLine(to: CGPoint(x: width * 0.5 - stemTopWidth * 0.5, y: barHeight))
        path.addLine(to: CGPoint(x: shoulderInset + chamfer * 0.55, y: barHeight - shoulderDrop))
        path.addLine(to: CGPoint(x: shoulderInset, y: chamfer))
        path.closeSubpath()
        return path
    }
}
