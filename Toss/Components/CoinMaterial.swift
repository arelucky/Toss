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
            .overlay(brushedMetalDepth)
            .overlay(reededEdgeHint)
            .overlay(edgeShade)
    }

    private var baseMetal: AngularGradient {
        AngularGradient(
            stops: [
                .init(color: theme.shadowGold.opacity(0.94), location: 0.00),
                .init(color: theme.baseGold, location: 0.14),
                .init(color: theme.highlightGold.opacity(0.42), location: 0.26),
                .init(color: theme.warmGold.opacity(0.84), location: 0.40),
                .init(color: theme.deepGold.opacity(0.90), location: 0.58),
                .init(color: theme.paleGold.opacity(0.46), location: 0.76),
                .init(color: theme.shadowGold.opacity(0.90), location: 1.00)
            ],
            center: .center
        )
    }

    private var radialDepth: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        theme.highlightGold.opacity(0.12),
                        theme.warmGold.opacity(0.12),
                        theme.shadowGold.opacity(0.36)
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
                        theme.warmGold.opacity(0.10),
                        theme.paleGold.opacity(0.04),
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
                        theme.coolReflection.opacity(0.09),
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
                        .white.opacity(0.10),
                        .white.opacity(0.025),
                        .black.opacity(0.10)
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
                        theme.shadowGold.opacity(0.26)
                    ],
                    startPoint: UnitPoint(x: 0.58, y: 0.22),
                    endPoint: UnitPoint(x: 0.08, y: 0.92)
                )
            )
            .blendMode(.multiply)
    }

    private var edgeShade: some View {
        Circle()
            .strokeBorder(theme.shadowGold.opacity(0.26), lineWidth: 1)
    }

    private var brushedMetalDepth: some View {
        ZStack {
            Circle()
                .strokeBorder(theme.highlightGold.opacity(0.12), lineWidth: 1)
                .padding(theme.defaultSize * 0.045)

            Circle()
                .strokeBorder(theme.shadowGold.opacity(0.14), lineWidth: 1)
                .padding(theme.defaultSize * 0.075)

            Circle()
                .strokeBorder(theme.baseGold.opacity(0.14), lineWidth: 1)
                .padding(theme.defaultSize * 0.115)
        }
        .blendMode(.softLight)
    }

    private var reededEdgeHint: some View {
        ZStack {
            ForEach(0..<72, id: \.self) { index in
                Capsule()
                    .fill(edgeTickColor(index: index))
                    .frame(width: 0.7, height: theme.defaultSize * 0.034)
                    .offset(y: -theme.defaultSize * 0.485)
                    .rotationEffect(.degrees(Double(index) * 5))
            }
        }
        .clipShape(Circle())
        .blendMode(.softLight)
    }

    private func edgeTickColor(index: Int) -> Color {
        index.isMultiple(of: 2)
            ? theme.highlightGold.opacity(0.16)
            : theme.shadowGold.opacity(0.22)
    }
}
