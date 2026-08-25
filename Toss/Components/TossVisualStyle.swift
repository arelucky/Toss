import SwiftUI

struct TossVisualColor: Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double

    init(red: Double, green: Double, blue: Double, opacity: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }

    var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}

enum TossVisualStyle {
    static let controlSize: CGFloat = 44
    static let pageHorizontalInset: CGFloat = 16
    static let selectionGold = TossVisualColor(red: 0.86, green: 0.68, blue: 0.40)
    static let primaryText = TossVisualColor(red: 0.95, green: 0.93, blue: 0.88, opacity: 0.94)
    static let secondaryText = TossVisualColor(red: 0.95, green: 0.93, blue: 0.88, opacity: 0.62)
    static let surfaceOpacity: Double = 0.14
    static let charcoalTop = TossVisualColor(red: 0.065, green: 0.064, blue: 0.060)
    static let charcoalBottom = TossVisualColor(red: 0.016, green: 0.015, blue: 0.014)
    static let centerGlow = TossVisualColor(red: 0.66, green: 0.65, blue: 0.64)
}
