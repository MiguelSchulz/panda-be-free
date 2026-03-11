import Testing
import Foundation
@testable import BambuModels

@Suite("AMS Parsing and State")
struct AMSTests {

    // MARK: - MQTT Parsing

    @Test("Parses AMS units from MQTT payload")
    func parseAmsUnits() {
        let payload = parsePayload([
            "ams": [
                "ams": [
                    ["id": "0", "humidity": "3", "humidity_raw": "45", "temp": "24.5", "dry_time": 0, "tray": []]
                ],
                "tray_now": "255",
                "tray_is_bbl_bits": "f",
            ]
        ])
        #expect(payload?.amsUnits?.count == 1)
        #expect(payload?.amsUnits?[0].id == 0)
        #expect(payload?.amsUnits?[0].humidity == 3)
        #expect(payload?.amsUnits?[0].humidityRaw == 45)
        #expect(payload?.amsUnits?[0].temp == 24.5)
        #expect(payload?.amsUnits?[0].dryTime == 0)
    }

    @Test("Parses tray data with color and material")
    func parseTrayData() {
        let payload = parsePayload([
            "ams": [
                "ams": [
                    ["id": "0", "tray": [
                        ["id": "0", "tray_type": "PLA", "tray_color": "FFFF00FF", "remain": 85,
                         "nozzle_temp_min": "190", "nozzle_temp_max": "240",
                         "tray_temp": "55", "tray_time": "8"]
                    ]]
                ],
                "tray_is_bbl_bits": "1",
            ]
        ])
        let tray = payload?.amsUnits?[0].trays[0]
        #expect(tray?.trayType == "PLA")
        #expect(tray?.trayColor == "FFFF00FF")
        #expect(tray?.remain == 85)
        #expect(tray?.nozzleTempMin == 190)
        #expect(tray?.nozzleTempMax == 240)
        #expect(tray?.trayTemp == 55)
        #expect(tray?.trayTime == 8)
    }

    @Test("Empty tray has only id field")
    func parseEmptyTray() {
        let payload = parsePayload([
            "ams": [
                "ams": [
                    ["id": "0", "tray": [
                        ["id": "2"]
                    ]]
                ]
            ]
        ])
        let tray = payload?.amsUnits?[0].trays[0]
        #expect(tray?.id == 2)
        #expect(tray?.trayType == nil)
        #expect(tray?.trayColor == nil)
        #expect(tray?.remain == nil)
    }

    @Test("Parses drying time")
    func parseDryTime() {
        let payload = parsePayload([
            "ams": [
                "ams": [
                    ["id": "0", "dry_time": 3600, "tray": []]
                ]
            ]
        ])
        #expect(payload?.amsUnits?[0].dryTime == 3600)
    }

    @Test("Parses tray_now")
    func parseTrayNow() {
        let payload = parsePayload([
            "ams": ["tray_now": "2", "ams": []]
        ])
        #expect(payload?.trayNow == "2")
    }

    @Test("Parses tray_is_bbl_bits")
    func parseBblBits() {
        let payload = parsePayload([
            "ams": ["tray_is_bbl_bits": "f", "ams": []]
        ])
        #expect(payload?.trayIsBblBits == "f")
    }

    // MARK: - PrinterState apply()

    @Test("apply() creates AMSUnit from parsed data")
    func applyCreatesUnit() {
        let state = PrinterState()
        let payload = parsePayload([
            "ams": [
                "ams": [
                    ["id": "0", "humidity": "4", "humidity_raw": "62", "temp": "25.0", "dry_time": 0,
                     "tray": [
                        ["id": "0", "tray_type": "PLA", "tray_color": "FF0000FF", "remain": 50]
                     ]]
                ],
                "tray_now": "0",
                "tray_is_bbl_bits": "1",
            ]
        ])!
        state.apply(payload)

        #expect(state.amsUnits.count == 1)
        #expect(state.amsUnits[0].humidityLevel == 4)
        #expect(state.amsUnits[0].humidityRaw == 62)
        #expect(state.amsUnits[0].temperature == 25.0)
        #expect(state.amsUnits[0].trays[0].materialType == "PLA")
        #expect(state.amsUnits[0].trays[0].colorHex == "FF0000FF")
        #expect(state.amsUnits[0].trays[0].remainPercent == 50)
        #expect(state.amsUnits[0].trays[0].isBambuFilament == true)
        #expect(state.activeTrayIndex == 0)
    }

    @Test("apply() merges partial AMS updates")
    func applyMergesPartial() {
        let state = PrinterState()
        // First update: create unit with tray
        let first = parsePayload([
            "ams": [
                "ams": [["id": "0", "humidity": "3", "tray": [
                    ["id": "0", "tray_type": "PLA", "tray_color": "FFFF00FF", "remain": 80]
                ]]],
                "tray_is_bbl_bits": "1",
            ]
        ])!
        state.apply(first)
        #expect(state.amsUnits[0].humidityLevel == 3)
        #expect(state.amsUnits[0].trays[0].materialType == "PLA")

        // Second update: only humidity changes
        let second = parsePayload([
            "ams": [
                "ams": [["id": "0", "humidity": "5", "tray": []]],
            ]
        ])!
        state.apply(second)
        #expect(state.amsUnits[0].humidityLevel == 5)
        // Tray data preserved
        #expect(state.amsUnits[0].trays[0].materialType == "PLA")
    }

    @Test("apply() clears tray when only id present")
    func applyClearsEmptyTray() {
        let state = PrinterState()
        // First: set tray with material
        let first = parsePayload([
            "ams": [
                "ams": [["id": "0", "tray": [
                    ["id": "1", "tray_type": "ABS", "tray_color": "FF0000FF", "remain": 60]
                ]]],
                "tray_is_bbl_bits": "2",
            ]
        ])!
        state.apply(first)
        #expect(state.amsUnits[0].trays[1].materialType == "ABS")

        // Second: tray removed (only id)
        let second = parsePayload([
            "ams": [
                "ams": [["id": "0", "tray": [["id": "1"]]]],
            ]
        ])!
        state.apply(second)
        #expect(state.amsUnits[0].trays[1].materialType == nil)
        #expect(state.amsUnits[0].trays[1].isEmpty == true)
    }

    @Test("apply() updates activeTrayIndex")
    func applyActiveTray() {
        let state = PrinterState()
        // tray_now = 5 means AMS 1, tray 1
        let payload = parsePayload([
            "ams": ["tray_now": "5", "ams": []]
        ])!
        state.apply(payload)
        #expect(state.activeTrayIndex == 5)

        // tray_now = 255 means none
        let none = parsePayload([
            "ams": ["tray_now": "255", "ams": []]
        ])!
        state.apply(none)
        #expect(state.activeTrayIndex == nil)
    }

    @Test("apply() handles remain = -1 as unknown")
    func applyRemainUnknown() {
        let state = PrinterState()
        let payload = parsePayload([
            "ams": [
                "ams": [["id": "0", "tray": [
                    ["id": "0", "tray_type": "PLA", "tray_color": "FFFF00FF", "remain": -1]
                ]]],
                "tray_is_bbl_bits": "0",
            ]
        ])!
        state.apply(payload)
        #expect(state.amsUnits[0].trays[0].remainPercent == nil)
    }

    // MARK: - Color Parsing

    @Test("parseColor handles valid RRGGBBAA hex")
    func colorParsingValid() {
        let color = AMSTray.parseColor(from: "FFFF00FF")
        #expect(color != nil)
    }

    @Test("parseColor returns nil for invalid hex")
    func colorParsingInvalid() {
        #expect(AMSTray.parseColor(from: "invalid") == nil)
        #expect(AMSTray.parseColor(from: "FFF") == nil)
        #expect(AMSTray.parseColor(from: "") == nil)
    }

    // MARK: - AMSUnit Computed Properties

    @Test("isDrying returns true when dryTimeRemaining > 0")
    func isDrying() {
        let unit = AMSUnit(id: 0)
        #expect(unit.isDrying == false)
        unit.dryTimeRemaining = 3600
        #expect(unit.isDrying == true)
    }

    @Test("dryTimeFormatted formats hours and minutes")
    func dryTimeFormatted() {
        let unit = AMSUnit(id: 0)

        unit.dryTimeRemaining = 3661 // 1h 1m
        #expect(unit.dryTimeFormatted == "1h 1m")

        unit.dryTimeRemaining = 300 // 5m
        #expect(unit.dryTimeFormatted == "5m")

        unit.dryTimeRemaining = 7200 // 2h 0m
        #expect(unit.dryTimeFormatted == "2h 0m")
    }

    // MARK: - AMSTray Properties

    @Test("isEmpty returns true when materialType is nil")
    func trayIsEmpty() {
        let empty = AMSTray(id: 0)
        #expect(empty.isEmpty == true)

        let filled = AMSTray(id: 0, materialType: "PLA")
        #expect(filled.isEmpty == false)
    }

    @Test("globalIndex calculates correctly")
    func globalIndex() {
        let tray = AMSTray(id: 2)
        #expect(tray.globalIndex(amsId: 0) == 2)
        #expect(tray.globalIndex(amsId: 1) == 6)
        #expect(tray.globalIndex(amsId: 3) == 14)
    }

    // MARK: - Helpers

    private func parsePayload(_ printData: [String: Any]) -> BambuMQTTPayload? {
        let json: [String: Any] = ["print": printData]
        let data = try! JSONSerialization.data(withJSONObject: json)
        return BambuMQTTPayload.parse(from: data)
    }
}
