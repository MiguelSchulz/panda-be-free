import Foundation
import SwiftUI

/// Codable snapshot of a single AMS tray for widget data transfer.
public struct AMSTraySnapshot: Codable, Sendable {
    public let id: Int
    public var materialType: String?
    public var colorHex: String?
    public var remainPercent: Int?
    public var isBambuFilament: Bool

    public init(id: Int, materialType: String? = nil, colorHex: String? = nil,
                remainPercent: Int? = nil, isBambuFilament: Bool = false)
    {
        self.id = id
        self.materialType = materialType
        self.colorHex = colorHex
        self.remainPercent = remainPercent
        self.isBambuFilament = isBambuFilament
    }

    /// Reconstruct an `AMSTray` for use with shared views like `AMSTrayView`.
    public var asTray: AMSTray {
        AMSTray(
            id: id,
            materialType: materialType,
            color: colorHex.flatMap { AMSTray.parseColor(from: $0) },
            colorHex: colorHex,
            remainPercent: remainPercent,
            isBambuFilament: isBambuFilament
        )
    }
}

/// Codable snapshot of a single AMS unit for widget data transfer.
public struct AMSUnitSnapshot: Codable, Sendable {
    public let id: Int
    public var amsTypeName: String?
    public var humidityLevel: Int
    public var humidityRaw: Int
    public var temperature: Double
    public var dryTimeRemaining: Int
    public var trays: [AMSTraySnapshot]

    public var isDrying: Bool {
        dryTimeRemaining > 0
    }

    public init(id: Int, amsTypeName: String? = nil, humidityLevel: Int = 0,
                humidityRaw: Int = 0, temperature: Double = 0,
                dryTimeRemaining: Int = 0, trays: [AMSTraySnapshot] = [])
    {
        self.id = id
        self.amsTypeName = amsTypeName
        self.humidityLevel = humidityLevel
        self.humidityRaw = humidityRaw
        self.temperature = temperature
        self.dryTimeRemaining = dryTimeRemaining
        self.trays = trays
    }
}

/// Codable snapshot of the full printer state, stored in App Group for widget access.
public struct PrinterStateSnapshot: Codable, Sendable {
    public var contentState: PrinterAttributes.ContentState
    public var amsUnits: [AMSUnitSnapshot]
    public var activeTrayIndex: Int?
    public var lastUpdated: Date

    public init(from state: PrinterState) {
        self.contentState = state.contentState
        self.activeTrayIndex = state.activeTrayIndex
        self.lastUpdated = state.lastUpdated ?? Date.now

        self.amsUnits = state.amsUnits.map { unit in
            AMSUnitSnapshot(
                id: unit.id,
                amsTypeName: unit.amsType.map { String(localized: $0.displayName) },
                humidityLevel: unit.humidityLevel,
                humidityRaw: unit.humidityRaw,
                temperature: unit.temperature,
                dryTimeRemaining: unit.dryTimeRemaining,
                trays: unit.trays.map { tray in
                    AMSTraySnapshot(
                        id: tray.id,
                        materialType: tray.materialType,
                        colorHex: tray.colorHex,
                        remainPercent: tray.remainPercent,
                        isBambuFilament: tray.isBambuFilament
                    )
                }
            )
        }
    }
}
