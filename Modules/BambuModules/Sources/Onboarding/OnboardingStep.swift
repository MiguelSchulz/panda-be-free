import Foundation
import SFSafeSymbols

public enum OnboardingStep: Int, CaseIterable, Sendable {
    case lanMode
    case devMode
    case credentials
    case enterCredentials
    case slicerSetup

    public var stepNumber: Int {
        rawValue + 1
    }

    public static var totalSteps: Int {
        allCases.count
    }

    public var title: LocalizedStringResource {
        switch self {
        case .lanMode: "Enable LAN Mode"
        case .devMode: "Enable Developer Mode"
        case .credentials: "Find Your Credentials"
        case .enterCredentials: "Enter Credentials"
        case .slicerSetup: "Configure Your Slicer"
        }
    }

    public var description: LocalizedStringResource {
        switch self {
        case .lanMode:
            "LAN Mode allows your printer to communicate directly over your local network without going through the cloud."
        case .devMode:
            "Developer Mode lets third-party apps like this one control your printer. It only works when LAN Mode is enabled."
        case .credentials:
            "You'll need your printer's IP address and access code to connect. Here's where to find them."
        case .enterCredentials:
            "Enter the IP address and access code you found on your printer."
        case .slicerSetup:
            "To send prints over LAN, you'll also need to update your slicer's connection settings."
        }
    }

    public var systemSymbol: SFSymbol {
        switch self {
        case .lanMode: .wifiRouter
        case .devMode: .wrenchAndScrewdriver
        case .credentials: .keyFill
        case .enterCredentials: .rectangleAndPencilAndEllipsis
        case .slicerSetup: .desktopcomputer
        }
    }

    public var wikiURL: URL? {
        switch self {
        case .lanMode:
            URL(string: "https://wiki.bambulab.com/en/knowledge-sharing/enable-lan-mode")
        case .devMode:
            URL(string: "https://wiki.bambulab.com/en/knowledge-sharing/enable-developer-mode")
        case .credentials:
            URL(string: "https://wiki.bambulab.com/en/knowledge-sharing/access-code-connect")
        case .enterCredentials:
            nil
        case .slicerSetup:
            URL(string: "https://wiki.bambulab.com/en/knowledge-sharing/access-code-connect")
        }
    }
}
