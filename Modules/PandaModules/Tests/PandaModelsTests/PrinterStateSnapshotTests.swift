import Foundation
@testable import PandaModels
import Testing

@Suite("Printer State Snapshot")
struct PrinterStateSnapshotTests {
    // MARK: - AMSTraySnapshot

    @Test("AMSTraySnapshot default init has nil optionals and isBambuFilament false")
    func traySnapshotDefaults() {
        let snapshot = AMSTraySnapshot(id: 0)
        #expect(snapshot.materialType == nil)
        #expect(snapshot.colorHex == nil)
        #expect(snapshot.remainPercent == nil)
        #expect(snapshot.isBambuFilament == false)
    }

    @Test("AMSTraySnapshot.asTray reconstructs all fields")
    func traySnapshotAsTray() {
        let snapshot = AMSTraySnapshot(
            id: 2,
            materialType: "PLA",
            colorHex: "FFFF00FF",
            remainPercent: 85,
            isBambuFilament: true
        )
        let tray = snapshot.asTray
        #expect(tray.id == 2)
        #expect(tray.materialType == "PLA")
        #expect(tray.colorHex == "FFFF00FF")
        #expect(tray.color != nil)
        #expect(tray.remainPercent == 85)
        #expect(tray.isBambuFilament == true)
    }

    @Test("AMSTraySnapshot.asTray with nil fields produces empty tray")
    func traySnapshotNilFields() {
        let snapshot = AMSTraySnapshot(id: 0)
        let tray = snapshot.asTray
        #expect(tray.isEmpty == true)
        #expect(tray.color == nil)
        #expect(tray.remainPercent == nil)
    }

    // MARK: - AMSUnitSnapshot

    @Test("AMSUnitSnapshot.isDrying reflects dryTimeRemaining",
          arguments: [
              (0, false),
              (1, true),
              (60, true),
          ])
    func unitSnapshotIsDrying(dryTime: Int, expected: Bool) {
        let snapshot = AMSUnitSnapshot(id: 0, dryTimeRemaining: dryTime)
        #expect(snapshot.isDrying == expected)
    }

    @Test("AMSUnitSnapshot.dryTimeFormatted",
          arguments: [
              (45, "45m"),
              (90, "1h 30m"),
              (120, "2h 0m"),
              (0, "0m"),
          ])
    func unitSnapshotDryTimeFormatted(minutes: Int, expected: String) {
        let snapshot = AMSUnitSnapshot(id: 0, dryTimeRemaining: minutes)
        #expect(snapshot.dryTimeFormatted == expected)
    }

    // MARK: - PrinterStateSnapshot Codable

    @Test("PrinterStateSnapshot Codable round-trip preserves all fields")
    func codableRoundTrip() throws {
        let traySnapshot = AMSTraySnapshot(id: 0, materialType: "PLA", colorHex: "FF0000FF",
                                           remainPercent: 50, isBambuFilament: true)
        let unitSnapshot = AMSUnitSnapshot(id: 0, amsTypeName: "AMS 2 Pro",
                                           humidityLevel: 3, humidityRaw: 47,
                                           temperature: 24.5, dryTimeRemaining: 60,
                                           trays: [traySnapshot])

        let contentState = PrinterAttributes.ContentState(
            progress: 42, remainingMinutes: 83, jobName: "Benchy",
            layerNum: 150, totalLayers: 300, status: .printing,
            prepareStage: nil, stageCategory: nil,
            nozzleTemp: 220, bedTemp: 60,
            nozzleTargetTemp: 220, bedTargetTemp: 60, chamberTemp: 38
        )

        let original = try makeSnapshot(
            contentState: contentState,
            amsUnits: [unitSnapshot],
            activeTrayIndex: 0,
            chamberLightOn: true,
            lastUpdated: Date(timeIntervalSince1970: 1_000_000)
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PrinterStateSnapshot.self, from: data)

        #expect(decoded.contentState.progress == 42)
        #expect(decoded.contentState.jobName == "Benchy")
        #expect(decoded.amsUnits.count == 1)
        #expect(decoded.amsUnits[0].amsTypeName == "AMS 2 Pro")
        #expect(decoded.amsUnits[0].trays[0].materialType == "PLA")
        #expect(decoded.activeTrayIndex == 0)
        #expect(decoded.chamberLightOn == true)
        #expect(decoded.lastUpdated.timeIntervalSince1970 == 1_000_000)
    }

    @Test("Decoding without chamberLightOn key defaults to false")
    func decodingMissingChamberLight() throws {
        // Build JSON manually without chamberLightOn key
        let contentState = PrinterAttributes.ContentState(
            progress: 0, remainingMinutes: 0, jobName: "",
            layerNum: 0, totalLayers: 0, status: .idle,
            prepareStage: nil, stageCategory: nil,
            nozzleTemp: 0, bedTemp: 0,
            nozzleTargetTemp: 0, bedTargetTemp: 0, chamberTemp: 0
        )
        let snapshot = try makeSnapshot(
            contentState: contentState,
            amsUnits: [],
            activeTrayIndex: nil,
            chamberLightOn: true,
            lastUpdated: Date.now
        )

        // Encode, then remove chamberLightOn from the dictionary
        let data = try JSONEncoder().encode(snapshot)
        var dict = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        dict.removeValue(forKey: "chamberLightOn")
        let modifiedData = try JSONSerialization.data(withJSONObject: dict)

        let decoded = try JSONDecoder().decode(PrinterStateSnapshot.self, from: modifiedData)
        #expect(decoded.chamberLightOn == false)
    }

    @Test("Init from PrinterState maps all fields correctly")
    func initFromPrinterState() {
        let state = PrinterState()
        state.gcodeState = "RUNNING"
        state.progress = 42
        state.nozzleTemp = 220
        state.nozzleTargetTemp = 220
        state.bedTemp = 60
        state.bedTargetTemp = 60
        state.chamberTemp = 38
        state.jobName = "Benchy"
        state.layerNum = 150
        state.totalLayers = 300
        state.remainingMinutes = 83
        state.chamberLightOn = true
        state.lastUpdated = Date(timeIntervalSince1970: 1_000_000)

        let amsUnit = AMSUnit(id: 0)
        amsUnit.hwVersion = "N3F05"
        amsUnit.humidityLevel = 3
        amsUnit.trays[0] = AMSTray(id: 0, materialType: "PLA", colorHex: "FFFF00FF",
                                   remainPercent: 85, isBambuFilament: true)
        state.amsUnits = [amsUnit]
        state.activeTrayIndex = 0

        let snapshot = PrinterStateSnapshot(from: state)

        #expect(snapshot.contentState.progress == 42)
        #expect(snapshot.contentState.jobName == "Benchy")
        #expect(snapshot.amsUnits.count == 1)
        #expect(snapshot.amsUnits[0].amsTypeName == "AMS 2 Pro")
        #expect(snapshot.amsUnits[0].humidityLevel == 3)
        #expect(snapshot.amsUnits[0].trays[0].materialType == "PLA")
        #expect(snapshot.activeTrayIndex == 0)
        #expect(snapshot.chamberLightOn == true)
        #expect(snapshot.lastUpdated.timeIntervalSince1970 == 1_000_000)
    }

    @Test("Init from PrinterState with nil lastUpdated uses Date.now")
    func initFromPrinterStateNilLastUpdated() {
        let state = PrinterState()
        #expect(state.lastUpdated == nil)

        let before = Date.now
        let snapshot = PrinterStateSnapshot(from: state)
        let after = Date.now

        #expect(snapshot.lastUpdated >= before)
        #expect(snapshot.lastUpdated <= after)
    }

    // MARK: - Helpers

    /// Build a PrinterStateSnapshot via Codable round-trip (since the memberwise init is not public).
    private func makeSnapshot(
        contentState: PrinterAttributes.ContentState,
        amsUnits: [AMSUnitSnapshot],
        activeTrayIndex: Int?,
        chamberLightOn: Bool,
        lastUpdated: Date
    ) throws -> PrinterStateSnapshot {
        // Use PrinterState init path
        let state = PrinterState()
        state.gcodeState = contentState.status == .printing ? "RUNNING" : "UNKNOWN"
        state.progress = contentState.progress
        state.remainingMinutes = contentState.remainingMinutes
        state.jobName = contentState.jobName
        state.layerNum = contentState.layerNum
        state.totalLayers = contentState.totalLayers
        state.nozzleTemp = contentState.nozzleTemp ?? 0
        state.nozzleTargetTemp = contentState.nozzleTargetTemp ?? 0
        state.bedTemp = contentState.bedTemp ?? 0
        state.bedTargetTemp = contentState.bedTargetTemp ?? 0
        state.chamberTemp = contentState.chamberTemp ?? 0
        state.chamberLightOn = chamberLightOn
        state.activeTrayIndex = activeTrayIndex
        state.lastUpdated = lastUpdated

        // Reconstruct AMS units from snapshots
        for unitSnapshot in amsUnits {
            let unit = AMSUnit(id: unitSnapshot.id)
            unit.humidityLevel = unitSnapshot.humidityLevel
            unit.humidityRaw = unitSnapshot.humidityRaw
            unit.temperature = unitSnapshot.temperature
            unit.dryTimeRemaining = unitSnapshot.dryTimeRemaining
            // Set hwVersion to get the right displayName
            if unitSnapshot.amsTypeName == "AMS 2 Pro" {
                unit.hwVersion = "N3F05"
            } else if unitSnapshot.amsTypeName == "AMS HT" {
                unit.hwVersion = "N3S05"
            }
            for traySnapshot in unitSnapshot.trays {
                guard traySnapshot.id >= 0, traySnapshot.id < 4 else { continue }
                unit.trays[traySnapshot.id] = AMSTray(
                    id: traySnapshot.id,
                    materialType: traySnapshot.materialType,
                    color: traySnapshot.colorHex.flatMap { AMSTray.parseColor(from: $0) },
                    colorHex: traySnapshot.colorHex,
                    remainPercent: traySnapshot.remainPercent,
                    isBambuFilament: traySnapshot.isBambuFilament
                )
            }
            state.amsUnits.append(unit)
        }

        return PrinterStateSnapshot(from: state)
    }
}
