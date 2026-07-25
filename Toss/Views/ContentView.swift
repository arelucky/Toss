//
//  ContentView.swift
//  Toss
//
//  Created by henry on 2026/7/9.
//

import SwiftUI

struct ContentView: View {
    let coinSide: CoinSide
    @State private var rotationDegrees = 0.0
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

            CoinView(side: coinSide, rotationDegrees: rotationDegrees)
                .offset(y: viewModel.verticalOffset)
                .gesture(tossGesture)
                .onChange(of: viewModel.state) { _, state in
                    handleStateChange(state)
                }
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
                scheduleSpinIfNeeded()
            }
    }

    private var tossAnimation: Animation {
        .spring(response: 0.42, dampingFraction: 0.78)
    }

    private var spinAnimation: Animation {
        .linear(duration: 0.36)
        .repeatForever(autoreverses: false)
    }

    private func scheduleSpinIfNeeded() {
        guard viewModel.state == .tossing else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + viewModel.tossFlightDuration) {
            viewModel.completeTossFlight()
        }
    }

    private func handleStateChange(_ state: CoinTossState) {
        guard state == .spinning else { return }
        startSpinning()
    }

    private func startSpinning() {
        rotationDegrees = 0
        withAnimation(spinAnimation) {
            rotationDegrees = 360
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
