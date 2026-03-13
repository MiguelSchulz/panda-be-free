import Foundation
import Networking
@testable import PandaBeFree
import PandaModels
import Testing

@Suite("Dashboard ViewModel")
@MainActor
struct DashboardViewModelTests {
    // MARK: - Computed Properties

    @Test("isConnected reflects mqttConnectionState")
    func isConnected() {
        let vm = DashboardViewModel(mqttService: MockMQTTService())
        #expect(vm.isConnected == false)

        vm.mqttConnectionState = .connected
        #expect(vm.isConnected == true)

        vm.mqttConnectionState = .disconnected
        #expect(vm.isConnected == false)
    }

    @Test("isPrinting returns true for printing and preparing")
    func isPrinting() {
        let vm = DashboardViewModel(mqttService: MockMQTTService())

        vm.printerState.gcodeState = "RUNNING"
        vm.printerState.stgCur = 0
        vm.printerState.layerNum = 100
        #expect(vm.isPrinting == true)

        vm.printerState.gcodeState = "PREPARE"
        vm.printerState.stgCur = 1
        vm.printerState.layerNum = 0
        #expect(vm.isPrinting == true)
    }

    @Test("isPrinting returns false for other states")
    func isNotPrinting() {
        let vm = DashboardViewModel(mqttService: MockMQTTService())

        vm.printerState.gcodeState = "PAUSE"
        #expect(vm.isPrinting == false)

        vm.printerState.gcodeState = "FINISH"
        #expect(vm.isPrinting == false)
    }

    @Test("canPause returns true only for printing status")
    func canPause() {
        let vm = DashboardViewModel(mqttService: MockMQTTService())
        vm.printerState.gcodeState = "RUNNING"
        vm.printerState.layerNum = 100
        #expect(vm.canPause == true)

        vm.printerState.gcodeState = "PAUSE"
        #expect(vm.canPause == false)
    }

    @Test("canResume returns true only for paused status")
    func canResume() {
        let vm = DashboardViewModel(mqttService: MockMQTTService())
        vm.printerState.gcodeState = "PAUSE"
        vm.printerState.stgCur = 16
        #expect(vm.canResume == true)

        vm.printerState.gcodeState = "RUNNING"
        vm.printerState.stgCur = 0
        vm.printerState.layerNum = 100
        #expect(vm.canResume == false)
    }

    // MARK: - Commands

    @Test("pausePrint sends pause command")
    func pauseCommand() {
        let mock = MockMQTTService()
        let vm = DashboardViewModel(mqttService: mock)
        vm.pausePrint()
        assertCommand(mock.lastCommand, is: .pause)
    }

    @Test("resumePrint sends resume command")
    func resumeCommand() {
        let mock = MockMQTTService()
        let vm = DashboardViewModel(mqttService: mock)
        vm.resumePrint()
        assertCommand(mock.lastCommand, is: .resume)
    }

    @Test("stopPrint sends stop command")
    func stopCommand() {
        let mock = MockMQTTService()
        let vm = DashboardViewModel(mqttService: mock)
        vm.stopPrint()
        assertCommand(mock.lastCommand, is: .stop)
    }

    @Test("setSpeed updates selectedSpeed and sends command")
    func setSpeed() {
        let mock = MockMQTTService()
        let vm = DashboardViewModel(mqttService: mock)
        vm.setSpeed(.sport)
        #expect(vm.selectedSpeed == .sport)
        assertCommand(mock.lastCommand, is: .printSpeed(.sport))
    }

    @Test("toggleLight sends chamberLight command")
    func toggleLight() {
        let mock = MockMQTTService()
        let vm = DashboardViewModel(mqttService: mock)
        vm.toggleLight(on: true)
        #expect(vm.chamberLightOn == true)
        assertCommand(mock.lastCommand, is: .chamberLight(on: true))
    }

    // MARK: - Temperature Commands

    @Test("setNozzleTemp clamps to 0-300 and sends M104")
    func setNozzleTemp() {
        let mock = MockMQTTService()
        let vm = DashboardViewModel(mqttService: mock)

        vm.setNozzleTemp(220)
        #expect(vm.printerState.nozzleTargetTemp == 220)
        assertGcodeCommand(mock.lastCommand, contains: "M104 S220")

        vm.setNozzleTemp(500)
        #expect(vm.printerState.nozzleTargetTemp == 300) // clamped

        vm.setNozzleTemp(-10)
        #expect(vm.printerState.nozzleTargetTemp == 0) // clamped
    }

    @Test("setBedTemp clamps to 0-110 and sends M140")
    func setBedTemp() {
        let mock = MockMQTTService()
        let vm = DashboardViewModel(mqttService: mock)

        vm.setBedTemp(60)
        #expect(vm.printerState.bedTargetTemp == 60)
        assertGcodeCommand(mock.lastCommand, contains: "M140 S60")

        vm.setBedTemp(200)
        #expect(vm.printerState.bedTargetTemp == 110) // clamped
    }

    // MARK: - Fan Commands

    @Test("setFanSpeed converts percent to 0-255")
    func setFanSpeed() {
        let mock = MockMQTTService()
        let vm = DashboardViewModel(mqttService: mock)

        vm.setFanSpeed(fanIndex: 1, percent: 100)
        #expect(vm.printerState.partFanSpeed == 255)
        assertGcodeCommand(mock.lastCommand, contains: "M106 P1 S255")

        vm.setFanSpeed(fanIndex: 1, percent: 50)
        #expect(vm.printerState.partFanSpeed == 127) // 50% of 255

        vm.setFanSpeed(fanIndex: 2, percent: 75)
        #expect(vm.printerState.auxFanSpeed == 191) // 75% of 255
    }

    @Test("setFanSpeed clamps to 0-100")
    func setFanSpeedClamp() {
        let mock = MockMQTTService()
        let vm = DashboardViewModel(mqttService: mock)

        vm.setFanSpeed(fanIndex: 1, percent: 150)
        #expect(vm.printerState.partFanSpeed == 255) // clamped to 100%
    }

    // MARK: - Airduct Mode

    @Test("setAirductMode applies directly when not printing")
    func airductDirect() {
        let mock = MockMQTTService()
        let vm = DashboardViewModel(mqttService: mock)
        vm.printerState.gcodeState = "FINISH"
        vm.setAirductMode(1)
        #expect(vm.selectedAirductMode == 1)
        #expect(vm.showAirductModeConfirmation == false)
    }

    @Test("setAirductMode shows confirmation when printing")
    func airductConfirmation() {
        let mock = MockMQTTService()
        let vm = DashboardViewModel(mqttService: mock)
        vm.printerState.gcodeState = "RUNNING"
        vm.printerState.layerNum = 100
        vm.setAirductMode(1)
        #expect(vm.showAirductModeConfirmation == true)
        #expect(vm.pendingAirductMode == 1)
    }

    @Test("confirmAirductModeChange sends command")
    func airductConfirm() {
        let mock = MockMQTTService()
        let vm = DashboardViewModel(mqttService: mock)
        vm.pendingAirductMode = 1
        vm.confirmAirductModeChange()
        #expect(vm.selectedAirductMode == 1)
        #expect(vm.pendingAirductMode == nil)
    }

    @Test("cancelAirductModeChange clears pending")
    func airductCancel() {
        let vm = DashboardViewModel(mqttService: MockMQTTService())
        vm.pendingAirductMode = 1
        vm.cancelAirductModeChange()
        #expect(vm.pendingAirductMode == nil)
    }

    // MARK: - AMS Drying

    @Test("showStartDrying sets drying parameters and shows sheet")
    func showStartDrying() {
        let vm = DashboardViewModel(mqttService: MockMQTTService())
        vm.showStartDrying(amsId: 0)
        #expect(vm.showDryingSheet == true)
        #expect(vm.dryingAmsId == 0)
        #expect(vm.dryingPreset == .pla) // default
    }

    @Test("showStartDrying auto-detects preset from loaded material")
    func showStartDryingAutoDetect() {
        let vm = DashboardViewModel(mqttService: MockMQTTService())
        let amsUnit = AMSUnit(id: 0)
        amsUnit.hwVersion = "N3S05" // AMS HT supports up to 85°C
        amsUnit.trays[0] = AMSTray(id: 0, materialType: "ABS", color: .red, colorHex: "FF0000FF")
        vm.printerState.amsUnits = [amsUnit]

        vm.showStartDrying(amsId: 0)
        #expect(vm.dryingPreset == .abs)
        #expect(vm.dryingTemperature == 80)
    }

    @Test("startDrying sends command and closes sheet")
    func startDrying() {
        let mock = MockMQTTService()
        let vm = DashboardViewModel(mqttService: mock)
        vm.dryingAmsId = 0
        vm.dryingTemperature = 55
        vm.dryingDurationMinutes = 480
        vm.dryingRotateTray = false
        vm.startDrying()
        assertCommand(mock.lastCommand, is: .startDrying(amsId: 0, temperature: 55, durationMinutes: 480, rotateTray: false))
        #expect(vm.showDryingSheet == false)
    }

    @Test("startDrying clamps temperature to minimum 45")
    func startDryingMinTemp() {
        let mock = MockMQTTService()
        let vm = DashboardViewModel(mqttService: mock)
        vm.dryingAmsId = 0
        vm.dryingTemperature = 30 // below minimum
        vm.dryingDurationMinutes = 480
        vm.startDrying()
        assertCommand(mock.lastCommand, is: .startDrying(amsId: 0, temperature: 45, durationMinutes: 480, rotateTray: false))
    }

    @Test("stopDrying sends stop command with amsId")
    func stopDrying() {
        let mock = MockMQTTService()
        let vm = DashboardViewModel(mqttService: mock)
        vm.stoppingDryingAmsId = 2
        vm.stopDrying()
        assertCommand(mock.lastCommand, is: .stopDrying(amsId: 2))
        #expect(vm.showStopDryingConfirmation == false)
    }

    @Test("applyDryingPreset updates temperature and duration")
    func applyPreset() {
        let vm = DashboardViewModel(mqttService: MockMQTTService())
        vm.applyDryingPreset(.abs)
        #expect(vm.dryingPreset == .abs)
        #expect(vm.dryingTemperature == 80)
        #expect(vm.dryingDurationMinutes == 480)
    }

    @Test("applyDryingPreset custom does not override temp/duration")
    func applyCustomPreset() {
        let vm = DashboardViewModel(mqttService: MockMQTTService())
        vm.dryingTemperature = 70
        vm.dryingDurationMinutes = 600
        vm.applyDryingPreset(.custom)
        #expect(vm.dryingTemperature == 70)
        #expect(vm.dryingDurationMinutes == 600)
    }

    // MARK: - Loading State

    @Test("hasReceivedInitialData is false before any MQTT data")
    func hasReceivedInitialDataDefault() {
        let vm = DashboardViewModel(mqttService: MockMQTTService())
        #expect(vm.hasReceivedInitialData == false)
    }

    @Test("hasReceivedInitialData becomes true after printerState.lastUpdated is set")
    func hasReceivedInitialDataAfterUpdate() {
        let vm = DashboardViewModel(mqttService: MockMQTTService())
        #expect(vm.hasReceivedInitialData == false)

        vm.printerState.lastUpdated = Date.now
        #expect(vm.hasReceivedInitialData == true)
    }

    @Test("hasReceivedInitialData is independent of connection state")
    func hasReceivedInitialDataIndependentOfConnection() {
        let vm = DashboardViewModel(mqttService: MockMQTTService())

        // Connected but no data yet
        vm.mqttConnectionState = .connected
        #expect(vm.hasReceivedInitialData == false)

        // Error but no data yet
        vm.mqttConnectionState = .error("timeout")
        #expect(vm.hasReceivedInitialData == false)

        // Data arrives regardless of connection state
        vm.printerState.lastUpdated = Date.now
        #expect(vm.hasReceivedInitialData == true)

        // Stays true even after disconnect
        vm.mqttConnectionState = .disconnected
        #expect(vm.hasReceivedInitialData == true)
    }

    @Test("contentState returns placeholder values before initial data")
    func contentStatePlaceholderBeforeData() {
        let vm = DashboardViewModel(mqttService: MockMQTTService())
        #expect(vm.hasReceivedInitialData == false)

        // Default PrinterState values produce idle status with zero temps
        let state = vm.contentState
        #expect(state.status == .idle)
        #expect(state.nozzleTemp == 0)
        #expect(state.bedTemp == 0)
        #expect(state.progress == 0)
    }

    // MARK: - Filament Editing

    @Test("showFilamentEdit matches preset by trayInfoIdx")
    func filamentEditByTrayInfoIdx() {
        let vm = DashboardViewModel(mqttService: MockMQTTService())
        let tray = AMSTray(id: 0, materialType: "PLA", trayInfoIdx: "GFL99")
        vm.showFilamentEdit(amsId: 0, tray: tray)
        #expect(vm.editFilamentPreset.id == "GFL99")
        #expect(vm.editFilamentPreset.trayType == "PLA")
    }

    @Test("showFilamentEdit falls back to materialType when no trayInfoIdx")
    func filamentEditByMaterialType() {
        let vm = DashboardViewModel(mqttService: MockMQTTService())
        let tray = AMSTray(id: 0, materialType: "PETG")
        vm.showFilamentEdit(amsId: 0, tray: tray)
        #expect(vm.editFilamentPreset.trayType == "PETG")
    }

    @Test("showFilamentEdit defaults to first preset when no match")
    func filamentEditDefault() {
        let vm = DashboardViewModel(mqttService: MockMQTTService())
        let tray = AMSTray(id: 0, materialType: "UNKNOWN_MATERIAL")
        vm.showFilamentEdit(amsId: 0, tray: tray)
        #expect(vm.editFilamentPreset.id == FilamentPreset.all[0].id)
    }

    @Test("showFilamentEdit sets all editing state")
    func filamentEditSetsState() {
        let vm = DashboardViewModel(mqttService: MockMQTTService())
        let tray = AMSTray(id: 2, materialType: "ABS", color: .red, colorHex: "FF0000FF")
        vm.showFilamentEdit(amsId: 1, tray: tray)
        #expect(vm.editingAmsId == 1)
        #expect(vm.editingTrayId == 2)
        #expect(vm.showFilamentEditSheet == true)
    }

    @Test("confirmFilamentEdit sends amsFilamentSetting command")
    func confirmFilamentEdit() throws {
        let mock = MockMQTTService()
        let vm = DashboardViewModel(mqttService: mock)
        let tray = AMSTray(id: 1, materialType: "PLA", trayInfoIdx: "GFL99")
        vm.showFilamentEdit(amsId: 0, tray: tray)
        vm.confirmFilamentEdit()

        #expect(mock.lastCommand != nil)
        #expect(vm.showFilamentEditSheet == false)
        // Verify the command payload contains the right ams_id and tray_id
        let data = try #require(mock.lastCommand?.payload())
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let printData = try #require(json["print"] as? [String: Any])
        #expect(printData["command"] as? String == "ams_filament_setting")
        #expect(printData["ams_id"] as? Int == 0)
        #expect(printData["tray_id"] as? Int == 1)
    }

    @Test("confirmFilamentEdit does nothing when editingAmsId is nil")
    func confirmFilamentEditNoOp() {
        let mock = MockMQTTService()
        let vm = DashboardViewModel(mqttService: mock)
        vm.confirmFilamentEdit()
        #expect(mock.lastCommand == nil)
    }

    @Test("confirmStopDrying sets stoppingDryingAmsId and shows confirmation")
    func confirmStopDryingSetsState() {
        let vm = DashboardViewModel(mqttService: MockMQTTService())
        vm.confirmStopDrying(amsId: 2)
        #expect(vm.stoppingDryingAmsId == 2)
        #expect(vm.showStopDryingConfirmation == true)
    }

    @Test("showStartDrying clamps preset temp to standard AMS maxTemp")
    func showStartDryingClampsTemp() {
        let vm = DashboardViewModel(mqttService: MockMQTTService())
        let amsUnit = AMSUnit(id: 0)
        amsUnit.hwVersion = "AMS08" // standard, maxTemp = 55
        amsUnit.trays[0] = AMSTray(id: 0, materialType: "ABS") // ABS preset temp = 80
        vm.printerState.amsUnits = [amsUnit]

        vm.showStartDrying(amsId: 0)
        #expect(vm.dryingTemperature == 55) // clamped from 80 to 55
    }

    @Test("applyDryingPreset clamps to AMS maxTemp")
    func applyDryingPresetClampsToMax() {
        let vm = DashboardViewModel(mqttService: MockMQTTService())
        let amsUnit = AMSUnit(id: 0)
        amsUnit.hwVersion = "AMS08" // standard, maxTemp = 55
        vm.printerState.amsUnits = [amsUnit]
        vm.dryingAmsId = 0

        vm.applyDryingPreset(.abs) // ABS preset temp = 80
        #expect(vm.dryingTemperature == 55) // clamped to 55
    }

    @Test("startDrying optimistically updates AMS unit dryTimeRemaining")
    func startDryingOptimisticUpdate() {
        let vm = DashboardViewModel(mqttService: MockMQTTService())
        let amsUnit = AMSUnit(id: 0)
        vm.printerState.amsUnits = [amsUnit]
        vm.dryingAmsId = 0
        vm.dryingTemperature = 55
        vm.dryingDurationMinutes = 480

        vm.startDrying()
        #expect(vm.printerState.amsUnits[0].dryTimeRemaining == 480)
    }

    // MARK: - Connection

    @Test("disconnectAll resets state")
    func disconnectAll() {
        let vm = DashboardViewModel(mqttService: MockMQTTService())
        vm.mqttConnectionState = .connected
        vm.printerState.isConnected = true

        vm.disconnectAll()

        #expect(vm.mqttConnectionState == .disconnected)
        #expect(vm.printerState.isConnected == false)
    }

    // MARK: - Helpers

    private func assertCommand(_ actual: PrinterCommand?, is expected: PrinterCommand, sourceLocation: SourceLocation = #_sourceLocation) {
        guard let actual else {
            Issue.record("Expected command but got nil", sourceLocation: sourceLocation)
            return
        }
        let actualData = actual.payload()
        let expectedData = expected.payload()
        // Compare as parsed dictionaries to avoid JSON key ordering issues
        let actualDict = try! JSONSerialization.jsonObject(with: actualData) as! NSDictionary
        let expectedDict = try! JSONSerialization.jsonObject(with: expectedData) as! NSDictionary
        #expect(actualDict == expectedDict, sourceLocation: sourceLocation)
    }

    private func assertGcodeCommand(_ actual: PrinterCommand?, contains gcode: String, sourceLocation: SourceLocation = #_sourceLocation) {
        guard let actual else {
            Issue.record("Expected command but got nil", sourceLocation: sourceLocation)
            return
        }
        let data = actual.payload()
        let json = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        let printData = json["print"] as? [String: Any]
        let param = (printData?["param"] as? String) ?? ""
        #expect(param.contains(gcode), sourceLocation: sourceLocation)
    }
}
