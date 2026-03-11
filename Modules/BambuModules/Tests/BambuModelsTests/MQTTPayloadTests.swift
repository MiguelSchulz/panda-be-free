import Testing
import Foundation
@testable import BambuModels

@Suite("MQTT Payload Parsing")
struct MQTTPayloadTests {

    // MARK: - Invalid Input

    @Test("Returns nil for invalid JSON")
    func invalidJSON() {
        let data = "not json".data(using: .utf8)!
        #expect(BambuMQTTPayload.parse(from: data) == nil)
    }

    @Test("Returns nil for JSON without 'print' key")
    func missingPrintKey() {
        let json: [String: Any] = ["system": ["command": "test"]]
        let data = try! JSONSerialization.data(withJSONObject: json)
        #expect(BambuMQTTPayload.parse(from: data) == nil)
    }

    // MARK: - Basic Fields

    @Test("Parses gcode_state")
    func gcodeState() {
        let payload = parsePayload(["gcode_state": "RUNNING"])
        #expect(payload?.gcodeState == "RUNNING")
    }

    @Test("Parses mc_percent and mc_remaining_time")
    func progressFields() {
        let payload = parsePayload(["mc_percent": 42, "mc_remaining_time": 83])
        #expect(payload?.mcPercent == 42)
        #expect(payload?.mcRemainingTime == 83)
    }

    @Test("Parses temperature fields")
    func temperatureFields() {
        let payload = parsePayload([
            "nozzle_temper": 220.5,
            "nozzle_target_temper": 220.0,
            "bed_temper": 60.3,
            "bed_target_temper": 60.0,
        ])
        #expect(payload?.nozzleTemper == 220.5)
        #expect(payload?.nozzleTargetTemper == 220.0)
        #expect(payload?.bedTemper == 60.3)
        #expect(payload?.bedTargetTemper == 60.0)
    }

    @Test("Parses stg_cur and subtask_name")
    func stageAndJobFields() {
        let payload = parsePayload(["stg_cur": 7, "subtask_name": "Benchy"])
        #expect(payload?.stgCur == 7)
        #expect(payload?.subtaskName == "Benchy")
    }

    // MARK: - Layer Parsing

    @Test("Parses layer_num from top level")
    func layerNumTopLevel() {
        let payload = parsePayload(["layer_num": 150, "total_layer_num": 300])
        #expect(payload?.layerNum == 150)
        #expect(payload?.totalLayerNum == 300)
    }

    @Test("Parses layer_num from nested 3D object")
    func layerNumNested() {
        let payload = parsePayload(["3D": ["layer_num": 42, "total_layer_num": 200]])
        #expect(payload?.layerNum == 42)
        #expect(payload?.totalLayerNum == 200)
    }

    // MARK: - Fan Parsing

    @Test("Parses fan speeds from fan_gear bitmask")
    func fanGearBitmask() {
        // part=200 (0xC8), aux=128 (0x80), chamber=64 (0x40)
        let fanGear = 200 | (128 << 8) | (64 << 16)
        let payload = parsePayload(["fan_gear": fanGear])
        #expect(payload?.partFanSpeed == 200)
        #expect(payload?.auxFanSpeed == 128)
        #expect(payload?.chamberFanSpeed == 64)
    }

    @Test("Falls back to individual string fields when fan_gear absent")
    func fanStringFallback() {
        let payload = parsePayload([
            "cooling_fan_speed": "15",
            "big_fan1_speed": "7",
            "big_fan2_speed": "3",
        ])
        #expect(payload?.partFanSpeed == 255) // 15 -> 255
        #expect(payload?.auxFanSpeed != nil)
        #expect(payload?.chamberFanSpeed != nil)
    }

    @Test("Fan raw to normalized conversion",
          arguments: [(0, 0), (1, 0), (3, 51), (7, 102), (15, 255)])
    func fanConversion(raw: Int, expected: Int) {
        // Test via parsing individual fan string fields
        let payload = parsePayload(["cooling_fan_speed": "\(raw)"])
        #expect(payload?.partFanSpeed == expected)
    }

    @Test("Parses heatbreak_fan_speed from individual field")
    func heatbreakFan() {
        let payload = parsePayload(["heatbreak_fan_speed": "10"])
        #expect(payload?.heatbreakFanSpeed != nil)
    }

    // MARK: - Light Parsing

    @Test("Parses chamber_light 'on'")
    func chamberLightOn() {
        let payload = parsePayload([
            "lights_report": [["node": "chamber_light", "mode": "on"]]
        ])
        #expect(payload?.chamberLightOn == true)
    }

    @Test("Parses chamber_light 'off'")
    func chamberLightOff() {
        let payload = parsePayload([
            "lights_report": [["node": "chamber_light", "mode": "off"]]
        ])
        #expect(payload?.chamberLightOn == false)
    }

    @Test("Ignores non-chamber light nodes")
    func ignoresOtherLightNodes() {
        let payload = parsePayload([
            "lights_report": [["node": "work_light", "mode": "on"]]
        ])
        #expect(payload?.chamberLightOn == nil)
    }

    // MARK: - Chamber Temp

    @Test("Parses chamber temp from device.ctc.info.temp (newer firmware)")
    func chamberTempCTC() {
        let payload = parsePayload([
            "device": ["ctc": ["info": ["temp": 42]]]
        ])
        #expect(payload?.chamberTemper == 42.0)
    }

    @Test("Falls back to chamber_temper when ctc path absent")
    func chamberTempLegacy() {
        let payload = parsePayload(["chamber_temper": 38.5])
        #expect(payload?.chamberTemper == 38.5)
    }

    @Test("Masks ctc temp with 0xFFFF")
    func chamberTempMask() {
        let payload = parsePayload([
            "device": ["ctc": ["info": ["temp": 0x10028]]] // 65536 + 40
        ])
        #expect(payload?.chamberTemper == 40.0) // 0x10028 & 0xFFFF = 40
    }

    // MARK: - Airduct Mode

    @Test("Parses airduct mode")
    func airductMode() {
        let payload = parsePayload([
            "device": ["airduct": ["modeCur": 1]]
        ])
        #expect(payload?.airductMode == 1)
    }

    // MARK: - Partial Updates

    @Test("All fields remain nil when not present")
    func emptyPayload() {
        let payload = parsePayload([:])
        #expect(payload?.gcodeState == nil)
        #expect(payload?.mcPercent == nil)
        #expect(payload?.nozzleTemper == nil)
        #expect(payload?.partFanSpeed == nil)
        #expect(payload?.chamberLightOn == nil)
    }

    // MARK: - Helpers

    private func parsePayload(_ printData: [String: Any]) -> BambuMQTTPayload? {
        let json: [String: Any] = ["print": printData]
        let data = try! JSONSerialization.data(withJSONObject: json)
        return BambuMQTTPayload.parse(from: data)
    }
}
