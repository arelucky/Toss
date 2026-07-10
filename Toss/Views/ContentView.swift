//
//  ContentView.swift
//  Toss
//
//  Created by henry on 2026/7/9.
//

import SwiftUI

struct ContentView: View {
    let coinSide: CoinSide

    init(coinSide: CoinSide = .front) {
        self.coinSide = coinSide
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.09),
                    Color(red: 0.02, green: 0.02, blue: 0.03)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            CoinView(side: coinSide)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
            ContentView(coinSide: .back)
        }
    }
}
