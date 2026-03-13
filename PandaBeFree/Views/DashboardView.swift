import NavigatorUI
import PandaModels
import PandaUI
import Shimmer
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
    @State private var showConnectionError = false
    @State private var connectionErrorMessage = ""

    private var isLoading: Bool {
        !viewModel.hasReceivedInitialData
    }

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
            handleScenePhaseChange(newPhase)
        }
        .fullScreenCover(isPresented: $isFullscreen) {
            FullscreenCameraView(
                cameraProvider: viewModel.cameraManager,
                isPresented: $isFullscreen,
                isLightOn: viewModel.chamberLightOn,
                onToggleLight: viewModel.isConnected ? { viewModel.toggleLight(on: $0) } : nil
            )
        }
        .onChange(of: viewModel.mqttConnectionState) { _, newState in
            if case let .error(message) = newState {
                connectionErrorMessage = message
                showConnectionError = true
            }
        }
        .alert("Connection Failed", isPresented: $showConnectionError) {
            Button("Retry", role: .cancel) {
                viewModel.disconnectAll()
                Task {
                    await viewModel.connectAll(
                        ip: printerIP,
                        accessCode: accessCode,
                        printerType: PrinterType(rawValue: printerTypeRaw) ?? .auto
                    )
                }
            }
            Button("Disconnect", role: .destructive) {
                viewModel.disconnectAll()
                printerIP = ""
                accessCode = ""
            }
        } message: {
            Text(connectionErrorMessage)
        }
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            if viewModel.isConnected || viewModel.mqttConnectionState == .connecting {
                wasConnected = true
                if viewModel.hasReceivedInitialData {
                    SharedSettings.cachedPrinterState = PrinterStateSnapshot(from: viewModel.printerState)
                }
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

    private var dashboardContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                CameraCard(
                    cameraProvider: viewModel.cameraManager,
                    isLightOn: viewModel.chamberLightOn,
                    onToggleLight: viewModel.isConnected ? { viewModel.toggleLight(on: $0) } : nil,
                    onTapFullscreen: { isFullscreen = true }
                )
                .redacted(reason: isLoading ? .placeholder : [])
                .shimmering(active: isLoading)

                PrintProgressSection(state: viewModel.contentState)
                    .redacted(reason: isLoading ? .placeholder : [])
                    .shimmering(active: isLoading)

                TemperatureSection(viewModel: viewModel)
                    .redacted(reason: isLoading ? .placeholder : [])
                    .shimmering(active: isLoading)

                FanSection(viewModel: viewModel)
                    .redacted(reason: isLoading ? .placeholder : [])
                    .shimmering(active: isLoading)

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
