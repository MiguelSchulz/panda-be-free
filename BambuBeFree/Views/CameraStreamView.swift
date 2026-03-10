import BambuModels
import BambuUI
import SwiftUI

struct CameraStreamView: View {
    @AppStorage("printerIP", store: UserDefaults(suiteName: SharedSettings.suiteName))
    private var printerIP: String = ""
    @AppStorage("printerAccessCode", store: UserDefaults(suiteName: SharedSettings.suiteName))
    private var accessCode: String = ""
    @AppStorage("printerType", store: UserDefaults(suiteName: SharedSettings.suiteName))
    private var printerTypeRaw: String = "auto"
    @Environment(\.scenePhase) private var scenePhase
    @State private var manager = CameraStreamManager()
    @State private var editingIP: String = ""
    @State private var editingAccessCode: String = ""
    @State private var wasStreaming = false
    @State private var isFullscreen = false

    private var hasConfig: Bool {
        !printerIP.isEmpty && !accessCode.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                switch manager.connectionState {
                case .disconnected where !hasConfig:
                    configForm

                case .disconnected:
                    ProgressView("Connecting...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .connecting:
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Connecting to printer...")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .streaming:
                    streamingView

                case .error(let message):
                    errorView(message: message)
                }
            }
            .navigationTitle("Camera")
            .task {
                if hasConfig && manager.connectionState == .disconnected {
                    manager.connect(ip: printerIP, accessCode: accessCode, printerType: PrinterType(rawValue: printerTypeRaw) ?? .auto)
                }
            }
            .onDisappear {
                if manager.connectionState == .streaming || manager.connectionState == .connecting {
                    wasStreaming = true
                    manager.disconnect()
                }
            }
            .onAppear {
                if wasStreaming && hasConfig {
                    wasStreaming = false
                    manager.connect(ip: printerIP, accessCode: accessCode, printerType: PrinterType(rawValue: printerTypeRaw) ?? .auto)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background:
                    if manager.connectionState == .streaming || manager.connectionState == .connecting {
                        wasStreaming = true
                        manager.disconnect()
                    }
                case .active:
                    if wasStreaming && hasConfig {
                        wasStreaming = false
                        manager.connect(ip: printerIP, accessCode: accessCode, printerType: PrinterType(rawValue: printerTypeRaw) ?? .auto)
                    }
                default:
                    break
                }
            }
        }
        .fullScreenCover(isPresented: $isFullscreen) {
            FullscreenCameraView(cameraProvider: manager, isPresented: $isFullscreen)
        }
    }

    // MARK: - Config Form

    private var configForm: some View {
        Form {
            Section {
                TextField("Printer IP Address", text: $editingIP)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textContentType(.none)
                SecureField("Access Code", text: $editingAccessCode)
                    .autocorrectionDisabled()
                    .textContentType(.password)
            } header: {
                Text("Printer Connection")
            } footer: {
                Text("Find the IP address in your printer's network settings and the access code under Settings > LAN Only Mode.")
            }

            Section {
                Button("Connect") {
                    printerIP = editingIP.trimmingCharacters(in: .whitespaces)
                    accessCode = editingAccessCode.trimmingCharacters(in: .whitespaces)
                    manager.connect(ip: printerIP, accessCode: accessCode, printerType: PrinterType(rawValue: printerTypeRaw) ?? .auto)
                }
                .disabled(editingIP.isEmpty || editingAccessCode.isEmpty)
            }
        }
        .onAppear {
            editingIP = printerIP
            editingAccessCode = accessCode
        }
    }

    // MARK: - Streaming View

    private var streamingView: some View {
        ZStack(alignment: .bottomTrailing) {
            if let frame = manager.currentFrame {
                ZoomableContainer {
                    Image(uiImage: frame)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView("Waiting for first frame...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Button {
                isFullscreen = true
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.5), in: Circle())
            }
            .padding(12)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    manager.disconnect()
                    manager.connect(ip: printerIP, accessCode: accessCode, printerType: PrinterType(rawValue: printerTypeRaw) ?? .auto)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reset") {
                    manager.disconnect()
                    printerIP = ""
                    accessCode = ""
                    editingIP = ""
                    editingAccessCode = ""
                }
            }
        }
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)

            Text("Connection Error")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Retry") {
                manager.connect(ip: printerIP, accessCode: accessCode, printerType: PrinterType(rawValue: printerTypeRaw) ?? .auto)
            }
            .buttonStyle(.borderedProminent)

            Button("Change Settings") {
                manager.disconnect()
                printerIP = ""
                accessCode = ""
                editingIP = ""
                editingAccessCode = ""
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

#Preview {
    CameraStreamView()
}
