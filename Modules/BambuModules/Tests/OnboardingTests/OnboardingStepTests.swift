@testable import Onboarding
import Testing

@Suite("Onboarding Steps")
struct OnboardingStepTests {
    @Test("Total steps count")
    func totalSteps() {
        #expect(OnboardingStep.totalSteps == 5)
    }

    @Test("Step numbers are 1-based",
          arguments: [
              (OnboardingStep.lanMode, 1),
              (OnboardingStep.devMode, 2),
              (OnboardingStep.credentials, 3),
              (OnboardingStep.enterCredentials, 4),
              (OnboardingStep.slicerSetup, 5),
          ])
    func stepNumbers(step: OnboardingStep, expected: Int) {
        #expect(step.stepNumber == expected)
    }

    @Test("Steps are in correct order")
    func stepOrder() {
        let steps = OnboardingStep.allCases
        #expect(steps[0] == .lanMode)
        #expect(steps[1] == .devMode)
        #expect(steps[2] == .credentials)
        #expect(steps[3] == .enterCredentials)
        #expect(steps[4] == .slicerSetup)
    }

    @Test("All steps have non-empty titles")
    func titlesNotEmpty() {
        for step in OnboardingStep.allCases {
            #expect(!step.title.key.isEmpty)
        }
    }

    @Test("All steps have non-empty descriptions")
    func descriptionsNotEmpty() {
        for step in OnboardingStep.allCases {
            #expect(!step.description.key.isEmpty)
        }
    }

    @Test("All steps have non-empty system symbols")
    func systemSymbolsNotEmpty() {
        for step in OnboardingStep.allCases {
            #expect(!step.systemSymbol.rawValue.isEmpty)
        }
    }

    @Test("Wiki URLs are set for informational steps",
          arguments: [
              OnboardingStep.lanMode,
              OnboardingStep.devMode,
              OnboardingStep.credentials,
              OnboardingStep.slicerSetup,
          ])
    func wikiURLsExist(step: OnboardingStep) {
        #expect(step.wikiURL != nil)
    }

    @Test("Enter credentials step has no wiki URL")
    func enterCredentialsNoWikiURL() {
        #expect(OnboardingStep.enterCredentials.wikiURL == nil)
    }
}
