import Compression
import Foundation

/// Metadata extracted from a 3MF file's project settings.
public struct ThreeMFMetadata: Sendable {
    public let filaments: [ProjectFilament]
    public let hasGcode: Bool
    public let printerModel: String
    public let printSettingsId: String
}

/// A filament slot defined in the 3MF project.
public struct ProjectFilament: Identifiable, Sendable {
    public let id: Int // index in the project
    public let type: String // "PLA", "ABS", etc.
    public let colorHex: String // "#RRGGBB" or raw from 3MF
    public let settingId: String // OrcaSlicer profile setting_id
}

/// Parses Bambu 3MF archives (ZIP) to extract project metadata.
public enum ThreeMFParser {

    /// Parse a 3MF file from a URL and return its metadata.
    public static func parse(url: URL) throws -> ThreeMFMetadata {
        let data = try Data(contentsOf: url)
        return try parse(data: data)
    }

    /// Parse a 3MF file from raw bytes.
    public static func parse(data: Data) throws -> ThreeMFMetadata {
        let entries = try ZIPReader.readCentralDirectory(from: data)

        guard let settingsEntry = entries.first(where: { $0.fileName == "Metadata/project_settings.config" }) else {
            throw ThreeMFError.missingProjectSettings
        }

        let settingsData = try ZIPReader.extractEntry(settingsEntry, from: data)
        guard let json = try JSONSerialization.jsonObject(with: settingsData) as? [String: Any] else {
            throw ThreeMFError.missingProjectSettings
        }

        let hasGcode = entries.contains { entry in
            entry.fileName.hasPrefix("Metadata/plate_") && entry.fileName.hasSuffix(".gcode")
        }

        let filaments = extractFilaments(from: json)
        let printerModel = (json["printer_model"] as? String) ?? ""
        let printSettingsId = (json["print_settings_id"] as? String) ?? ""

        return ThreeMFMetadata(
            filaments: filaments,
            hasGcode: hasGcode,
            printerModel: printerModel,
            printSettingsId: printSettingsId
        )
    }

    // MARK: - Private

    private static func extractFilaments(from settings: [String: Any]) -> [ProjectFilament] {
        guard let types = settings["filament_type"] as? [String] else { return [] }

        let colors = settings["filament_colour"] as? [String] ?? []
        let settingIds = settings["filament_settings_id"] as? [String] ?? []

        return types.enumerated().map { index, type in
            ProjectFilament(
                id: index,
                type: type,
                colorHex: index < colors.count ? colors[index] : "",
                settingId: index < settingIds.count ? settingIds[index] : ""
            )
        }
    }
}

public enum ThreeMFError: LocalizedError {
    case invalidArchive
    case missingProjectSettings
    case corruptEntry(String)

    public var errorDescription: String? {
        switch self {
        case .invalidArchive:
            String(localized: "The file is not a valid 3MF archive.")
        case .missingProjectSettings:
            String(localized: "The 3MF file does not contain project settings.")
        case let .corruptEntry(name):
            String(localized: "Could not read entry '\(name)' from the 3MF archive.")
        }
    }
}

// MARK: - Minimal ZIP Reader (Foundation + Compression only)

/// Reads ZIP archives without external dependencies.
/// Supports Store (method 0) and Deflate (method 8) — sufficient for 3MF files.
enum ZIPReader {

    struct Entry {
        let fileName: String
        let compressedSize: UInt32
        let uncompressedSize: UInt32
        let compressionMethod: UInt16
        let localHeaderOffset: UInt32
    }

    /// Parse the central directory to list all entries.
    static func readCentralDirectory(from data: Data) throws -> [Entry] {
        guard data.count >= 22 else { throw ThreeMFError.invalidArchive }

        // Find End of Central Directory record (signature 0x06054b50)
        var eocdOffset = -1
        let searchStart = max(0, data.count - 65557)
        for i in stride(from: data.count - 22, through: searchStart, by: -1) {
            if data.leUInt32(at: i) == 0x06054B50 {
                eocdOffset = i
                break
            }
        }
        guard eocdOffset >= 0 else { throw ThreeMFError.invalidArchive }

        let totalEntries = Int(data.leUInt16(at: eocdOffset + 10))
        var offset = Int(data.leUInt32(at: eocdOffset + 16))

        var entries: [Entry] = []
        entries.reserveCapacity(totalEntries)

        for _ in 0 ..< totalEntries {
            guard offset + 46 <= data.count,
                  data.leUInt32(at: offset) == 0x02014B50
            else { break }

            let method = data.leUInt16(at: offset + 10)
            let compSize = data.leUInt32(at: offset + 20)
            let uncompSize = data.leUInt32(at: offset + 24)
            let nameLen = Int(data.leUInt16(at: offset + 28))
            let extraLen = Int(data.leUInt16(at: offset + 30))
            let commentLen = Int(data.leUInt16(at: offset + 32))
            let localOffset = data.leUInt32(at: offset + 42)

            let nameStart = offset + 46
            guard nameStart + nameLen <= data.count else { break }
            let fileName = String(data: data[nameStart ..< nameStart + nameLen], encoding: .utf8) ?? ""

            entries.append(Entry(
                fileName: fileName,
                compressedSize: compSize,
                uncompressedSize: uncompSize,
                compressionMethod: method,
                localHeaderOffset: localOffset
            ))

            offset = nameStart + nameLen + extraLen + commentLen
        }

        return entries
    }

    /// Extract the uncompressed data for a specific entry.
    static func extractEntry(_ entry: Entry, from data: Data) throws -> Data {
        let offset = Int(entry.localHeaderOffset)
        guard offset + 30 <= data.count,
              data.leUInt32(at: offset) == 0x04034B50
        else {
            throw ThreeMFError.corruptEntry(entry.fileName)
        }

        let nameLen = Int(data.leUInt16(at: offset + 26))
        let extraLen = Int(data.leUInt16(at: offset + 28))
        let dataStart = offset + 30 + nameLen + extraLen
        let dataEnd = dataStart + Int(entry.compressedSize)

        guard dataEnd <= data.count else {
            throw ThreeMFError.corruptEntry(entry.fileName)
        }

        let compressed = data[dataStart ..< dataEnd]

        switch entry.compressionMethod {
        case 0: // Stored
            return Data(compressed)
        case 8: // Deflate
            return try inflate(Data(compressed), expectedSize: Int(entry.uncompressedSize))
        default:
            throw ThreeMFError.corruptEntry(entry.fileName)
        }
    }

    private static func inflate(_ data: Data, expectedSize: Int) throws -> Data {
        let destSize = max(expectedSize, 1)
        var dest = Data(count: destSize)

        let written = dest.withUnsafeMutableBytes { destPtr in
            data.withUnsafeBytes { srcPtr in
                compression_decode_buffer(
                    destPtr.bindMemory(to: UInt8.self).baseAddress!,
                    destSize,
                    srcPtr.bindMemory(to: UInt8.self).baseAddress!,
                    data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        guard written > 0 else {
            throw ThreeMFError.corruptEntry("deflate decompression failed")
        }
        return dest.prefix(written)
    }
}

// MARK: - Little-endian Data helpers

private extension Data {
    func leUInt16(at offset: Int) -> UInt16 {
        withUnsafeBytes { buf in
            let p = buf.baseAddress!.advanced(by: offset)
            var value: UInt16 = 0
            memcpy(&value, p, 2)
            return UInt16(littleEndian: value)
        }
    }

    func leUInt32(at offset: Int) -> UInt32 {
        withUnsafeBytes { buf in
            let p = buf.baseAddress!.advanced(by: offset)
            var value: UInt32 = 0
            memcpy(&value, p, 4)
            return UInt32(littleEndian: value)
        }
    }
}
