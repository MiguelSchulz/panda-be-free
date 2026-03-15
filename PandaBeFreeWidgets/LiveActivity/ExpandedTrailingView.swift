import PandaModels
import SwiftUI
import WidgetKit

/// Expanded Dynamic Island trailing view — status text for non-printing states only.
struct ExpandedTrailingView: View {
    let state: PrinterAttributes.ContentState

    var body: some View {
        switch state.status {
        case .completed, .cancelled, .paused, .issue, .preparing:
            HStack {
                Spacer()
                Text(state.trailingText)
                    .font(.headline)
                    .fontWeight(.bold)
                    .padding(.vertical, 2)
                    .monospacedDigit()
                    .foregroundStyle(state.accentColor)
                Spacer()
            }
        case .printing, .idle:
            EmptyView()
        }
    }
}
