import SwiftUI

struct DistributionProfileChoiceView: View {
    let onChoose: (DistributionProfile) -> Void

    var body: some View {
        ZStack {
            TossBackground()

            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Choose your region")
                        .font(.title2.weight(.semibold))
                    Text("This one-time choice determines which Toss experience is available.")
                        .font(.subheadline)
                        .foregroundStyle(TossVisualStyle.secondaryText.swiftUIColor)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    choiceButton(
                        title: "Mainland China",
                        hint: "Uses the offline Classic experience",
                        profile: .mainlandClassicOnly
                    )
                    choiceButton(
                        title: "Other regions",
                        hint: "Uses the global online experience",
                        profile: .globalOnline
                    )
                }
            }
            .padding(32)
        }
    }

    private func choiceButton(
        title: String,
        hint: String,
        profile: DistributionProfile
    ) -> some View {
        Button(title) {
            onChoose(profile)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .accessibilityHint(hint)
    }
}
