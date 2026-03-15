import Foundation
import Networking
import PandaLogger
import PandaModels
import PandaNotifications
import SwiftUI
import WidgetKit

private let logCategory = "Dashboard"

@MainActor
@Observable
final class DashboardViewModel {
    struct PrinterConfig {
        let ip: String
        let accessCode: String
        let serial: String
        let printerModel: BambuPrinter?

        var printerType: PrinterType {
            printerModel?.cameraProtocol ?? .auto
        }

        static func fromSharedSettings() -> PrinterConfig {
            PrinterConfig(
                ip: SharedSettings.printerIP,
                accessCode: SharedSettings.printerAccessCode,
                serial: SharedSettings.printerSerial,
                printerModel: SharedSettings.printerModel
            )
        }
    }

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
    private let notificationScheduler: any NotificationScheduling
    private let liveActivityManager: any LiveActivityManaging
    private var wasConnected = false
    // nonisolated(unsafe) allows cancellation from deinit; Task.cancel() is thread-safe.
    // swiftformat:disable:next nonisolatedUnsafe
    @ObservationIgnored private nonisolated(unsafe) var messageTask: Task<Void, Never>?
    // swiftformat:disable:next nonisolatedUnsafe
    @ObservationIgnored private nonisolated(unsafe) var stateTask: Task<Void, Never>?
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
    private var commandedDryingState: [Int: Int] = [:] // amsId -> dryTimeRemaining (minutes)
    private var lastWidgetReload: Date?
    private var lastScheduledPrintMinutes: Int?
    private var lastScheduledDryingMinutes: [Int: Int] = [:]
    private var lastScheduledStatus: PrinterStatus?

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

    init(
        mqttService: any MQTTServiceProtocol = PandaMQTTService(),
        notificationScheduler: any NotificationScheduling = LocalNotificationScheduler.shared,
        liveActivityManager: any LiveActivityManaging = LiveActivityManager.shared
    ) {
        self.mqttService = mqttService
        self.notificationScheduler = notificationScheduler
        self.liveActivityManager = liveActivityManager
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
                let wasFirstUpdate = self.printerState.lastUpdated == nil
                let previousStgCur = self.printerState.stgCur
                self.printerState.apply(payload)
                self.printerState.isConnected = true

                if wasFirstUpdate {
                    appLog(.info, category: logCategory, "First printer data received — state: \(self.printerState.gcodeState)")
                }
                // Log printer issue states
                if let stg = payload.stgCur, stg != previousStgCur {
                    let (status, category) = PreparationStages.determineState(
                        gcodeState: self.printerState.gcodeState,
                        stgCur: stg,
                        layerNum: self.printerState.layerNum
                    )
                    if status == .issue {
                        let stageName = PreparationStages.name(for: stg) ?? "unknown"
                        appLog(.warning, category: category ?? "Printer", "Printer issue detected: \(stageName) (stg_cur: \(stg))")
                    }
                }
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
                    let snapshot = PrinterStateSnapshot(from: self.printerState)
                    SharedSettings.cachedPrinterState = snapshot

                    // Schedule/cancel notifications only when ETA or status changes
                    let cs = snapshot.contentState
                    let statusChanged = cs.status != self.lastScheduledStatus
                    let printETAChanged = cs.remainingMinutes != self.lastScheduledPrintMinutes
                    let dryingChanged = snapshot.amsUnits.contains { unit in
                        self.lastScheduledDryingMinutes[unit.id] != unit.dryTimeRemaining
                    }
                    if statusChanged || printETAChanged || dryingChanged {
                        self.lastScheduledStatus = cs.status
                        self.lastScheduledPrintMinutes = cs.remainingMinutes
                        for unit in snapshot.amsUnits {
                            self.lastScheduledDryingMinutes[unit.id] = unit.dryTimeRemaining
                        }
                        let actions = NotificationEvaluator.evaluate(
                            contentState: cs,
                            amsUnits: snapshot.amsUnits
                        )
                        let scheduler = self.notificationScheduler
                        Task { await scheduler.execute(actions) }
                    }
                }
                // Reload widgets periodically (debounced to every 30s)
                if self.lastWidgetReload.map({ Date.now.timeIntervalSince($0) > 30 }) ?? true {
                    self.lastWidgetReload = Date.now
                    WidgetCenter.shared.reloadTimelines(ofKind: "PrintStateWidget")
                    WidgetCenter.shared.reloadTimelines(ofKind: "AMSWidget")
                }

                // Update Live Activity
                if self.printerState.lastUpdated != nil {
                    let cs = self.printerState.contentState
                    let printerName = SharedSettings.printerModel?.displayName ?? "3D Printer"
                    let lam = self.liveActivityManager
                    Task {
                        await lam.startIfNeeded(contentState: cs, printerName: printerName)
                        await lam.update(contentState: cs)
                        await lam.endIfNeeded(contentState: cs)
                    }
                }
            }
        }

        stateTask = Task { [weak self] in
            guard let self else { return }
            for await state in stateStream {
                self.mqttConnectionState = state
                switch state {
                case .disconnected:
                    self.printerState.isConnected = false
                case let .error(message):
                    appLog(.error, category: logCategory, "MQTT connection error: \(message)")
                    self.printerState.isConnected = false
                case .connected:
                    appLog(.info, category: logCategory, "MQTT connected")
                case .connecting:
                    break
                }
            }
        }
    }

    /// Connect MQTT and camera using config from SharedSettings. Awaits until MQTT reaches connected/error/timeout.
    func connectAll() async {
        let config = PrinterConfig.fromSharedSettings()
        appLog(.info, category: logCategory, "connectAll — model: \(config.printerModel?.displayName ?? "unknown"), IP: \(config.ip), camera: \(config.printerType)")
        // Set up stream consumers first so no events are missed
        startStreamsIfNeeded()

        // Then connect
        mqttService.connect(ip: config.ip, accessCode: config.accessCode, serial: config.serial)
        // Only reconnect camera if not already streaming — avoids killing the
        // shared stream when SwiftUI re-runs .task on tab switches.
        if !cameraManager.isStreaming {
            cameraManager.connect(ip: config.ip, accessCode: config.accessCode, printerType: config.printerType)
        }

        // Wait for connection result (connected, error, or 10s timeout)
        let deadline = Date.now.addingTimeInterval(10)
        while Date.now < deadline {
            if case .connected = mqttConnectionState { return }
            if case .error = mqttConnectionState { return }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    func disconnectAll() {
        appLog(.info, category: logCategory, "disconnectAll")
        mqttService.disconnect()
        cameraManager.disconnect()
        printerState.isConnected = false
        mqttConnectionState = .disconnected
        lastScheduledPrintMinutes = nil
        lastScheduledDryingMinutes = [:]
        lastScheduledStatus = nil
    }

    /// Disconnect and clear all saved configuration, returning to onboarding.
    func clearConfigAndDisconnect() {
        disconnectAll()
        SharedSettings.printerIP = ""
        SharedSettings.printerAccessCode = ""
        SharedSettings.printerSerial = ""
        SharedSettings.printerModel = nil
    }

    func disconnectCamera() {
        cameraManager.disconnect()
    }

    func reconnectCamera() {
        let config = PrinterConfig.fromSharedSettings()
        cameraManager.connect(ip: config.ip, accessCode: config.accessCode, printerType: config.printerType)
    }

    /// Handle scene phase transitions. Call from `onChange(of: scenePhase)`.
    func handleScenePhase(_ newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            appLog(.info, category: logCategory, "Scene phase → background")
            if isConnected || mqttConnectionState == .connecting {
                wasConnected = true
                if hasReceivedInitialData {
                    SharedSettings.cachedPrinterState = PrinterStateSnapshot(from: printerState)
                    // Final Live Activity update before losing MQTT
                    let cs = printerState.contentState
                    let lam = liveActivityManager
                    Task { await lam.update(contentState: cs) }
                }
                disconnectAll()
                WidgetCenter.shared.reloadAllTimelines()
                // Schedule background refresh for Live Activity updates
                if liveActivityManager.isActivityActive {
                    AppDelegate.scheduleLiveActivityRefresh()
                }
            }
        case .active:
            appLog(.info, category: logCategory, "Scene phase → active (wasConnected: \(wasConnected))")
            WidgetCenter.shared.reloadTimelines(ofKind: "PrintStateWidget")
            WidgetCenter.shared.reloadTimelines(ofKind: "AMSWidget")
            // Reconcile notifications and Live Activity from cached state before MQTT reconnects
            if let cached = SharedSettings.cachedPrinterState {
                let lam = liveActivityManager
                let scheduler = notificationScheduler
                Task {
                    let actions = NotificationEvaluator.evaluate(
                        contentState: cached.contentState,
                        amsUnits: cached.amsUnits
                    )
                    await scheduler.execute(actions)
                    await lam.update(contentState: cached.contentState)
                }
            }
            if wasConnected {
                wasConnected = false
                Task { await connectAll() }
            }
        default:
            break
        }
    }

    // MARK: - Commands

    func pausePrint() {
        appLog(.info, category: logCategory, "Command: pause")
        mqttService.sendCommand(.pause)
    }

    func resumePrint() {
        appLog(.info, category: logCategory, "Command: resume")
        mqttService.sendCommand(.resume)
    }

    func stopPrint() {
        appLog(.info, category: logCategory, "Command: stop")
        mqttService.sendCommand(.stop)
    }

    func setSpeed(_ level: PrinterCommand.SpeedLevel) {
        appLog(.info, category: logCategory, "Command: setSpeed(\(level))")
        selectedSpeed = level
        mqttService.sendCommand(.printSpeed(level))
    }

    func toggleLight(on: Bool) {
        appLog(.info, category: logCategory, "Command: light \(on ? "on" : "off")")
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
        appLog(.info, category: logCategory, "Command: airductMode(\(mode))")
        selectedAirductMode = mode
        airductCommandTime = Date.now
        mqttService.sendCommand(.airductMode(mode: mode))
    }

    func setNozzleTemp(_ temp: Int) {
        let clamped = max(0, min(300, temp))
        appLog(.info, category: logCategory, "Command: setNozzleTemp(\(clamped))")
        commandedNozzleTarget = clamped
        printerState.nozzleTargetTemp = clamped
        nozzleTempCommandTime = Date.now
        mqttService.sendCommand(.gcodeLine("M104 S\(clamped)"))
    }

    func setBedTemp(_ temp: Int) {
        let clamped = max(0, min(110, temp))
        appLog(.info, category: logCategory, "Command: setBedTemp(\(clamped))")
        commandedBedTarget = clamped
        printerState.bedTargetTemp = clamped
        bedTempCommandTime = Date.now
        mqttService.sendCommand(.gcodeLine("M140 S\(clamped)"))
    }

    func setFanSpeed(fanIndex: Int, percent: Int) {
        let clamped = max(0, min(100, percent))
        appLog(.info, category: logCategory, "Command: setFanSpeed(fan: \(fanIndex), percent: \(clamped))")
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
        dryingCommandTime = Date.now
        commandedDryingState[amsId] = dryingDurationMinutes
        // Optimistically update UI
        if let unit = printerState.amsUnits.first(where: { $0.id == amsId }) {
            unit.dryTimeRemaining = dryingDurationMinutes
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
