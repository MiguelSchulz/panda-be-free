import PandaModels
import SFSafeSymbols
import SwiftUI

struct SpeedControlSection: View {
    @Bindable var viewModel: DashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Print Speed", systemSymbol: .gaugeWithNeedle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("Speed", selection: Binding(
                get: { viewModel.selectedSpeed },
                set: { viewModel.setSpeed($0) }
            )) {
                ForEach(PrinterCommand.SpeedLevel.allCases) { level in
                    Text(level.label).tag(level)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    SpeedControlSection(viewModel: .preview).padding()
}
