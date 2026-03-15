import PandaModels
import SwiftUI
import WidgetKit

/// Minimal Dynamic Island view — circular progress or status icon.
struct MinimalView: View {
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
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .cancelled:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .paused:
            Image(systemName: "pause.circle.fill")
                .foregroundStyle(.yellow)
        case .issue:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        case .preparing:
            ProgressView()
                .progressViewStyle(.circular)
        case .printing, .idle:
            if state.remainingMinutes > 0, state.progress < 100 {
                ProgressView(
                    timerInterval: estimatedStartDate...endDate,
                    countsDown: false,
                    label: { EmptyView() },
                    currentValueLabel: { EmptyView() }
                )
                .progressViewStyle(.circular)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }
}
