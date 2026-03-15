import Foundation
import SwiftUI

/// AMS hardware type, detected from `hw_ver` in MQTT data.
public enum AMSType: Sendable {
    case standard // AMS08 — original AMS / AMS Lite
    case pro // N3F05 — AMS 2 Pro
    case ht // N3S05 — AMS HT (high temperature)

    public var supportsDrying: Bool {
        switch self {
        case .standard: false
        case .pro, .ht: true
        }
    }

    public var maxDryingTemp: Int {
        switch self {
        case .standard: 55
        case .pro: 65
        case .ht: 85
        }
    }

    public var displayName: String {
        switch self {
        case .standard: "AMS"
        case .pro: "AMS 2 Pro"
        case .ht: "AMS HT"
        }
    }

    public static func from(hwVersion: String) -> AMSType {
        if hwVersion.hasPrefix("N3F05") { return .pro }
        if hwVersion.hasPrefix("N3S05") { return .ht }
        return .standard
    }
}

/// Represents a single filament tray slot in an AMS unit.
public struct AMSTray: Identifiable {
    public let id: Int // 0-3
    public var materialType: String? // "PLA", "ABS", "PETG", etc. nil = empty
    public var color: Color? // Parsed from RRGGBBAA hex. nil = empty
    public var colorHex: String? // Raw hex for storage
    public var remainPercent: Int? // 0-100, nil if unknown or empty
    public var isBambuFilament = false
    public var nozzleTempMin: Int?
    public var nozzleTempMax: Int?
    public var recommendedDryTemp: Int? // from spool RFID
    public var recommendedDryTime: Int? // from spool RFID (minutes)
    public var traySubBrands: String? // e.g. "PLA Matte"
    public var trayInfoIdx: String? // filament profile identifier

    public var isEmpty: Bool {
        materialType == nil
    }

    /// Perceived brightness of the tray color (0.0 = black, 1.0 = white).
    /// Returns nil if `colorHex` is nil or invalid.
    public var perceivedBrightness: Double? {
        guard let hex = colorHex, hex.count == 8,
              let value = UInt32(hex, radix: 16) else { return nil }
        let r = Double((value >> 24) & 0xFF) / 255.0
        let g = Double((value >> 16) & 0xFF) / 255.0
        let b = Double((value >> 8) & 0xFF) / 255.0
        return r * 0.299 + g * 0.587 + b * 0.114
    }

    /// Global tray index across all AMS units (amsId * 4 + id)
    public func globalIndex(amsId: Int) -> Int {
        amsId * 4 + id
    }

    /// Parse RRGGBBAA hex string to SwiftUI Color
    public static func parseColor(from hex: String) -> Color? {
        guard hex.count == 8,
              let value = UInt32(hex, radix: 16) else { return nil }
        let r = Double((value >> 24) & 0xFF) / 255.0
        let g = Double((value >> 16) & 0xFF) / 255.0
        let b = Double((value >> 8) & 0xFF) / 255.0
        let a = Double(value & 0xFF) / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    public init(id: Int, materialType: String? = nil, color: Color? = nil,
                colorHex: String? = nil, remainPercent: Int? = nil,
                isBambuFilament: Bool = false, nozzleTempMin: Int? = nil,
                nozzleTempMax: Int? = nil, recommendedDryTemp: Int? = nil,
                recommendedDryTime: Int? = nil, traySubBrands: String? = nil,
                trayInfoIdx: String? = nil)
    {
        self.id = id
        self.materialType = materialType
        self.color = color
        self.colorHex = colorHex
        self.remainPercent = remainPercent
        self.isBambuFilament = isBambuFilament
        self.nozzleTempMin = nozzleTempMin
        self.nozzleTempMax = nozzleTempMax
        self.recommendedDryTemp = recommendedDryTemp
        self.recommendedDryTime = recommendedDryTime
        self.traySubBrands = traySubBrands
        self.trayInfoIdx = trayInfoIdx
    }
}

/// Represents a single AMS unit (contains 4 tray slots).
@Observable
public final class AMSUnit: Identifiable {
    public let id: Int // 0-3
    public var hwVersion: String?
    public var humidityLevel = 0 // 1-5
    public var humidityRaw = 0 // 0-100%
    public var temperature: Double = 0 // Celsius
    public var dryTimeRemaining = 0 // minutes, 0 = not drying
    public var trays: [AMSTray] = (0...3).map { AMSTray(id: $0) }

    public var amsType: AMSType? {
        hwVersion.map { AMSType.from(hwVersion: $0) }
    }

    public var isDrying: Bool {
        dryTimeRemaining > 0
    }

    public var dryTimeFormatted: String {
        let hours = dryTimeRemaining / 60
        let minutes = dryTimeRemaining % 60
        if hours > 0 {
            return String(localized: "\(hours)h \(minutes)m")
        }
        return String(localized: "\(minutes)m")
    }

    public init(id: Int) {
        self.id = id
    }
}

public extension Color {
    /// Convert to RRGGBBAA hex string for Bambu MQTT commands.
    var hexRRGGBBAA: String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X%02X",
                      Int((r * 255).rounded()), Int((g * 255).rounded()),
                      Int((b * 255).rounded()), Int((a * 255).rounded()))
    }
}
