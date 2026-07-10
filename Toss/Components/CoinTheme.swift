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

    static let defaultGold = CoinTheme(
        defaultSize: 220,
        outerRingLineWidth: 7,
        innerRingLineWidth: 2,
        raisedCenterScale: 0.54,
        backCircleScales: [0.28, 0.42, 0.58],
        baseGold: Color(red: 0.92, green: 0.66, blue: 0.22),
        deepGold: Color(red: 0.50, green: 0.29, blue: 0.07),
        warmGold: Color(red: 0.98, green: 0.78, blue: 0.34),
        paleGold: Color(red: 1.00, green: 0.91, blue: 0.56),
        highlightGold: Color(red: 1.00, green: 0.96, blue: 0.75),
        shadowGold: Color(red: 0.34, green: 0.18, blue: 0.04)
    )
}
