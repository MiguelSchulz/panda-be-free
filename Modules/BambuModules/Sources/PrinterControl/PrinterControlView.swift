import BambuModels
import BambuUI
import Networking
import SFSafeSymbols
import SwiftUI

public struct PrinterControlView: View {
    @State private var viewModel: ControlViewModel

    public init(
        mqttService: any MQTTServiceProtocol,
        cameraProvider: (any CameraStreamProviding)? = nil,
        isLightOn: Bool = false,
        printerState: PrinterState
    ) {
        _viewModel = State(initialValue: ControlViewModel(
            mqttService: mqttService,
            cameraProvider: cameraProvider,
            isLightOn: isLightOn,
            printerState: printerState
        ))
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if !viewModel.controlsEnabled {
                        Label(
                            "Controls are disabled while the printer is busy.",
                            systemSymbol: .exclamationmarkTriangleFill
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                    }

                    if let camera = viewModel.cameraProvider {
                        CameraCard(
                            cameraProvider: camera,
                            isLightOn: viewModel.isLightOn,
                            onToggleLight: { viewModel.toggleLight(on: $0) }
                        )
                    }

                    ControlCard(title: "Position", systemSymbol: .move3d) {
                        HStack(alignment: .center, spacing: 16) {
                            JogPadView(viewModel: viewModel)
                            BedControlView(viewModel: viewModel)
                        }
                    }
                    .disabled(!viewModel.controlsEnabled)

                    ControlCard(title: "Extruder", systemSymbol: .arrowDownToLine) {
                        ExtruderControlView(viewModel: viewModel)
                    }
                    .disabled(!viewModel.controlsEnabled)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Control")
            .alert("Axes Not Homed", isPresented: $viewModel.showHomingWarning) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please home all axes before moving to avoid damaging the printer.")
            }
            .alert("Nozzle Too Cold", isPresented: $viewModel.showExtruderTempWarning) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please heat the nozzle to above 170°C before loading or unloading filament.")
            }
        }
    }
}

#Preview {
    PrinterControlView(
        mqttService: MockMQTTService(),
        isLightOn: true,
        printerState: PrinterState()
    )
}
