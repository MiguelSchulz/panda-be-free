import Foundation
import PandaModels
@testable import PandaNotifications
import Testing

struct LiveActivitySettingsTests {
    private let settingsKey = "liveActivity.enabled"

    @Test("Defaults to enabled")
    func defaultsToEnabled() {
        SharedSettings.sharedDefaults?.removeObject(forKey: settingsKey)
        defer { SharedSettings.sharedDefaults?.removeObject(forKey: settingsKey) }

        #expect(LiveActivitySettings.isEnabled == true)
    }

    @Test("Persists disabled state")
    func persistsDisabled() {
        defer { SharedSettings.sharedDefaults?.removeObject(forKey: settingsKey) }

        LiveActivitySettings.isEnabled = false
        #expect(LiveActivitySettings.isEnabled == false)
    }

    @Test("Persists re-enabled state")
    func persistsReEnabled() {
        defer { SharedSettings.sharedDefaults?.removeObject(forKey: settingsKey) }

        LiveActivitySettings.isEnabled = false
        LiveActivitySettings.isEnabled = true
        #expect(LiveActivitySettings.isEnabled == true)
    }
}
