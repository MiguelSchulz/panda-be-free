import PandaModels
import SFSafeSymbols
import SwiftUI
import WidgetKit

/// Expanded Dynamic Island bottom view — job name, progress bar, countdown/status.
struct ExpandedBottomView: View {
    let state: PrinterAttributes.ContentState
    let isStale: Bool

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
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemSymbol: state.iconName)
                    .foregroundStyle(state.accentColor)
                Text(state.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            progressSection

            if isStale {
                Text("Open app for live data")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var progressSection: some View {
        switch state.status {
        case .preparing:
            ProgressView()
                .progressViewStyle(.linear)
                .tint(.orange)
            HStack {
                Text("Preparing...")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                Spacer()
                if state.remainingMinutes > 0 {
                    Text(timerInterval: Date.now...endDate, countsDown: true)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        case .paused, .issue:
            ProgressView(value: Double(state.progress), total: 100)
                .tint(state.accentColor)
            HStack {
                if let stage = state.prepareStageLabel {
                    Text(stage)
                        .font(.caption2)
                        .foregroundStyle(state.accentColor)
                } else {
                    Text(state.stateLabel)
                        .font(.caption2)
                        .foregroundStyle(state.accentColor)
                }
                Spacer()
            }
        case .completed:
            ProgressView(value: 1.0, total: 1.0)
                .tint(.green)
            Text("Print complete!")
                .font(.caption2)
                .foregroundStyle(.green)
        case .cancelled:
            ProgressView(value: Double(state.progress), total: 100)
                .tint(.red)
            Text("Print cancelled")
                .font(.caption2)
                .foregroundStyle(.red)
        case .printing, .idle:
            if state.remainingMinutes > 0, state.progress < 100 {
                ProgressView(
                    timerInterval: estimatedStartDate...endDate,
                    countsDown: false,
                    label: { EmptyView() },
                    currentValueLabel: { EmptyView() }
                )
                .tint(.blue)
            } else {
                ProgressView(value: Double(state.progress), total: 100)
                    .tint(.blue)
            }
            HStack(spacing: 4) {
                if state.remainingMinutes > 0 {
                    Text(timerInterval: Date.now...endDate, countsDown: true)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("Estimated finish:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(endDate, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
