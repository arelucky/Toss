import SwiftUI

struct CoinMaterial: View {
    let theme: CoinTheme

    var body: some View {
        Circle()
            .fill(baseMetal)
            .overlay(radialDepth)
            .overlay(specularSweep)
            .overlay(edgeShade)
    }

    private var baseMetal: AngularGradient {
        AngularGradient(
            stops: [
                .init(color: theme.deepGold, location: 0.00),
                .init(color: theme.warmGold, location: 0.14),
                .init(color: theme.highlightGold, location: 0.24),
                .init(color: theme.baseGold, location: 0.38),
                .init(color: theme.shadowGold, location: 0.54),
                .init(color: theme.paleGold, location: 0.70),
                .init(color: theme.deepGold, location: 1.00)
            ],
            center: .center
        )
    }

    private var radialDepth: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        theme.highlightGold.opacity(0.38),
                        theme.warmGold.opacity(0.12),
                        theme.shadowGold.opacity(0.40)
                    ],
                    center: UnitPoint(x: 0.34, y: 0.28),
                    startRadius: 8,
                    endRadius: 132
                )
            )
            .blendMode(.softLight)
    }

    private var specularSweep: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        .white.opacity(0.34),
                        .white.opacity(0.04),
                        .black.opacity(0.10)
                    ],
                    startPoint: UnitPoint(x: 0.18, y: 0.10),
                    endPoint: UnitPoint(x: 0.84, y: 0.92)
                )
            )
            .blendMode(.overlay)
    }

    private var edgeShade: some View {
        Circle()
            .strokeBorder(theme.shadowGold.opacity(0.38), lineWidth: 1)
    }
}
