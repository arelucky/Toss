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
                    width: theme.defaultSize * 0.32,
                    height: theme.defaultSize * 0.36
                )
                .overlay(monogramTopHighlight)
                .overlay(monogramInnerShade)
                .shadow(color: theme.highlightGold.opacity(0.34), radius: 1, x: -1, y: -1)
                .shadow(color: theme.shadowGold.opacity(0.36), radius: 2, x: 2, y: 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var raisedCenter: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        theme.highlightGold.opacity(0.90),
                        theme.warmGold,
                        theme.baseGold,
                        theme.deepGold
                    ],
                    center: UnitPoint(x: 0.66, y: 0.20),
                    startRadius: 6,
                    endRadius: theme.defaultSize * 0.36
                )
            )
            .overlay(
                Circle()
                    .strokeBorder(theme.highlightGold.opacity(0.38), lineWidth: 1.4)
                    .padding(1)
            )
            .overlay(
                Circle()
                    .strokeBorder(theme.shadowGold.opacity(0.28), lineWidth: 1.7)
            )
            .shadow(color: theme.highlightGold.opacity(0.32), radius: 3, x: -1, y: -2)
            .shadow(color: theme.shadowGold.opacity(0.24), radius: 5, x: 3, y: 4)
            .scaleEffect(theme.raisedCenterScale)
    }

    private var markFill: LinearGradient {
        LinearGradient(
            colors: [
                theme.coolReflection.opacity(0.48),
                theme.highlightGold.opacity(0.92),
                theme.paleGold,
                theme.baseGold,
                theme.deepGold.opacity(0.90)
            ],
            startPoint: .topTrailing,
            endPoint: .bottomTrailing
        )
    }

    private var monogramTopHighlight: some View {
        TossMonogramMark()
            .stroke(theme.coolReflection.opacity(0.26), lineWidth: 1.2)
            .blur(radius: 0.4)
            .offset(x: 0, y: -0.8)
            .mask(TossMonogramMark())
            .frame(
                width: theme.defaultSize * 0.32,
                height: theme.defaultSize * 0.36
            )
    }

    private var monogramInnerShade: some View {
        TossMonogramMark()
            .stroke(theme.shadowGold.opacity(0.28), lineWidth: 2.2)
            .blur(radius: 0.5)
            .offset(x: 1.1, y: 1.2)
            .mask(TossMonogramMark())
            .frame(
                width: theme.defaultSize * 0.32,
                height: theme.defaultSize * 0.36
            )
    }
}
