import AppIntents
import Networking
import PandaModels
import WidgetKit

struct RefreshPrintStateWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh Print Status"
    static let description = IntentDescription("Refreshes the print status widget with latest data.")

    func perform() async throws -> some IntentResult {
        if SharedSettings.hasConfiguration {
            if let snapshot = try? await WidgetMQTTService.fetchSnapshot(
                ip: SharedSettings.printerIP,
                accessCode: SharedSettings.printerAccessCode,
                serial: SharedSettings.printerSerial
            ) {
                SharedSettings.cachedPrinterState = snapshot
            }
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "PrintStateWidget")
        return .result()
    }
}

struct RefreshAMSWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh AMS"
    static let description = IntentDescription("Refreshes the AMS widget with latest data.")

    func perform() async throws -> some IntentResult {
        if SharedSettings.hasConfiguration {
            if let snapshot = try? await WidgetMQTTService.fetchSnapshot(
                ip: SharedSettings.printerIP,
                accessCode: SharedSettings.printerAccessCode,
                serial: SharedSettings.printerSerial
            ) {
                SharedSettings.cachedPrinterState = snapshot
            }
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "AMSWidget")
        return .result()
    }
}
