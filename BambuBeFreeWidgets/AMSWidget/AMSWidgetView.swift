import BambuModels
import BambuUI
import SFSafeSymbols
import SwiftUI
import WidgetKit

struct AMSWidgetView: View {
    let entry: AMSWidgetEntry

    var body: some View {
        switch entry.state {
        case let .data(unit, activeTrayIndex):
            dataView(unit: unit, activeTrayIndex: activeTrayIndex)
        case .noAMS:
            noAMSView
        case .loading:
            loadingView
        case let .error(message):
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
                Label {
                    if let name = unit.amsTypeName {
                        Text(name)
                    } else {
                        Text("AMS")
                    }
                } icon: {
                    Image(systemSymbol: .tray2Fill)
                }
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemSymbol: humidityIcon(level: unit.humidityLevel))
                        .foregroundStyle(humidityColor(level: unit.humidityLevel))
                        .font(.caption)
                    Text("\(unit.humidityRaw)%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()
                    .frame(height: 14)

                HStack(spacing: 2) {
                    Image(systemSymbol: .thermometerMedium)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(Int(unit.temperature.rounded()))\u{00B0}C")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                    Image(systemSymbol: .arrowClockwise)
                        .fontWeight(.semibold)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.fill.quaternary, in: Capsule())
                }
                .accessibilityLabel("Refresh")
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

    private func humidityIcon(level: Int) -> SFSymbol {
        switch level {
        case 1: .drop
        case 2: .dropFill
        case 3: .dropFill
        case 4: .humidityFill
        case 5: .humidityFill
        default: .drop
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
        ContentUnavailableView {
            Label("No AMS Detected", systemSymbol: .tray2Fill)
        } description: {
            Text("No AMS unit connected to your printer.")
        } actions: {
            Button(intent: RefreshAMSWidgetIntent()) {
                Label("Retry", systemSymbol: .arrowClockwise)
                    .font(.caption2)
            }
            .buttonStyle(.bordered)
            .tint(.bambuBrand)
        }
        .containerBackground(.background, for: .widget)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 8) {
            Image(systemSymbol: .tray2Fill)
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
        ContentUnavailableView {
            Label("AMS Unavailable", systemSymbol: .tray2Fill)
        } description: {
            Text(message)
        } actions: {
            Button(intent: RefreshAMSWidgetIntent()) {
                Label("Retry", systemSymbol: .arrowClockwise)
                    .font(.caption2)
            }
            .buttonStyle(.bordered)
            .tint(.bambuBrand)
        }
        .containerBackground(.background, for: .widget)
    }

    // MARK: - Not Configured

    private var notConfiguredView: some View {
        ContentUnavailableView {
            Label("No Printer Configured", systemSymbol: .printerFill)
        } description: {
            Text("Open Bambu Companion to set up your printer.")
        }
        .containerBackground(.background, for: .widget)
    }
}
