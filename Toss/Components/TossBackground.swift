import SwiftUI

struct TossBackgroundStyle: Equatable {
    let topColor: TossVisualColor
    let bottomColor: TossVisualColor
    let centerLightColor: TossVisualColor
    let centerLightOpacity: Double
    let floorShadowOpacity: Double

    static let defaultDisplay = TossBackgroundStyle(
        topColor: TossVisualStyle.charcoalTop,
        bottomColor: TossVisualStyle.charcoalBottom,
        centerLightColor: TossVisualStyle.centerGlow,
        centerLightOpacity: 0.20,
        floorShadowOpacity: 0.12
    )
}

struct TossBackground: View {
    let style: TossBackgroundStyle

    init(style: TossBackgroundStyle = .defaultDisplay) {
        self.style = style
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    style.topColor.swiftUIColor,
                    style.bottomColor.swiftUIColor
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    style.centerLightColor.swiftUIColor.opacity(style.centerLightOpacity),
                    style.centerLightColor.swiftUIColor.opacity(0)
                ],
                center: .center,
                startRadius: 24,
                endRadius: 250
            )

            VStack {
                Spacer()
                Ellipse()
                    .fill(Color.black.opacity(style.floorShadowOpacity))
                    .blur(radius: 36)
                    .frame(width: 280, height: 54)
                    .offset(y: -128)
            }
        }
        .ignoresSafeArea()
    }
}

struct TossBackground_Previews: PreviewProvider {
    static var previews: some View {
        TossBackground()
    }
}
