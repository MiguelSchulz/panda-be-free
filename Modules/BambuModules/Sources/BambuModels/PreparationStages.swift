import Foundation

public enum PreparationStages {
    // MARK: - Stage Names (stg_cur → human-readable)

    private static let stageNames: [Int: String] = [
        1: "Auto bed leveling",
        2: "Preheating heatbed",
        3: "Vibration compensation",
        4: "Changing filament",
        5: "M400 pause",
        6: "Filament runout pause",
        7: "Heating hotend",
        8: "Calibrating extrusion",
        9: "Scanning bed surface",
        10: "Inspecting first layer",
        11: "Identifying build plate",
        12: "Calibrating micro lidar",
        13: "Homing toolhead",
        14: "Cleaning nozzle tip",
        15: "Checking extruder temp",
        16: "Paused by user",
        17: "Front cover falling",
        18: "Calibrating micro lidar",
        19: "Calibrating extrusion flow",
        20: "Nozzle temp malfunction",
        21: "Heatbed temp malfunction",
        22: "Filament unloading",
        23: "Paused: skipped step",
        24: "Filament loading",
        25: "Calibrating motor noise",
        26: "Paused: AMS lost",
        27: "Paused: low fan speed",
        28: "Chamber temp control error",
        29: "Cooling chamber",
        30: "Paused by G-code",
        31: "Motor noise calibration",
        32: "Paused: nozzle filament covered",
        33: "Paused: cutter error",
        34: "Paused: first layer error",
        35: "Paused: nozzle clog",
        36: "Checking absolute accuracy",
        37: "Absolute accuracy calibration",
        38: "Checking absolute accuracy",
        39: "Calibrating nozzle offset",
        40: "Bed leveling (high temp)",
        41: "Checking quick release",
        42: "Checking door and cover",
        43: "Laser calibration",
        44: "Checking platform",
        45: "Checking camera position",
        46: "Calibrating camera",
        47: "Bed leveling phase 1",
        48: "Bed leveling phase 2",
        49: "Heating chamber",
        50: "Cooling heatbed",
        51: "Printing calibration lines",
        52: "Checking material",
        53: "Live view camera calibration",
        54: "Waiting for heatbed temp",
        55: "Checking material position",
        56: "Cutting module offset calibration",
        57: "Measuring surface",
        58: "Thermal preconditioning",
        59: "Homing blade holder",
        60: "Calibrating camera offset",
        61: "Calibrating blade holder",
        62: "Hotend pick and place test",
        63: "Waiting for chamber temp",
        64: "Preparing hotend",
        65: "Calibrating nozzle clump detection",
        66: "Purifying chamber air",
        77: "Preparing AMS",
    ]

    // MARK: - Stage Categories

    public enum Category: String, Sendable {
        case prepare
        case calibrate
        case paused
        case filament
        case issue
    }

    private static let stageCategories: [Int: Category] = [
        // prepare — normal pre-print setup
        1: .prepare, 2: .prepare, 3: .prepare, 7: .prepare, 9: .prepare,
        11: .prepare, 13: .prepare, 14: .prepare, 15: .prepare, 29: .prepare,
        40: .prepare, 41: .prepare, 42: .prepare, 47: .prepare, 48: .prepare,
        49: .prepare, 50: .prepare, 51: .prepare, 52: .prepare, 54: .prepare,
        55: .prepare, 57: .prepare, 58: .prepare, 59: .prepare, 63: .prepare,
        64: .prepare, 66: .prepare, 77: .prepare,
        // calibrate — calibration/scanning steps
        8: .calibrate, 10: .calibrate, 12: .calibrate, 18: .calibrate,
        19: .calibrate, 25: .calibrate, 31: .calibrate, 36: .calibrate,
        37: .calibrate, 38: .calibrate, 39: .calibrate, 43: .calibrate,
        44: .calibrate, 45: .calibrate, 46: .calibrate, 53: .calibrate,
        56: .calibrate, 60: .calibrate, 61: .calibrate, 62: .calibrate,
        65: .calibrate,
        // paused — expected interruptions
        5: .paused, 16: .paused, 30: .paused,
        // filament — filament operations
        4: .filament, 22: .filament, 24: .filament,
        // issue — errors/malfunctions
        6: .issue, 17: .issue, 20: .issue, 21: .issue, 23: .issue,
        26: .issue, 27: .issue, 28: .issue, 32: .issue, 33: .issue,
        34: .issue, 35: .issue,
    ]

    // MARK: - Public API

    public static func name(for stgCur: Int) -> String? {
        stageNames[stgCur]
    }

    public static func category(for stgCur: Int) -> Category? {
        stageCategories[stgCur]
    }

    /// Determine printer status and stage category from gcode state, stg_cur, and layer number.
    /// Mirrors the Python server's `_determine_state()` logic.
    public static func determineState(
        gcodeState: String,
        stgCur: Int,
        layerNum: Int
    ) -> (status: PrinterStatus, category: String?) {
        if gcodeState == "FINISH" || gcodeState == "COMPLETED" {
            return (.completed, nil)
        }
        if gcodeState == "CANCELLED" || gcodeState == "FAILED" {
            return (.cancelled, nil)
        }

        if gcodeState == "PAUSE" {
            let cat = stageCategories[stgCur]
            return (.paused, cat?.rawValue ?? "paused")
        }

        let cat = stageCategories[stgCur]
        let stageName = stageNames[stgCur]

        // Pauses and issues are always interruptions
        if cat == .paused || cat == .issue {
            let status: PrinterStatus = cat == .issue ? .issue : .paused
            return (status, cat?.rawValue)
        }

        // Prep/calibration/filament: use layer_num to determine context
        if cat == .prepare || cat == .calibrate || cat == .filament {
            if gcodeState == "PREPARE" || ((gcodeState == "RUNNING" || gcodeState == "PRINTING") && stageName != nil) {
                if layerNum >= 1 {
                    return (.paused, cat?.rawValue)
                } else {
                    return (.preparing, cat?.rawValue)
                }
            }
        }

        if gcodeState == "RUNNING" || gcodeState == "PRINTING" {
            return (.printing, nil)
        }

        return (.idle, nil)
    }
}
