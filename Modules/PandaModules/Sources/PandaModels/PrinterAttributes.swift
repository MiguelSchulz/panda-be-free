import ActivityKit
import Foundation
import SFSafeSymbols
import SwiftUI

// MARK: - Printer Status Enum

/// Type-safe representation of printer states.
public enum PrinterStatus: String, Codable, Hashable, Sendable {
    case preparing = "starting"
    case printing
    case paused
    case issue
    case completed
    case cancelled
    case idle
}

// MARK: - Printer Attributes

/// Shared data model for printer state display.
/// Used by the main app, widgets, Live Activity, and cached state snapshots.
public struct PrinterAttributes: ActivityAttributes, Sendable {
    public var printerName: String

    public init(printerName: String) {
        self.printerName = printerName
    }

    /// Dynamic content state for printer display.
    public struct ContentState: Codable, Hashable, Sendable {
        public var progress: Int // 0-100
        public var remainingMinutes: Int // ETA in minutes
        public var jobName: String // print job name (can be empty)
        public var layerNum: Int // current layer number
        public var totalLayers: Int // total layer count
        public var status: PrinterStatus // current printer state
        public var prepareStage: String? // stage description (e.g. "Auto bed leveling", "Nozzle clog")
        public var stageCategory: String? // "prepare", "calibrate", "paused", "filament", "issue"
        public var nozzleTemp: Int? // current nozzle temperature (°C)
        public var bedTemp: Int? // current bed temperature (°C)
        public var nozzleTargetTemp: Int? // target nozzle temperature (°C)
        public var bedTargetTemp: Int? // target bed temperature (°C)
        public var chamberTemp: Int? // current chamber temperature (°C)

        /// Map Swift property `status` to JSON key `state` for APNs wire compatibility
        enum CodingKeys: String, CodingKey {
            case progress, remainingMinutes, jobName, layerNum, totalLayers
            case status = "state"
            case prepareStage, stageCategory
            case nozzleTemp, bedTemp, nozzleTargetTemp, bedTargetTemp, chamberTemp
        }

        public init(
            progress: Int,
            remainingMinutes: Int,
            jobName: String,
            layerNum: Int,
            totalLayers: Int,
            status: PrinterStatus,
            prepareStage: String? = nil,
            stageCategory: String? = nil,
            nozzleTemp: Int? = nil,
            bedTemp: Int? = nil,
            nozzleTargetTemp: Int? = nil,
            bedTargetTemp: Int? = nil,
            chamberTemp: Int? = nil
        ) {
            self.progress = progress
            self.remainingMinutes = remainingMinutes
            self.jobName = jobName
            self.layerNum = layerNum
            self.totalLayers = totalLayers
            self.status = status
            self.prepareStage = prepareStage
            self.stageCategory = stageCategory
            self.nozzleTemp = nozzleTemp
            self.bedTemp = bedTemp
            self.nozzleTargetTemp = nozzleTargetTemp
            self.bedTargetTemp = bedTargetTemp
            self.chamberTemp = chamberTemp
        }
    }
}

// MARK: - Convenience

public extension PrinterAttributes.ContentState {
    var formattedTime: LocalizedStringResource {
        guard remainingMinutes > 0 else { return "<1m" }
        let hours = remainingMinutes / 60
        let mins = remainingMinutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }

    var formattedTimeRemaining: LocalizedStringResource {
        guard remainingMinutes > 0 else { return "<1m remaining" }
        let hours = remainingMinutes / 60
        let mins = remainingMinutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m remaining"
        }
        return "\(mins)m remaining"
    }

    var layerInfo: String? {
        guard totalLayers > 0 else { return nil }
        return "\(layerNum)/\(totalLayers)"
    }

    var displayTitle: String {
        jobName.isEmpty ? String(localized: "3D Print") : jobName
    }

    var temperatureInfo: LocalizedStringResource? {
        guard let nozzle = nozzleTemp, let bed = bedTemp else { return nil }
        let nozzleStr = if let target = nozzleTargetTemp, target > 0 {
            "\(nozzle)/\(target)°C"
        } else {
            "\(nozzle)°C"
        }
        let bedStr = if let target = bedTargetTemp, target > 0 {
            "\(bed)/\(target)°C"
        } else {
            "\(bed)°C"
        }
        if let chamber = chamberTemp, chamber > 0 {
            return "Nozzle \(nozzleStr) · Bed \(bedStr) · Chamber \(chamber)°C"
        }
        return "Nozzle \(nozzleStr) · Bed \(bedStr)"
    }

    var stateLabel: LocalizedStringResource {
        switch status {
        case .preparing:
            if stageCategory == "calibrate" { return "Calibrating" }
            return "Preparing"
        case .printing: return "Printing"
        case .paused:
            if stageCategory == "filament" { return "Filament" }
            return "Paused"
        case .issue: return "Issue"
        case .completed: return "Complete"
        case .cancelled: return "Cancelled"
        case .idle: return "Idle"
        }
    }

    /// Human-readable stage description, shown for preparing/paused/issue states
    var prepareStageLabel: String? {
        guard [.preparing, .paused, .issue].contains(status),
              let stage = prepareStage, !stage.isEmpty else { return nil }
        return stage
    }
}

// MARK: - UI Helpers

public extension PrinterAttributes.ContentState {
    var iconName: SFSymbol {
        switch status {
        case .completed: .checkmarkCircleFill
        case .cancelled: .xmarkCircleFill
        case .paused: .pauseCircleFill
        case .issue: .exclamationmarkTriangleFill
        case .preparing, .printing, .idle: .printerFill
        }
    }

    var accentColor: Color {
        switch status {
        case .completed: .green
        case .cancelled: .red
        case .preparing: .orange
        case .paused: .yellow
        case .issue: .red
        case .printing, .idle: .blue
        }
    }

    var compactLeadingTemp: String {
        if let chamber = chamberTemp, chamber > 0 {
            return "\(chamber)°"
        }
        if let nozzle = nozzleTemp, nozzle > 0 {
            return "\(nozzle)°"
        }
        return "—"
    }

    /// Abbreviated temperature lines for compact display: "N 150/220", "B 45/60", "C 28"
    struct TempLine: Identifiable, Sendable {
        public let id: String // "N", "B", "C"
        public let label: String
        public let text: String

        public init(id: String, label: String, text: String) {
            self.id = id
            self.label = label
            self.text = text
        }
    }

    var compactTemperatureLines: [TempLine] {
        var lines: [TempLine] = []
        if let nozzle = nozzleTemp {
            let text = if let target = nozzleTargetTemp, target > 0 {
                "\(nozzle)/\(target)"
            } else {
                "\(nozzle)"
            }
            lines.append(TempLine(id: "N", label: "N", text: text))
        }
        if let bed = bedTemp {
            let text = if let target = bedTargetTemp, target > 0 {
                "\(bed)/\(target)"
            } else {
                "\(bed)"
            }
            lines.append(TempLine(id: "B", label: "B", text: text))
        }
        if let chamber = chamberTemp, chamber > 0 {
            lines.append(TempLine(id: "C", label: "C", text: "\(chamber)"))
        }
        return lines
    }

    var trailingText: LocalizedStringResource {
        switch status {
        case .completed: "Done"
        case .cancelled: "Stop"
        case .preparing: "..."
        case .paused: "\(progress)%"
        case .issue: "!"
        case .printing, .idle: "\(progress)%"
        }
    }
}

// MARK: - Preview Mock Data

public extension PrinterAttributes.ContentState {
    static let mockPrinting = PrinterAttributes.ContentState(
        progress: 42,
        remainingMinutes: 83,
        jobName: "Benchy",
        layerNum: 150,
        totalLayers: 300,
        status: .printing,
        nozzleTemp: 220,
        bedTemp: 60,
        chamberTemp: 38
    )

    static let mockStarting = PrinterAttributes.ContentState(
        progress: 0,
        remainingMinutes: 240,
        jobName: "Phone Stand",
        layerNum: 0,
        totalLayers: 500,
        status: .preparing,
        prepareStage: "Auto bed leveling",
        nozzleTemp: 150,
        bedTemp: 45,
        nozzleTargetTemp: 220,
        bedTargetTemp: 60,
        chamberTemp: 28
    )

    static let mockCompleted = PrinterAttributes.ContentState(
        progress: 100,
        remainingMinutes: 0,
        jobName: "Benchy",
        layerNum: 300,
        totalLayers: 300,
        status: .completed
    )

    static let mockCancelled = PrinterAttributes.ContentState(
        progress: 37,
        remainingMinutes: 0,
        jobName: "Phone Case",
        layerNum: 111,
        totalLayers: 300,
        status: .cancelled
    )

    static let mockPaused = PrinterAttributes.ContentState(
        progress: 42,
        remainingMinutes: 83,
        jobName: "Benchy",
        layerNum: 150,
        totalLayers: 300,
        status: .paused,
        prepareStage: "Changing filament",
        stageCategory: "filament",
        nozzleTemp: 220,
        bedTemp: 60,
        chamberTemp: 38
    )

    static let mockIssue = PrinterAttributes.ContentState(
        progress: 42,
        remainingMinutes: 83,
        jobName: "Benchy",
        layerNum: 150,
        totalLayers: 300,
        status: .issue,
        prepareStage: "Paused: nozzle clog",
        stageCategory: "issue",
        nozzleTemp: 220,
        bedTemp: 60,
        chamberTemp: 38
    )
}

public extension PrinterAttributes {
    static let preview = PrinterAttributes(printerName: "Bambu Lab P1S")
}
