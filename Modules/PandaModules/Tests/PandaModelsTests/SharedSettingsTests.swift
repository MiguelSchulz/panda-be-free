@testable import PandaModels
import Testing

@Suite("PrinterType Enum")
struct SharedSettingsTests {
    @Test("Raw values match expected strings",
          arguments: [
              (PrinterType.auto, "auto"),
              (PrinterType.rtsp, "rtsp"),
              (PrinterType.tcp, "tcp"),
          ])
    func rawValues(type: PrinterType, expected: String) {
        #expect(type.rawValue == expected)
    }

    @Test("CaseIterable has 3 cases")
    func caseCount() {
        #expect(PrinterType.allCases.count == 3)
    }

    @Test("id equals rawValue for all cases", arguments: PrinterType.allCases)
    func idEqualsRawValue(type: PrinterType) {
        #expect(type.id == type.rawValue)
    }

    @Test("displayName is non-empty for all cases", arguments: PrinterType.allCases)
    func displayNameNonEmpty(type: PrinterType) {
        let name = String(localized: type.displayName)
        #expect(!name.isEmpty)
    }

    @Test("Init from valid rawValue returns case",
          arguments: [("auto", PrinterType.auto), ("rtsp", PrinterType.rtsp), ("tcp", PrinterType.tcp)])
    func initFromValidRawValue(raw: String, expected: PrinterType) {
        #expect(PrinterType(rawValue: raw) == expected)
    }

    @Test("Init from invalid rawValue returns nil")
    func initFromInvalidRawValue() {
        #expect(PrinterType(rawValue: "invalid") == nil)
    }
}
