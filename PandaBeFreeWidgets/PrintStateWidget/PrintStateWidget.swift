import Networking
import PandaModels
import PandaNotifications
import SwiftUI
import WidgetKit

// MARK: - Timeline Entry

struct PrintStateWidgetEntry: TimelineEntry {
    let date: Date
    let state: PrintStateWidgetState
    let refreshId = UUID()
}

enum PrintStateWidgetState: Sendable {
    case data(PrinterAttributes.ContentState)
    case loading
    case error(String)
    case notConfigured
}

// MARK: - Timeline Provider

struct PrintStateWidgetProvider: TimelineProvider {
    func placeholder(in _: Context) -> PrintStateWidgetEntry {
        PrintStateWidgetEntry(date: .now, state: .loading)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (PrintStateWidgetEntry) -> Void) {
        if context.isPreview {
            completion(PrintStateWidgetEntry(date: .now, state: .data(.mockPrinting)))
            return
        }
        if let cached = SharedSettings.cachedPrinterState {
            completion(PrintStateWidgetEntry(date: .now, state: .data(cached.contentState)))
        } else if SharedSettings.hasConfiguration {
            completion(PrintStateWidgetEntry(date: .now, state: .loading))
        } else {
            completion(PrintStateWidgetEntry(date: .now, state: .notConfigured))
        }
    }

    func getTimeline(in _: Context, completion: @escaping @Sendable (Timeline<PrintStateWidgetEntry>) -> Void) {
        guard SharedSettings.hasConfiguration else {
            let entry = PrintStateWidgetEntry(date: .now, state: .notConfigured)
            let timeline = Timeline(entries: [entry], policy: .after(Date.now.addingTimeInterval(60 * 60)))
            completion(timeline)
            return
        }

        // Fetch fresh data via MQTT
        Task {
            let entry: PrintStateWidgetEntry
            do {
                let snapshot = try await WidgetMQTTService.fetchSnapshot(
                    ip: SharedSettings.printerIP,
                    accessCode: SharedSettings.printerAccessCode,
                    serial: SharedSettings.printerSerial
                )
                SharedSettings.cachedPrinterState = snapshot
                let actions = NotificationEvaluator.evaluate(
                    contentState: snapshot.contentState,
                    amsUnits: snapshot.amsUnits
                )
                await LocalNotificationScheduler.shared.execute(actions)
                entry = PrintStateWidgetEntry(date: .now, state: .data(snapshot.contentState))
            } catch {
                // Fall back to stale cache if available
                if let cached = SharedSettings.cachedPrinterState {
                    entry = PrintStateWidgetEntry(date: .now, state: .data(cached.contentState))
                } else {
                    entry = PrintStateWidgetEntry(date: .now, state: .error(error.localizedDescription))
                }
            }
            let nextRefresh = Date.now.addingTimeInterval(15 * 60)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }
}

// MARK: - Widget Definition

struct PrintStateWidget: Widget {
    let kind = "PrintStateWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrintStateWidgetProvider()) { entry in
            PrintStateWidgetView(entry: entry)
        }
        .configurationDisplayName("Print Status")
        .description("Current print job status from your Bambu Lab 3D printer.")
        .supportedFamilies([.systemMedium])
    }
}
