import PandaModels
import Printing
import Testing

@Suite
struct AMSMappingBuilderTests {
    @Test func allFilamentsMapped() {
        let mappings = [
            FilamentMapping(
                projectFilament: ProjectFilament(id: 0, type: "PLA", colorHex: "FFD700FF", settingId: "GFL99"),
                selectedTraySlot: 0
            ),
            FilamentMapping(
                projectFilament: ProjectFilament(id: 1, type: "PETG", colorHex: "0000FFFF", settingId: "GFG99"),
                selectedTraySlot: 2
            ),
        ]

        let (amsMapping, useAMS) = AMSMappingBuilder.build(from: mappings, projectFilamentCount: 2)

        #expect(amsMapping == [0, 2])
        #expect(useAMS == true)
    }

    @Test func partialMapping() {
        let mappings = [
            FilamentMapping(
                projectFilament: ProjectFilament(id: 0, type: "PLA", colorHex: "FFD700FF", settingId: "GFL99"),
                selectedTraySlot: 1
            ),
            FilamentMapping(
                projectFilament: ProjectFilament(id: 1, type: "ABS", colorHex: "FF0000FF", settingId: "GFB99")
            ),
            FilamentMapping(
                projectFilament: ProjectFilament(id: 2, type: "PETG", colorHex: "00FF00FF", settingId: "GFG99"),
                selectedTraySlot: 5
            ),
        ]

        let (amsMapping, useAMS) = AMSMappingBuilder.build(from: mappings, projectFilamentCount: 3)

        #expect(amsMapping == [1, -1, 5])
        #expect(useAMS == true)
    }

    @Test func noMappingsFallsBackToDefaultArray() {
        let mappings = [
            FilamentMapping(
                projectFilament: ProjectFilament(id: 0, type: "PLA", colorHex: "FFD700FF", settingId: "GFL99")
            ),
        ]

        let (amsMapping, useAMS) = AMSMappingBuilder.build(from: mappings, projectFilamentCount: 1)

        // When no trays are assigned, matches reference gateway: [0] with useAMS=false
        #expect(amsMapping == [0])
        #expect(useAMS == false)
    }

    @Test func externalSpool() {
        let mappings = [
            FilamentMapping(
                projectFilament: ProjectFilament(id: 0, type: "PLA", colorHex: "FFD700FF", settingId: "GFL99"),
                selectedTraySlot: 254
            ),
        ]

        let (amsMapping, useAMS) = AMSMappingBuilder.build(from: mappings, projectFilamentCount: 1)

        #expect(amsMapping == [254])
        #expect(useAMS == true)
    }
}
