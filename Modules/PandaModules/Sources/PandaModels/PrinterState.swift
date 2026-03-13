import Foundation
import SwiftUI

@Observable
public final class PrinterState {
    // Raw MQTT values
    public var gcodeState = "UNKNOWN"
    public var stgCur: Int = -1
    public var progress = 0
    public var remainingMinutes = 0
    public var jobName = ""
    public var layerNum = 0
    public var totalLayers = 0
    public var nozzleTemp = 0
    public var nozzleTargetTemp = 0
    public var bedTemp = 0
    public var bedTargetTemp = 0
    public var chamberTemp = 0

    // Fan speeds (0–255, from fan_gear or converted from 0–15)
    public var partFanSpeed = 0
    public var auxFanSpeed = 0
    public var chamberFanSpeed = 0
    public var heatbreakFanSpeed = 0

    public var airductMode: Int = -1 // -1=unknown, 0=cooling, 1=heating

    public var homeFlag = 0 // 0 = not homed, non-zero = homed
    public var chamberLightOn = false

    // AMS
    public var amsUnits: [AMSUnit] = []
    public var activeTrayIndex: Int? // nil=none, parsed from tray_now
    private var pendingModuleVersions: [AMSModuleVersion] = [] // cached until AMS units exist

    public var isConnected = false
    public var lastUpdated: Date?

    public init() {}

    /// Convert raw MQTT state to ContentState for reusing existing UI components.
    public var contentState: PrinterAttributes.ContentState {
        let (status, category) = PreparationStages.determineState(
            gcodeState: gcodeState,
            stgCur: stgCur,
            layerNum: layerNum
        )
        let stageName = PreparationStages.name(for: stgCur)

        return PrinterAttributes.ContentState(
            progress: progress,
            remainingMinutes: remainingMinutes,
            jobName: jobName,
            layerNum: layerNum,
            totalLayers: totalLayers,
            status: status,
            prepareStage: stageName,
            stageCategory: category,
            nozzleTemp: nozzleTemp,
            bedTemp: bedTemp,
            nozzleTargetTemp: nozzleTargetTemp,
            bedTargetTemp: bedTargetTemp,
            chamberTemp: chamberTemp
        )
    }

    /// Apply a partial MQTT update. Only updates fields that are present in the payload.
    public func apply(_ payload: PandaMQTTPayload) {
        if let v = payload.gcodeState { gcodeState = v }
        if let v = payload.mcPercent { progress = v }
        if let v = payload.mcRemainingTime { remainingMinutes = v }
        if let v = payload.subtaskName { jobName = v }
        if let v = payload.layerNum { layerNum = v }
        if let v = payload.totalLayerNum { totalLayers = v }
        if let v = payload.stgCur { stgCur = v }
        if let v = payload.nozzleTemper { nozzleTemp = Int(v.rounded()) }
        if let v = payload.nozzleTargetTemper { nozzleTargetTemp = Int(v.rounded()) }
        if let v = payload.bedTemper { bedTemp = Int(v.rounded()) }
        if let v = payload.bedTargetTemper { bedTargetTemp = Int(v.rounded()) }
        if let v = payload.chamberTemper { chamberTemp = Int(v.rounded()) }
        if let v = payload.partFanSpeed { partFanSpeed = v }
        if let v = payload.auxFanSpeed { auxFanSpeed = v }
        if let v = payload.chamberFanSpeed { chamberFanSpeed = v }
        // Heatbreak comes from the jittery individual field (not fan_gear),
        // so suppress ±1 raw step changes (≈26 in 0–255 scale)
        if let v = payload.heatbreakFanSpeed, abs(v - heatbreakFanSpeed) > 26 || heatbreakFanSpeed == 0 {
            heatbreakFanSpeed = v
        }
        if let v = payload.airductMode { airductMode = v }
        if let v = payload.homeFlag { homeFlag = v }
        if let v = payload.chamberLightOn { chamberLightOn = v }

        // AMS active tray
        if let trayNow = payload.trayNow, let index = Int(trayNow) {
            activeTrayIndex = (index == 255 || index == 254) ? nil : index
        }

        // AMS units — merge partial updates
        if let parsedUnits = payload.amsUnits {
            let isBblBits = payload.trayIsBblBits.flatMap { UInt16($0, radix: 16) } ?? 0

            for parsed in parsedUnits {
                let unit: AMSUnit
                if let existing = amsUnits.first(where: { $0.id == parsed.id }) {
                    unit = existing
                } else {
                    let newUnit = AMSUnit(id: parsed.id)
                    amsUnits.append(newUnit)
                    amsUnits.sort { $0.id < $1.id }
                    unit = newUnit
                }

                if let v = parsed.humidity { unit.humidityLevel = v }
                if let v = parsed.humidityRaw { unit.humidityRaw = v }
                if let v = parsed.temp { unit.temperature = v }
                if let v = parsed.hwVersion { unit.hwVersion = v }
                if let v = parsed.dryTime { unit.dryTimeRemaining = v }

                for parsedTray in parsed.trays {
                    guard parsedTray.id >= 0, parsedTray.id < 4 else { continue }
                    var tray = unit.trays[parsedTray.id]

                    // Empty tray: only has "id", no type/color/remain
                    if parsedTray.trayType == nil, parsedTray.trayColor == nil, parsedTray.remain == nil {
                        tray.materialType = nil
                        tray.color = nil
                        tray.colorHex = nil
                        tray.remainPercent = nil
                        tray.isBambuFilament = false
                        tray.nozzleTempMin = nil
                        tray.nozzleTempMax = nil
                        tray.recommendedDryTemp = nil
                        tray.recommendedDryTime = nil
                        tray.traySubBrands = nil
                        tray.trayInfoIdx = nil
                    } else {
                        tray.materialType = parsedTray.trayType ?? tray.materialType
                        if let hex = parsedTray.trayColor {
                            tray.colorHex = hex
                            tray.color = AMSTray.parseColor(from: hex)
                        }
                        if let remain = parsedTray.remain {
                            tray.remainPercent = remain >= 0 ? remain : nil
                        }
                        let globalIdx = tray.globalIndex(amsId: parsed.id)
                        tray.isBambuFilament = (isBblBits >> globalIdx) & 1 == 1
                        tray.nozzleTempMin = parsedTray.nozzleTempMin ?? tray.nozzleTempMin
                        tray.nozzleTempMax = parsedTray.nozzleTempMax ?? tray.nozzleTempMax
                        tray.recommendedDryTemp = parsedTray.trayTemp ?? tray.recommendedDryTemp
                        tray.recommendedDryTime = parsedTray.trayTime ?? tray.recommendedDryTime
                        tray.traySubBrands = parsedTray.traySubBrands ?? tray.traySubBrands
                        tray.trayInfoIdx = parsedTray.trayInfoIdx ?? tray.trayInfoIdx
                    }

                    unit.trays[parsedTray.id] = tray
                }
            }
        }

        // AMS module versions from info messages
        if let modules = payload.amsModuleVersions {
            pendingModuleVersions = modules
        }
        // Apply cached module versions to AMS units
        if !pendingModuleVersions.isEmpty, !amsUnits.isEmpty {
            for mod in pendingModuleVersions {
                if let unit = amsUnits.first(where: { $0.id == mod.id }) {
                    unit.hwVersion = mod.hwVer
                }
            }
        }

        lastUpdated = Date.now
    }
}
