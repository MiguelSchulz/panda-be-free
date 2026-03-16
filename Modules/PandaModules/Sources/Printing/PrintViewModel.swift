import Foundation
import GCodePreview
import PandaModels
import SceneKit
import SwiftUI

extension ColorPalette {
    /// Palette matching PandaBeFree's accent green and semantic system colors.
    static let panda = ColorPalette(
        filamentColors: [
            Color(hex: 0x4DAB50), // accent green
            Color(hex: 0x4078D9), // blue
            Color(hex: 0xEB8C2E), // orange
            Color(hex: 0xE6BF33), // yellow
            Color(hex: 0xD14545), // red
            Color(hex: 0x2E9EA8), // teal
        ],
        supportColor: Color(hex: 0x8C9EB3, alpha: 0.45)
    )
}

/// Phases of the print workflow.
public enum PrintPhase: Sendable {
    case idle
    case parsing
    case loadingProfiles
    case configuring
    case slicing
    case previewing
    case uploading
    case sent
    case error(String)
}

/// Orchestrates the print tab workflow: load 3MF, fetch profiles, map filaments to AMS trays,
/// slice, upload via FTPS, and send the MQTT print command.
@Observable
@MainActor
public final class PrintViewModel {
    // MARK: - State

    public private(set) var phase: PrintPhase = .idle
    public private(set) var selectedFileURL: URL?
    public private(set) var selectedFileName: String?
    public private(set) var metadata: ThreeMFMetadata?

    // MARK: - Preview State

    public var previewScene: SCNScene?
    public var isShowingPreview = false

    // Profiles from orcaslicer-cli (filtered by configured machine)
    public private(set) var processProfiles: [ProcessProfile] = []
    public private(set) var filamentProfiles: [SlicerFilamentProfile] = []

    /// User selections
    public var selectedProcess: ProcessProfile? {
        didSet {
            SharedSettings.sharedDefaults?.set(selectedProcess?.settingId, forKey: "lastProcessProfileId")
        }
    }

    public private(set) var filamentMappings: [FilamentMapping] = []

    /// Whether the "Slice & Print" / "Print" button should be enabled.
    public var canStartPrint: Bool {
        let isPreSliced = metadata?.hasGcode == true
        // Pre-sliced files only need a tray assignment; unsliced also need a process profile
        if !isPreSliced, selectedProcess == nil { return false }
        // At least one filament must have a tray assigned
        return filamentMappings.contains { $0.selectedTraySlot != nil }
    }

    /// Dependencies
    @ObservationIgnored
    private let amsUnitsProvider: @MainActor () -> [AMSUnit]
    @ObservationIgnored
    private let mqttCommandSender: @MainActor (PrinterCommand) throws -> Void
    @ObservationIgnored
    private var activeTask: Task<Void, Never>?

    /// Cached file data loaded during parsing, kept for slicing.
    @ObservationIgnored
    private var loadedFileData: Data?

    /// Sliced (or pre-sliced) 3MF data, cached after preview for the final upload.
    @ObservationIgnored
    private var slicedFileData: Data?

    public init(
        amsUnitsProvider: @escaping @MainActor () -> [AMSUnit],
        mqttCommandSender: @escaping @MainActor (PrinterCommand) throws -> Void
    ) {
        self.amsUnitsProvider = amsUnitsProvider
        self.mqttCommandSender = mqttCommandSender
    }

    // MARK: - Private

    private func makeSlicerClient() -> OrcaSlicerClient? {
        let urlString = SharedSettings.slicerServerURL
        guard !urlString.isEmpty, let url = URL(string: urlString) else { return nil }
        return OrcaSlicerClient(baseURL: url)
    }

    /// The configured machine setting_id, or nil if not set.
    private var configuredMachineId: String? {
        let id = SharedSettings.slicerMachineId
        return id.isEmpty ? nil : id
    }

    // MARK: - Actions

    public func selectFile(url: URL) {
        selectedFileURL = url
        selectedFileName = url.lastPathComponent
        slicedFileData = nil
        previewScene = nil
        phase = .parsing

        activeTask?.cancel()
        activeTask = Task {
            do {
                let accessing = url.startAccessingSecurityScopedResource()
                defer {
                    if accessing { url.stopAccessingSecurityScopedResource() }
                }

                let fileURL = url
                let (parsed, fileData) = try await Task.detached {
                    let data = try Data(contentsOf: fileURL)
                    let metadata = try ThreeMFParser.parse(data: data)
                    return (metadata, data)
                }.value

                guard !Task.isCancelled else { return }
                self.metadata = parsed
                self.loadedFileData = fileData
                await loadProfiles()
            } catch {
                guard !Task.isCancelled else { return }
                phase = .error(error.localizedDescription)
            }
        }
    }

    public func loadProfiles() async {
        guard let client = makeSlicerClient() else {
            phase = .error(String(localized: "Slicer server not configured. Set the URL in More > Slicer Server."))
            return
        }

        let machineId = configuredMachineId

        phase = .loadingProfiles

        do {
            async let processes = client.fetchProcessProfiles(machine: machineId)
            async let filaments = client.fetchFilamentProfiles(machine: machineId)

            processProfiles = try await processes
            filamentProfiles = try await filaments

            guard !Task.isCancelled else { return }

            // Restore last selected process profile
            if let lastId = SharedSettings.sharedDefaults?.string(forKey: "lastProcessProfileId") {
                selectedProcess = processProfiles.first { $0.settingId == lastId }
            }

            // Auto-match filaments to AMS trays
            if let projectFilaments = metadata?.filaments {
                filamentMappings = FilamentMatcher.autoMatch(
                    projectFilaments: projectFilaments,
                    slicerProfiles: filamentProfiles,
                    amsUnits: amsUnitsProvider()
                )
                resolveMissingProfiles()
            }

            phase = .configuring
        } catch {
            guard !Task.isCancelled else { return }
            phase = .error(error.localizedDescription)
        }
    }

    // MARK: - Preview & Print Pipeline

    public func startPreview() {
        guard let fileData = loadedFileData,
              let fileName = selectedFileName,
              let metadata
        else { return }

        let isPreSliced = metadata.hasGcode

        if !isPreSliced {
            guard selectedProcess != nil, configuredMachineId != nil else { return }
        }

        activeTask?.cancel()
        activeTask = Task {
            do {
                // 1. Slice if needed
                let slicedData: Data
                if isPreSliced {
                    slicedData = fileData
                } else {
                    guard let client = makeSlicerClient(),
                          let machineId = configuredMachineId,
                          let processProfile = selectedProcess
                    else {
                        phase = .error(String(localized: "Slicer server not configured."))
                        return
                    }
                    phase = .slicing
                    let filamentProfilesPayload = buildFilamentProfilesPayload()
                    slicedData = try await client.slice(
                        fileData: fileData,
                        fileName: fileName,
                        machineProfile: machineId,
                        processProfile: processProfile.settingId,
                        filamentProfiles: filamentProfilesPayload
                    )
                }

                guard !Task.isCancelled else { return }
                self.slicedFileData = slicedData

                // 2. Extract G-code and build preview scene
                phase = .previewing
                let box = try await Task.detached {
                    let gcode = try ThreeMFParser.extractGCode(from: slicedData)
                    let model = try GCodeParser().parse(gcode)
                    let scene = PrintSceneBuilder(palette: .panda).buildScene(from: model)
                    return SendableBox(scene)
                }.value

                guard !Task.isCancelled else { return }
                previewScene = box.value
                isShowingPreview = true
            } catch {
                guard !Task.isCancelled else { return }
                phase = .error(error.localizedDescription)
            }
        }
    }

    public func confirmPrint() {
        guard let slicedData = slicedFileData,
              let fileName = selectedFileName,
              let metadata
        else { return }

        isShowingPreview = false
        previewScene = nil

        activeTask?.cancel()
        activeTask = Task {
            do {
                // 1. Build AMS mapping
                let projectFilamentCount = metadata.filaments.count
                let (amsMapping, useAMS) = AMSMappingBuilder.build(
                    from: filamentMappings,
                    projectFilamentCount: projectFilamentCount
                )

                // 2. Upload via FTPS
                phase = .uploading
                let printerIP = SharedSettings.printerIP
                let accessCode = SharedSettings.printerAccessCode
                guard !printerIP.isEmpty, !accessCode.isEmpty else {
                    phase = .error(String(localized: "Printer not configured. Set IP and access code in settings."))
                    return
                }

                let uploader = FTPSUploader()
                try await uploader.upload(
                    fileData: slicedData,
                    filename: fileName,
                    printerIP: printerIP,
                    accessCode: accessCode
                )

                guard !Task.isCancelled else { return }

                // 3. Send MQTT print command
                let command = PrinterCommand.projectFile(
                    filename: fileName,
                    amsMapping: amsMapping,
                    useAMS: useAMS
                )
                try mqttCommandSender(command)

                phase = .sent
            } catch {
                guard !Task.isCancelled else { return }
                phase = .error(error.localizedDescription)
            }
        }
    }

    public func cancelPreview() {
        isShowingPreview = false
        phase = .configuring
    }

    /// Whether a cached preview is available to show without re-slicing.
    public var hasPreviewCache: Bool {
        previewScene != nil && slicedFileData != nil
    }

    /// Re-show a previously built preview without slicing again.
    public func showCachedPreview() {
        guard hasPreviewCache else { return }
        isShowingPreview = true
    }

    private func buildFilamentProfilesPayload() -> [String: FilamentSelection] {
        var payload: [String: FilamentSelection] = [:]
        for mapping in filamentMappings {
            guard let profile = mapping.selectedProfile else { continue }
            payload["\(mapping.id)"] = FilamentSelection(
                profileSettingId: profile.settingId,
                traySlot: mapping.selectedTraySlot
            )
        }
        return payload
    }

    // MARK: - Filament Assignment

    public func assignTray(filamentIndex: Int, traySlot: Int?) {
        guard let idx = filamentMappings.firstIndex(where: { $0.id == filamentIndex }) else { return }
        filamentMappings[idx].selectedTraySlot = traySlot
        filamentMappings[idx].matchReason = traySlot != nil ? .manual : .none

        // Auto-resolve profile from the tray's trayInfoIdx if user hasn't manually picked one
        if !filamentMappings[idx].userPickedProfile, let traySlot {
            filamentMappings[idx].selectedProfile = resolveProfileFromTray(globalSlot: traySlot)
        }
    }

    public func assignProfile(filamentIndex: Int, profile: SlicerFilamentProfile) {
        guard let idx = filamentMappings.firstIndex(where: { $0.id == filamentIndex }) else { return }
        filamentMappings[idx].selectedProfile = profile

        // If the user picked the profile that matches the current tray, treat it as auto
        if let traySlot = filamentMappings[idx].selectedTraySlot,
           let recommended = resolveProfileFromTray(globalSlot: traySlot),
           recommended.settingId == profile.settingId
        {
            filamentMappings[idx].userPickedProfile = false
        } else {
            filamentMappings[idx].userPickedProfile = true
        }
    }

    private func resolveProfileFromTray(globalSlot: Int) -> SlicerFilamentProfile? {
        for unit in amsUnitsProvider() {
            for tray in unit.trays {
                if tray.globalIndex(amsId: unit.id) == globalSlot,
                   let idx = tray.trayInfoIdx, !idx.isEmpty
                {
                    return filamentProfiles.first {
                        $0.filamentId.caseInsensitiveCompare(idx) == .orderedSame
                    }
                }
            }
        }
        return nil
    }

    /// Fill in missing profiles for mappings that have a tray but no profile.
    /// Called after auto-match and when AMS data may have refreshed.
    public func resolveMissingProfiles() {
        for i in filamentMappings.indices {
            if filamentMappings[i].selectedProfile == nil,
               !filamentMappings[i].userPickedProfile,
               let traySlot = filamentMappings[i].selectedTraySlot
            {
                filamentMappings[i].selectedProfile = resolveProfileFromTray(globalSlot: traySlot)
            }
        }
    }

    public func setError(_ message: String) {
        phase = .error(message)
    }

    public func reset() {
        activeTask?.cancel()
        activeTask = nil
        phase = .idle
        selectedFileURL = nil
        selectedFileName = nil
        metadata = nil
        loadedFileData = nil
        slicedFileData = nil
        previewScene = nil
        isShowingPreview = false
        processProfiles = []
        filamentProfiles = []
        selectedProcess = nil
        filamentMappings = []
    }

    public func currentAMSUnits() -> [AMSUnit] {
        amsUnitsProvider()
    }
}

/// Wraps a non-Sendable value so it can cross isolation boundaries.
private struct SendableBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}
