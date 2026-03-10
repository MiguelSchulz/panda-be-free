import SwiftUI
import UIKit
import WidgetKit

struct CameraWidgetView: View {
    let entry: CameraWidgetEntry

    var body: some View {
        switch entry.state {
        case .snapshot(let imageData, let capturedAt):
            if let uiImage = UIImage(data: imageData) {
                snapshotView(image: uiImage, capturedAt: capturedAt)
            } else {
                errorView(message: "Invalid image data")
            }
        case .loading:
            loadingView
        case .error(let message):
            errorView(message: message)
        case .notConfigured:
            notConfiguredView
        }
    }

    // MARK: - Snapshot

    private func snapshotView(image: UIImage, capturedAt: Date) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .overlay(alignment: .bottom) {
                HStack {
                    Text(capturedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.white)

                    Button(intent: RefreshCameraWidgetIntent()) {
                        Image(systemName: "arrow.clockwise")
                            .fontWeight(.semibold)
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.6), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 12)
                .padding(.horizontal, 8)
            }
            .containerBackground(.black, for: .widget)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 8) {
            Image(systemName: "camera.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Loading camera...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.background, for: .widget)
    }

    // MARK: - Error

    private func errorView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "camera.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Camera Unavailable")
                .font(.caption)
                .fontWeight(.medium)
            Text(message)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Button(intent: RefreshCameraWidgetIntent()) {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.caption2)
            }
            .buttonStyle(.bordered)
            .tint(.blue)
        }
        .padding()
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
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.background, for: .widget)
    }
}
