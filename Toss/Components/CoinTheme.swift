import SwiftUI

struct CoinTheme {
    let defaultSize: CGFloat
    let outerRingLineWidth: CGFloat
    let innerRingLineWidth: CGFloat
    let raisedCenterScale: CGFloat
    let backCircleScales: [CGFloat]

    let baseGold: Color
    let deepGold: Color
    let warmGold: Color
    let paleGold: Color
    let highlightGold: Color
    let shadowGold: Color
    let coolReflection: Color

    static let defaultGold = CoinTheme(
        defaultSize: 220,
        outerRingLineWidth: 6.3,
        innerRingLineWidth: 2,
        raisedCenterScale: 0.58,
        backCircleScales: [0.22, 0.34, 0.47, 0.61],
        baseGold: Color(red: 0.78, green: 0.62, blue: 0.42),
        deepGold: Color(red: 0.36, green: 0.25, blue: 0.15),
        warmGold: Color(red: 0.88, green: 0.72, blue: 0.50),
        paleGold: Color(red: 0.96, green: 0.86, blue: 0.68),
        highlightGold: Color(red: 1.00, green: 0.93, blue: 0.78),
        shadowGold: Color(red: 0.22, green: 0.16, blue: 0.10),
        coolReflection: Color(red: 0.92, green: 0.96, blue: 1.00)
    )
}
