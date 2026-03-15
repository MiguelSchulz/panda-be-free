import PandaModels
import SFSafeSymbols
import SwiftUI
import WidgetKit

/// Compact Dynamic Island leading view — shows printer icon or status icon.
struct CompactLeadingView: View {
    let state: PrinterAttributes.ContentState

    var body: some View {
        switch state.status {
        case .completed, .cancelled, .paused, .issue:
            Image(systemSymbol: state.iconName)
                .font(.body)
                .foregroundStyle(state.accentColor)
        case .preparing:
            ProgressView()
                .progressViewStyle(.circular)
        case .printing, .idle:
            Image(systemSymbol: .printerFill)
                .font(.body)
                .foregroundStyle(state.accentColor)
        }
    }
}
