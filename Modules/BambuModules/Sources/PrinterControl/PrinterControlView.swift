import BambuModels
import BambuUI
import NavigatorUI
import Networking
import SFSafeSymbols
import Shimmer
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

    private var isLoading: Bool {
        viewModel.printerState.lastUpdated == nil
    }

    public var body: some View {
        ManagedNavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if !viewModel.controlsEnabled, !isLoading {
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
                        .redacted(reason: isLoading ? .placeholder : [])
                        .shimmering(active: isLoading)
                    }

                    ControlCard(title: "Position", systemSymbol: .move3d) {
                        HStack(alignment: .center, spacing: 16) {
                            JogPadView(viewModel: viewModel)
                            BedControlView(viewModel: viewModel)
                        }
                    }
                    .disabled(!viewModel.controlsEnabled)
                    .redacted(reason: isLoading ? .placeholder : [])
                    .shimmering(active: isLoading)

                    ControlCard(title: "Extruder", systemSymbol: .arrowDownToLine) {
                        ExtruderControlView(viewModel: viewModel)
                    }
                    .disabled(!viewModel.controlsEnabled)
                    .redacted(reason: isLoading ? .placeholder : [])
                    .shimmering(active: isLoading)
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
