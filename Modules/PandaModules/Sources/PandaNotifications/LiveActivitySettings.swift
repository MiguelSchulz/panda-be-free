import Foundation
import PandaModels

/// Manages Live Activity enabled/disabled state in shared UserDefaults.
/// Accessible from both main app and widget extension.
public enum LiveActivitySettings {
    private static let key = "liveActivity.enabled"

    /// Whether Live Activities are enabled. Defaults to true (opt-out).
    public static var isEnabled: Bool {
        get { SharedSettings.sharedDefaults?.object(forKey: key) as? Bool ?? true }
        set { SharedSettings.sharedDefaults?.set(newValue, forKey: key) }
    }
}
