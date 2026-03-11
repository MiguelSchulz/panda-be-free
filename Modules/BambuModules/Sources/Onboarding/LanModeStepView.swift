import BambuUI
import NavigatorUI
import SwiftUI

struct LanModeStepView: View {
    @Environment(\.navigator) private var navigator

    var body: some View {
        SetupStepLayout(step: .lanMode) {
            navigator.navigate(to: OnboardingDestinations.guidedDevMode)
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                InstructionRow(number: 1, text: "On your printer's touchscreen, tap **Settings**")
                InstructionRow(number: 2, text: "Navigate to **WLAN** (or Network Settings)")
                InstructionRow(number: 3, text: "Find **LAN Only Mode** and turn it **ON**")
                InstructionRow(number: 4, text: "The toggle should turn **green** when enabled")
            }
            .padding()
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
        }
        .navigationTitle("LAN Mode")
    }
}

#Preview {
    LanModeStepView()
}
