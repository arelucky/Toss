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
                .strokeBorder(theme.highlightGold.opacity(0.50), lineWidth: theme.innerRingLineWidth)
                .padding(theme.defaultSize * 0.13)

            Circle()
                .strokeBorder(theme.shadowGold.opacity(0.30), lineWidth: 1)
                .padding(theme.defaultSize * 0.18)
        }
    }

    private var outerRingGradient: LinearGradient {
        LinearGradient(
            colors: [
                theme.highlightGold,
                theme.warmGold,
                theme.deepGold
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct TossMonogramMark: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let barHeight = height * 0.22
        let stemWidth = width * 0.34
        let corner = min(width, height) * 0.08

        var path = Path()
        path.addRoundedRect(
            in: CGRect(x: 0, y: 0, width: width, height: barHeight),
            cornerSize: CGSize(width: corner, height: corner)
        )
        path.addRoundedRect(
            in: CGRect(
                x: (width - stemWidth) / 2,
                y: barHeight * 0.52,
                width: stemWidth,
                height: height - barHeight * 0.52
            ),
            cornerSize: CGSize(width: corner, height: corner)
        )
        return path
    }
}
