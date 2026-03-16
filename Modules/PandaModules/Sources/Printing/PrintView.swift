import PandaModels
import PandaUI
import SFSafeSymbols
import SwiftUI
import UniformTypeIdentifiers

public struct PrintView: View {
    @Bindable var viewModel: PrintViewModel

    public init(viewModel: PrintViewModel) {
        self.viewModel = viewModel
    }

    @State private var showFilePicker = false

    public var body: some View {
        NavigationStack {
            Group {
                switch viewModel.phase {
                case .idle:
                    idleView
                case .parsing, .loadingProfiles:
                    loadingView
                case .configuring:
                    configuringView
                case .slicing:
                    progressView(
                        title: "Slicing",
                        description: "Sending file to slicer server..."
                    )
                case .uploading:
                    progressView(
                        title: "Uploading",
                        description: "Uploading to printer via FTPS..."
                    )
                case .sent:
                    sentView
                case let .error(message):
                    errorView(message: message)
                }
            }
            .navigationTitle("Print")
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.threeMF],
                onCompletion: handleFileSelection
            )
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        ContentUnavailableView {
            Label("Select a 3MF File", systemSymbol: .docBadgePlus)
        } description: {
            Text("Choose a 3MF file to slice and print.")
        } actions: {
            Button {
                showFilePicker = true
            } label: {
                Text("Browse Files")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        ContentUnavailableView {
            ProgressView()
        } description: {
            switch viewModel.phase {
            case .parsing:
                Text("Reading 3MF file...")
            case .loadingProfiles:
                Text("Loading slicer profiles...")
            default:
                Text("Loading...")
            }
        }
    }

    // MARK: - Configuring

    private var configuringView: some View {
        List {
            if let fileName = viewModel.selectedFileName {
                Section {
                    Button {
                        showFilePicker = true
                    } label: {
                        Label {
                            Text(fileName)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        } icon: {
                            Image(systemSymbol: .docFill)
                        }
                    }
                } header: {
                    Text("File")
                }
            }

            Section {
                Picker(selection: $viewModel.selectedProcess) {
                    Text("Select...").tag(nil as ProcessProfile?)
                    ForEach(viewModel.processProfiles) { profile in
                        Text(profile.name).tag(profile as ProcessProfile?)
                    }
                } label: {
                    EmptyView()
                }
            } header: {
                Text("Profile")
            }

            if !viewModel.filamentMappings.isEmpty {
                Section {
                    ForEach(viewModel.filamentMappings) { mapping in
                        FilamentMappingRow(
                            mapping: mapping,
                            filamentProfiles: viewModel.filamentProfiles,
                            amsUnits: viewModel.currentAMSUnits(),
                            onSelectProfile: { profile in
                                viewModel.assignProfile(filamentIndex: mapping.id, profile: profile)
                            },
                            onSelectTray: { slot in
                                viewModel.assignTray(filamentIndex: mapping.id, traySlot: slot)
                            }
                        )
                    }
                } header: {
                    Text("Filament Mapping")
                }
            }

            Section {
                Button {
                    viewModel.startPrint()
                } label: {
                    HStack {
                        Spacer()
                        Label(
                            viewModel.metadata?.hasGcode == true ? "Print" : "Slice & Print",
                            systemSymbol: .printerFill
                        )
                        .font(.headline)
                        Spacer()
                    }
                }
                .disabled(!viewModel.canStartPrint)
            }
        }
    }

    // MARK: - Progress (slicing / uploading)

    private func progressView(title: String, description: String) -> some View {
        ContentUnavailableView {
            Label(title, systemSymbol: .printerFill)
        } description: {
            VStack(spacing: 12) {
                ProgressView()
                Text(description)
            }
        }
    }

    // MARK: - Sent

    private var sentView: some View {
        ContentUnavailableView {
            Label("Print Started!", systemSymbol: .checkmarkCircleFill)
        } description: {
            Text("The print job has been sent to your printer.")
        } actions: {
            Button("New Print") {
                viewModel.reset()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Error

    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label("Error", systemSymbol: .exclamationmarkTriangle)
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                viewModel.reset()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Helpers

    private func handleFileSelection(_ result: Result<URL, Error>) {
        switch result {
        case let .success(url):
            viewModel.selectFile(url: url)
        case let .failure(error):
            viewModel.setError(error.localizedDescription)
        }
    }
}

// MARK: - UTType extension

extension UTType {
    static let threeMF = UTType(filenameExtension: "3mf") ?? .data
}
