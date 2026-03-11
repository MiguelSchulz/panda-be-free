import SwiftUI

public extension Color {
    /// The app's brand color, matching the AccentColor asset in the main app bundle.
    /// Use in widget extensions where `Color.accentColor` is not available.
    static let bambuBrand = Color("BambuBrand", bundle: .module)
}
