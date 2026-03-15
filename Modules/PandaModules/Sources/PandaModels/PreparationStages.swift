import Foundation

public enum PreparationStages {
    // MARK: - Stage Categories

    public enum Category: String, Sendable {
        case prepare
        case calibrate
        case paused
        case filament
        case issue
    }

    // MARK: - Public API

    public static func name(for stgCur: Int) -> String? {
        switch stgCur {
        case 1: String(localized: "Auto bed leveling")
        case 2: String(localized: "Preheating heatbed")
        case 3: String(localized: "Vibration compensation")
        case 4: String(localized: "Changing filament")
        case 5: String(localized: "M400 pause")
        case 6: String(localized: "Filament runout pause")
        case 7: String(localized: "Heating hotend")
        case 8: String(localized: "Calibrating extrusion")
        case 9: String(localized: "Scanning bed surface")
        case 10: String(localized: "Inspecting first layer")
        case 11: String(localized: "Identifying build plate")
        case 12, 18: String(localized: "Calibrating micro lidar")
        case 13: String(localized: "Homing toolhead")
        case 14: String(localized: "Cleaning nozzle tip")
        case 15: String(localized: "Checking extruder temp")
        case 16: String(localized: "Paused by user")
        case 17: String(localized: "Front cover falling")
        case 19: String(localized: "Calibrating extrusion flow")
        case 20: String(localized: "Nozzle temp malfunction")
        case 21: String(localized: "Heatbed temp malfunction")
        case 22: String(localized: "Filament unloading")
        case 23: String(localized: "Paused: skipped step")
        case 24: String(localized: "Filament loading")
        case 25: String(localized: "Calibrating motor noise")
        case 26: String(localized: "Paused: AMS lost")
        case 27: String(localized: "Paused: low fan speed")
        case 28: String(localized: "Chamber temp control error")
        case 29: String(localized: "Cooling chamber")
        case 30: String(localized: "Paused by G-code")
        case 31: String(localized: "Motor noise calibration")
        case 32: String(localized: "Paused: nozzle filament covered")
        case 33: String(localized: "Paused: cutter error")
        case 34: String(localized: "Paused: first layer error")
        case 35: String(localized: "Paused: nozzle clog")
        case 36, 38: String(localized: "Checking absolute accuracy")
        case 37: String(localized: "Absolute accuracy calibration")
        case 39: String(localized: "Calibrating nozzle offset")
        case 40: String(localized: "Bed leveling (high temp)")
        case 41: String(localized: "Checking quick release")
        case 42: String(localized: "Checking door and cover")
        case 43: String(localized: "Laser calibration")
        case 44: String(localized: "Checking platform")
        case 45: String(localized: "Checking camera position")
        case 46: String(localized: "Calibrating camera")
        case 47: String(localized: "Bed leveling phase 1")
        case 48: String(localized: "Bed leveling phase 2")
        case 49: String(localized: "Heating chamber")
        case 50: String(localized: "Cooling heatbed")
        case 51: String(localized: "Printing calibration lines")
        case 52: String(localized: "Checking material")
        case 53: String(localized: "Live view camera calibration")
        case 54: String(localized: "Waiting for heatbed temp")
        case 55: String(localized: "Checking material position")
        case 56: String(localized: "Cutting module offset calibration")
        case 57: String(localized: "Measuring surface")
        case 58: String(localized: "Thermal preconditioning")
        case 59: String(localized: "Homing blade holder")
        case 60: String(localized: "Calibrating camera offset")
        case 61: String(localized: "Calibrating blade holder")
        case 62: String(localized: "Hotend pick and place test")
        case 63: String(localized: "Waiting for chamber temp")
        case 64: String(localized: "Preparing hotend")
        case 65: String(localized: "Calibrating nozzle clump detection")
        case 66: String(localized: "Purifying chamber air")
        case 77: String(localized: "Preparing AMS")
        default: nil
        }
    }

    public static func category(for stgCur: Int) -> Category? {
        switch stgCur {
        // prepare — normal pre-print setup
        case 1, 2, 3, 7, 9, 11, 13, 14, 15, 29,
             40, 41, 42, 47, 48, 49, 50, 51, 52, 54,
             55, 57, 58, 59, 63, 64, 66, 77:
            .prepare
        // calibrate — calibration/scanning steps
        case 8, 10, 12, 18, 19, 25, 31, 36, 37, 38,
             39, 43, 44, 45, 46, 53, 56, 60, 61, 62, 65:
            .calibrate
        // paused — expected interruptions
        case 5, 16, 30:
            .paused
        // filament — filament operations
        case 4, 22, 24:
            .filament
        // issue — errors/malfunctions
        case 6, 17, 20, 21, 23, 26, 27, 28, 32, 33, 34, 35:
            .issue
        default:
            nil
        }
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
            let cat = category(for: stgCur)
            return (.paused, cat?.rawValue ?? "paused")
        }

        let cat = category(for: stgCur)
        let hasName = name(for: stgCur) != nil

        // Pauses and issues are always interruptions
        if cat == .paused || cat == .issue {
            let status: PrinterStatus = cat == .issue ? .issue : .paused
            return (status, cat?.rawValue)
        }

        // Prep/calibration/filament: use layer_num to determine context
        if cat == .prepare || cat == .calibrate || cat == .filament {
            if gcodeState == "PREPARE" || ((gcodeState == "RUNNING" || gcodeState == "PRINTING") && hasName) {
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
