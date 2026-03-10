import BambuModels
import BambuUI
import SwiftUI
import WidgetKit

struct AMSWidgetView: View {
    let entry: AMSWidgetEntry

    var body: some View {
        switch entry.state {
        case .data(let unit, let activeTrayIndex):
            dataView(unit: unit, activeTrayIndex: activeTrayIndex)
        case .noAMS:
            noAMSView
        case .loading:
            loadingView
        case .error(let message):
            errorView(message: message)
        case .notConfigured:
            notConfiguredView
        }
    }

    // MARK: - Data

    private func dataView(unit: AMSUnitSnapshot, activeTrayIndex: Int?) -> some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                Label(unit.amsTypeName ?? "AMS", systemImage: "tray.2.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: humidityIcon(level: unit.humidityLevel))
                        .foregroundColor(humidityColor(level: unit.humidityLevel))
                        .font(.caption)
                    Text("\(unit.humidityRaw)%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()
                    .frame(height: 14)

                HStack(spacing: 2) {
                    Image(systemName: "thermometer.medium")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(Int(unit.temperature.rounded()))\u{00B0}C")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Tray slots
            HStack(spacing: 8) {
                ForEach(unit.trays, id: \.id) { traySnapshot in
                    let localActive = activeTrayInUnit(activeTrayIndex: activeTrayIndex, unitId: unit.id, trayId: traySnapshot.id)
                    AMSTrayView(
                        tray: traySnapshot.asTray,
                        slotLabel: "A\(traySnapshot.id + 1)",
                        isActive: localActive
                    )
                }
            }
            .invalidatableContent()

            // Footer: timestamp + refresh
            HStack {
                Text(entry.date, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .invalidatableContent()

                Button(intent: RefreshAMSWidgetIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .fontWeight(.semibold)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.fill.quaternary, in: Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func activeTrayInUnit(activeTrayIndex: Int?, unitId: Int, trayId: Int) -> Bool {
        guard let active = activeTrayIndex else { return false }
        let unitStart = unitId * 4
        return active - unitStart == trayId
    }

    private func humidityIcon(level: Int) -> String {
        switch level {
        case 1: "drop"
        case 2: "drop.fill"
        case 3: "drop.fill"
        case 4: "humidity.fill"
        case 5: "humidity.fill"
        default: "drop"
        }
    }

    private func humidityColor(level: Int) -> Color {
        switch level {
        case 1...2: .green
        case 3: .yellow
        case 4...5: .red
        default: .secondary
        }
    }

    // MARK: - No AMS

    private var noAMSView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray.2.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No AMS Detected")
                .font(.caption)
                .fontWeight(.medium)
            Text("No AMS unit connected to your printer.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(intent: RefreshAMSWidgetIntent()) {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.caption2)
            }
            .buttonStyle(.bordered)
            .tint(.blue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.background, for: .widget)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray.2.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Loading AMS...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.background, for: .widget)
    }

    // MARK: - Error

    private func errorView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "tray.2.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("AMS Unavailable")
                .font(.caption)
                .fontWeight(.medium)
            Text(message)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Button(intent: RefreshAMSWidgetIntent()) {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.caption2)
            }
            .buttonStyle(.bordered)
            .tint(.blue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.background, for: .widget)
    }

    // MARK: - Not Configured

    private var notConfiguredView: some View {
        VStack(spacing: 8) {
            Image(systemName: "printer.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No Printer Configured")
                .font(.caption)
                .fontWeight(.medium)
            Text("Open Bambu Companion to set up your printer.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.background, for: .widget)
    }
}
