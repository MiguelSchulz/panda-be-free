import BambuModels
import Networking
import SwiftUI
import WidgetKit

// MARK: - Timeline Entry

struct CameraWidgetEntry: TimelineEntry {
    let date: Date
    let state: CameraWidgetState
}

enum CameraWidgetState: Sendable {
    case snapshot(Data, capturedAt: Date)
    case loading
    case error(String)
    case notConfigured
}

// MARK: - Timeline Provider

struct CameraWidgetProvider: TimelineProvider {
    func placeholder(in _: Context) -> CameraWidgetEntry {
        CameraWidgetEntry(date: .now, state: .loading)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (CameraWidgetEntry) -> Void) {
        if context.isPreview {
            completion(CameraWidgetEntry(date: .now, state: .loading))
            return
        }
        if let data = SharedSettings.cachedSnapshotData,
           let cachedDate = SharedSettings.cachedSnapshotDate
        {
            completion(CameraWidgetEntry(date: .now, state: .snapshot(data, capturedAt: cachedDate)))
        } else if SharedSettings.hasConfiguration {
            completion(CameraWidgetEntry(date: .now, state: .loading))
        } else {
            completion(CameraWidgetEntry(date: .now, state: .notConfigured))
        }
    }

    func getTimeline(in _: Context, completion: @escaping @Sendable (Timeline<CameraWidgetEntry>) -> Void) {
        guard SharedSettings.hasConfiguration else {
            let entry = CameraWidgetEntry(date: .now, state: .notConfigured)
            let timeline = Timeline(entries: [entry], policy: .after(Date.now.addingTimeInterval(60 * 60)))
            completion(timeline)
            return
        }

        Task {
            let entry: CameraWidgetEntry

            do {
                let jpegData = try await CameraSnapshotService.captureSnapshot(
                    ip: SharedSettings.printerIP,
                    accessCode: SharedSettings.printerAccessCode,
                    printerType: SharedSettings.printerType
                )

                SharedSettings.cachedSnapshotData = jpegData
                SharedSettings.cachedSnapshotDate = Date.now

                entry = CameraWidgetEntry(date: .now, state: .snapshot(jpegData, capturedAt: .now))
            } catch {
                if let data = SharedSettings.cachedSnapshotData,
                   let cachedDate = SharedSettings.cachedSnapshotDate
                {
                    entry = CameraWidgetEntry(date: .now, state: .snapshot(data, capturedAt: cachedDate))
                } else {
                    entry = CameraWidgetEntry(
                        date: .now,
                        state: .error(error.localizedDescription)
                    )
                }
            }

            let nextRefresh = Date.now.addingTimeInterval(15 * 60)
            let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
            completion(timeline)
        }
    }
}

// MARK: - Widget Definition

struct CameraWidget: Widget {
    let kind = "CameraWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CameraWidgetProvider()) { entry in
            CameraWidgetView(entry: entry)
        }
        .configurationDisplayName("Printer Camera")
        .description("Live snapshot from your Bambu Lab 3D printer camera.")
        .supportedFamilies([.systemMedium])
    }
}
