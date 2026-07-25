//
//  ContentView.swift
//  Toss
//
//  Created by henry on 2026/7/9.
//

import SwiftUI

struct ContentView: View {
    let coinSide: CoinSide
    @StateObject private var viewModel: CoinTossViewModel

    init(coinSide: CoinSide = .front, viewModel: CoinTossViewModel = CoinTossViewModel()) {
        self.coinSide = coinSide
        _viewModel = StateObject(wrappedValue: viewModel)
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
                .offset(y: viewModel.verticalOffset)
                .gesture(tossGesture)
        }
    }

    private var tossGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                viewModel.updateDragTranslation(value.translation)
            }
            .onEnded { value in
                withAnimation(tossAnimation) {
                    viewModel.endDrag(translation: value.translation)
                }
            }
    }

    private var tossAnimation: Animation {
        .spring(response: 0.42, dampingFraction: 0.78)
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
