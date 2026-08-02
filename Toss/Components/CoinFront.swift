import SwiftUI

struct CoinFront: View {
    let theme: CoinTheme

    var body: some View {
        ZStack {
            CoinMaterial(theme: theme)
            CoinRings(theme: theme)
            raisedCenter
            monogramContactShadow
            TossMonogramMark()
                .fill(markFill)
                .frame(
                    width: theme.defaultSize * 0.32,
                    height: theme.defaultSize * 0.36
                )
                .overlay(monogramBevelHighlight)
                .overlay(monogramTopHighlight)
                .overlay(monogramInnerShade)
                .shadow(color: theme.highlightGold.opacity(0.16), radius: 0.8, x: -0.7, y: -0.8)
                .shadow(color: theme.shadowGold.opacity(0.38), radius: 1.8, x: 1.6, y: 1.9)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var raisedCenter: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        theme.highlightGold.opacity(0.48),
                        theme.paleGold.opacity(0.50),
                        theme.baseGold.opacity(0.94),
                        theme.deepGold.opacity(0.88)
                    ],
                    center: UnitPoint(x: 0.66, y: 0.20),
                    startRadius: 6,
                    endRadius: theme.defaultSize * 0.36
                )
            )
            .overlay(
                Circle()
                    .strokeBorder(theme.coolReflection.opacity(0.16), lineWidth: 1)
                    .padding(1)
            )
            .overlay(
                Circle()
                    .strokeBorder(theme.shadowGold.opacity(0.26), lineWidth: 1.8)
            )
            .shadow(color: theme.highlightGold.opacity(0.14), radius: 1.8, x: -0.8, y: -1.2)
            .shadow(color: theme.shadowGold.opacity(0.24), radius: 3.2, x: 2.2, y: 2.8)
            .scaleEffect(theme.raisedCenterScale)
    }

    private var markFill: LinearGradient {
        LinearGradient(
            colors: [
                theme.highlightGold.opacity(0.58),
                theme.paleGold.opacity(0.76),
                theme.baseGold,
                theme.warmGold.opacity(0.82),
                theme.deepGold.opacity(0.92)
            ],
            startPoint: .topTrailing,
            endPoint: .bottomTrailing
        )
    }

    private var monogramContactShadow: some View {
        TossMonogramMark()
            .fill(theme.shadowGold.opacity(0.26))
            .blur(radius: 1.4)
            .offset(x: 1.5, y: 1.8)
            .frame(
                width: theme.defaultSize * 0.32,
                height: theme.defaultSize * 0.36
            )
            .allowsHitTesting(false)
    }

    private var monogramBevelHighlight: some View {
        TossMonogramMark()
            .stroke(
                LinearGradient(
                    colors: [
                        theme.highlightGold.opacity(0.22),
                        theme.paleGold.opacity(0.26),
                        theme.shadowGold.opacity(0.22)
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                ),
                lineWidth: 1.2
            )
            .frame(
                width: theme.defaultSize * 0.32,
                height: theme.defaultSize * 0.36
            )
    }

    private var monogramTopHighlight: some View {
        TossMonogramMark()
            .stroke(theme.highlightGold.opacity(0.16), lineWidth: 0.8)
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
            .stroke(theme.shadowGold.opacity(0.38), lineWidth: 2.8)
            .blur(radius: 0.55)
            .offset(x: 1.2, y: 1.4)
            .mask(TossMonogramMark())
            .frame(
                width: theme.defaultSize * 0.32,
                height: theme.defaultSize * 0.36
            )
    }
}
