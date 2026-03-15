import PandaModels
import SwiftUI
import WidgetKit

/// Expanded Dynamic Island leading view — status badge for non-printing states only.
struct ExpandedLeadingView: View {
    let state: PrinterAttributes.ContentState

    var body: some View {
        switch state.status {
        case .preparing, .paused, .issue, .completed, .cancelled:
            HStack {
                Spacer()
                Text(state.stateLabel)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(state.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(state.accentColor.opacity(0.2))
                    .clipShape(Capsule())
                    .lineLimit(1)
                Spacer()
            }
        case .printing, .idle:
            EmptyView()
        }
    }
}
