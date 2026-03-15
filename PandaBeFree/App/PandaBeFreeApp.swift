import NavigatorUI
import Networking
import Onboarding
import PandaModels
import PrinterControl
import SFSafeSymbols
import SwiftUI

enum RootTab: Hashable {
    case dashboard
    case control
    case more
}

@main
struct PandaBeFreeApp: App {
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
    private static func testMQTTConnection(ip: String, accessCode: String, serial: String) async -> String? {
        let service = PandaMQTTService()
        let stateStream = service.stateStream
        service.connect(ip: ip, accessCode: accessCode, serial: serial)
        defer { service.disconnect() }

        let connectDeadline = Date.now.addingTimeInterval(10)

        // Phase 1: Wait for MQTT broker connection
        for await state in stateStream {
            switch state {
            case .connected:
                break // Move to phase 2
            case .error:
                return String(localized: "Could not connect to the printer. Please check that the IP address and access code are correct, and that your iPhone is on the same Wi-Fi network as the printer.")
            default:
                if Date.now > connectDeadline { break }
                continue
            }
            break
        }

        guard service.connectionState == .connected else {
            return String(localized: "Connection timed out. Make sure the printer is turned on and that your iPhone is on the same Wi-Fi network.")
        }

        // Phase 2: Wait for an actual message from the printer to confirm
        // the subscription works (some printers don't support wildcard topics)
        let messageReceived = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                for await _ in service.messageStream {
                    return true
                }
                return false
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(5))
                return false
            }
            let result = await group.next() ?? false
            group.cancelAll()
            return result
        }

        if messageReceived {
            return nil
        }

        if serial.isEmpty {
            return String(localized: "Connected to the printer, but no data was received. This printer may require a serial number. Please enter the serial number and try again.")
        }
        return String(localized: "Connection timed out while waiting for printer data. Make sure the printer is turned on and reachable.")
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
                    Tab("More", systemImage: SFSymbol.ellipsisCircle.rawValue, value: RootTab.more) {
                        MoreView()
                    }
                }
                .onNavigationReceive(assign: $selectedTab)
            } else {
                OnboardingRootView { ip, accessCode, serial in
                    await Self.testMQTTConnection(ip: ip, accessCode: accessCode, serial: serial)
                }
            }
        }
    }
}
