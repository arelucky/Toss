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
                    .overlay(circleInsetShade(scale: scale, index: index))
                    .shadow(color: theme.highlightGold.opacity(0.10), radius: 0.6, x: -0.6, y: -0.6)
                    .shadow(color: theme.shadowGold.opacity(0.20), radius: 1, x: 0.8, y: 0.9)
            }

            centerDisk
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func circleGradient(index: Int) -> LinearGradient {
        LinearGradient(
            colors: [
                theme.coolReflection.opacity(index.isMultiple(of: 2) ? 0.12 : 0.16),
                theme.highlightGold.opacity(index.isMultiple(of: 2) ? 0.28 : 0.40),
                theme.baseGold.opacity(0.30),
                theme.deepGold.opacity(0.48)
            ],
            startPoint: UnitPoint(x: 0.72, y: 0.12),
            endPoint: UnitPoint(x: 0.20, y: 0.90)
        )
    }

    private func circleLineWidth(index: Int) -> CGFloat {
        index.isMultiple(of: 2) ? 1.1 : 2.3
    }

    private func circleInsetShade(scale: CGFloat, index: Int) -> some View {
        Circle()
            .strokeBorder(theme.shadowGold.opacity(index.isMultiple(of: 2) ? 0.12 : 0.18), lineWidth: 0.7)
            .scaleEffect(scale + 0.018)
            .blur(radius: 0.25)
    }

    private var centerDisk: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        theme.coolReflection.opacity(0.12),
                        theme.highlightGold.opacity(0.24),
                        theme.baseGold.opacity(0.62),
                        theme.deepGold.opacity(0.70)
                    ],
                    center: UnitPoint(x: 0.66, y: 0.22),
                    startRadius: 1,
                    endRadius: theme.defaultSize * 0.10
                )
            )
            .overlay(
                Circle()
                    .strokeBorder(theme.highlightGold.opacity(0.14), lineWidth: 0.7)
                    .padding(1)
            )
            .overlay(
                Circle()
                    .strokeBorder(theme.shadowGold.opacity(0.26), lineWidth: 0.9)
            )
            .shadow(color: theme.highlightGold.opacity(0.08), radius: 0.6, x: -0.4, y: -0.5)
            .shadow(color: theme.shadowGold.opacity(0.18), radius: 1, x: 0.7, y: 0.8)
            .scaleEffect(0.165)
    }
}
