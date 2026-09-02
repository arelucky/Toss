import SwiftUI

struct MainlandClassicRootView: View {
    @StateObject private var tossViewModel = CoinTossViewModel()

    var body: some View {
        ContentView(
            viewModel: tossViewModel,
            coinModelSource: .bundledClassic,
            onOpenCoinLibrary: nil
        )
    }
}
