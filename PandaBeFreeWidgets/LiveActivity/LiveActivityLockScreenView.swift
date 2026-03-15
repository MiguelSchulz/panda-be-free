import PandaModels
import SFSafeSymbols
import SwiftUI
import WidgetKit

struct LiveActivityLockScreenView: View {
    let state: PrinterAttributes.ContentState
    let isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TopRow(state: state)
            LiveActivityProgressBar(state: state)
            BottomRow(state: state, isStale: isStale)
        }
        .padding()
        .activityBackgroundTint(Color.black.opacity(0.6))
    }
}

// MARK: - Top Row

private struct TopRow: View {
    let state: PrinterAttributes.ContentState

    var body: some View {
        HStack {
            Image(systemSymbol: state.iconName)
                .foregroundStyle(state.accentColor)
            Text(state.displayTitle)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            Text(state.stateLabel)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(state.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(state.accentColor.opacity(0.2))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Progress Bar

private struct LiveActivityProgressBar: View {
    let state: PrinterAttributes.ContentState

    var body: some View {
        switch state.status {
        case .preparing:
            ProgressView()
                .progressViewStyle(.linear)
                .tint(.orange)
        case .printing, .idle:
            if state.remainingMinutes > 0, state.progress < 100 {
                ProgressView(
                    timerInterval: estimatedStartDate...estimatedEndDate,
                    countsDown: false,
                    label: { EmptyView() },
                    currentValueLabel: { EmptyView() }
                )
                .tint(.blue)
            } else {
                ProgressView(value: Double(state.progress), total: 100)
                    .tint(.blue)
            }
        case .paused:
            ProgressView(value: Double(state.progress), total: 100)
                .tint(.yellow)
        case .issue:
            ProgressView(value: Double(state.progress), total: 100)
                .tint(.red)
        case .completed:
            ProgressView(value: 1.0, total: 1.0)
                .tint(.green)
        case .cancelled:
            ProgressView(value: Double(state.progress), total: 100)
                .tint(.red)
        }
    }

    private var estimatedEndDate: Date {
        Date.now.addingTimeInterval(TimeInterval(state.remainingMinutes) * 60)
    }

    private var estimatedStartDate: Date {
        let remainingSec = TimeInterval(state.remainingMinutes) * 60
        let fraction = max(1.0 - Double(state.progress) / 100.0, 0.01)
        let totalDuration = remainingSec / fraction
        return estimatedEndDate.addingTimeInterval(-totalDuration)
    }
}

// MARK: - Bottom Row

private struct BottomRow: View {
    let state: PrinterAttributes.ContentState
    let isStale: Bool

    private var endDate: Date {
        Date.now.addingTimeInterval(TimeInterval(state.remainingMinutes) * 60)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                switch state.status {
                case .preparing:
                    Label("Preparing...", systemImage: "gearshape.2")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Spacer()
                    if state.remainingMinutes > 0 {
                        Text(timerInterval: Date.now...endDate, countsDown: true)
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                case .printing, .idle:
                    VStack(alignment: .leading, spacing: 2) {
                        if state.remainingMinutes > 0 {
                            Text(timerInterval: Date.now...endDate, countsDown: true)
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Text("Estimated finish:")
                                Text(endDate, style: .time)
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                case .paused, .issue:
                    if let stage = state.prepareStageLabel {
                        Label(stage, systemSymbol: state.iconName)
                            .font(.caption)
                            .foregroundStyle(state.accentColor)
                    }
                    Spacer()
                case .completed:
                    Spacer()
                    Text("Print complete!")
                        .font(.caption)
                        .foregroundStyle(.green)
                case .cancelled:
                    Spacer()
                    Text("Print cancelled")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if isStale {
                Text("Open app for live data")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
