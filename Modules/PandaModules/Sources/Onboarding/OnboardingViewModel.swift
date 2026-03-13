import Foundation
import PandaModels

@MainActor
@Observable
public final class OnboardingViewModel {
    public var ip = ""
    public var accessCode = ""
    public var printerTypeRaw = "auto"
    public var isTesting = false
    public var connectionError: String?

    public let connectionTester: @MainActor (String, String) async -> String?

    public init(
        connectionTester: @escaping @MainActor (String, String) async -> String? = { _, _ in nil }
    ) {
        self.connectionTester = connectionTester
    }

    public var canConnect: Bool {
        !ip.trimmingCharacters(in: .whitespaces).isEmpty
            && !accessCode.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public func testAndSave() async -> Bool {
        let success = await testConnection()
        if success { saveCredentials() }
        return success
    }

    public func testConnection() async -> Bool {
        let trimmedIP = ip.trimmingCharacters(in: .whitespaces)
        let trimmedCode = accessCode.trimmingCharacters(in: .whitespaces)

        connectionError = nil
        isTesting = true
        defer { isTesting = false }

        if let error = await connectionTester(trimmedIP, trimmedCode) {
            connectionError = error
            return false
        }
        return true
    }

    public func saveCredentials() {
        SharedSettings.printerIP = ip.trimmingCharacters(in: .whitespaces)
        SharedSettings.printerAccessCode = accessCode.trimmingCharacters(in: .whitespaces)
        if let type = PrinterType(rawValue: printerTypeRaw) {
            SharedSettings.printerType = type
        }
    }
}
