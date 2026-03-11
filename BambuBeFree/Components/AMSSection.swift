import BambuModels
import BambuUI
import SFSafeSymbols
import SwiftUI

struct AMSSection: View {
    @Bindable var viewModel: DashboardViewModel
    let amsUnit: AMSUnit

    private var headerLabel: String {
        let name = amsUnit.amsType.map { String(localized: $0.displayName) } ?? String(localized: "AMS")
        if viewModel.printerState.amsUnits.count > 1 {
            return "\(name) \(amsUnit.id + 1)"
        }
        return name
    }

    private var activeTrayInThisUnit: Int? {
        guard let active = viewModel.printerState.activeTrayIndex else { return nil }
        let unitStart = amsUnit.id * 4
        let localIndex = active - unitStart
        return (0...3).contains(localIndex) ? localIndex : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            traySlots
            dryingControls
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var header: some View {
        HStack {
            Label(headerLabel, systemSymbol: .tray2Fill)
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()

            HStack(spacing: 4) {
                Image(systemSymbol: humidityIcon)
                    .foregroundColor(humidityColor)
                    .font(.caption)
                Text("\(amsUnit.humidityRaw)%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()
                .frame(height: 14)

            HStack(spacing: 2) {
                Image(systemSymbol: .thermometerMedium)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(Int(amsUnit.temperature.rounded()))\u{00B0}C")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var humidityIcon: SFSymbol {
        switch amsUnit.humidityLevel {
        case 1: .drop
        case 2: .dropFill
        case 3: .dropFill
        case 4: .humidityFill
        case 5: .humidityFill
        default: .drop
        }
    }

    private var humidityColor: Color {
        switch amsUnit.humidityLevel {
        case 1...2: .green
        case 3: .yellow
        case 4...5: .red
        default: .secondary
        }
    }

    private var traySlots: some View {
        HStack(spacing: 8) {
            ForEach(amsUnit.trays) { tray in
                AMSTrayView(
                    tray: tray,
                    slotLabel: "A\(tray.id + 1)",
                    isActive: tray.id == activeTrayInThisUnit,
                    onTap: {
                        viewModel.showFilamentEdit(amsId: amsUnit.id, tray: tray)
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var dryingControls: some View {
        if amsUnit.isDrying {
            HStack {
                Image(systemSymbol: .flameFill)
                    .foregroundColor(.orange)
                Text("Drying \u{2014} \(amsUnit.dryTimeFormatted) remaining")
                    .font(.caption)
                Spacer()
                Button("Stop") {
                    viewModel.confirmStopDrying(amsId: amsUnit.id)
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .tint(.red)
            }
        } else {
            Button {
                viewModel.showStartDrying(amsId: amsUnit.id)
            } label: {
                Label("Start Drying", systemSymbol: .flame)
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.contentState.status != .idle)
        }
    }
}

#Preview {
    AMSSection(viewModel: .preview, amsUnit: DashboardViewModel.preview.printerState.amsUnits[0])
        .padding()
}
