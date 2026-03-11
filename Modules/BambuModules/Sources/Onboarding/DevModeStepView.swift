import BambuUI
import NavigatorUI
import SwiftUI

struct DevModeStepView: View {
    @Environment(\.navigator) private var navigator

    var body: some View {
        SetupStepLayout(step: .devMode) {
            navigator.navigate(to: OnboardingDestinations.guidedCredentials)
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                InstructionRow(number: 1, text: "With LAN Mode enabled, scroll down in **Settings**")
                InstructionRow(number: 2, text: "Find **Developer Mode**")
                InstructionRow(number: 3, text: "Read the important notice carefully")
                InstructionRow(number: 4, text: "Check the confirmation box and tap **Enable**")
                InstructionRow(number: 5, text: "The button should turn **green** when enabled")
            }
            .padding()
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))

            Text("Developer Mode disables cloud authentication so third-party apps can connect directly.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .navigationTitle("Developer Mode")
    }
}

#Preview {
    DevModeStepView()
}
