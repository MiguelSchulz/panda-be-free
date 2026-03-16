import Foundation

/// Response model for GET /profiles/machines
public struct MachineProfile: Codable, Identifiable, Hashable, Sendable {
    public let settingId: String
    public let name: String
    public let nozzleDiameter: String
    public let printerModel: String

    public var id: String {
        settingId
    }

    enum CodingKeys: String, CodingKey {
        case settingId = "setting_id"
        case name
        case nozzleDiameter = "nozzle_diameter"
        case printerModel = "printer_model"
    }
}

/// Response model for GET /profiles/processes
public struct ProcessProfile: Codable, Identifiable, Hashable, Sendable {
    public let settingId: String
    public let name: String

    public var id: String {
        settingId
    }

    enum CodingKeys: String, CodingKey {
        case settingId = "setting_id"
        case name
    }
}

/// Response model for GET /profiles/filaments
public struct SlicerFilamentProfile: Codable, Identifiable, Hashable, Sendable {
    public let settingId: String
    public let filamentId: String
    public let name: String
    public let filamentType: String
    public let amsAssignable: Bool

    public var id: String {
        settingId
    }

    enum CodingKeys: String, CodingKey {
        case settingId = "setting_id"
        case filamentId = "filament_id"
        case name
        case filamentType = "filament_type"
        case amsAssignable = "ams_assignable"
    }
}

/// Client for the orcaslicer-cli REST API.
public actor OrcaSlicerClient {
    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL) {
        self.baseURL = baseURL
        self.session = URLSession(configuration: .default)
    }

    // MARK: - Health

    public func checkHealth() async throws {
        let url = baseURL.appendingPathComponent("health")
        let (_, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw OrcaSlicerError.serverUnreachable
        }
    }

    // MARK: - Profiles

    public func fetchMachineProfiles() async throws -> [MachineProfile] {
        try await get("profiles/machines")
    }

    public func fetchProcessProfiles(machine: String? = nil) async throws -> [ProcessProfile] {
        var components = makeComponents("profiles/processes")
        if let machine {
            components.queryItems = [URLQueryItem(name: "machine", value: machine)]
        }
        guard let url = components.url else { throw OrcaSlicerError.invalidURL }
        return try await get(url: url)
    }

    public func fetchFilamentProfiles(machine: String? = nil, amsAssignable: Bool = true) async throws -> [SlicerFilamentProfile] {
        var components = makeComponents("profiles/filaments")
        var items: [URLQueryItem] = []
        if let machine {
            items.append(URLQueryItem(name: "machine", value: machine))
        }
        if amsAssignable {
            items.append(URLQueryItem(name: "ams_assignable", value: "true"))
        }
        if !items.isEmpty {
            components.queryItems = items
        }
        guard let url = components.url else { throw OrcaSlicerError.invalidURL }
        return try await get(url: url)
    }

    private func makeComponents(_ path: String) -> URLComponents {
        URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
            ?? URLComponents()
    }

    // MARK: - Slicing

    /// Send a 3MF file to orcaslicer-cli for slicing and return the sliced 3MF data.
    ///
    /// - Parameters:
    ///   - fileData: The raw 3MF file data.
    ///   - fileName: Original filename (e.g. `model.3mf`).
    ///   - machineProfile: Machine profile `setting_id`.
    ///   - processProfile: Process profile `setting_id`.
    ///   - filamentProfiles: Mapping of filament index → `FilamentSelection`.
    ///   - plateType: Optional plate type (e.g. `cool_plate`).
    /// - Returns: The sliced 3MF file data.
    public func slice(
        fileData: Data,
        fileName: String,
        machineProfile: String,
        processProfile: String,
        filamentProfiles: [String: FilamentSelection],
        plateType: String? = nil
    ) async throws -> Data {
        let boundary = "Boundary-\(UUID().uuidString)"
        let url = baseURL.appendingPathComponent("slice")

        var body = Data()
        func appendField(name: String, value: String) {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }

        // File part
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n")
        body.append("Content-Type: application/octet-stream\r\n\r\n")
        body.append(fileData)
        body.append("\r\n")

        // Form fields
        appendField(name: "machine_profile", value: machineProfile)
        appendField(name: "process_profile", value: processProfile)

        let profilesJSON = try JSONEncoder().encode(filamentProfiles)
        appendField(name: "filament_profiles", value: String(data: profilesJSON, encoding: .utf8) ?? "{}")

        if let plateType, !plateType.isEmpty {
            appendField(name: "plate_type", value: plateType)
        }

        body.append("--\(boundary)--\r\n")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 600 // slicing can take several minutes

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OrcaSlicerError.serverError(statusCode: -1)
        }

        if http.statusCode != 200 {
            // Try to decode error response
            if let errorResponse = try? JSONDecoder().decode(SliceErrorResponse.self, from: data) {
                throw OrcaSlicerError.slicingFailed(errorResponse.error, orcaOutput: errorResponse.orcaOutput)
            }
            throw OrcaSlicerError.serverError(statusCode: http.statusCode)
        }

        return data
    }

    // MARK: - Private

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        return try await get(url: url)
    }

    private func get<T: Decodable>(url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw OrcaSlicerError.serverError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

/// Filament selection for the slice request payload.
public struct FilamentSelection: Codable, Sendable {
    public let profileSettingId: String
    public let traySlot: Int?

    public init(profileSettingId: String, traySlot: Int?) {
        self.profileSettingId = profileSettingId
        self.traySlot = traySlot
    }

    enum CodingKeys: String, CodingKey {
        case profileSettingId = "profile_setting_id"
        case traySlot = "tray_slot"
    }
}

private struct SliceErrorResponse: Decodable {
    let error: String
    let orcaOutput: String?

    enum CodingKeys: String, CodingKey {
        case error
        case orcaOutput = "orca_output"
    }
}

public enum OrcaSlicerError: LocalizedError {
    case serverUnreachable
    case serverError(statusCode: Int)
    case invalidURL
    case slicingFailed(String, orcaOutput: String?)

    public var errorDescription: String? {
        switch self {
        case .serverUnreachable:
            String(localized: "Cannot reach the slicer server. Check the URL in Settings.")
        case let .serverError(code):
            String(localized: "Slicer server error (HTTP \(code)).")
        case .invalidURL:
            String(localized: "Invalid slicer server URL.")
        case let .slicingFailed(message, _):
            String(localized: "Slicing failed: \(message)")
        }
    }
}

// MARK: - Data helpers for multipart

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
