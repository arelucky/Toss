//
//  TossApp.swift
//  Toss
//
//  Created by henry on 2026/7/9.
//

import SwiftUI

@main
@MainActor
struct TossApp: App {
    @StateObject private var launchCoordinator = AppLaunchCoordinator()

    var body: some Scene {
        WindowGroup {
            AppBootstrapView(coordinator: launchCoordinator)
                .preferredColorScheme(.dark)
        }
    }
}
