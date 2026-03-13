@testable import BambuModels
import Foundation
import Testing

@Suite("Printer Command Payloads")
struct PrinterCommandTests {
    // MARK: - Print Commands

    @Test("Pause command")
    func pauseCommand() {
        let dict = deserialize(.pause)
        let printData = dict["print"] as? [String: Any]
        #expect(printData?["command"] as? String == "pause")
    }

    @Test("Resume command")
    func resumeCommand() {
        let dict = deserialize(.resume)
        let printData = dict["print"] as? [String: Any]
        #expect(printData?["command"] as? String == "resume")
    }

    @Test("Stop command")
    func stopCommand() {
        let dict = deserialize(.stop)
        let printData = dict["print"] as? [String: Any]
        #expect(printData?["command"] as? String == "stop")
    }

    // MARK: - Speed Levels

    @Test("Print speed command",
          arguments: PrinterCommand.SpeedLevel.allCases)
    func printSpeed(level: PrinterCommand.SpeedLevel) {
        let dict = deserialize(.printSpeed(level))
        let printData = dict["print"] as? [String: Any]
        #expect(printData?["command"] as? String == "print_speed")
        #expect(printData?["param"] as? String == "\(level.rawValue)")
    }

    @Test("SpeedLevel raw values")
    func speedLevelRawValues() {
        #expect(PrinterCommand.SpeedLevel.silent.rawValue == 1)
        #expect(PrinterCommand.SpeedLevel.standard.rawValue == 2)
        #expect(PrinterCommand.SpeedLevel.sport.rawValue == 3)
        #expect(PrinterCommand.SpeedLevel.ludicrous.rawValue == 4)
    }

    @Test("SpeedLevel labels",
          arguments: zip(
              PrinterCommand.SpeedLevel.allCases,
              ["Silent", "Standard", "Sport", "Ludicrous"]
          ))
    func speedLevelLabels(level: PrinterCommand.SpeedLevel, expected: String) {
        #expect(String(localized: level.label) == expected)
    }

    // MARK: - Chamber Light

    @Test("Chamber light on")
    func lightOn() {
        let dict = deserialize(.chamberLight(on: true))
        let sysData = dict["system"] as? [String: Any]
        #expect(sysData?["command"] as? String == "ledctrl")
        #expect(sysData?["led_mode"] as? String == "on")
        #expect(sysData?["led_node"] as? String == "chamber_light")
    }

    @Test("Chamber light off")
    func lightOff() {
        let dict = deserialize(.chamberLight(on: false))
        let sysData = dict["system"] as? [String: Any]
        #expect(sysData?["led_mode"] as? String == "off")
    }

    // MARK: - Airduct Mode

    @Test("Airduct mode command")
    func airductMode() {
        let dict = deserialize(.airductMode(mode: 1))
        let printData = dict["print"] as? [String: Any]
        #expect(printData?["command"] as? String == "set_airduct")
        #expect(printData?["modeId"] as? Int == 1)
    }

    // MARK: - G-code

    @Test("Gcode line appends newline")
    func gcodeNewline() {
        let dict = deserialize(.gcodeLine("M104 S220"))
        let printData = dict["print"] as? [String: Any]
        #expect(printData?["command"] as? String == "gcode_line")
        #expect(printData?["param"] as? String == "M104 S220\n")
    }

    // MARK: - PushAll

    @Test("PushAll uses 'pushing' key")
    func pushAll() {
        let dict = deserialize(.pushAll)
        #expect(dict["pushing"] != nil)
        #expect(dict["print"] == nil)
        let pushData = dict["pushing"] as? [String: Any]
        #expect(pushData?["command"] as? String == "pushall")
    }

    // MARK: - AMS Drying

    @Test("Start drying command")
    func startDrying() {
        let dict = deserialize(.startDrying(amsId: 0, temperature: 55, durationMinutes: 480, rotateTray: false))
        let printData = dict["print"] as? [String: Any]
        #expect(printData?["command"] as? String == "ams_filament_drying")
        #expect(printData?["ams_id"] as? Int == 0)
        #expect(printData?["temp"] as? Int == 55)
        #expect(printData?["duration"] as? Int == 480 / 60)
        #expect(printData?["rotate_tray"] as? Bool == false)
        #expect(printData?["cooling_temp"] as? Int == 45)
        #expect(printData?["mode"] as? Int == 1)
    }

    @Test("Stop drying command")
    func stopDrying() {
        let dict = deserialize(.stopDrying(amsId: 0))
        let printData = dict["print"] as? [String: Any]
        #expect(printData?["command"] as? String == "ams_filament_drying")
        #expect(printData?["mode"] as? Int == 0)
        #expect(printData?["ams_id"] as? Int == 0)
        #expect(printData?["temp"] as? Int == 0)
        #expect(printData?["duration"] as? Int == 0)
    }

    @Test("DryingPreset temperatures",
          arguments: zip(
              PrinterCommand.DryingPreset.allCases,
              [55, 80, 65, 55, 80, 55]
          ))
    func dryingPresetTemps(preset: PrinterCommand.DryingPreset, expected: Int) {
        #expect(preset.temperature == expected)
    }

    // MARK: - Helpers

    private func deserialize(_ command: PrinterCommand) -> [String: Any] {
        let data = command.payload()
        return try! JSONSerialization.jsonObject(with: data) as! [String: Any]
    }
}
