import AppIntents
import Networking
import PandaModels
import WidgetKit

struct RefreshPrinterOverviewWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh Printer Overview"
    static let description = IntentDescription("Refreshes the printer overview widget with latest data.")

    func perform() async throws -> some IntentResult {
        if SharedSettings.hasConfiguration {
            if let snapshot = try? await WidgetMQTTService.fetchSnapshot(
                ip: SharedSettings.printerIP,
                accessCode: SharedSettings.printerAccessCode
            ) {
                SharedSettings.cachedPrinterState = snapshot
            }
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "PrinterOverviewWidget")
        return .result()
    }
}
