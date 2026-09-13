import SwiftUI

struct DistributionProfileChoiceView: View {
    let onChoose: (DistributionProfile) -> Void

    var body: some View {
        ZStack {
            TossBackground()

            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Test a Toss profile")
                        .font(.title2.weight(.semibold))
                    Text("TestFlight only. Choose the experience to verify for this launch.")
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
