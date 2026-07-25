import SwiftUI

struct CoinMaterial: View {
    let theme: CoinTheme

    var body: some View {
        Circle()
            .fill(baseMetal)
            .overlay(radialDepth)
            .overlay(warmReflection)
            .overlay(coolReflection)
            .overlay(specularSweep)
            .overlay(directionalShade)
            .overlay(edgeShade)
    }

    private var baseMetal: AngularGradient {
        AngularGradient(
            stops: [
                .init(color: theme.deepGold, location: 0.00),
                .init(color: theme.warmGold, location: 0.16),
                .init(color: theme.highlightGold.opacity(0.82), location: 0.27),
                .init(color: theme.baseGold, location: 0.43),
                .init(color: theme.shadowGold, location: 0.60),
                .init(color: theme.paleGold.opacity(0.86), location: 0.78),
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
                        theme.highlightGold.opacity(0.30),
                        theme.warmGold.opacity(0.14),
                        theme.shadowGold.opacity(0.34)
                    ],
                    center: UnitPoint(x: 0.68, y: 0.24),
                    startRadius: 8,
                    endRadius: 132
                )
            )
            .blendMode(.softLight)
    }

    private var warmReflection: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        theme.warmGold.opacity(0.20),
                        theme.paleGold.opacity(0.08),
                        .clear
                    ],
                    startPoint: UnitPoint(x: 0.70, y: 0.08),
                    endPoint: UnitPoint(x: 0.30, y: 0.74)
                )
            )
            .blendMode(.screen)
    }

    private var coolReflection: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        theme.coolReflection.opacity(0.13),
                        .clear,
                        theme.coolReflection.opacity(0.04)
                    ],
                    startPoint: UnitPoint(x: 0.72, y: 0.10),
                    endPoint: UnitPoint(x: 0.18, y: 0.90)
                )
            )
            .blendMode(.softLight)
    }

    private var specularSweep: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        .white.opacity(0.27),
                        .white.opacity(0.04),
                        .black.opacity(0.08)
                    ],
                    startPoint: UnitPoint(x: 0.76, y: 0.08),
                    endPoint: UnitPoint(x: 0.18, y: 0.90)
                )
            )
            .blendMode(.overlay)
    }

    private var directionalShade: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        .clear,
                        theme.shadowGold.opacity(0.18)
                    ],
                    startPoint: UnitPoint(x: 0.58, y: 0.22),
                    endPoint: UnitPoint(x: 0.08, y: 0.92)
                )
            )
            .blendMode(.multiply)
    }

    private var edgeShade: some View {
        Circle()
            .strokeBorder(theme.shadowGold.opacity(0.30), lineWidth: 1)
    }
}
