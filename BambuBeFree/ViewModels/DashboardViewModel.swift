import BambuModels
import Foundation
import Networking
import SwiftUI
import WidgetKit

@MainActor
@Observable
final class DashboardViewModel {
    let printerState = PrinterState()
    let cameraManager = CameraStreamManager()

    var mqttConnectionState: MQTTConnectionState = .disconnected
    var showDisconnectConfirmation = false
    var showStopConfirmation = false
    var showPauseConfirmation = false
    var showAirductModeConfirmation = false
    var selectedSpeed: PrinterCommand.SpeedLevel = .standard
    var chamberLightOn = false
    var selectedAirductMode: Int = -1
    var pendingAirductMode: Int?

    // Filament editing
    var showFilamentEditSheet = false
    var editingAmsId: Int?
    var editingTrayId: Int?
    var editFilamentPreset = FilamentPreset.all[0]
    var editFilamentColor: Color = .white

    // AMS Drying
    var showDryingSheet = false
    var dryingAmsId: Int?
    var dryingPreset: PrinterCommand.DryingPreset = .pla
    var dryingTemperature = 55
    var dryingDurationMinutes = 480
    var dryingRotateTray = false
    var showStopDryingConfirmation = false
    var stoppingDryingAmsId: Int?

    private let mqttService: any MQTTServiceProtocol
    // nonisolated(unsafe) allows cancellation from deinit; Task.cancel() is thread-safe.
    // swiftformat:disable:next nonisolatedUnsafe
    @ObservationIgnored nonisolated(unsafe) private var messageTask: Task<Void, Never>?
    // swiftformat:disable:next nonisolatedUnsafe
    @ObservationIgnored nonisolated(unsafe) private var stateTask: Task<Void, Never>?
    private var streamsStarted = false
    private var lightCommandTime: Date?
    private var airductCommandTime: Date?
    private var nozzleTempCommandTime: Date?
    private var bedTempCommandTime: Date?
    private var fanCommandTimes: [Int: Date] = [:]
    private var commandedNozzleTarget = 0
    private var commandedBedTarget = 0
    private var commandedFanSpeeds: [Int: Int] = [:]
    private var dryingCommandTime: Date?
    private var commandedDryingState: [Int: Int] = [:] // amsId -> dryTimeRemaining
    private var lastWidgetReload: Date?

    var mqttServiceRef: any MQTTServiceProtocol {
        mqttService
    }

    var contentState: PrinterAttributes.ContentState {
        printerState.contentState
    }

    var isConnected: Bool {
        mqttConnectionState == .connected
    }

    var hasReceivedInitialData: Bool {
        printerState.lastUpdated != nil
    }

    var isPrinting: Bool {
        let s = contentState.status
        return s == .printing || s == .preparing
    }

    var canPause: Bool {
        contentState.status == .printing
    }

    var canResume: Bool {
        contentState.status == .paused
    }

    init(mqttService: any MQTTServiceProtocol = BambuMQTTService()) {
        self.mqttService = mqttService
    }

    deinit {
        messageTask?.cancel()
        stateTask?.cancel()
    }

    /// Start consuming MQTT streams. Must be called once, before connect.
    private func startStreamsIfNeeded() {
        guard !streamsStarted else { return }
        streamsStarted = true

        // Capture the streams eagerly so the AsyncStream closures run
        // and set up their continuations before connect() is called.
        let messageStream = mqttService.messageStream
        let stateStream = mqttService.stateStream

        messageTask = Task { [weak self] in
            guard let self else { return }
            for await payload in messageStream {
                self.printerState.apply(payload)
                self.printerState.isConnected = true
                // Sync light state from printer, but ignore for 3s after
                // a local toggle to prevent the old state snapping back
                if payload.chamberLightOn != nil {
                    let suppress = self.lightCommandTime.map { Date.now.timeIntervalSince($0) < 3 } ?? false
                    if !suppress {
                        self.chamberLightOn = self.printerState.chamberLightOn
                    }
                }
                if payload.airductMode != nil {
                    let suppress = self.airductCommandTime.map { Date.now.timeIntervalSince($0) < 3 } ?? false
                    if !suppress {
                        self.selectedAirductMode = self.printerState.airductMode
                    }
                }
                // Suppress snapback for manually-set temperatures
                if payload.nozzleTargetTemper != nil,
                   let t = self.nozzleTempCommandTime, Date.now.timeIntervalSince(t) < 3
                {
                    self.printerState.nozzleTargetTemp = self.commandedNozzleTarget
                }
                if payload.bedTargetTemper != nil,
                   let t = self.bedTempCommandTime, Date.now.timeIntervalSince(t) < 3
                {
                    self.printerState.bedTargetTemp = self.commandedBedTarget
                }
                // Suppress snapback for manually-set fan speeds
                for (index, time) in self.fanCommandTimes where Date.now.timeIntervalSince(time) < 3 {
                    if let speed = self.commandedFanSpeeds[index] {
                        switch index {
                        case 1: self.printerState.partFanSpeed = speed
                        case 2: self.printerState.auxFanSpeed = speed
                        case 3: self.printerState.chamberFanSpeed = speed
                        default: break
                        }
                    }
                }
                // Suppress snapback for AMS drying commands
                if payload.amsUnits != nil,
                   let t = self.dryingCommandTime, Date.now.timeIntervalSince(t) < 5
                {
                    for (amsId, dryTime) in self.commandedDryingState {
                        if let unit = self.printerState.amsUnits.first(where: { $0.id == amsId }) {
                            unit.dryTimeRemaining = dryTime
                        }
                    }
                }

                // Update widget cache with latest state (skip placeholder data)
                if self.printerState.lastUpdated != nil {
                    SharedSettings.cachedPrinterState = PrinterStateSnapshot(from: self.printerState)
                }
                // Reload widgets periodically (debounced to every 30s)
                if self.lastWidgetReload.map({ Date.now.timeIntervalSince($0) > 30 }) ?? true {
                    self.lastWidgetReload = Date.now
                    WidgetCenter.shared.reloadTimelines(ofKind: "PrintStateWidget")
                    WidgetCenter.shared.reloadTimelines(ofKind: "AMSWidget")
                }
            }
        }

        stateTask = Task { [weak self] in
            guard let self else { return }
            for await state in stateStream {
                self.mqttConnectionState = state
                if case .disconnected = state {
                    self.printerState.isConnected = false
                } else if case .error = state {
                    self.printerState.isConnected = false
                }
            }
        }
    }

    /// Connect MQTT and camera. Awaits until MQTT reaches connected/error/timeout.
    func connectAll(ip: String, accessCode: String, printerType: PrinterType = .auto) async {
        // Set up stream consumers first so no events are missed
        startStreamsIfNeeded()

        // Then connect
        mqttService.connect(ip: ip, accessCode: accessCode)
        cameraManager.connect(ip: ip, accessCode: accessCode, printerType: printerType)

        // Wait for connection result (connected, error, or 10s timeout)
        let deadline = Date.now.addingTimeInterval(10)
        while Date.now < deadline {
            if case .connected = mqttConnectionState { return }
            if case .error = mqttConnectionState { return }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    func disconnectAll() {
        mqttService.disconnect()
        cameraManager.disconnect()
        printerState.isConnected = false
        mqttConnectionState = .disconnected
    }

    func disconnectCamera() {
        cameraManager.disconnect()
    }

    func reconnectCamera(ip: String, accessCode: String, printerType: PrinterType = .auto) {
        cameraManager.connect(ip: ip, accessCode: accessCode, printerType: printerType)
    }

    // MARK: - Commands

    func pausePrint() {
        mqttService.sendCommand(.pause)
    }

    func resumePrint() {
        mqttService.sendCommand(.resume)
    }

    func stopPrint() {
        mqttService.sendCommand(.stop)
    }

    func setSpeed(_ level: PrinterCommand.SpeedLevel) {
        selectedSpeed = level
        mqttService.sendCommand(.printSpeed(level))
    }

    func toggleLight(on: Bool) {
        chamberLightOn = on
        lightCommandTime = Date.now
        mqttService.sendCommand(.chamberLight(on: on))
    }

    func setAirductMode(_ mode: Int) {
        if isPrinting {
            pendingAirductMode = mode
            showAirductModeConfirmation = true
        } else {
            applyAirductMode(mode)
        }
    }

    func confirmAirductModeChange() {
        if let mode = pendingAirductMode {
            applyAirductMode(mode)
            pendingAirductMode = nil
        }
    }

    func cancelAirductModeChange() {
        pendingAirductMode = nil
    }

    private func applyAirductMode(_ mode: Int) {
        selectedAirductMode = mode
        airductCommandTime = Date.now
        mqttService.sendCommand(.airductMode(mode: mode))
    }

    func setNozzleTemp(_ temp: Int) {
        let clamped = max(0, min(300, temp))
        commandedNozzleTarget = clamped
        printerState.nozzleTargetTemp = clamped
        nozzleTempCommandTime = Date.now
        mqttService.sendCommand(.gcodeLine("M104 S\(clamped)"))
    }

    func setBedTemp(_ temp: Int) {
        let clamped = max(0, min(110, temp))
        commandedBedTarget = clamped
        printerState.bedTargetTemp = clamped
        bedTempCommandTime = Date.now
        mqttService.sendCommand(.gcodeLine("M140 S\(clamped)"))
    }

    func setFanSpeed(fanIndex: Int, percent: Int) {
        let clamped = max(0, min(100, percent))
        let value255 = Int(Double(clamped) / 100.0 * 255.0)
        commandedFanSpeeds[fanIndex] = value255
        fanCommandTimes[fanIndex] = Date.now
        switch fanIndex {
        case 1: printerState.partFanSpeed = value255
        case 2: printerState.auxFanSpeed = value255
        case 3: printerState.chamberFanSpeed = value255
        default: break
        }
        mqttService.sendCommand(.gcodeLine("M106 P\(fanIndex) S\(value255)"))
    }

    // MARK: - Filament Editing

    func showFilamentEdit(amsId: Int, tray: AMSTray) {
        editingAmsId = amsId
        editingTrayId = tray.id
        // Match current tray to a known preset, or default to Generic PLA
        if let idx = tray.trayInfoIdx, let preset = FilamentPreset.find(byId: idx) {
            editFilamentPreset = preset
        } else if let type = tray.materialType,
                  let preset = FilamentPreset.all.first(where: { $0.trayType == type })
        {
            editFilamentPreset = preset
        } else {
            editFilamentPreset = FilamentPreset.all[0]
        }
        editFilamentColor = tray.color ?? .white
        showFilamentEditSheet = true
    }

    func confirmFilamentEdit() {
        guard let amsId = editingAmsId, let trayId = editingTrayId else { return }
        let preset = editFilamentPreset
        let colorHex = editFilamentColor.hexRRGGBBAA

        mqttService.sendCommand(.amsFilamentSetting(
            amsId: amsId,
            trayId: trayId,
            trayInfoIdx: preset.id,
            trayType: preset.trayType,
            trayColor: colorHex,
            nozzleTempMin: preset.nozzleTempMin,
            nozzleTempMax: preset.nozzleTempMax
        ))
        showFilamentEditSheet = false
    }

    // MARK: - AMS Drying

    func showStartDrying(amsId: Int) {
        dryingAmsId = amsId
        let maxTemp = printerState.amsUnits.first(where: { $0.id == amsId })?.amsType?.maxDryingTemp ?? 85
        // Auto-detect preset from first non-empty tray material
        if let unit = printerState.amsUnits.first(where: { $0.id == amsId }),
           let material = unit.trays.first(where: { !$0.isEmpty })?.materialType,
           let preset = PrinterCommand.DryingPreset(rawValue: material)
        {
            dryingPreset = preset
            dryingTemperature = min(preset.temperature, maxTemp)
            dryingDurationMinutes = preset.durationMinutes
        } else {
            dryingPreset = .pla
            dryingTemperature = min(55, maxTemp)
            dryingDurationMinutes = 480
        }
        dryingRotateTray = false
        showDryingSheet = true
    }

    func applyDryingPreset(_ preset: PrinterCommand.DryingPreset) {
        dryingPreset = preset
        if preset != .custom {
            let maxTemp = dryingAmsId.flatMap { id in
                printerState.amsUnits.first(where: { $0.id == id })?.amsType?.maxDryingTemp
            } ?? 85
            dryingTemperature = min(preset.temperature, maxTemp)
            dryingDurationMinutes = preset.durationMinutes
        }
    }

    func startDrying() {
        guard let amsId = dryingAmsId else { return }
        let durationSeconds = dryingDurationMinutes * 60
        dryingCommandTime = Date.now
        commandedDryingState[amsId] = durationSeconds
        // Optimistically update UI
        if let unit = printerState.amsUnits.first(where: { $0.id == amsId }) {
            unit.dryTimeRemaining = durationSeconds
        }
        mqttService.sendCommand(.startDrying(
            amsId: amsId,
            temperature: max(45, dryingTemperature),
            durationMinutes: dryingDurationMinutes,
            rotateTray: dryingRotateTray
        ))
        showDryingSheet = false
    }

    func confirmStopDrying(amsId: Int) {
        stoppingDryingAmsId = amsId
        showStopDryingConfirmation = true
    }

    func stopDrying() {
        guard let amsId = stoppingDryingAmsId else { return }
        dryingCommandTime = Date.now
        commandedDryingState[amsId] = 0
        // Optimistically update UI
        if let unit = printerState.amsUnits.first(where: { $0.id == amsId }) {
            unit.dryTimeRemaining = 0
        }
        mqttService.sendCommand(.stopDrying(amsId: amsId))
        showStopDryingConfirmation = false
        stoppingDryingAmsId = nil
    }
}

// MARK: - Preview Helper

extension DashboardViewModel {
    static var preview: DashboardViewModel {
        let vm = DashboardViewModel(mqttService: MockMQTTService())
        vm.printerState.gcodeState = "RUNNING"
        vm.printerState.progress = 42
        vm.printerState.nozzleTemp = 220
        vm.printerState.nozzleTargetTemp = 220
        vm.printerState.bedTemp = 60
        vm.printerState.bedTargetTemp = 60
        vm.printerState.chamberTemp = 38
        vm.printerState.partFanSpeed = 200
        vm.printerState.auxFanSpeed = 128
        vm.printerState.heatbreakFanSpeed = 200
        vm.printerState.jobName = "Benchy"
        vm.printerState.layerNum = 150
        vm.printerState.totalLayers = 300
        vm.printerState.remainingMinutes = 83
        vm.printerState.isConnected = true
        vm.mqttConnectionState = .connected

        // Mock AMS data
        let amsUnit = AMSUnit(id: 0)
        amsUnit.hwVersion = "N3F05"
        amsUnit.humidityLevel = 3
        amsUnit.humidityRaw = 47
        amsUnit.temperature = 24.5
        amsUnit.trays = [
            AMSTray(id: 0, materialType: "PLA", color: .yellow, colorHex: "FFFF00FF",
                    remainPercent: 85, isBambuFilament: true),
            AMSTray(id: 1, materialType: "ABS", color: .red, colorHex: "FF0000FF",
                    remainPercent: 42, isBambuFilament: true),
            AMSTray(id: 2, materialType: "PETG", color: .blue, colorHex: "0000FFFF",
                    remainPercent: nil, isBambuFilament: false),
            AMSTray(id: 3),
        ]
        vm.printerState.amsUnits = [amsUnit]
        vm.printerState.activeTrayIndex = 0

        return vm
    }
}
