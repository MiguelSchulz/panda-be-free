import Foundation
import PandaModels
import Testing

@Suite
struct PrinterCommandProjectFileTests {
    @Test func projectFilePayload() throws {
        let command = PrinterCommand.projectFile(
            filename: "test_model.3mf",
            plateId: 1,
            amsMapping: [0, 2, -1],
            useAMS: true
        )

        let data = command.payload()
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let print = try #require(json["print"] as? [String: Any])

        #expect(print["command"] as? String == "project_file")
        #expect(print["param"] as? String == "Metadata/plate_1.gcode")
        #expect(print["url"] as? String == "file:///sdcard/cache/test_model.3mf")
        #expect(print["subtask_name"] as? String == "test_model.3mf")
        #expect(print["use_ams"] as? Bool == true)
        #expect(print["bed_type"] as? String == "auto")
        #expect(print["bed_leveling"] as? Bool == true)

        let mapping = try #require(print["ams_mapping"] as? [Int])
        #expect(mapping == [0, 2, -1])
    }

    @Test func projectFileNoAMS() throws {
        let command = PrinterCommand.projectFile(
            filename: "simple.3mf",
            amsMapping: [0],
            useAMS: false
        )

        let data = command.payload()
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let print = try #require(json["print"] as? [String: Any])

        #expect(print["use_ams"] as? Bool == false)
        #expect(print["ams_mapping"] as? [Int] == [0])
    }

    @Test func logDescription() {
        let command = PrinterCommand.projectFile(
            filename: "model.3mf",
            amsMapping: [0],
            useAMS: true
        )

        #expect(command.logDescription == "projectFile(model.3mf)")
    }
}
