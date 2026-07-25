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
            coinBody
                .rotation3DEffect(
                    .degrees(geometry.effectiveRotationDegrees),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: 0.55
                )
        }
        .frame(width: theme.defaultSize, height: theme.defaultSize * 1.18)
        .accessibilityLabel(geometry.face == .front ? "Toss coin front" : "Toss coin back")
    }

    private var coinBody: some View {
        ZStack {
            CoinShadow(theme: theme)
                .opacity(geometry.shadowOpacity)
            CoinThickness(theme: theme, visibility: geometry.edgeVisibility)
            coinFace
        }
        .frame(width: theme.defaultSize, height: theme.defaultSize)
        .drawingGroup()
    }

    private var coinFace: some View {
        ZStack {
            CoinBack(theme: theme)
                .rotation3DEffect(.degrees(180), axis: (x: 1, y: 0, z: 0))
                .opacity(geometry.backOpacity)
            CoinFront(theme: theme)
                .opacity(geometry.frontOpacity)
        }
    }

    private var geometry: CoinFlipGeometry {
        CoinFlipGeometry(rotationDegrees: rotationDegrees, restingSide: side)
    }
}

struct CoinFlipGeometry {
    let rotationDegrees: Double
    let restingSide: CoinSide

    var effectiveRotationDegrees: Double {
        rotationDegrees + restingSide.baseRotationDegrees
    }

    var face: CoinSide {
        switch normalizedHalfTurn {
        case 90...270:
            .back
        default:
            .front
        }
    }

    var frontOpacity: Double {
        guard edgeVisibility < 0.94 else { return 0 }
        return face == .front ? faceVisibility : 0
    }

    var backOpacity: Double {
        guard edgeVisibility < 0.94 else { return 0 }
        return face == .back ? faceVisibility : 0
    }

    var edgeVisibility: Double {
        abs(sin(effectiveRotationDegrees * .pi / 180))
    }

    var shadowOpacity: Double {
        0.78 - edgeVisibility * 0.18
    }

    private var normalizedHalfTurn: Double {
        let degrees = effectiveRotationDegrees.truncatingRemainder(dividingBy: 360)
        return degrees >= 0 ? degrees : degrees + 360
    }

    private var faceVisibility: Double {
        max(0, 1 - edgeVisibility * 1.12)
    }
}

private extension CoinSide {
    var baseRotationDegrees: Double {
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
    let visibility: Double

    var body: some View {
        ZStack {
            Capsule()
                .fill(edgeGradient)
                .frame(width: theme.defaultSize * 0.96, height: edgeHeight)
                .overlay(edgeHighlight)
                .shadow(color: theme.shadowGold.opacity(0.20 * visibility), radius: 3, x: 0, y: 1)

            Circle()
                .strokeBorder(theme.deepGold.opacity(0.18 * visibility), lineWidth: 1.2)
        }
        .opacity(0.18 + visibility * 0.82)
        .allowsHitTesting(false)
    }

    private var edgeHeight: CGFloat {
        theme.defaultSize * (0.035 + 0.075 * CGFloat(visibility))
    }

    private var edgeGradient: LinearGradient {
        LinearGradient(
            colors: [
                theme.highlightGold.opacity(0.68),
                theme.warmGold,
                theme.deepGold.opacity(0.90),
                theme.paleGold.opacity(0.72)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var edgeHighlight: some View {
        Capsule()
            .strokeBorder(theme.coolReflection.opacity(0.22 * visibility), lineWidth: 1)
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
