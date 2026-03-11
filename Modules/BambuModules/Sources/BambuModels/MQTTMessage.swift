import Foundation

/// Parsed AMS data from a single MQTT message (data transfer only).
public struct AMSParsedUnit {
    public let id: Int
    public var hwVersion: String?
    public var humidity: Int? // 1-5
    public var humidityRaw: Int? // 0-100
    public var temp: Double?
    public var dryTime: Int? // seconds
    public var trays: [AMSParsedTray]

    public init(id: Int, hwVersion: String? = nil, humidity: Int? = nil,
                humidityRaw: Int? = nil, temp: Double? = nil, dryTime: Int? = nil,
                trays: [AMSParsedTray] = []) {
        self.id = id
        self.hwVersion = hwVersion
        self.humidity = humidity
        self.humidityRaw = humidityRaw
        self.temp = temp
        self.dryTime = dryTime
        self.trays = trays
    }
}

public struct AMSParsedTray {
    public let id: Int
    public var trayType: String?
    public var trayColor: String? // RRGGBBAA
    public var remain: Int? // 0-100 or -1
    public var nozzleTempMin: Int?
    public var nozzleTempMax: Int?
    public var trayTemp: Int? // recommended dry temp from spool RFID
    public var trayTime: Int? // recommended dry time from spool RFID (minutes)
    public var traySubBrands: String? // e.g. "PLA Matte"
    public var trayInfoIdx: String? // filament profile identifier

    public init(id: Int, trayType: String? = nil, trayColor: String? = nil,
                remain: Int? = nil, nozzleTempMin: Int? = nil, nozzleTempMax: Int? = nil,
                trayTemp: Int? = nil, trayTime: Int? = nil, traySubBrands: String? = nil,
                trayInfoIdx: String? = nil) {
        self.id = id
        self.trayType = trayType
        self.trayColor = trayColor
        self.remain = remain
        self.nozzleTempMin = nozzleTempMin
        self.nozzleTempMax = nozzleTempMax
        self.trayTemp = trayTemp
        self.trayTime = trayTime
        self.traySubBrands = traySubBrands
        self.trayInfoIdx = trayInfoIdx
    }
}

/// Represents the JSON payload from Bambu printer MQTT reports.
/// All fields are optional because the printer sends partial/incremental updates.
public struct BambuMQTTPayload {
    public var gcodeState: String?
    public var mcPercent: Int?
    public var mcRemainingTime: Int?
    public var nozzleTemper: Double?
    public var nozzleTargetTemper: Double?
    public var bedTemper: Double?
    public var bedTargetTemper: Double?
    public var chamberTemper: Double?
    public var stgCur: Int?
    public var subtaskName: String?
    public var layerNum: Int?
    public var totalLayerNum: Int?
    public var chamberLightOn: Bool?
    public var partFanSpeed: Int?      // 0–255 (from fan_gear or converted from 0–15)
    public var auxFanSpeed: Int?       // 0–255
    public var chamberFanSpeed: Int?   // 0–255
    public var heatbreakFanSpeed: Int?  // 0–255 (converted from 0–15)
    public var airductMode: Int?       // device.airduct.modeCur (0=cooling, 1=heating)
    public var homeFlag: Int?           // 0 = not homed, non-zero = homed

    // AMS
    public var amsUnits: [AMSParsedUnit]?
    public var trayNow: String?         // "255"=none, "254"=external, else amsId*4+trayId
    public var trayIsBblBits: String?   // hex bitmask of Bambu-branded trays

    /// AMS module versions from info.module (hw_ver, name, product_name)
    public var amsModuleVersions: [AMSModuleVersion]?

    public init() {}

    /// Parse from raw MQTT JSON data. Returns nil if no recognized data.
    public static func parse(from data: Data) -> BambuMQTTPayload? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Handle info messages (contains module versions with hw_ver)
        if let infoData = json["info"] as? [String: Any] {
            return parseInfo(infoData)
        }

        guard let printData = json["print"] as? [String: Any] else {
            return nil
        }

        var payload = BambuMQTTPayload()
        payload.gcodeState = printData["gcode_state"] as? String
        payload.mcPercent = printData["mc_percent"] as? Int
        payload.mcRemainingTime = printData["mc_remaining_time"] as? Int
        payload.nozzleTemper = printData["nozzle_temper"] as? Double
        payload.nozzleTargetTemper = printData["nozzle_target_temper"] as? Double
        payload.bedTemper = printData["bed_temper"] as? Double
        payload.bedTargetTemper = printData["bed_target_temper"] as? Double
        payload.stgCur = printData["stg_cur"] as? Int
        payload.subtaskName = printData["subtask_name"] as? String
        payload.homeFlag = printData["home_flag"] as? Int

        // Layer num can be at top level or nested under "3D"
        payload.layerNum = printData["layer_num"] as? Int
            ?? (printData["3D"] as? [String: Any])?["layer_num"] as? Int
        payload.totalLayerNum = printData["total_layer_num"] as? Int
            ?? (printData["3D"] as? [String: Any])?["total_layer_num"] as? Int

        // Fan speeds: prefer fan_gear (stable, no jitter) over individual string fields.
        // fan_gear packs three fans into a 32-bit int: bits 0–7 = part cooling,
        // 8–15 = aux, 16–23 = chamber. Values are 0–255.
        if let fanGear = printData["fan_gear"] as? Int {
            payload.partFanSpeed = fanGear & 0xFF
            payload.auxFanSpeed = (fanGear >> 8) & 0xFF
            payload.chamberFanSpeed = (fanGear >> 16) & 0xFF
        } else {
            // Fallback: individual string fields (0–15), convert to 0–255
            // using OrcaSlicer's formula: round(floor(x / 1.5) * 25.5)
            if let v = printData["cooling_fan_speed"] as? String, let raw = Int(v) {
                payload.partFanSpeed = Self.fanRawToNormalized(raw)
            }
            if let v = printData["big_fan1_speed"] as? String, let raw = Int(v) {
                payload.auxFanSpeed = Self.fanRawToNormalized(raw)
            }
            if let v = printData["big_fan2_speed"] as? String, let raw = Int(v) {
                payload.chamberFanSpeed = Self.fanRawToNormalized(raw)
            }
        }

        // Heatbreak fan: not in fan_gear, always from individual field
        if let v = printData["heatbreak_fan_speed"] as? String, let raw = Int(v) {
            payload.heatbreakFanSpeed = Self.fanRawToNormalized(raw)
        }

        // Airduct mode: device.airduct.modeCur (0=cooling, 1=heating)
        if let airduct = (printData["device"] as? [String: Any])?["airduct"] as? [String: Any],
           let modeCur = airduct["modeCur"] as? Int {
            payload.airductMode = modeCur
        }

        // Chamber light: reported as lights_report array with node "chamber_light"
        if let lightsReport = printData["lights_report"] as? [[String: Any]] {
            for light in lightsReport {
                if light["node"] as? String == "chamber_light",
                   let mode = light["mode"] as? String {
                    payload.chamberLightOn = (mode == "on")
                }
            }
        }

        // Chamber temp: newer firmware uses device.ctc.info.temp, legacy uses chamber_temper
        if let ctcTemp = (printData["device"] as? [String: Any])?["ctc"]
            .flatMap({ $0 as? [String: Any] })?["info"]
            .flatMap({ $0 as? [String: Any] })?["temp"] as? Int {
            payload.chamberTemper = Double(ctcTemp & 0xFFFF)
        } else if let chamberTemp = printData["chamber_temper"] as? Double {
            payload.chamberTemper = chamberTemp
        }

        // AMS data: nested under print.ams
        if let amsData = printData["ams"] as? [String: Any] {
            payload.trayNow = amsData["tray_now"] as? String
            payload.trayIsBblBits = amsData["tray_is_bbl_bits"] as? String

            if let amsArray = amsData["ams"] as? [[String: Any]] {
                payload.amsUnits = amsArray.compactMap { unitDict -> AMSParsedUnit? in
                    guard let idStr = unitDict["id"] as? String,
                          let unitId = Int(idStr) else { return nil }

                    var unit = AMSParsedUnit(id: unitId, trays: [])
                    unit.hwVersion = unitDict["hw_ver"] as? String
                    if let h = unitDict["humidity"] as? String { unit.humidity = Int(h) }
                    if let hr = unitDict["humidity_raw"] as? String { unit.humidityRaw = Int(hr) }
                    if let t = unitDict["temp"] as? String { unit.temp = Double(t) }
                    unit.dryTime = unitDict["dry_time"] as? Int

                    if let traysArray = unitDict["tray"] as? [[String: Any]] {
                        unit.trays = traysArray.compactMap { trayDict -> AMSParsedTray? in
                            guard let trayIdStr = trayDict["id"] as? String,
                                  let trayId = Int(trayIdStr) else { return nil }
                            var tray = AMSParsedTray(id: trayId)
                            tray.trayType = trayDict["tray_type"] as? String
                            tray.trayColor = trayDict["tray_color"] as? String
                            tray.remain = trayDict["remain"] as? Int
                            if let v = trayDict["nozzle_temp_min"] as? String { tray.nozzleTempMin = Int(v) }
                            if let v = trayDict["nozzle_temp_max"] as? String { tray.nozzleTempMax = Int(v) }
                            if let v = trayDict["tray_temp"] as? String { tray.trayTemp = Int(v) }
                            if let v = trayDict["tray_time"] as? String { tray.trayTime = Int(v) }
                            tray.traySubBrands = trayDict["tray_sub_brands"] as? String
                            tray.trayInfoIdx = trayDict["tray_info_idx"] as? String
                            return tray
                        }
                    }
                    return unit
                }
            }
        }

        return payload
    }

    /// Parse info message containing module version data.
    private static func parseInfo(_ infoData: [String: Any]) -> BambuMQTTPayload? {
        guard let modules = infoData["module"] as? [[String: Any]] else { return nil }

        // Extract AMS module versions from info.module array
        // AMS modules have names like "ams/0", "n3f/0" (AMS 2 Pro), "n3s/0" (AMS HT)
        var amsModules: [AMSModuleVersion] = []
        for mod in modules {
            guard let name = mod["name"] as? String,
                  let hwVer = mod["hw_ver"] as? String else { continue }
            // AMS modules: "ams/N", "n3f/N", "n3s/N"
            let prefix = name.split(separator: "/").first.map(String.init) ?? ""
            guard ["ams", "n3f", "n3s"].contains(prefix),
                  let idx = name.split(separator: "/").last.flatMap({ Int($0) }) else { continue }
            amsModules.append(AMSModuleVersion(id: idx, hwVer: hwVer))
        }

        guard !amsModules.isEmpty else { return nil }
        var payload = BambuMQTTPayload()
        payload.amsModuleVersions = amsModules
        return payload
    }

    /// Convert raw 0–15 string value to 0–255 (OrcaSlicer formula)
    private static func fanRawToNormalized(_ raw: Int) -> Int {
        Int((floor(Double(raw) / 1.5) * 25.5).rounded())
    }
}

/// AMS module version info from info.module MQTT messages.
public struct AMSModuleVersion {
    public let id: Int       // AMS unit index (0, 1, 2, ...)
    public let hwVer: String // e.g. "AMS08", "N3F05", "N3S05"

    public init(id: Int, hwVer: String) {
        self.id = id
        self.hwVer = hwVer
    }
}
