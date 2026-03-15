import PandaModels
import SwiftUI
import WidgetKit

/// Compact Dynamic Island trailing view — circular progress ring or status text.
struct CompactTrailingView: View {
    let state: PrinterAttributes.ContentState

    private var endDate: Date {
        Date.now.addingTimeInterval(TimeInterval(state.remainingMinutes) * 60)
    }

    private var estimatedStartDate: Date {
        let remainingSec = TimeInterval(state.remainingMinutes) * 60
        let fraction = max(1.0 - Double(state.progress) / 100.0, 0.01)
        let totalDuration = remainingSec / fraction
        return endDate.addingTimeInterval(-totalDuration)
    }

    var body: some View {
        switch state.status {
        case .printing, .idle:
            if state.remainingMinutes > 0, state.progress < 100 {
                ProgressView(
                    timerInterval: estimatedStartDate...endDate,
                    countsDown: false,
                    label: { EmptyView() },
                    currentValueLabel: { EmptyView() }
                )
                .progressViewStyle(.circular)
                .tint(state.accentColor)
            } else {
                Text(state.trailingText)
                    .font(.caption)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundStyle(state.accentColor)
            }
        default:
            Text(state.trailingText)
                .font(.caption)
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundStyle(state.accentColor)
        }
    }
}
