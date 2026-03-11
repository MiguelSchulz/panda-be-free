import BambuModels
import Networking
import SwiftUI
import WidgetKit

// MARK: - Timeline Entry

struct AMSWidgetEntry: TimelineEntry {
    let date: Date
    let state: AMSWidgetState
    let refreshId = UUID()
}

enum AMSWidgetState: Sendable {
    case data(AMSUnitSnapshot, activeTrayIndex: Int?)
    case noAMS
    case loading
    case error(String)
    case notConfigured
}

// MARK: - Timeline Provider

struct AMSWidgetProvider: TimelineProvider {
    func placeholder(in _: Context) -> AMSWidgetEntry {
        AMSWidgetEntry(date: .now, state: .loading)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (AMSWidgetEntry) -> Void) {
        if context.isPreview {
            completion(AMSWidgetEntry(date: .now, state: .data(AMSUnitSnapshot.mock, activeTrayIndex: 1)))
            return
        }
        if let cached = SharedSettings.cachedPrinterState {
            if let firstUnit = cached.amsUnits.first {
                completion(AMSWidgetEntry(date: .now, state: .data(firstUnit, activeTrayIndex: cached.activeTrayIndex)))
            } else {
                completion(AMSWidgetEntry(date: .now, state: .noAMS))
            }
        } else if SharedSettings.hasConfiguration {
            completion(AMSWidgetEntry(date: .now, state: .loading))
        } else {
            completion(AMSWidgetEntry(date: .now, state: .notConfigured))
        }
    }

    func getTimeline(in _: Context, completion: @escaping @Sendable (Timeline<AMSWidgetEntry>) -> Void) {
        guard SharedSettings.hasConfiguration else {
            let entry = AMSWidgetEntry(date: .now, state: .notConfigured)
            let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60 * 60)))
            completion(timeline)
            return
        }

        // If cache was just written (by app or refresh intent), use it directly
        if let cached = SharedSettings.cachedPrinterState,
           Date().timeIntervalSince(cached.lastUpdated) < 15
        {
            let entry = amsEntry(from: cached)
            let nextRefresh = Date().addingTimeInterval(15 * 60)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
            return
        }

        // Fetch fresh data via MQTT (matches camera widget pattern)
        Task {
            let entry: AMSWidgetEntry
            do {
                let snapshot = try await WidgetMQTTService.fetchSnapshot(
                    ip: SharedSettings.printerIP,
                    accessCode: SharedSettings.printerAccessCode
                )
                SharedSettings.cachedPrinterState = snapshot
                entry = amsEntry(from: snapshot)
            } catch {
                // Fall back to stale cache if available
                if let cached = SharedSettings.cachedPrinterState {
                    entry = amsEntry(from: cached)
                } else {
                    entry = AMSWidgetEntry(date: .now, state: .error(error.localizedDescription))
                }
            }
            let nextRefresh = Date().addingTimeInterval(15 * 60)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    private func amsEntry(from snapshot: PrinterStateSnapshot) -> AMSWidgetEntry {
        if let firstUnit = snapshot.amsUnits.first {
            AMSWidgetEntry(date: .now, state: .data(firstUnit, activeTrayIndex: snapshot.activeTrayIndex))
        } else {
            AMSWidgetEntry(date: .now, state: .noAMS)
        }
    }
}

// MARK: - Widget Definition

struct AMSWidget: Widget {
    let kind = "AMSWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AMSWidgetProvider()) { entry in
            AMSWidgetView(entry: entry)
        }
        .configurationDisplayName("AMS Filaments")
        .description("Filament slots in your Bambu Lab AMS unit.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Preview Mock

extension AMSUnitSnapshot {
    static let mock = AMSUnitSnapshot(
        id: 0,
        amsTypeName: "AMS",
        humidityLevel: 2,
        humidityRaw: 35,
        temperature: 26.5,
        dryTimeRemaining: 0,
        trays: [
            AMSTraySnapshot(id: 0, materialType: "PLA", colorHex: "FFFF00FF", remainPercent: 85, isBambuFilament: true),
            AMSTraySnapshot(id: 1, materialType: "ABS", colorHex: "FF0000FF", remainPercent: 42, isBambuFilament: true),
            AMSTraySnapshot(id: 2, materialType: "PETG", colorHex: "0000FFFF", remainPercent: nil, isBambuFilament: false),
            AMSTraySnapshot(id: 3, materialType: nil, colorHex: nil, remainPercent: nil, isBambuFilament: false),
        ]
    )
}
