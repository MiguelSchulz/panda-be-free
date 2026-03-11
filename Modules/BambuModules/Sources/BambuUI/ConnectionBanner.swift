import BambuModels
import SFSafeSymbols
import SwiftUI

/// Displays a contextual banner for the current MQTT connection state.
public struct ConnectionBanner: View {
    public let state: MQTTConnectionState

    public init(state: MQTTConnectionState) {
        self.state = state
    }

    public var body: some View {
        switch state {
        case .connecting:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Connecting to printer...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        case let .error(message):
            HStack(spacing: 8) {
                Image(systemSymbol: .exclamationmarkTriangleFill)
                    .foregroundColor(.red)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        case .disconnected:
            HStack(spacing: 8) {
                Image(systemSymbol: .wifiSlash)
                    .foregroundColor(.secondary)
                Text("Disconnected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        case .connected:
            EmptyView()
        }
    }
}

#Preview("Connecting") {
    ConnectionBanner(state: .connecting).padding()
}

#Preview("Error") {
    ConnectionBanner(state: .error("Connection timed out")).padding()
}

#Preview("Disconnected") {
    ConnectionBanner(state: .disconnected).padding()
}
