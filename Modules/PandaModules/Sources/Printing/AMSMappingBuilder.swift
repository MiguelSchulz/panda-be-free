import Foundation

/// Builds the `ams_mapping` array for the printer's `project_file` MQTT command.
public enum AMSMappingBuilder {
    /// Build the AMS mapping array from filament mappings.
    ///
    /// Returns a variable-length array (one entry per project filament) mapping each
    /// filament index to an AMS tray slot, plus a `useAMS` flag.
    ///
    /// - Parameters:
    ///   - mappings: The filament mappings with selected tray slots.
    ///   - projectFilamentCount: Total number of filaments in the project.
    /// - Returns: A tuple of `(amsMapping, useAMS)`.
    public static func build(
        from mappings: [FilamentMapping],
        projectFilamentCount: Int
    ) -> (amsMapping: [Int], useAMS: Bool) {
        var amsMapping = Array(repeating: -1, count: projectFilamentCount)
        var useAMS = false

        for mapping in mappings {
            let index = mapping.id
            guard index >= 0, index < projectFilamentCount else { continue }
            if let traySlot = mapping.selectedTraySlot {
                amsMapping[index] = traySlot
                useAMS = true
            }
        }

        // Match the reference gateway: when no trays are selected, send [0]
        // with useAMS=false rather than an array of -1s.
        if !useAMS {
            return ([0], false)
        }

        return (amsMapping, useAMS)
    }
}
