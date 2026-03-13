import PandaModels
import SwiftUI

struct FilamentEditSheet: View {
    @Bindable var viewModel: DashboardViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Filament") {
                    Picker("Profile", selection: $viewModel.editFilamentPreset) {
                        ForEach(FilamentPreset.all) { preset in
                            Text(preset.name).tag(preset)
                        }
                    }
                }

                Section("Color") {
                    ColorPicker("Filament Color", selection: $viewModel.editFilamentColor, supportsOpacity: false)
                }

                Section("Nozzle Temperature") {
                    LabeledContent("Min", value: "\(viewModel.editFilamentPreset.nozzleTempMin)\u{00B0}C")
                    LabeledContent("Max", value: "\(viewModel.editFilamentPreset.nozzleTempMax)\u{00B0}C")
                }
            }
            .navigationTitle("Edit Filament")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.showFilamentEditSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { viewModel.confirmFilamentEdit() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    FilamentEditSheet(viewModel: .preview)
}
