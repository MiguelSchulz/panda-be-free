import BambuUI
import SFSafeSymbols
import SwiftUI

struct SetupStepLayout<Content: View>: View {
    let step: OnboardingStep
    let nextLabel: LocalizedStringResource
    let isNextDisabled: Bool
    let isLoading: Bool
    let nextAction: () -> Void
    @ViewBuilder let content: () -> Content

    init(
        step: OnboardingStep,
        nextLabel: LocalizedStringResource = "Continue",
        isNextDisabled: Bool = false,
        isLoading: Bool = false,
        nextAction: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.step = step
        self.nextLabel = nextLabel
        self.isNextDisabled = isNextDisabled
        self.isLoading = isLoading
        self.nextAction = nextAction
        self.content = content
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemSymbol: step.systemSymbol)
                    .font(.system(size: 60))
                    .foregroundStyle(.tint)
                    .padding(.top, 24)

                Text(step.title)
                    .font(.title2.bold())

                Text(step.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                content()

                if let wikiURL = step.wikiURL {
                    Link(destination: wikiURL) {
                        Label("View on Bambu Wiki", systemSymbol: .safari)
                    }
                    .font(.subheadline)
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: nextAction) {
                Group {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text(nextLabel)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isNextDisabled || isLoading)
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                StepProgressIndicator(
                    current: step.stepNumber,
                    total: OnboardingStep.totalSteps
                )
            }
        }
    }
}
