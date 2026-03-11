import BambuModels
import BambuUI
import NavigatorUI
import SwiftUI
import WidgetKit

struct DashboardView: View {
    @AppStorage("printerIP", store: UserDefaults(suiteName: SharedSettings.suiteName))
    private var printerIP = ""
    @AppStorage("printerAccessCode", store: UserDefaults(suiteName: SharedSettings.suiteName))
    private var accessCode = ""
    @AppStorage("printerType", store: UserDefaults(suiteName: SharedSettings.suiteName))
    private var printerTypeRaw = "auto"
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var viewModel: DashboardViewModel
    @State private var isFullscreen = false
    @State private var wasConnected = false

    var body: some View {
        ManagedNavigationStack {
            dashboardContent
                .navigationTitle("Dashboard")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Disconnect") {
                            viewModel.showDisconnectConfirmation = true
                        }
                        .confirmationDialog(
                            "Disconnect from Printer?",
                            isPresented: $viewModel.showDisconnectConfirmation
                        ) {
                            Button("Disconnect", role: .destructive) {
                                viewModel.disconnectAll()
                                printerIP = ""
                                accessCode = ""
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("This will disconnect from the printer and return to the setup screen.")
                        }
                    }
                }
        }
        .task {
            await viewModel.connectAll(
                ip: printerIP,
                accessCode: accessCode,
                printerType: PrinterType(rawValue: printerTypeRaw) ?? .auto
            )
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                if viewModel.isConnected || viewModel.mqttConnectionState == .connecting {
                    wasConnected = true
                    SharedSettings.cachedPrinterState = PrinterStateSnapshot(from: viewModel.printerState)
                    viewModel.disconnectAll()
                    WidgetCenter.shared.reloadAllTimelines()
                }
            case .active:
                WidgetCenter.shared.reloadTimelines(ofKind: "PrintStateWidget")
                WidgetCenter.shared.reloadTimelines(ofKind: "AMSWidget")
                if wasConnected {
                    wasConnected = false
                    Task {
                        await viewModel.connectAll(
                            ip: printerIP,
                            accessCode: accessCode,
                            printerType: PrinterType(rawValue: printerTypeRaw) ?? .auto
                        )
                    }
                }
            default:
                break
            }
        }
        .fullScreenCover(isPresented: $isFullscreen) {
            FullscreenCameraView(
                cameraProvider: viewModel.cameraManager,
                isPresented: $isFullscreen,
                isLightOn: viewModel.chamberLightOn,
                onToggleLight: viewModel.isConnected ? { viewModel.toggleLight(on: $0) } : nil
            )
        }
    }

    private var dashboardContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                CameraCard(
                    cameraProvider: viewModel.cameraManager,
                    isLightOn: viewModel.chamberLightOn,
                    onToggleLight: viewModel.isConnected ? { viewModel.toggleLight(on: $0) } : nil,
                    onTapFullscreen: { isFullscreen = true }
                )

                ConnectionBanner(state: viewModel.mqttConnectionState)

                PrintProgressSection(state: viewModel.contentState)

                TemperatureSection(viewModel: viewModel)

                if viewModel.isConnected {
                    FanSection(viewModel: viewModel)
                }

                if viewModel.isConnected && !viewModel.printerState.amsUnits.isEmpty {
                    ForEach(viewModel.printerState.amsUnits) { amsUnit in
                        AMSSection(viewModel: viewModel, amsUnit: amsUnit)
                    }
                }

                if viewModel.isPrinting || viewModel.canResume {
                    PrinterControlsSection(viewModel: viewModel)
                }

                if viewModel.isPrinting {
                    SpeedControlSection(viewModel: viewModel)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            viewModel.disconnectAll()
            async let connect: Void = viewModel.connectAll(ip: printerIP, accessCode: accessCode)
            async let minDelay: Void = { try? await Task.sleep(for: .seconds(1)) }()
            _ = await (connect, minDelay)
        }
        .sheet(isPresented: $viewModel.showDryingSheet) {
            DryingSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showFilamentEditSheet) {
            FilamentEditSheet(viewModel: viewModel)
        }
        .alert("Stop Drying", isPresented: $viewModel.showStopDryingConfirmation) {
            Button("Stop", role: .destructive) { viewModel.stopDrying() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to stop the drying cycle?")
        }
    }
}

#Preview {
    DashboardView(viewModel: .preview)
}
