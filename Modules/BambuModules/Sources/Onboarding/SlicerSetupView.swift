import BambuUI
import SFSafeSymbols
import SwiftUI

struct SlicerSetupView: View {
    @Environment(OnboardingViewModel.self) private var viewModel

    var body: some View {
        SetupStepLayout(step: .slicerSetup, nextLabel: "Done") {
            viewModel.saveCredentials()
        } content: {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    InstructionRow(icon: .desktopcomputer, text: "Open **Bambu Studio** on your computer")
                    InstructionRow(icon: .printer, text: "Go to the **Device** page and select your printer")
                    InstructionRow(icon: .lockFill, text: "Look for the **lock icon** indicating LAN mode")
                    InstructionRow(icon: .keyFill, text: "Enter your **Access Code** when prompted")
                }
                .padding()
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))

                Text("This step is optional for using this app, but required to send prints over LAN.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .navigationTitle("Slicer Setup")
    }
}

#Preview {
    SlicerSetupView()
        .environment(OnboardingViewModel())
}
