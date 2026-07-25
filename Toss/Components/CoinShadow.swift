import SwiftUI

struct CoinShadow: View {
    let theme: CoinTheme

    var body: some View {
        Ellipse()
            .fill(.black.opacity(0.16))
            .blur(radius: 20)
            .frame(width: theme.defaultSize * 0.68, height: theme.defaultSize * 0.14)
            .offset(y: theme.defaultSize * 0.46)
    }
}
