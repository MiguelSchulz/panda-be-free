import BambuUI
import NavigatorUI
import SFSafeSymbols
import SwiftUI

struct CredentialsStepView: View {
    @Environment(\.navigator) private var navigator

    var body: some View {
        SetupStepLayout(step: .credentials) {
            navigator.navigate(to: OnboardingDestinations.guidedEnterCredentials)
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                InstructionRow(number: 1, text: "On your printer's touchscreen, go to **Settings**")
                InstructionRow(number: 2, text: "Navigate to **WLAN** (or Network Settings)")
                InstructionRow(number: 3, text: "Note down the **IP Address** shown")
                InstructionRow(number: 4, text: "Find the **Access Code** displayed under LAN Only Mode")
            }
            .padding()
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 16) {
                credentialCard(icon: .network, title: "IP Address", example: "192.168.1.100")
                credentialCard(icon: .lockShield, title: "Access Code", example: "12345678")
            }
            .padding(.horizontal)
        }
        .navigationTitle("Credentials")
    }

    private func credentialCard(icon: SFSymbol, title: LocalizedStringResource, example: String) -> some View {
        VStack(spacing: 8) {
            Image(systemSymbol: icon)
                .font(.title2)
                .foregroundStyle(.tint)
            Text(title)
                .font(.caption.bold())
            Text(example)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospaced()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    CredentialsStepView()
}
