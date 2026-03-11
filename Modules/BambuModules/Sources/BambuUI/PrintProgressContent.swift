import BambuModels
import SwiftUI

/// Shared print progress view content used by both the dashboard (PrintProgressSection)
/// and the Print State Widget. Contains status header, progress bar, and detail row
/// without any container styling.
public struct PrintProgressContent: View {
    public let state: PrinterAttributes.ContentState

    public init(state: PrinterAttributes.ContentState) {
        self.state = state
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status header: icon + job name + state badge
            HStack {
                Image(systemName: state.iconName)
                    .foregroundColor(state.accentColor)
                Text(state.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(state.stateLabel)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(state.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(state.accentColor.opacity(0.2))
                    .clipShape(Capsule())
            }

            // Prepare stage label
            if let stage = state.prepareStageLabel {
                Label(stage, systemImage: "gearshape.2")
                    .font(.subheadline)
                    .foregroundColor(state.accentColor)
            }

            // Progress bar
            switch state.status {
            case .preparing:
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(.blue)
            case .paused:
                ProgressView(value: Double(state.progress), total: 100)
                    .tint(.yellow)
            case .issue:
                ProgressView(value: Double(state.progress), total: 100)
                    .tint(.red)
            case .printing, .completed, .cancelled, .idle:
                ProgressView(value: Double(state.progress), total: 100)
                    .tint(state.accentColor)
            }

            // Bottom row: percentage + layers + ETA
            HStack(alignment: .firstTextBaseline) {
                Text("\(state.progress)%")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(state.accentColor)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    if let layers = state.layerInfo {
                        Label("Layer \(layers)", systemImage: "square.stack.3d.up")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if state.remainingMinutes > 0 {
                        Label(state.formattedTime + " remaining", systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if state.status == .completed {
                        Text("Print complete!")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    if state.status == .cancelled {
                        Text("Print cancelled")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }
}
