import NavigatorUI
import SwiftUI

nonisolated public enum OnboardingDestinations: NavigationDestination {
    case directConnect
    case guidedLanMode
    case guidedDevMode
    case guidedCredentials
    case guidedEnterCredentials
    case guidedSlicerSetup

    public var body: some View {
        switch self {
        case .directConnect:
            DirectConnectView()
        case .guidedLanMode:
            LanModeStepView()
        case .guidedDevMode:
            DevModeStepView()
        case .guidedCredentials:
            CredentialsStepView()
        case .guidedEnterCredentials:
            EnterCredentialsView()
        case .guidedSlicerSetup:
            SlicerSetupView()
        }
    }
}
