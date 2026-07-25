import SwiftUI

struct CoinBack: View {
    let theme: CoinTheme

    var body: some View {
        ZStack {
            CoinMaterial(theme: theme)
            CoinRings(theme: theme)

            ForEach(Array(theme.backCircleScales.enumerated()), id: \.offset) { index, scale in
                Circle()
                    .strokeBorder(circleGradient(index: index), lineWidth: circleLineWidth(index: index))
                    .scaleEffect(scale)
                    .shadow(color: theme.highlightGold.opacity(0.16), radius: 1, x: -0.8, y: -0.8)
                    .shadow(color: theme.shadowGold.opacity(0.18), radius: 1, x: 0.9, y: 0.9)
            }

            centerDisk
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func circleGradient(index: Int) -> LinearGradient {
        LinearGradient(
            colors: [
                theme.highlightGold.opacity(index.isMultiple(of: 2) ? 0.48 : 0.64),
                theme.warmGold.opacity(0.28),
                theme.deepGold.opacity(0.40)
            ],
            startPoint: UnitPoint(x: 0.72, y: 0.12),
            endPoint: UnitPoint(x: 0.20, y: 0.90)
        )
    }

    private func circleLineWidth(index: Int) -> CGFloat {
        index.isMultiple(of: 2) ? 1.2 : 2.5
    }

    private var centerDisk: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        theme.coolReflection.opacity(0.24),
                        theme.highlightGold.opacity(0.40),
                        theme.baseGold.opacity(0.72),
                        theme.deepGold.opacity(0.62)
                    ],
                    center: UnitPoint(x: 0.66, y: 0.22),
                    startRadius: 1,
                    endRadius: theme.defaultSize * 0.12
                )
            )
            .overlay(
                Circle()
                    .strokeBorder(theme.highlightGold.opacity(0.28), lineWidth: 1)
            )
            .shadow(color: theme.highlightGold.opacity(0.16), radius: 1, x: -0.6, y: -0.8)
            .shadow(color: theme.shadowGold.opacity(0.18), radius: 1.5, x: 1, y: 1.2)
            .scaleEffect(0.16)
    }
}
