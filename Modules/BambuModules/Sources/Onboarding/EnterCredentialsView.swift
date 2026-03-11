import NavigatorUI
import SwiftUI

struct EnterCredentialsView: View {
    @Environment(OnboardingViewModel.self) private var viewModel
    @Environment(\.navigator) private var navigator
    @FocusState private var focusedField: CredentialsField?

    var body: some View {
        SetupStepLayout(
            step: .enterCredentials,
            nextLabel: "Test Connection",
            isNextDisabled: !viewModel.canConnect,
            isLoading: viewModel.isTesting
        ) {
            focusedField = nil
            Task {
                let success = await viewModel.testConnection()
                if success {
                    navigator.navigate(to: OnboardingDestinations.guidedSlicerSetup)
                }
            }
        } content: {
            CredentialsForm(focusedField: $focusedField)
        }
        .navigationTitle("Enter Credentials")
    }
}

#Preview {
    EnterCredentialsView()
        .environment(OnboardingViewModel())
}
