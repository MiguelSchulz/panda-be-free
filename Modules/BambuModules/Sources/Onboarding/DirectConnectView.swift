import SwiftUI

struct DirectConnectView: View {
    @Environment(OnboardingViewModel.self) private var viewModel
    @FocusState private var focusedField: CredentialsField?

    var body: some View {
        ScrollView {
            CredentialsForm(focusedField: $focusedField)
                .padding()
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                focusedField = nil
                Task { await viewModel.testAndSave() }
            } label: {
                Group {
                    if viewModel.isTesting {
                        ProgressView()
                    } else {
                        Text("Connect")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.canConnect || viewModel.isTesting)
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
        }
        .navigationTitle("Connect")
    }
}

#Preview {
    DirectConnectView()
        .environment(OnboardingViewModel())
}
