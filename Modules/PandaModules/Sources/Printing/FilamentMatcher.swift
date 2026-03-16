import Foundation
import PandaModels

/// Why a particular AMS tray was matched to a project filament.
public enum FilamentMatchReason: Sendable {
    case exactFilamentId
    case typeFallback
    case manual
    case none
}

/// Maps a project filament slot to an AMS tray selection.
public struct FilamentMapping: Identifiable, Sendable {
    public let id: Int // project filament index
    public let projectFilament: ProjectFilament
    public var selectedProfile: SlicerFilamentProfile?
    public var selectedTraySlot: Int? // global AMS tray index
    public var matchReason: FilamentMatchReason
    public var userPickedProfile = false // true when the user explicitly chose a profile

    public init(
        projectFilament: ProjectFilament,
        selectedProfile: SlicerFilamentProfile? = nil,
        selectedTraySlot: Int? = nil,
        matchReason: FilamentMatchReason = .none
    ) {
        self.id = projectFilament.id
        self.projectFilament = projectFilament
        self.selectedProfile = selectedProfile
        self.selectedTraySlot = selectedTraySlot
        self.matchReason = matchReason
    }
}

/// Matches project filaments to AMS trays using slicer profile data.
public enum FilamentMatcher {

    /// Auto-match project filaments to AMS trays.
    ///
    /// Algorithm (mirrors bambu-gateway's `_build_project_filament_matches`):
    /// 1. Resolve project filament's `settingId` to a slicer profile to get `filamentId`
    /// 2. Exact match: find AMS tray where `trayInfoIdx == filamentId`
    /// 3. Type fallback: find AMS tray where `materialType` matches filament type
    /// 4. No match: leave unassigned
    public static func autoMatch(
        projectFilaments: [ProjectFilament],
        slicerProfiles: [SlicerFilamentProfile],
        amsUnits: [AMSUnit]
    ) -> [FilamentMapping] {
        let allTrays = flattenTrays(amsUnits: amsUnits)
        // Build a lookup from filament_id → slicer profile for reverse matching
        let profilesByFilamentId = Dictionary(
            slicerProfiles
                .filter { !$0.filamentId.isEmpty }
                .map { ($0.filamentId.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        return projectFilaments.map { filament in
            // Resolve slicer profile by setting_id (or name-based fallback)
            let resolvedProfile = resolveProfile(
                settingId: filament.settingId,
                profiles: slicerProfiles
            )

            // Try exact match by filament_id / tray_info_idx
            if let profile = resolvedProfile,
               !profile.filamentId.isEmpty,
               let tray = allTrays.first(where: {
                   $0.tray.trayInfoIdx?.lowercased() == profile.filamentId.lowercased()
               })
            {
                return FilamentMapping(
                    projectFilament: filament,
                    selectedProfile: profile,
                    selectedTraySlot: tray.globalSlot,
                    matchReason: .exactFilamentId
                )
            }

            // Fallback: match by filament type, and resolve profile from the matched tray's trayInfoIdx
            let filamentType = filament.type.uppercased()
            if let tray = allTrays.first(where: {
                $0.tray.materialType?.uppercased() == filamentType
            }) {
                // If we didn't resolve a profile from the project, try from the AMS tray
                let profile = resolvedProfile ?? tray.tray.trayInfoIdx.flatMap {
                    profilesByFilamentId[$0.lowercased()]
                }
                return FilamentMapping(
                    projectFilament: filament,
                    selectedProfile: profile,
                    selectedTraySlot: tray.globalSlot,
                    matchReason: .typeFallback
                )
            }

            // No tray match — still try to resolve a profile from any tray with matching type
            if resolvedProfile == nil {
                // Find any AMS tray whose trayInfoIdx maps to a profile matching the filament type
                for tray in allTrays {
                    if let idx = tray.tray.trayInfoIdx,
                       let profile = profilesByFilamentId[idx.lowercased()],
                       profile.filamentType.uppercased() == filamentType
                    {
                        return FilamentMapping(
                            projectFilament: filament,
                            selectedProfile: profile,
                            matchReason: .none
                        )
                    }
                }
            }

            return FilamentMapping(
                projectFilament: filament,
                selectedProfile: resolvedProfile,
                matchReason: .none
            )
        }
    }

    // MARK: - Helpers

    private struct FlatTray {
        let tray: AMSTray
        let globalSlot: Int
    }

    private static func flattenTrays(amsUnits: [AMSUnit]) -> [FlatTray] {
        amsUnits.flatMap { unit in
            unit.trays.compactMap { tray in
                guard !tray.isEmpty else { return nil }
                return FlatTray(tray: tray, globalSlot: tray.globalIndex(amsId: unit.id))
            }
        }
    }

    private static func resolveProfile(
        settingId: String,
        profiles: [SlicerFilamentProfile]
    ) -> SlicerFilamentProfile? {
        guard !settingId.isEmpty else { return nil }
        // Exact match by setting_id
        if let match = profiles.first(where: { $0.settingId == settingId }) {
            return match
        }
        // Fallback: match by name
        return profiles.first(where: { $0.name == settingId })
    }
}
