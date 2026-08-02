import SwiftUI

struct CoinShadow: View {
    let theme: CoinTheme

    var body: some View {
        Ellipse()
            .fill(theme.shadowGold.opacity(0.18))
            .blur(radius: 24)
            .frame(width: theme.defaultSize * 0.72, height: theme.defaultSize * 0.12)
            .offset(y: theme.defaultSize * 0.47)
            .overlay(
                Ellipse()
                    .fill(.black.opacity(0.06))
                    .blur(radius: 18)
                    .frame(width: theme.defaultSize * 0.46, height: theme.defaultSize * 0.075)
                    .offset(y: theme.defaultSize * 0.47)
            )
    }
}
