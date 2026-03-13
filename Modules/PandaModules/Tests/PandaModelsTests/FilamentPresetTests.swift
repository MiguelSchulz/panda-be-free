@testable import PandaModels
import Testing

@Suite("Filament Presets")
struct FilamentPresetTests {
    @Test("All preset IDs are unique")
    func uniqueIds() {
        let ids = FilamentPreset.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("All presets have non-empty name, trayType, and id")
    func nonEmptyFields() {
        for preset in FilamentPreset.all {
            #expect(!preset.id.isEmpty, "Preset has empty id")
            #expect(!preset.name.isEmpty, "Preset \(preset.id) has empty name")
            #expect(!preset.trayType.isEmpty, "Preset \(preset.id) has empty trayType")
        }
    }

    @Test("Nozzle temp ranges are valid", arguments: FilamentPreset.all)
    func validTempRanges(preset: FilamentPreset) {
        #expect(preset.nozzleTempMin >= 150, "Preset \(preset.id) min temp \(preset.nozzleTempMin) < 150")
        #expect(preset.nozzleTempMax <= 350, "Preset \(preset.id) max temp \(preset.nozzleTempMax) > 350")
        #expect(preset.nozzleTempMin <= preset.nozzleTempMax, "Preset \(preset.id) min > max")
    }

    @Test("find(byId:) returns correct preset for known IDs",
          arguments: [
              ("GFL99", "PLA"),
              ("GFG99", "PETG"),
              ("GFB99", "ABS"),
              ("GFU99", "TPU"),
              ("GFN99", "PA"),
          ])
    func findByKnownId(id: String, expectedType: String) {
        let preset = FilamentPreset.find(byId: id)
        #expect(preset != nil)
        #expect(preset?.trayType == expectedType)
    }

    @Test("find(byId:) returns nil for unknown ID")
    func findByUnknownId() {
        #expect(FilamentPreset.find(byId: "UNKNOWN") == nil)
    }

    @Test("find(byId:) returns nil for empty string")
    func findByEmptyId() {
        #expect(FilamentPreset.find(byId: "") == nil)
    }

    @Test("Expected preset count is 55")
    func presetCount() {
        #expect(FilamentPreset.all.count == 55)
    }

    @Test("Hashable conformance — Set deduplication")
    func hashable() {
        let presets = FilamentPreset.all + [FilamentPreset.all[0]]
        let unique = Set(presets)
        #expect(unique.count == FilamentPreset.all.count)
    }
}
