import BambuModels
import Foundation
import Networking
@testable import PrinterControl
import Testing

// MARK: - Test Case Types

struct JogCase: CustomStringConvertible, Sendable {
    let axis: String
    let distance: Double
    let expectedMove: String

    var description: String {
        "\(axis) \(distance > 0 ? "+" : "")\(Int(distance))mm"
    }
}

// MARK: - Tests

@Suite("Control ViewModel")
@MainActor
struct ControlViewModelTests {
    // MARK: - XY Jog

    nonisolated static let xyJogCases: [JogCase] = [
        JogCase(axis: "X", distance: 1, expectedMove: "G1 X1 F3000"),
        JogCase(axis: "X", distance: -1, expectedMove: "G1 X-1 F3000"),
        JogCase(axis: "X", distance: 10, expectedMove: "G1 X10 F3000"),
        JogCase(axis: "X", distance: -10, expectedMove: "G1 X-10 F3000"),
        JogCase(axis: "Y", distance: 1, expectedMove: "G1 Y1 F3000"),
        JogCase(axis: "Y", distance: -1, expectedMove: "G1 Y-1 F3000"),
        JogCase(axis: "Y", distance: 10, expectedMove: "G1 Y10 F3000"),
        JogCase(axis: "Y", distance: -10, expectedMove: "G1 Y-10 F3000"),
    ]

    @Test("XY jog sends correct GCode", arguments: xyJogCases)
    func xyJog(jogCase: JogCase) {
        let mock = MockMQTTService()
        // homeFlag 0 = default → all axes homed (OrcaSlicer behavior)
        let vm = ControlViewModel(mqttService: mock)

        if jogCase.axis == "X" {
            vm.jogX(distance: jogCase.distance)
        } else {
            vm.jogY(distance: jogCase.distance)
        }

        assertGcodeCommand(mock.lastCommand, contains: "M211 S")
        assertGcodeCommand(mock.lastCommand, contains: "M211 X1 Y1 Z1")
        assertGcodeCommand(mock.lastCommand, contains: "G91")
        assertGcodeCommand(mock.lastCommand, contains: jogCase.expectedMove)
        assertGcodeCommand(mock.lastCommand, contains: "G90")
        assertGcodeCommand(mock.lastCommand, contains: "M211 R")
    }

    // MARK: - Z Jog

    nonisolated static let zJogCases: [JogCase] = [
        JogCase(axis: "Z", distance: 1, expectedMove: "G1 Z1 F1200"),
        JogCase(axis: "Z", distance: -1, expectedMove: "G1 Z-1 F1200"),
        JogCase(axis: "Z", distance: 10, expectedMove: "G1 Z10 F1200"),
        JogCase(axis: "Z", distance: -10, expectedMove: "G1 Z-10 F1200"),
    ]

    @Test("Z jog sends correct GCode", arguments: zJogCases)
    func zJog(jogCase: JogCase) {
        let mock = MockMQTTService()
        let vm = ControlViewModel(mqttService: mock)

        vm.jogZ(distance: jogCase.distance)

        assertGcodeCommand(mock.lastCommand, contains: "M211 S")
        assertGcodeCommand(mock.lastCommand, contains: "M211 X1 Y1 Z1")
        assertGcodeCommand(mock.lastCommand, contains: "G91")
        assertGcodeCommand(mock.lastCommand, contains: jogCase.expectedMove)
        assertGcodeCommand(mock.lastCommand, contains: "G90")
        assertGcodeCommand(mock.lastCommand, contains: "M211 R")
    }

    // MARK: - Home

    @Test("homeAll sends G28")
    func homeAll() {
        let mock = MockMQTTService()
        let vm = ControlViewModel(mqttService: mock)

        vm.homeAll()

        assertGcodeCommand(mock.lastCommand, contains: "G28")
    }

    // MARK: - Extruder

    @Test("extrude sends correct GCode")
    func extrude() {
        let mock = MockMQTTService()
        let state = PrinterState()
        state.nozzleTemp = 200
        let vm = ControlViewModel(mqttService: mock, printerState: state)

        vm.extrude()

        assertGcodeCommand(mock.lastCommand, contains: "M83")
        assertGcodeCommand(mock.lastCommand, contains: "G1 E10 F300")
        assertGcodeCommand(mock.lastCommand, contains: "M82")
    }

    @Test("retract sends correct GCode")
    func retract() {
        let mock = MockMQTTService()
        let state = PrinterState()
        state.nozzleTemp = 200
        let vm = ControlViewModel(mqttService: mock, printerState: state)

        vm.retract()

        assertGcodeCommand(mock.lastCommand, contains: "M83")
        assertGcodeCommand(mock.lastCommand, contains: "G1 E-10 F300")
        assertGcodeCommand(mock.lastCommand, contains: "M82")
    }

    // MARK: - Light

    @Test("toggleLight sends command and updates state", arguments: [true, false])
    func toggleLight(on: Bool) {
        let mock = MockMQTTService()
        let vm = ControlViewModel(mqttService: mock, isLightOn: !on)

        vm.toggleLight(on: on)

        #expect(vm.isLightOn == on)
        assertCommand(mock.lastCommand, is: .chamberLight(on: on))
    }

    // MARK: - Homing Warning (bitmask)

    @Test("homeFlag 0 means all axes homed (default)")
    func homeFlagZeroAllHomed() {
        let mock = MockMQTTService()
        let vm = ControlViewModel(mqttService: mock)

        vm.jogX(distance: 1)
        #expect(vm.showHomingWarning == false)
        #expect(mock.lastCommand != nil)
    }

    @Test("XY jog blocked when X not homed (homeFlag has Y+Z but not X)")
    func jogXBlockedWhenXNotHomed() {
        let mock = MockMQTTService()
        let state = PrinterState()
        // bits: Z=1, Y=1, X=0 → 0b110 = 6
        state.homeFlag = 0b110
        let vm = ControlViewModel(mqttService: mock, printerState: state)

        vm.jogX(distance: 1)

        #expect(vm.showHomingWarning == true)
        #expect(mock.lastCommand == nil)
    }

    @Test("XY jog blocked when Y not homed (homeFlag has X+Z but not Y)")
    func jogYBlockedWhenYNotHomed() {
        let mock = MockMQTTService()
        let state = PrinterState()
        // bits: Z=1, Y=0, X=1 → 0b101 = 5
        state.homeFlag = 0b101
        let vm = ControlViewModel(mqttService: mock, printerState: state)

        vm.jogY(distance: 1)

        #expect(vm.showHomingWarning == true)
        #expect(mock.lastCommand == nil)
    }

    @Test("Z jog blocked when Z not homed (homeFlag has X+Y but not Z)")
    func jogZBlockedWhenZNotHomed() {
        let mock = MockMQTTService()
        let state = PrinterState()
        // bits: Z=0, Y=1, X=1 → 0b011 = 3
        state.homeFlag = 0b011
        let vm = ControlViewModel(mqttService: mock, printerState: state)

        vm.jogZ(distance: 1)

        #expect(vm.showHomingWarning == true)
        #expect(mock.lastCommand == nil)
    }

    @Test("All jog succeeds when all axes homed (homeFlag 0b111)")
    func allJogSucceedsWhenFullyHomed() {
        let mock = MockMQTTService()
        let state = PrinterState()
        // bits: Z=1, Y=1, X=1 → 0b111 = 7
        state.homeFlag = 0b111
        let vm = ControlViewModel(mqttService: mock, printerState: state)

        vm.jogX(distance: 1)
        #expect(vm.showHomingWarning == false)
        #expect(mock.lastCommand != nil)

        vm.jogY(distance: 1)
        #expect(vm.showHomingWarning == false)

        vm.jogZ(distance: 1)
        #expect(vm.showHomingWarning == false)
    }

    @Test("Z jog succeeds when only Z homed")
    func zJogSucceedsWithOnlyZHomed() {
        let mock = MockMQTTService()
        let state = PrinterState()
        // bits: Z=1, Y=0, X=0 → 0b100 = 4
        state.homeFlag = 0b100
        let vm = ControlViewModel(mqttService: mock, printerState: state)

        vm.jogZ(distance: 1)

        #expect(vm.showHomingWarning == false)
        #expect(mock.lastCommand != nil)
    }

    @Test("Homing state updates are reflected live")
    func homingStateLive() {
        let mock = MockMQTTService()
        let state = PrinterState()
        state.homeFlag = 0b110 // X not homed
        let vm = ControlViewModel(mqttService: mock, printerState: state)

        vm.jogX(distance: 1)
        #expect(vm.showHomingWarning == true)
        #expect(mock.lastCommand == nil)

        // Simulate MQTT update: all axes now homed
        vm.showHomingWarning = false
        state.homeFlag = 0b111

        vm.jogX(distance: 1)
        #expect(vm.showHomingWarning == false)
        #expect(mock.lastCommand != nil)
    }

    // MARK: - Extruder Temperature Warning

    @Test("Extrude shows temp warning when nozzle cold")
    func extrudeShowsTempWarning() {
        let mock = MockMQTTService()
        let state = PrinterState()
        state.nozzleTemp = 169
        let vm = ControlViewModel(mqttService: mock, printerState: state)

        vm.extrude()

        #expect(vm.showExtruderTempWarning == true)
        #expect(mock.lastCommand == nil)
    }

    @Test("Retract shows temp warning when nozzle cold")
    func retractShowsTempWarning() {
        let mock = MockMQTTService()
        let state = PrinterState()
        state.nozzleTemp = 100
        let vm = ControlViewModel(mqttService: mock, printerState: state)

        vm.retract()

        #expect(vm.showExtruderTempWarning == true)
        #expect(mock.lastCommand == nil)
    }

    @Test("Extrude succeeds at exactly 170°C")
    func extrudeSucceedsAtThreshold() {
        let mock = MockMQTTService()
        let state = PrinterState()
        state.nozzleTemp = 170
        let vm = ControlViewModel(mqttService: mock, printerState: state)

        vm.extrude()

        #expect(vm.showExtruderTempWarning == false)
        #expect(mock.lastCommand != nil)
    }

    // MARK: - Controls Disabled During Print

    @Test("Controls enabled when idle")
    func controlsEnabledWhenIdle() {
        let mock = MockMQTTService()
        let vm = ControlViewModel(mqttService: mock)

        #expect(vm.controlsEnabled == true)
    }

    @Test("Controls disabled when printing", arguments: ["RUNNING", "PRINTING"])
    func controlsDisabledWhenPrinting(gcodeState: String) {
        let mock = MockMQTTService()
        let state = PrinterState()
        state.gcodeState = gcodeState
        let vm = ControlViewModel(mqttService: mock, printerState: state)

        #expect(vm.controlsEnabled == false)
    }

    @Test("Controls disabled when paused")
    func controlsDisabledWhenPaused() {
        let mock = MockMQTTService()
        let state = PrinterState()
        state.gcodeState = "PAUSE"
        let vm = ControlViewModel(mqttService: mock, printerState: state)

        #expect(vm.controlsEnabled == false)
    }

    @Test("Controls disabled when preparing")
    func controlsDisabledWhenPreparing() {
        let mock = MockMQTTService()
        let state = PrinterState()
        state.gcodeState = "PREPARE"
        state.stgCur = 1
        let vm = ControlViewModel(mqttService: mock, printerState: state)

        #expect(vm.controlsEnabled == false)
    }

    @Test("Controls re-enabled after print completes")
    func controlsReEnabledAfterComplete() {
        let mock = MockMQTTService()
        let state = PrinterState()
        state.gcodeState = "RUNNING"
        let vm = ControlViewModel(mqttService: mock, printerState: state)

        #expect(vm.controlsEnabled == false)

        state.gcodeState = "FINISH"
        // contentState.status is now .completed, not .idle — still disabled
        // After user clears, printer goes to idle
        state.gcodeState = "UNKNOWN"
        #expect(vm.controlsEnabled == true)
    }

    // MARK: - Init

    @Test("Default state has correct initial values")
    func defaultState() {
        let mock = MockMQTTService()
        let vm = ControlViewModel(mqttService: mock)

        #expect(vm.isLightOn == false)
        #expect(vm.printerState.nozzleTemp == 0)
        #expect(vm.printerState.homeFlag == 0)
        #expect(vm.showHomingWarning == false)
        #expect(vm.showExtruderTempWarning == false)
        #expect(vm.controlsEnabled == true)
    }

    @Test("Custom isLightOn is preserved")
    func customLightState() {
        let mock = MockMQTTService()
        let vm = ControlViewModel(mqttService: mock, isLightOn: true)

        #expect(vm.isLightOn == true)
    }

    // MARK: - Helpers

    private func assertGcodeCommand(
        _ actual: PrinterCommand?,
        contains gcode: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        guard let actual else {
            Issue.record("Expected command but got nil", sourceLocation: sourceLocation)
            return
        }
        let data = actual.payload()
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let printData = json["print"] as? [String: Any],
              let param = printData["param"] as? String
        else {
            Issue.record("Failed to parse command payload", sourceLocation: sourceLocation)
            return
        }
        #expect(param.contains(gcode), sourceLocation: sourceLocation)
    }

    private func assertCommand(
        _ actual: PrinterCommand?,
        is expected: PrinterCommand,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        guard let actual else {
            Issue.record("Expected command but got nil", sourceLocation: sourceLocation)
            return
        }
        let actualData = actual.payload()
        let expectedData = expected.payload()
        guard let actualDict = try? JSONSerialization.jsonObject(with: actualData) as? NSDictionary,
              let expectedDict = try? JSONSerialization.jsonObject(with: expectedData) as? NSDictionary
        else {
            Issue.record("Failed to parse command payloads", sourceLocation: sourceLocation)
            return
        }
        #expect(actualDict == expectedDict, sourceLocation: sourceLocation)
    }
}
