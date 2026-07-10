import SwiftUI

struct CoinFront: View {
    let theme: CoinTheme

    var body: some View {
        ZStack {
            CoinMaterial(theme: theme)
            CoinRings(theme: theme)
            raisedCenter
            TossMonogramMark()
                .fill(markFill)
                .frame(
                    width: theme.defaultSize * 0.28,
                    height: theme.defaultSize * 0.34
                )
                .shadow(color: theme.highlightGold.opacity(0.44), radius: 1, x: -1, y: -1)
                .shadow(color: theme.shadowGold.opacity(0.46), radius: 2, x: 2, y: 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var raisedCenter: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        theme.highlightGold,
                        theme.warmGold,
                        theme.baseGold,
                        theme.deepGold
                    ],
                    center: UnitPoint(x: 0.32, y: 0.24),
                    startRadius: 6,
                    endRadius: theme.defaultSize * 0.36
                )
            )
            .overlay(
                Circle()
                    .strokeBorder(theme.highlightGold.opacity(0.46), lineWidth: 1.5)
                    .padding(1)
            )
            .overlay(
                Circle()
                    .strokeBorder(theme.shadowGold.opacity(0.32), lineWidth: 2)
            )
            .shadow(color: theme.highlightGold.opacity(0.42), radius: 3, x: -2, y: -2)
            .shadow(color: theme.shadowGold.opacity(0.32), radius: 5, x: 4, y: 5)
            .scaleEffect(theme.raisedCenterScale)
    }

    private var markFill: LinearGradient {
        LinearGradient(
            colors: [
                theme.highlightGold,
                theme.paleGold,
                theme.deepGold
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
