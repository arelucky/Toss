//
//  TossApp.swift
//  Toss
//
//  Created by henry on 2026/7/9.
//

import SwiftUI

@main
struct TossApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView(dependencies: .live())
        }
    }
}
