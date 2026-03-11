import Foundation

public enum PrinterCommand {
    case pause
    case resume
    case stop
    case printSpeed(SpeedLevel)
    case chamberLight(on: Bool)
    case airductMode(mode: Int)
    case gcodeLine(String)
    case startDrying(amsId: Int, temperature: Int, durationMinutes: Int, rotateTray: Bool)
    case stopDrying(amsId: Int)
    case amsFilamentSetting(amsId: Int, trayId: Int, trayInfoIdx: String, trayType: String,
                               trayColor: String, nozzleTempMin: Int, nozzleTempMax: Int)
    case getVersion
    case pushAll

    public enum DryingPreset: String, CaseIterable, Identifiable, Sendable {
        case pla = "PLA"
        case abs = "ABS"
        case petg = "PETG"
        case tpu = "TPU"
        case pa = "PA"
        case custom = "Custom"

        public var id: String { rawValue }

        public var temperature: Int {
            switch self {
            case .pla: 55
            case .abs: 80
            case .petg: 65
            case .tpu: 55
            case .pa: 80
            case .custom: 55
            }
        }

        public var durationMinutes: Int {
            switch self {
            case .pla: 480
            case .abs: 480
            case .petg: 480
            case .tpu: 480
            case .pa: 720
            case .custom: 480
            }
        }
    }

    public enum SpeedLevel: Int, CaseIterable, Identifiable, Sendable {
        case silent = 1
        case standard = 2
        case sport = 3
        case ludicrous = 4

        public var id: Int { rawValue }

        public var label: String {
            switch self {
            case .silent: "Silent"
            case .standard: "Standard"
            case .sport: "Sport"
            case .ludicrous: "Ludicrous"
            }
        }
    }

    public func payload(sequenceId: String = "0") -> Data {
        let dict: [String: Any]

        switch self {
        case .pause:
            dict = ["print": ["sequence_id": sequenceId, "command": "pause", "param": ""]]
        case .resume:
            dict = ["print": ["sequence_id": sequenceId, "command": "resume", "param": ""]]
        case .stop:
            dict = ["print": ["sequence_id": sequenceId, "command": "stop", "param": ""]]
        case .printSpeed(let level):
            dict = ["print": ["sequence_id": sequenceId, "command": "print_speed", "param": "\(level.rawValue)"]]
        case .chamberLight(let on):
            dict = ["system": [
                "sequence_id": sequenceId,
                "command": "ledctrl",
                "led_node": "chamber_light",
                "led_mode": on ? "on" : "off",
                "led_on_time": 500,
                "led_off_time": 500,
                "loop_times": 1,
                "interval_time": 1000,
            ]]
        case .airductMode(let mode):
            dict = ["print": [
                "sequence_id": sequenceId,
                "command": "set_airduct",
                "modeId": mode,
                "submode": -1,
            ]]
        case .gcodeLine(let gcode):
            dict = ["print": [
                "sequence_id": sequenceId,
                "command": "gcode_line",
                "param": gcode + "\n",
            ]]
        case .startDrying(let amsId, let temperature, let durationMinutes, let rotateTray):
            dict = ["print": [
                "sequence_id": sequenceId,
                "command": "ams_filament_drying",
                "ams_id": amsId,
                "temp": temperature,
                "cooling_temp": 45,
                "duration": durationMinutes,
                "humidity": 0,
                "mode": 1,
                "rotate_tray": rotateTray,
            ] as [String: Any]]
        case .stopDrying(let amsId):
            dict = ["print": [
                "sequence_id": sequenceId,
                "command": "ams_filament_drying",
                "ams_id": amsId,
                "temp": 0,
                "cooling_temp": 45,
                "duration": 0,
                "humidity": 0,
                "mode": 0,
                "rotate_tray": false,
            ] as [String: Any]]
        case .amsFilamentSetting(let amsId, let trayId, let trayInfoIdx, let trayType,
                                let trayColor, let nozzleTempMin, let nozzleTempMax):
            dict = ["print": [
                "sequence_id": sequenceId,
                "command": "ams_filament_setting",
                "ams_id": amsId,
                "tray_id": trayId,
                "tray_info_idx": trayInfoIdx,
                "tray_type": trayType,
                "tray_color": trayColor,
                "nozzle_temp_min": nozzleTempMin,
                "nozzle_temp_max": nozzleTempMax,
            ] as [String: Any]]
        case .getVersion:
            dict = ["info": ["sequence_id": sequenceId, "command": "get_version"]]
        case .pushAll:
            dict = ["pushing": ["sequence_id": sequenceId, "command": "pushall"]]
        }

        return try! JSONSerialization.data(withJSONObject: dict)
    }
}
