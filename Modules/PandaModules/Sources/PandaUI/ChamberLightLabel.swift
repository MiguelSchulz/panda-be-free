import SFSafeSymbols
import SwiftUI

/// Reusable label for the chamber light toggle button.
/// Wrap in a `Button` with either a closure (app) or an `AppIntent` (widget).
public struct ChamberLightLabel: View {
    public let isOn: Bool

    public init(isOn: Bool) {
        self.isOn = isOn
    }

    public var body: some View {
        Image(systemSymbol: isOn ? .lightbulbFill : .lightbulb)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isOn ? .yellow : .white.opacity(0.7))
            .padding(10)
            .background(.black.opacity(0.5), in: Circle())
    }
}
