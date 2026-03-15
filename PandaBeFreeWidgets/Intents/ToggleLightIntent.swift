import AppIntents
import Networking
import PandaModels
import WidgetKit

struct ToggleLightIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Light"
    static let description = IntentDescription("Toggles the printer's chamber light on or off.")

    func perform() async throws -> some IntentResult {
        guard SharedSettings.hasConfiguration else { return .result() }

        let currentState = SharedSettings.cachedPrinterState?.chamberLightOn ?? false
        let newState = !currentState

        // Update cached state so widgets reflect the change immediately
        if var snapshot = SharedSettings.cachedPrinterState {
            snapshot.chamberLightOn = newState
            SharedSettings.cachedPrinterState = snapshot
        }

        try? await WidgetMQTTService.sendCommand(
            .chamberLight(on: newState),
            ip: SharedSettings.printerIP,
            accessCode: SharedSettings.printerAccessCode,
            serial: SharedSettings.printerSerial
        )

        WidgetCenter.shared.reloadTimelines(ofKind: "CameraWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "PrinterOverviewWidget")
        return .result()
    }
}
