import Foundation

public enum PrinterType: String, CaseIterable, Identifiable, Sendable {
    case auto
    case rtsp
    case tcp

    public var id: String {
        rawValue
    }

    public var displayName: LocalizedStringResource {
        switch self {
        case .auto: "Auto Detect"
        case .rtsp: "X1 / P2S (RTSP)"
        case .tcp: "A1 / P1 (TCP)"
        }
    }
}

public enum SharedSettings {
    public static let suiteName: String = {
        if let groupId = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String, !groupId.isEmpty {
            return groupId
        }
        return "group.com.bambubefree.app"
    }()

    public static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    public static var printerIP: String {
        get { sharedDefaults?.string(forKey: "printerIP") ?? "" }
        set { sharedDefaults?.set(newValue, forKey: "printerIP") }
    }

    public static var printerAccessCode: String {
        get { sharedDefaults?.string(forKey: "printerAccessCode") ?? "" }
        set { sharedDefaults?.set(newValue, forKey: "printerAccessCode") }
    }

    public static var printerType: PrinterType {
        get {
            guard let raw = sharedDefaults?.string(forKey: "printerType"),
                  let type = PrinterType(rawValue: raw) else { return .auto }
            return type
        }
        set { sharedDefaults?.set(newValue.rawValue, forKey: "printerType") }
    }

    public static var hasConfiguration: Bool {
        !printerIP.isEmpty && !printerAccessCode.isEmpty
    }

    // MARK: - Cached Snapshot

    private static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)
    }

    public static var cachedSnapshotData: Data? {
        get {
            guard let url = containerURL?.appendingPathComponent("camera_snapshot.jpg") else { return nil }
            return try? Data(contentsOf: url)
        }
        set {
            guard let url = containerURL?.appendingPathComponent("camera_snapshot.jpg") else { return }
            if let data = newValue {
                try? data.write(to: url, options: .atomic)
            } else {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    public static var cachedSnapshotDate: Date? {
        get { sharedDefaults?.object(forKey: "cachedSnapshotDate") as? Date }
        set { sharedDefaults?.set(newValue, forKey: "cachedSnapshotDate") }
    }

    // MARK: - Cached Printer State

    public static var cachedPrinterState: PrinterStateSnapshot? {
        get {
            guard let url = containerURL?.appendingPathComponent("printer_state.json"),
                  let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(PrinterStateSnapshot.self, from: data)
        }
        set {
            guard let url = containerURL?.appendingPathComponent("printer_state.json") else { return }
            if let snapshot = newValue,
               let data = try? JSONEncoder().encode(snapshot)
            {
                try? data.write(to: url, options: .atomic)
            } else {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    // MARK: - Migration

    public static func migrateFromStandardDefaults() {
        let standard = UserDefaults.standard
        guard let shared = sharedDefaults else { return }
        // Only migrate if shared doesn't already have values
        if shared.string(forKey: "printerIP") == nil,
           let ip = standard.string(forKey: "printerIP"), !ip.isEmpty
        {
            shared.set(ip, forKey: "printerIP")
            shared.set(standard.string(forKey: "printerAccessCode"), forKey: "printerAccessCode")
        }
    }
}
