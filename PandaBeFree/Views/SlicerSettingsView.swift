import PandaModels
import Printing
import SFSafeSymbols
import SwiftUI

struct SlicerSettingsView: View {
    @AppStorage("slicerServerURL", store: UserDefaults(suiteName: SharedSettings.suiteName))
    private var serverURL = ""

    @AppStorage("slicerMachineId", store: UserDefaults(suiteName: SharedSettings.suiteName))
    private var selectedMachineId = ""

    @State private var testStatus: TestStatus = .idle
    @State private var machineProfiles: [MachineProfile] = []
    @State private var isLoadingMachines = false
    @State private var showMachinePicker = false

    private enum TestStatus: Equatable {
        case idle
        case testing
        case success
        case failure(String)
    }

    private var selectedMachineName: String? {
        machineProfiles.first { $0.settingId == selectedMachineId }?.name
    }

    var body: some View {
        List {
            connectionSection
            printerModelSection
            linksSection
        }
        .navigationTitle("Slicer Server")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !serverURL.isEmpty, testStatus == .idle {
                testConnection()
            }
        }
        .sheet(isPresented: $showMachinePicker) {
            MachinePickerView(
                profiles: machineProfiles,
                selectedId: selectedMachineId
            ) { id in
                selectedMachineId = id
                showMachinePicker = false
            }
        }
    }

    // MARK: - Connection Section

    private var connectionSection: some View {
        Section {
            switch testStatus {
            case .success where !serverURL.isEmpty:
                Label("Connected", systemSymbol: .checkmarkCircleFill)
                    .foregroundStyle(.green)
            case .failure:
                Label("Not Connected", systemSymbol: .xmarkCircleFill)
                    .foregroundStyle(.red)
            default:
                if serverURL.isEmpty {
                    Label("Not Configured", systemSymbol: .serverRack)
                        .foregroundStyle(.secondary)
                } else if testStatus == .testing {
                    Label("Connecting...", systemSymbol: .serverRack)
                        .foregroundStyle(.secondary)
                } else {
                    Label("Not Tested", systemSymbol: .serverRack)
                        .foregroundStyle(.secondary)
                }
            }

            TextField("http://192.168.1.100:8000", text: $serverURL)
                .keyboardType(.URL)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            Button {
                testConnection()
            } label: {
                HStack {
                    Label("Test Connection", systemSymbol: .arrowTriangle2Circlepath)
                    Spacer()
                    if testStatus == .testing {
                        ProgressView()
                    }
                }
            }
            .disabled(serverURL.isEmpty || testStatus == .testing)

            if case let .failure(message) = testStatus {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Server")
        } footer: {
            Text("The address of your orcaslicer-cli server on the local network.")
        }
    }

    // MARK: - Printer Model Section

    @ViewBuilder
    private var printerModelSection: some View {
        if !machineProfiles.isEmpty {
            Section {
                Button {
                    showMachinePicker = true
                } label: {
                    HStack {
                        Label {
                            Text("Printer")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemSymbol: .printerFill)
                        }
                        Spacer()
                        Text(selectedMachineName ?? "Select...")
                            .foregroundStyle(.secondary)
                        Image(systemSymbol: .chevronRight)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            } header: {
                Text("Printer Model")
            } footer: {
                Text("Select your printer to filter slicer profiles. Process and filament profiles will only show options compatible with this printer.")
            }
        } else if isLoadingMachines {
            Section {
                HStack {
                    Label("Loading printers...", systemSymbol: .printerFill)
                    Spacer()
                    ProgressView()
                }
            } header: {
                Text("Printer Model")
            }
        } else if !selectedMachineId.isEmpty, testStatus != .success {
            // Server not yet tested but a machine was previously configured
            Section {
                HStack {
                    Label {
                        Text("Printer")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemSymbol: .printerFill)
                    }
                    Spacer()
                    Text(selectedMachineId)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Printer Model")
            }
        }
    }

    // MARK: - Links Section

    private var linksSection: some View {
        Section {
            Link(destination: URL(string: "https://github.com/leolobato/orcaslicer-cli")!) {
                Label("orcaslicer-cli on GitHub", systemSymbol: .arrowUpRightSquare)
                    .foregroundStyle(.primary)
            }
        }
    }

    // MARK: - Actions

    private func testConnection() {
        guard let url = URL(string: serverURL) else {
            testStatus = .failure("Invalid URL")
            return
        }

        testStatus = .testing
        isLoadingMachines = true
        let client = OrcaSlicerClient(baseURL: url)

        Task {
            do {
                try await client.checkHealth()
                testStatus = .success
                let profiles = try await client.fetchMachineProfiles()
                machineProfiles = profiles
            } catch {
                testStatus = .failure(error.localizedDescription)
            }
            isLoadingMachines = false
        }
    }
}

// MARK: - Machine Picker

private struct MachinePickerView: View {
    let profiles: [MachineProfile]
    let selectedId: String
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredProfiles: [MachineProfile] {
        if searchText.isEmpty { return profiles }
        return profiles.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.printerModel.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Group profiles by printer model for easier browsing.
    private var groupedProfiles: [(model: String, profiles: [MachineProfile])] {
        let grouped = Dictionary(grouping: filteredProfiles) { $0.printerModel }
        return grouped
            .sorted { $0.key < $1.key }
            .map { (model: $0.key.isEmpty ? "Other" : $0.key, profiles: $0.value) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedProfiles, id: \.model) { group in
                    Section(group.model) {
                        ForEach(group.profiles) { profile in
                            Button {
                                onSelect(profile.settingId)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(profile.name)
                                        Text("\(profile.nozzleDiameter)mm nozzle")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if profile.settingId == selectedId {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search printers")
            .navigationTitle("Select Printer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SlicerSettingsView()
    }
}
