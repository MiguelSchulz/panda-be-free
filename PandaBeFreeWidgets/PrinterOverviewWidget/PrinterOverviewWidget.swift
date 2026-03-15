import Networking
import PandaModels
import SwiftUI
import WidgetKit

// MARK: - Timeline Entry

struct PrinterOverviewEntry: TimelineEntry {
    let date: Date
    let cameraState: CameraHalfState
    let printState: PrintHalfState
    let isLightOn: Bool
}

enum CameraHalfState: Sendable {
    case snapshot(Data, capturedAt: Date)
    case loading
    case error(String)
}

enum PrintHalfState: Sendable {
    case data(PrinterAttributes.ContentState)
    case loading
    case error(String)
}

// MARK: - Timeline Provider

struct PrinterOverviewProvider: TimelineProvider {
    func placeholder(in _: Context) -> PrinterOverviewEntry {
        PrinterOverviewEntry(date: .now, cameraState: .loading, printState: .loading, isLightOn: false)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (PrinterOverviewEntry) -> Void) {
        let lightOn = SharedSettings.cachedPrinterState?.chamberLightOn ?? false
        if context.isPreview {
            completion(PrinterOverviewEntry(date: .now, cameraState: .loading, printState: .data(.mockPrinting), isLightOn: lightOn))
            return
        }

        let camState: CameraHalfState = if let data = SharedSettings.cachedSnapshotData,
           let cachedDate = SharedSettings.cachedSnapshotDate
        {
            .snapshot(data, capturedAt: cachedDate)
        } else {
            .loading
        }

        let prtState: PrintHalfState = if let cached = SharedSettings.cachedPrinterState {
            .data(cached.contentState)
        } else {
            .loading
        }

        completion(PrinterOverviewEntry(date: .now, cameraState: camState, printState: prtState, isLightOn: lightOn))
    }

    func getTimeline(in _: Context, completion: @escaping @Sendable (Timeline<PrinterOverviewEntry>) -> Void) {
        guard SharedSettings.hasConfiguration else {
            let entry = PrinterOverviewEntry(date: .now, cameraState: .loading, printState: .loading, isLightOn: false)
            let timeline = Timeline(entries: [entry], policy: .after(Date.now.addingTimeInterval(60 * 60)))
            completion(timeline)
            return
        }

        Task {
            async let cameraResult: CameraHalfState = {
                do {
                    let jpegData = try await CameraSnapshotService.captureSnapshot(
                        ip: SharedSettings.printerIP,
                        accessCode: SharedSettings.printerAccessCode,
                        printerType: SharedSettings.printerType
                    )
                    SharedSettings.cachedSnapshotData = jpegData
                    SharedSettings.cachedSnapshotDate = Date.now
                    return .snapshot(jpegData, capturedAt: .now)
                } catch {
                    if let data = SharedSettings.cachedSnapshotData,
                       let cachedDate = SharedSettings.cachedSnapshotDate
                    {
                        return .snapshot(data, capturedAt: cachedDate)
                    }
                    return .error(error.localizedDescription)
                }
            }()

            async let printResult: PrintHalfState = {
                do {
                    let snapshot = try await WidgetMQTTService.fetchSnapshot(
                        ip: SharedSettings.printerIP,
                        accessCode: SharedSettings.printerAccessCode,
                        serial: SharedSettings.printerSerial
                    )
                    SharedSettings.cachedPrinterState = snapshot
                    return .data(snapshot.contentState)
                } catch {
                    if let cached = SharedSettings.cachedPrinterState {
                        return .data(cached.contentState)
                    }
                    return .error(error.localizedDescription)
                }
            }()

            let cameraState = await cameraResult
            let printState = await printResult

            let lightOn = SharedSettings.cachedPrinterState?.chamberLightOn ?? false
            let entry = PrinterOverviewEntry(date: .now, cameraState: cameraState, printState: printState, isLightOn: lightOn)
            let nextRefresh = Date.now.addingTimeInterval(15 * 60)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }
}

// MARK: - Widget Definition

struct PrinterOverviewWidget: Widget {
    let kind = "PrinterOverviewWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrinterOverviewProvider()) { entry in
            PrinterOverviewWidgetView(entry: entry)
        }
        .configurationDisplayName("Printer Overview")
        .description("Camera snapshot and print status from your Bambu Lab 3D printer.")
        .supportedFamilies([.systemLarge])
    }
}
