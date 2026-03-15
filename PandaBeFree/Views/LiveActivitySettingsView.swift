import PandaNotifications
import SFSafeSymbols
import SwiftUI

struct LiveActivitySettingsView: View {
    @State private var isEnabled = LiveActivitySettings.isEnabled

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                infoSection
                toggleSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Live Activity")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Info Section

private struct LiveActivityInfoSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("What is this?", systemSymbol: .infoCircleFill)
                .font(.headline)

            Text("Live Activities show your print progress on the Lock Screen and Dynamic Island. Since this app connects directly to your printer over your local network, the Live Activity can only receive real-time updates while the app is open.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Label("What to expect", systemSymbol: .clockFill)
                .font(.headline)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 6) {
                BulletPoint("Real-time updates while the app is in the foreground")
                BulletPoint("Estimated countdown timer continues in the background")
                BulletPoint("Widgets can refresh the Live Activity approximately every 15 minutes")
                BulletPoint("After about 2 minutes without an update, the activity shows estimated data \u{2014} open the app for live data")
            }

            Label("How it works", systemSymbol: .gearshapeFill)
                .font(.headline)
                .padding(.top, 4)

            Text("When a print starts, a Live Activity appears automatically. It ends when the print completes, is cancelled, or the printer goes idle.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
    }
}

// MARK: - Bullet Point

private struct BulletPoint: View {
    let text: LocalizedStringResource

    init(_ text: LocalizedStringResource) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\u{2022}")
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Toggle Section

private struct LiveActivityToggleSection: View {
    @Binding var isEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $isEnabled) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Live Activity")
                        Text("Show print progress on Lock Screen and Dynamic Island.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemSymbol: .timerCircleFill)
                }
            }
            .onChange(of: isEnabled) { _, newValue in
                LiveActivitySettings.isEnabled = newValue
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
    }
}

// MARK: - Extension

private extension LiveActivitySettingsView {
    var infoSection: some View {
        LiveActivityInfoSection()
    }

    var toggleSection: some View {
        LiveActivityToggleSection(isEnabled: $isEnabled)
    }
}

#Preview {
    NavigationStack {
        LiveActivitySettingsView()
    }
}
