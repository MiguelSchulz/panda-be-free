import NavigatorUI
import Networking
import Onboarding
import PandaModels
import PrinterControl
import Printing
import SFSafeSymbols
import SwiftUI

enum PrintCommandError: LocalizedError {
    case notConnected

    var errorDescription: String? {
        "Printer is not connected. Check your connection and try again."
    }
}

enum RootTab: Hashable {
    case dashboard
    case control
    case print
    case more
}

@main
struct PandaBeFreeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    /// @AppStorage is needed here for SwiftUI reactivity — when clearConfigAndDisconnect()
    /// clears these values, SwiftUI re-evaluates body and switches to onboarding.
    @AppStorage("printerIP", store: UserDefaults(suiteName: SharedSettings.suiteName))
    private var printerIP = ""
    @AppStorage("printerAccessCode", store: UserDefaults(suiteName: SharedSettings.suiteName))
    private var accessCode = ""
    @AppStorage("slicerServerURL", store: UserDefaults(suiteName: SharedSettings.suiteName))
    private var slicerServerURL = ""
    @AppStorage("slicerMachineId", store: UserDefaults(suiteName: SharedSettings.suiteName))
    private var slicerMachineId = ""
    @State private var selectedTab: RootTab = .dashboard
    @State private var dashboardViewModel = DashboardViewModel()
    @State private var printViewModel: PrintViewModel?

    private var hasConfig: Bool {
        !printerIP.isEmpty && !accessCode.isEmpty
    }

    init() {
        SharedSettings.migrateFromStandardDefaults()
    }

    private func makePrintViewModel() -> PrintViewModel {
        let viewModel = dashboardViewModel
        return PrintViewModel(
            amsUnitsProvider: { @MainActor in
                viewModel.printerState.amsUnits
            },
            mqttCommandSender: { @MainActor command in
                guard viewModel.mqttServiceRef.connectionState == .connected else {
                    throw PrintCommandError.notConnected
                }
                viewModel.mqttServiceRef.sendCommand(command)
            }
        )
    }

    var body: some Scene {
        WindowGroup {
            if hasConfig {
                TabView(selection: $selectedTab) {
                    Tab("Dashboard", systemImage: SFSymbol.printerFill.rawValue, value: RootTab.dashboard) {
                        DashboardView(viewModel: dashboardViewModel)
                    }
                    Tab("Control", systemImage: SFSymbol.gamecontrollerFill.rawValue, value: RootTab.control) {
                        PrinterControlView(
                            mqttService: dashboardViewModel.mqttServiceRef,
                            cameraProvider: dashboardViewModel.cameraManager,
                            isLightOn: dashboardViewModel.chamberLightOn,
                            printerState: dashboardViewModel.printerState
                        )
                    }
                    if !slicerServerURL.isEmpty, !slicerMachineId.isEmpty {
                        Tab("Print", systemImage: SFSymbol.cubeTransparent.rawValue, value: RootTab.print) {
                            PrintView(viewModel: printViewModel ?? makePrintViewModel())
                        }
                    }
                    Tab("More", systemImage: SFSymbol.ellipsisCircle.rawValue, value: RootTab.more) {
                        MoreView()
                    }
                }
                .onNavigationReceive(assign: $selectedTab)
                .onChange(of: printViewModel?.phase) { _, newPhase in
                    if case .sent = newPhase {
                        selectedTab = .dashboard
                    }
                }
                .onChange(of: slicerServerURL) { _, newValue in
                    if newValue.isEmpty, selectedTab == .print {
                        selectedTab = .dashboard
                    }
                    printViewModel = nil
                }
                .onChange(of: slicerMachineId) { _, newValue in
                    if newValue.isEmpty, selectedTab == .print {
                        selectedTab = .dashboard
                    }
                    printViewModel = nil
                }
                .task {
                    if printViewModel == nil, !slicerServerURL.isEmpty, !slicerMachineId.isEmpty {
                        printViewModel = makePrintViewModel()
                    }
                }
            } else {
                OnboardingRootView { ip, accessCode, serial, printerModel in
                    await ConnectionTestService.testConnection(
                        ip: ip,
                        accessCode: accessCode,
                        serial: serial,
                        printerModel: printerModel
                    )
                }
            }
        }
    }
}
