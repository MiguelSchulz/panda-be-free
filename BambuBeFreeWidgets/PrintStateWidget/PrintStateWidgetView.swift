import BambuModels
import BambuUI
import SFSafeSymbols
import SwiftUI
import WidgetKit

struct PrintStateWidgetView: View {
    let entry: PrintStateWidgetEntry

    var body: some View {
        switch entry.state {
        case let .data(contentState):
            dataView(state: contentState)
        case .loading:
            loadingView
        case let .error(message):
            errorView(message: message)
        case .notConfigured:
            notConfiguredView
        }
    }

    // MARK: - Data

    private func dataView(state: PrinterAttributes.ContentState) -> some View {
        VStack(spacing: 0) {
            PrintProgressContent(state: state)
                .invalidatableContent()

            HStack {
                Text(entry.date, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .invalidatableContent()

                Button(intent: RefreshPrintStateWidgetIntent()) {
                    Image(systemSymbol: .arrowClockwise)
                        .fontWeight(.semibold)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.fill.quaternary, in: Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 8) {
            Image(systemSymbol: .printerFill)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Loading status...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.background, for: .widget)
    }

    // MARK: - Error

    private func errorView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemSymbol: .printerFill)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Printer Unavailable")
                .font(.caption)
                .fontWeight(.medium)
            Text(message)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Button(intent: RefreshPrintStateWidgetIntent()) {
                Label("Retry", systemSymbol: .arrowClockwise)
                    .font(.caption2)
            }
            .buttonStyle(.bordered)
            .tint(.bambuBrand)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.background, for: .widget)
    }

    // MARK: - Not Configured

    private var notConfiguredView: some View {
        VStack(spacing: 8) {
            Image(systemSymbol: .printerFill)
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
