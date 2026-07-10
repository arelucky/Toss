import SwiftUI

struct CoinBack: View {
    let theme: CoinTheme

    var body: some View {
        ZStack {
            CoinMaterial(theme: theme)
            CoinRings(theme: theme)

            ForEach(Array(theme.backCircleScales.enumerated()), id: \.offset) { index, scale in
                Circle()
                    .strokeBorder(circleGradient(index: index), lineWidth: index == 1 ? 2.4 : 1.6)
                    .scaleEffect(scale)
                    .shadow(color: theme.highlightGold.opacity(0.20), radius: 1, x: -1, y: -1)
                    .shadow(color: theme.shadowGold.opacity(0.24), radius: 1, x: 1, y: 1)
            }

            Circle()
                .fill(theme.highlightGold.opacity(0.18))
                .scaleEffect(0.12)
                .blendMode(.screen)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func circleGradient(index: Int) -> LinearGradient {
        LinearGradient(
            colors: [
                theme.highlightGold.opacity(index == 1 ? 0.72 : 0.54),
                theme.deepGold.opacity(0.44)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
