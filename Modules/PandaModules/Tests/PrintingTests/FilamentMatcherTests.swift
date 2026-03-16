import PandaModels
import Printing
import Testing

@Suite
struct FilamentMatcherTests {
    @Test func exactMatchByFilamentId() {
        let projectFilaments = [
            ProjectFilament(id: 0, type: "PLA", colorHex: "FFD700FF", settingId: "GFL99"),
        ]
        let profiles = [
            SlicerFilamentProfile(
                settingId: "GFL99", filamentId: "GFA00", name: "Bambu PLA Basic",
                filamentType: "PLA", amsAssignable: true
            ),
        ]
        let amsUnit = AMSUnit(id: 0)
        amsUnit.trays[0] = AMSTray(
            id: 0, materialType: "PLA", color: .yellow,
            colorHex: "FFD700FF", trayInfoIdx: "GFA00"
        )

        let mappings = FilamentMatcher.autoMatch(
            projectFilaments: projectFilaments,
            slicerProfiles: profiles,
            amsUnits: [amsUnit]
        )

        #expect(mappings.count == 1)
        #expect(mappings[0].selectedTraySlot == 0)
        #expect(mappings[0].matchReason == .exactFilamentId)
    }

    @Test func typeFallback() {
        let projectFilaments = [
            ProjectFilament(id: 0, type: "PETG", colorHex: "0000FFFF", settingId: "unknown_profile"),
        ]
        let profiles: [SlicerFilamentProfile] = []
        let amsUnit = AMSUnit(id: 0)
        amsUnit.trays[1] = AMSTray(id: 1, materialType: "PETG", color: .blue, colorHex: "0000FFFF")

        let mappings = FilamentMatcher.autoMatch(
            projectFilaments: projectFilaments,
            slicerProfiles: profiles,
            amsUnits: [amsUnit]
        )

        #expect(mappings.count == 1)
        #expect(mappings[0].selectedTraySlot == 1)
        #expect(mappings[0].matchReason == .typeFallback)
    }

    @Test func typeFallbackResolvesProfileFromTray() {
        // Project has unknown setting_id, but the AMS tray's trayInfoIdx
        // maps to a known slicer profile — profile should be pre-selected
        let projectFilaments = [
            ProjectFilament(id: 0, type: "PLA", colorHex: "FFFFFFFF", settingId: "unknown"),
        ]
        let profiles = [
            SlicerFilamentProfile(
                settingId: "GFL99", filamentId: "GFA00", name: "Bambu PLA Basic",
                filamentType: "PLA", amsAssignable: true
            ),
        ]
        let amsUnit = AMSUnit(id: 0)
        amsUnit.trays[0] = AMSTray(
            id: 0, materialType: "PLA", color: .white,
            colorHex: "FFFFFFFF", trayInfoIdx: "GFA00"
        )

        let mappings = FilamentMatcher.autoMatch(
            projectFilaments: projectFilaments,
            slicerProfiles: profiles,
            amsUnits: [amsUnit]
        )

        #expect(mappings.count == 1)
        #expect(mappings[0].selectedTraySlot == 0)
        #expect(mappings[0].matchReason == .typeFallback)
        #expect(mappings[0].selectedProfile?.settingId == "GFL99")
    }

    @Test func noMatch() {
        let projectFilaments = [
            ProjectFilament(id: 0, type: "TPU", colorHex: "FF0000FF", settingId: ""),
        ]
        let amsUnit = AMSUnit(id: 0)
        amsUnit.trays[0] = AMSTray(id: 0, materialType: "PLA", color: .yellow, colorHex: "FFD700FF")

        let mappings = FilamentMatcher.autoMatch(
            projectFilaments: projectFilaments,
            slicerProfiles: [],
            amsUnits: [amsUnit]
        )

        #expect(mappings.count == 1)
        #expect(mappings[0].selectedTraySlot == nil)
        #expect(mappings[0].matchReason == .none)
    }
}
