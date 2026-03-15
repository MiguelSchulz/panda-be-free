import BackgroundTasks
import Networking
import PandaModels
import PandaNotifications
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock: UIInterfaceOrientationMask = .portrait

    static let bgTaskIdentifier = "com.pandabefree.liveactivity.refresh"

    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.bgTaskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            Self.handleBackgroundRefresh(refreshTask)
        }
        return true
    }

    func application(
        _: UIApplication,
        supportedInterfaceOrientationsFor _: UIWindow?
    ) -> UIInterfaceOrientationMask {
        Self.orientationLock
    }

    /// Schedule a background refresh task for Live Activity updates.
    static func scheduleLiveActivityRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: bgTaskIdentifier)
        request.earliestBeginDate = Date.now.addingTimeInterval(15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handleBackgroundRefresh(_ task: BGAppRefreshTask) {
        let fetchTask = Task {
            defer { task.setTaskCompleted(success: true) }

            guard SharedSettings.hasConfiguration,
                  LiveActivityManager.shared.isActivityActive
            else { return }

            do {
                let snapshot = try await WidgetMQTTService.fetchSnapshot(
                    ip: SharedSettings.printerIP,
                    accessCode: SharedSettings.printerAccessCode,
                    serial: SharedSettings.printerSerial
                )
                SharedSettings.cachedPrinterState = snapshot
                await LiveActivityManager.shared.update(contentState: snapshot.contentState)
                await LiveActivityManager.shared.endIfNeeded(contentState: snapshot.contentState)
            } catch {
                // MQTT fetch failed — leave Live Activity as-is (staleDate will handle UI)
            }

            // Re-schedule if Live Activity is still active
            if LiveActivityManager.shared.isActivityActive {
                scheduleLiveActivityRefresh()
            }
        }

        task.expirationHandler = {
            fetchTask.cancel()
        }
    }
}
