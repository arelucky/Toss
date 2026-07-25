import SwiftUI

struct CoinView: View {
    let side: CoinSide
    let theme: CoinTheme

    init(side: CoinSide = .front, theme: CoinTheme = .defaultGold) {
        self.side = side
        self.theme = theme
    }

    var body: some View {
        ZStack {
            CoinShadow(theme: theme)

            coinFace
                .frame(width: theme.defaultSize, height: theme.defaultSize)
                .drawingGroup()
        }
        .frame(width: theme.defaultSize, height: theme.defaultSize * 1.18)
        .accessibilityLabel(side == .front ? "Toss coin front" : "Toss coin back")
    }

    @ViewBuilder
    private var coinFace: some View {
        switch side {
        case .front:
            CoinFront(theme: theme)
        case .back:
            CoinBack(theme: theme)
        }
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
