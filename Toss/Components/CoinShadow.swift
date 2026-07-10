import SwiftUI

struct CoinShadow: View {
    let theme: CoinTheme

    var body: some View {
        Ellipse()
            .fill(.black.opacity(0.24))
            .blur(radius: 18)
            .frame(width: theme.defaultSize * 0.72, height: theme.defaultSize * 0.16)
            .offset(y: theme.defaultSize * 0.46)
    }
}
