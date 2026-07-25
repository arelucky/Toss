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
        baseGold: Color(red: 0.90, green: 0.62, blue: 0.19),
        deepGold: Color(red: 0.45, green: 0.25, blue: 0.06),
        warmGold: Color(red: 0.96, green: 0.70, blue: 0.25),
        paleGold: Color(red: 0.98, green: 0.86, blue: 0.48),
        highlightGold: Color(red: 1.00, green: 0.93, blue: 0.66),
        shadowGold: Color(red: 0.30, green: 0.16, blue: 0.04),
        coolReflection: Color(red: 0.88, green: 0.94, blue: 1.00)
    )
}
