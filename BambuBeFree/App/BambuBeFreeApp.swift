import BambuModels
import NavigatorUI
import Networking
import Onboarding
import PrinterControl
import SFSafeSymbols
import SwiftUI

enum RootTab: Hashable {
    case dashboard
    case control
    case more
}

@main
struct BambuBeFreeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("printerIP", store: UserDefaults(suiteName: SharedSettings.suiteName))
    private var printerIP = ""
    @AppStorage("printerAccessCode", store: UserDefaults(suiteName: SharedSettings.suiteName))
    private var accessCode = ""
    @State private var selectedTab: RootTab = .dashboard
    @State private var dashboardViewModel = DashboardViewModel()

    private var hasConfig: Bool {
        !printerIP.isEmpty && !accessCode.isEmpty
    }

    init() {
        SharedSettings.migrateFromStandardDefaults()
    }

    @MainActor
    private static func testMQTTConnection(ip: String, accessCode: String) async -> String? {
        let service = BambuMQTTService()
        let stream = service.stateStream
        service.connect(ip: ip, accessCode: accessCode)
        defer { service.disconnect() }

        let deadline = Date().addingTimeInterval(10)
        for await state in stream {
            switch state {
            case .connected:
                return nil
            case .error:
                return String(localized: "Could not connect to the printer. Please check that the IP address and access code are correct, and that your iPhone is on the same Wi-Fi network as the printer.")
            default:
                break
            }
            if Date() > deadline { break }
        }
        return String(localized: "Connection timed out. Make sure the printer is turned on and that your iPhone is on the same Wi-Fi network.")
    }

    var body: some Scene {
        WindowGroup {
            if hasConfig {
                TabView(selection: $selectedTab) {
                    DashboardView(viewModel: dashboardViewModel)
                        .tabItem {
                            Label("Dashboard", systemSymbol: .printerFill)
                        }
                        .tag(RootTab.dashboard)
                    PrinterControlView(
                        mqttService: dashboardViewModel.mqttServiceRef,
                        cameraProvider: dashboardViewModel.cameraManager,
                        isLightOn: dashboardViewModel.chamberLightOn,
                        printerState: dashboardViewModel.printerState
                    )
                    .tabItem {
                        Label("Control", systemSymbol: .gamecontrollerFill)
                    }
                    .tag(RootTab.control)
                    PlaceholderView()
                        .tabItem {
                            Label("More", systemSymbol: .ellipsisCircle)
                        }
                        .tag(RootTab.more)
                }
                .onNavigationReceive(assign: $selectedTab)
            } else {
                OnboardingRootView { ip, accessCode in
                    await Self.testMQTTConnection(ip: ip, accessCode: accessCode)
                }
            }
        }
    }
}

private struct PlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Coming Soon",
                systemImage: SFSymbol.sparkles.rawValue,
                description: Text("New features are on the way.")
            )
            .navigationTitle("More")
        }
    }
}
