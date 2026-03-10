import AppIntents
import WidgetKit

struct RefreshCameraWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh Camera"
    static let description = IntentDescription("Refreshes the camera widget with a new snapshot.")

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadTimelines(ofKind: "CameraWidget")
        return .result()
    }
}
