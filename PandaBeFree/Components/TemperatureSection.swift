import PandaModels
import PandaUI
import SFSafeSymbols
import SwiftUI

struct TemperatureSection: View {
    @Bindable var viewModel: DashboardViewModel

    private var state: PrinterAttributes.ContentState {
        viewModel.contentState
    }

    var body: some View {
        HStack(spacing: 12) {
            if let nozzle = state.nozzleTemp {
                TemperatureGauge(
                    label: "Nozzle",
                    icon: .flameFill,
                    current: nozzle,
                    target: state.nozzleTargetTemp,
                    range: 0...300,
                    editable: viewModel.isConnected
                ) { viewModel.setNozzleTemp($0) }
            }
            if let bed = state.bedTemp {
                TemperatureGauge(
                    label: "Bed",
                    icon: .squareFill,
                    current: bed,
                    target: state.bedTargetTemp,
                    range: 0...110,
                    editable: viewModel.isConnected
                ) { viewModel.setBedTemp($0) }
            }
            if let chamber = state.chamberTemp, chamber > 0 {
                TemperatureGauge(
                    label: "Chamber",
                    icon: .wind,
                    current: chamber,
                    target: nil,
                    range: nil,
                    editable: false
                ) { _ in }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    TemperatureSection(viewModel: .preview)
}
