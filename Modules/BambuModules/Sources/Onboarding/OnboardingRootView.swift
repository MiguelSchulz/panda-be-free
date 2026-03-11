import NavigatorUI
import SwiftUI

public struct OnboardingRootView: View {
    @State private var viewModel: OnboardingViewModel

    public init(
        connectionTester: @escaping @MainActor (String, String) async -> String? = { _, _ in nil }
    ) {
        _viewModel = State(initialValue: OnboardingViewModel(connectionTester: connectionTester))
    }

    public var body: some View {
        ManagedNavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "printer.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.tint)

                VStack(spacing: 8) {
                    Text("Welcome to Bambu Companion")
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
                        Label("Guide Me Through Setup", systemImage: "questionmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    NavigationLink(to: OnboardingDestinations.directConnect) {
                        Label("I Know What I'm Doing", systemImage: "bolt.fill")
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
