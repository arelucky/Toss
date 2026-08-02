import SwiftUI

struct TossBackgroundColor: Equatable {
    let red: Double
    let green: Double
    let blue: Double

    var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue)
    }
}

struct TossBackgroundStyle: Equatable {
    let topColor: TossBackgroundColor
    let bottomColor: TossBackgroundColor
    let centerLightColor: TossBackgroundColor
    let centerLightOpacity: Double
    let floorShadowOpacity: Double

    static let defaultDisplay = TossBackgroundStyle(
        topColor: TossBackgroundColor(red: 0.095, green: 0.098, blue: 0.108),
        bottomColor: TossBackgroundColor(red: 0.018, green: 0.019, blue: 0.024),
        centerLightColor: TossBackgroundColor(red: 0.74, green: 0.76, blue: 0.78),
        centerLightOpacity: 0.24,
        floorShadowOpacity: 0.14
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
