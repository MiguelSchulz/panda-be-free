import BambuModels
import SwiftUI

struct DryingSheet: View {
    @Bindable var viewModel: DashboardViewModel

    private var maxTemp: Int {
        guard let amsId = viewModel.dryingAmsId,
              let unit = viewModel.printerState.amsUnits.first(where: { $0.id == amsId })
        else {
            return 85
        }
        return unit.amsType?.maxDryingTemp ?? 85
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Material Preset") {
                    Picker("Preset", selection: Binding(
                        get: { viewModel.dryingPreset },
                        set: { viewModel.applyDryingPreset($0) }
                    )) {
                        ForEach(PrinterCommand.DryingPreset.allCases) { preset in
                            Text(preset.label).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Parameters") {
                    Stepper("Temperature: \(viewModel.dryingTemperature)\u{00B0}C",
                            value: $viewModel.dryingTemperature,
                            in: 45...maxTemp, step: 5)

                    Stepper("Duration: \(viewModel.dryingDurationMinutes / 60)h",
                            value: $viewModel.dryingDurationMinutes,
                            in: 60...1440, step: 60)

                    Toggle("Rotate Spool", isOn: $viewModel.dryingRotateTray)
                }
            }
            .navigationTitle("Start Drying")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.showDryingSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") { viewModel.startDrying() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    DryingSheet(viewModel: .preview)
}
