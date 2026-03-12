import BambuModels
import BambuUI
import SFSafeSymbols
import SwiftUI
import UIKit
import WidgetKit

struct PrinterOverviewWidgetView: View {
    let entry: PrinterOverviewEntry

    var body: some View {
        if !SharedSettings.hasConfiguration {
            notConfiguredView
        } else {
            contentView
        }
    }

    // MARK: - Main Content

    private var contentView: some View {
        VStack(spacing: 4) {
            cameraSection
                .frame(maxWidth: .infinity)
                .clipShape(.rect(cornerRadius: 12))

            Spacer()

            printStateSection

            footerSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - Camera Section

    @ViewBuilder
    private var cameraSection: some View {
        switch entry.cameraState {
        case let .snapshot(imageData, _):
            if let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            } else {
                cameraErrorContent(message: "Invalid image data")
            }
        case .loading:
            VStack(spacing: 8) {
                Image(systemSymbol: .cameraFill)
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Loading camera...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .error(message):
            cameraErrorContent(message: message)
        }
    }

    private func cameraErrorContent(message: String) -> some View {
        ContentUnavailableView {
            Label("Camera Unavailable", systemSymbol: .cameraFill)
        } description: {
            Text(message)
        }
    }

    // MARK: - Print State Section

    @ViewBuilder
    private var printStateSection: some View {
        switch entry.printState {
        case let .data(contentState):
            PrintProgressContent(state: contentState)
                .invalidatableContent()
        case .loading:
            HStack {
                Image(systemSymbol: .printerFill)
                    .foregroundStyle(.secondary)
                Text("Loading status...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case let .error(message):
            HStack {
                Image(systemSymbol: .printerFill)
                    .foregroundStyle(.secondary)
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Text(entry.date, style: .relative)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .invalidatableContent()

            Button(intent: RefreshPrinterOverviewWidgetIntent()) {
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
