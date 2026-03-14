import NavigatorUI
import SFSafeSymbols
import SwiftUI

public struct OnboardingRootView: View {
    @State private var viewModel: OnboardingViewModel

    public init(
        connectionTester: @escaping @MainActor (String, String, String) async -> String? = { _, _, _ in nil }
    ) {
        _viewModel = State(initialValue: OnboardingViewModel(connectionTester: connectionTester))
    }

    public var body: some View {
        ManagedNavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Image(.logo)
                    .resizable()
                    .frame(width: 120, height: 120)

                VStack(spacing: 8) {
                    Text("Welcome to PandaBeFree")
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    Text("Connect to your Bambu Lab printer to get started.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)

                Spacer()

                VStack(spacing: 12) {
                    NavigationLink(to: OnboardingDestinations.guidedLanMode) {
                        Label("Guide Me Through Setup", systemSymbol: .questionmarkCircle)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    NavigationLink(to: OnboardingDestinations.directConnect) {
                        Label("I Know What I'm Doing", systemSymbol: .boltFill)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
        }
        .environment(viewModel)
    }
}

#Preview {
    OnboardingRootView()
}
