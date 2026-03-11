import Foundation

/// A known filament profile with its Bambu `filament_id` (used as `tray_info_idx` in MQTT commands).
public struct FilamentPreset: Identifiable, Hashable, Sendable {
    public let id: String // filament_id, e.g. "GFL99"
    public let name: String // Display name, e.g. "Generic PLA"
    public let trayType: String // Material type, e.g. "PLA"
    public let nozzleTempMin: Int
    public let nozzleTempMax: Int

    public init(id: String, name: String, trayType: String, nozzleTempMin: Int, nozzleTempMax: Int) {
        self.id = id
        self.name = name
        self.trayType = trayType
        self.nozzleTempMin = nozzleTempMin
        self.nozzleTempMax = nozzleTempMax
    }

    /// All known Bambu Lab filament presets, grouped by category.
    public static let all: [FilamentPreset] = [
        // Generic materials
        FilamentPreset(id: "GFL99", name: "Generic PLA", trayType: "PLA", nozzleTempMin: 190, nozzleTempMax: 230),
        FilamentPreset(id: "GFL95", name: "Generic PLA High Speed", trayType: "PLA", nozzleTempMin: 190, nozzleTempMax: 230),
        FilamentPreset(id: "GFL96", name: "Generic PLA Silk", trayType: "PLA", nozzleTempMin: 200, nozzleTempMax: 230),
        FilamentPreset(id: "GFL98", name: "Generic PLA-CF", trayType: "PLA-CF", nozzleTempMin: 220, nozzleTempMax: 250),
        FilamentPreset(id: "GFG99", name: "Generic PETG", trayType: "PETG", nozzleTempMin: 220, nozzleTempMax: 260),
        FilamentPreset(id: "GFG96", name: "Generic PETG HF", trayType: "PETG", nozzleTempMin: 230, nozzleTempMax: 270),
        FilamentPreset(id: "GFG98", name: "Generic PETG-CF", trayType: "PETG-CF", nozzleTempMin: 240, nozzleTempMax: 270),
        FilamentPreset(id: "GFG97", name: "Generic PCTG", trayType: "PCTG", nozzleTempMin: 240, nozzleTempMax: 270),
        FilamentPreset(id: "GFB99", name: "Generic ABS", trayType: "ABS", nozzleTempMin: 240, nozzleTempMax: 270),
        FilamentPreset(id: "GFB98", name: "Generic ASA", trayType: "ASA", nozzleTempMin: 240, nozzleTempMax: 270),
        FilamentPreset(id: "GFU99", name: "Generic TPU", trayType: "TPU", nozzleTempMin: 210, nozzleTempMax: 230),
        FilamentPreset(id: "GFU98", name: "Generic TPU for AMS", trayType: "TPU", nozzleTempMin: 210, nozzleTempMax: 230),
        FilamentPreset(id: "GFN99", name: "Generic PA", trayType: "PA", nozzleTempMin: 270, nozzleTempMax: 300),
        FilamentPreset(id: "GFN98", name: "Generic PA-CF", trayType: "PA-CF", nozzleTempMin: 270, nozzleTempMax: 300),
        FilamentPreset(id: "GFC99", name: "Generic PC", trayType: "PC", nozzleTempMin: 260, nozzleTempMax: 280),
        FilamentPreset(id: "GFS99", name: "Generic PVA", trayType: "PVA", nozzleTempMin: 190, nozzleTempMax: 210),
        FilamentPreset(id: "GFS98", name: "Generic HIPS", trayType: "HIPS", nozzleTempMin: 230, nozzleTempMax: 250),
        FilamentPreset(id: "GFS97", name: "Generic BVOH", trayType: "BVOH", nozzleTempMin: 190, nozzleTempMax: 210),
        FilamentPreset(id: "GFR99", name: "Generic EVA", trayType: "EVA", nozzleTempMin: 190, nozzleTempMax: 220),
        FilamentPreset(id: "GFR98", name: "Generic PHA", trayType: "PHA", nozzleTempMin: 190, nozzleTempMax: 220),
        FilamentPreset(id: "GFP99", name: "Generic PE", trayType: "PE", nozzleTempMin: 190, nozzleTempMax: 220),
        FilamentPreset(id: "GFP98", name: "Generic PE-CF", trayType: "PE-CF", nozzleTempMin: 220, nozzleTempMax: 250),
        FilamentPreset(id: "GFP97", name: "Generic PP", trayType: "PP", nozzleTempMin: 200, nozzleTempMax: 230),
        FilamentPreset(id: "GFP96", name: "Generic PP-CF", trayType: "PP-CF", nozzleTempMin: 220, nozzleTempMax: 250),
        FilamentPreset(id: "GFP95", name: "Generic PP-GF", trayType: "PP-GF", nozzleTempMin: 220, nozzleTempMax: 250),
        FilamentPreset(id: "GFN97", name: "Generic PPA-CF", trayType: "PPA-CF", nozzleTempMin: 280, nozzleTempMax: 300),
        FilamentPreset(id: "GFN96", name: "Generic PPA-GF", trayType: "PPA-GF", nozzleTempMin: 280, nozzleTempMax: 300),

        // Bambu Lab branded
        FilamentPreset(id: "GFA00", name: "Bambu PLA Basic", trayType: "PLA", nozzleTempMin: 190, nozzleTempMax: 230),
        FilamentPreset(id: "GFA01", name: "Bambu PLA Matte", trayType: "PLA", nozzleTempMin: 190, nozzleTempMax: 230),
        FilamentPreset(id: "GFA02", name: "Bambu PLA Metal", trayType: "PLA", nozzleTempMin: 200, nozzleTempMax: 230),
        FilamentPreset(id: "GFA05", name: "Bambu PLA Silk", trayType: "PLA", nozzleTempMin: 200, nozzleTempMax: 230),
        FilamentPreset(id: "GFA09", name: "Bambu PLA Tough", trayType: "PLA", nozzleTempMin: 190, nozzleTempMax: 230),
        FilamentPreset(id: "GFA11", name: "Bambu PLA Aero", trayType: "PLA", nozzleTempMin: 190, nozzleTempMax: 230),
        FilamentPreset(id: "GFA50", name: "Bambu PLA-CF", trayType: "PLA-CF", nozzleTempMin: 220, nozzleTempMax: 250),
        FilamentPreset(id: "GFB00", name: "Bambu ABS", trayType: "ABS", nozzleTempMin: 240, nozzleTempMax: 270),
        FilamentPreset(id: "GFB01", name: "Bambu ASA", trayType: "ASA", nozzleTempMin: 240, nozzleTempMax: 270),
        FilamentPreset(id: "GFG00", name: "Bambu PETG Basic", trayType: "PETG", nozzleTempMin: 220, nozzleTempMax: 260),
        FilamentPreset(id: "GFG02", name: "Bambu PETG HF", trayType: "PETG", nozzleTempMin: 230, nozzleTempMax: 270),
        FilamentPreset(id: "GFG50", name: "Bambu PETG-CF", trayType: "PETG-CF", nozzleTempMin: 240, nozzleTempMax: 270),
        FilamentPreset(id: "GFC00", name: "Bambu PC", trayType: "PC", nozzleTempMin: 260, nozzleTempMax: 280),
        FilamentPreset(id: "GFN03", name: "Bambu PA-CF", trayType: "PA-CF", nozzleTempMin: 270, nozzleTempMax: 300),
        FilamentPreset(id: "GFN04", name: "Bambu PAHT-CF", trayType: "PA-CF", nozzleTempMin: 280, nozzleTempMax: 300),
        FilamentPreset(id: "GFN05", name: "Bambu PA6-CF", trayType: "PA-CF", nozzleTempMin: 270, nozzleTempMax: 300),
        FilamentPreset(id: "GFN06", name: "Bambu PPA-CF", trayType: "PPA-CF", nozzleTempMin: 280, nozzleTempMax: 300),
        FilamentPreset(id: "GFN08", name: "Bambu PA6-GF", trayType: "PA-GF", nozzleTempMin: 270, nozzleTempMax: 300),
        FilamentPreset(id: "GFU01", name: "Bambu TPU 95A", trayType: "TPU", nozzleTempMin: 210, nozzleTempMax: 230),
        FilamentPreset(id: "GFU00", name: "Bambu TPU 95A HF", trayType: "TPU", nozzleTempMin: 210, nozzleTempMax: 230),
        FilamentPreset(id: "GFU02", name: "Bambu TPU for AMS", trayType: "TPU", nozzleTempMin: 210, nozzleTempMax: 230),

        // Bambu Support
        FilamentPreset(id: "GFS02", name: "Bambu Support For PLA", trayType: "PLA-S", nozzleTempMin: 190, nozzleTempMax: 230),
        FilamentPreset(id: "GFS05", name: "Bambu Support For PLA/PETG", trayType: "PLA-S", nozzleTempMin: 190, nozzleTempMax: 230),
        FilamentPreset(id: "GFS03", name: "Bambu Support For PA/PET", trayType: "PA-S", nozzleTempMin: 240, nozzleTempMax: 270),
        FilamentPreset(id: "GFS06", name: "Bambu Support for ABS", trayType: "ABS-S", nozzleTempMin: 240, nozzleTempMax: 260),
        FilamentPreset(id: "GFS00", name: "Bambu Support W", trayType: "PVA", nozzleTempMin: 190, nozzleTempMax: 210),
        FilamentPreset(id: "GFS01", name: "Bambu Support G", trayType: "PA-S", nozzleTempMin: 240, nozzleTempMax: 270),
        FilamentPreset(id: "GFS04", name: "Bambu PVA", trayType: "PVA", nozzleTempMin: 190, nozzleTempMax: 210),
    ]

    /// Look up a preset by its filament_id / tray_info_idx.
    public static func find(byId id: String) -> FilamentPreset? {
        all.first { $0.id == id }
    }
}
