import BambuModels
import BambuUI
import SwiftUI

struct FanSection: View {
    @Bindable var viewModel: DashboardViewModel

    private var printerState: PrinterState {
        viewModel.printerState
    }

    private var auxFanLabel: LocalizedStringResource {
        switch printerState.airductMode {
        case 0: "Aux Fan (Intake)"
        case 1: "Aux Fan (Recirc.)"
        default: "Aux Fan"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if printerState.airductMode >= 0 {
                Picker("Air Duct Mode", selection: Binding(
                    get: { viewModel.selectedAirductMode },
                    set: { viewModel.setAirductMode($0) }
                )) {
                    Text("Cooling").tag(0)
                    Text("Heating").tag(1)
                }
                .pickerStyle(.segmented)
            }

            let columns = [
                GridItem(.flexible()),
                GridItem(.flexible()),
            ]

            LazyVGrid(columns: columns, spacing: 10) {
                FanGauge(label: "Part Cooling", speed255: printerState.partFanSpeed, editable: viewModel.isConnected) {
                    viewModel.setFanSpeed(fanIndex: 1, percent: $0)
                }
                FanGauge(label: auxFanLabel, speed255: printerState.auxFanSpeed, editable: viewModel.isConnected) {
                    viewModel.setFanSpeed(fanIndex: 2, percent: $0)
                }
                FanGauge(label: "Hotend", speed255: printerState.heatbreakFanSpeed, editable: false) { _ in }
                if printerState.chamberFanSpeed > 0 || printerState.chamberTemp > 0 {
                    FanGauge(label: "Chamber", speed255: printerState.chamberFanSpeed, editable: viewModel.isConnected) {
                        viewModel.setFanSpeed(fanIndex: 3, percent: $0)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .alert("Change Air Duct Mode",
               isPresented: $viewModel.showAirductModeConfirmation)
        {
            Button("Switch", role: .destructive) {
                viewModel.confirmAirductModeChange()
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelAirductModeChange()
            }
        } message: {
            Text("Changing the air duct mode while printing may affect print quality. Are you sure you want to switch?")
        }
    }
}

#Preview {
    FanSection(viewModel: .preview)
}
