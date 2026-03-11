import BambuModels
import SwiftUI

enum CredentialsField: Hashable {
    case ip
    case accessCode
}

struct CredentialsForm: View {
    @Environment(OnboardingViewModel.self) private var viewModel
    var focusedField: FocusState<CredentialsField?>.Binding

    var body: some View {
        @Bindable var vm = viewModel

        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("IP Address")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                TextField("e.g. 192.168.1.100", text: $vm.ip)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textContentType(.none)
                    .textFieldStyle(.roundedBorder)
                    .focused(focusedField, equals: .ip)
                    .submitLabel(.next)
                    .onSubmit { focusedField.wrappedValue = .accessCode }
                    .onChange(of: viewModel.ip) {
                        viewModel.connectionError = nil
                    }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Access Code")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                SecureField("e.g. 12345678", text: $vm.accessCode)
                    .autocorrectionDisabled()
                    .textContentType(.password)
                    .textFieldStyle(.roundedBorder)
                    .focused(focusedField, equals: .accessCode)
                    .submitLabel(.done)
                    .onSubmit { focusedField.wrappedValue = nil }
                    .onChange(of: viewModel.accessCode) {
                        viewModel.connectionError = nil
                    }
            }

            HStack {
                Text("Camera Protocol")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Camera Protocol", selection: $vm.printerTypeRaw) {
                    ForEach(PrinterType.allCases) { type in
                        Text(type.displayName).tag(type.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            if let error = viewModel.connectionError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))

        Label {
            Text("Your iPhone must be on the same network as your printer (LAN mode only). Using a VPN like Tailscale or WireGuard is the easiest way to connect remotely.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
        }
    }
}
