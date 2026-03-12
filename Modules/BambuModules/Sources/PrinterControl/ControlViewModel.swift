import BambuModels
import BambuUI
import Foundation
import Networking

@MainActor
@Observable
public final class ControlViewModel {
    private let mqttService: any MQTTServiceProtocol
    public let cameraProvider: (any CameraStreamProviding)?
    public let printerState: PrinterState

    public var isLightOn: Bool

    public var showHomingWarning = false
    public var showExtruderTempWarning = false

    /// Controls are allowed when the printer is idle, or after a print completes/cancels.
    public var controlsEnabled: Bool {
        switch printerState.contentState.status {
        case .idle, .completed, .cancelled: true
        default: false
        }
    }

    public init(
        mqttService: any MQTTServiceProtocol,
        cameraProvider: (any CameraStreamProviding)? = nil,
        isLightOn: Bool = false,
        printerState: PrinterState = PrinterState()
    ) {
        self.mqttService = mqttService
        self.cameraProvider = cameraProvider
        self.isLightOn = isLightOn
        self.printerState = printerState
    }

    // MARK: - XY Jog

    public func jogX(distance: Double) {
        guard checkXYHomed() else { return }
        sendJog(axis: "X", distance: distance, feedrate: 3000)
    }

    public func jogY(distance: Double) {
        guard checkXYHomed() else { return }
        sendJog(axis: "Y", distance: distance, feedrate: 3000)
    }

    // MARK: - Home

    public func homeAll() {
        mqttService.sendCommand(.gcodeLine("G28"))
    }

    // MARK: - Z Jog

    public func jogZ(distance: Double) {
        guard checkZHomed() else { return }
        sendJog(axis: "Z", distance: distance, feedrate: 1200)
    }

    // MARK: - Extruder

    public func extrude() {
        guard checkExtruderTemp() else { return }
        sendGcode(["M83", "G1 E10 F300", "M82"])
    }

    public func retract() {
        guard checkExtruderTemp() else { return }
        sendGcode(["M83", "G1 E-10 F300", "M82"])
    }

    // MARK: - Light

    public func toggleLight(on: Bool) {
        isLightOn = on
        mqttService.sendCommand(.chamberLight(on: on))
    }

    // MARK: - Homing Checks

    /// Matches OrcaSlicer's `is_axis_at_home` logic:
    /// - `homeFlag == 0` → default state, all axes considered homed
    /// - Otherwise, bit 0 = X homed, bit 1 = Y homed, bit 2 = Z homed
    public func isAxisHomed(_ axis: Character) -> Bool {
        let flag = printerState.homeFlag
        if flag == 0 { return true }
        switch axis {
        case "X": return (flag & 1) == 1
        case "Y": return (flag >> 1 & 1) == 1
        case "Z": return (flag >> 2 & 1) == 1
        default: return true
        }
    }

    // MARK: - Private

    private func checkXYHomed() -> Bool {
        if !isAxisHomed("X") || !isAxisHomed("Y") {
            showHomingWarning = true
            return false
        }
        return true
    }

    private func checkZHomed() -> Bool {
        if !isAxisHomed("Z") {
            showHomingWarning = true
            return false
        }
        return true
    }

    private func checkExtruderTemp() -> Bool {
        if printerState.nozzleTemp < 170 {
            showExtruderTempWarning = true
            return false
        }
        return true
    }

    private func sendJog(axis: String, distance: Double, feedrate: Int) {
        // Match OrcaSlicer: push soft endstop state, force them ON so firmware
        // clips the move to physical limits, then restore previous state.
        sendGcode([
            "M211 S",
            "M211 X1 Y1 Z1",
            "G91",
            "G1 \(axis)\(formatDistance(distance)) F\(feedrate)",
            "G90",
            "M211 R",
        ])
    }

    private func sendGcode(_ lines: [String]) {
        let joined = lines.joined(separator: "\n")
        mqttService.sendCommand(.gcodeLine(joined))
    }

    private func formatDistance(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(value)
    }

    // MARK: - Preview

    static var preview: ControlViewModel {
        ControlViewModel(mqttService: MockMQTTService(), isLightOn: true)
    }
}
