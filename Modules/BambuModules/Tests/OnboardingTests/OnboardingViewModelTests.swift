@testable import BambuModels
@testable import Onboarding
import Testing

@Suite("Onboarding ViewModel")
@MainActor
struct OnboardingViewModelTests {
    // MARK: - Default State

    @Test("Default values are empty")
    func defaultValues() {
        let vm = OnboardingViewModel()
        #expect(vm.ip == "")
        #expect(vm.accessCode == "")
        #expect(vm.printerTypeRaw == "auto")
        #expect(!vm.isTesting)
        #expect(vm.connectionError == nil)
    }

    // MARK: - canConnect

    @Test("canConnect is false when both fields empty")
    func canConnectBothEmpty() {
        let vm = OnboardingViewModel()
        #expect(!vm.canConnect)
    }

    @Test("canConnect is false when IP empty")
    func canConnectIPEmpty() {
        let vm = OnboardingViewModel()
        vm.accessCode = "12345678"
        #expect(!vm.canConnect)
    }

    @Test("canConnect is false when access code empty")
    func canConnectAccessCodeEmpty() {
        let vm = OnboardingViewModel()
        vm.ip = "192.168.1.100"
        #expect(!vm.canConnect)
    }

    @Test("canConnect is true when both non-empty")
    func canConnectBothFilled() {
        let vm = OnboardingViewModel()
        vm.ip = "192.168.1.100"
        vm.accessCode = "12345678"
        #expect(vm.canConnect)
    }

    @Test("canConnect is false when IP is only whitespace")
    func canConnectWhitespaceIP() {
        let vm = OnboardingViewModel()
        vm.ip = "   "
        vm.accessCode = "12345678"
        #expect(!vm.canConnect)
    }

    @Test("canConnect is false when access code is only whitespace")
    func canConnectWhitespaceAccessCode() {
        let vm = OnboardingViewModel()
        vm.ip = "192.168.1.100"
        vm.accessCode = "   "
        #expect(!vm.canConnect)
    }

    // MARK: - testConnection

    @Test("testConnection succeeds without saving credentials")
    func connectionSuccess() async {
        SharedSettings.printerIP = ""
        let vm = OnboardingViewModel { _, _ in nil }
        vm.ip = "192.168.1.100"
        vm.accessCode = "12345678"

        let result = await vm.testConnection()
        #expect(result)
        #expect(vm.connectionError == nil)
        #expect(!vm.isTesting)
        #expect(SharedSettings.printerIP == "")
    }

    @Test("testConnection fails and sets error")
    func connectionFailure() async {
        let vm = OnboardingViewModel { _, _ in "Connection refused" }
        vm.ip = "192.168.1.100"
        vm.accessCode = "wrong"

        let result = await vm.testConnection()
        #expect(!result)
        #expect(vm.connectionError == "Connection refused")
        #expect(!vm.isTesting)
    }

    @Test("testConnection trims whitespace before testing")
    func connectionTrimsWhitespace() async {
        var testedIP = ""
        var testedCode = ""
        let vm = OnboardingViewModel { ip, code in
            testedIP = ip
            testedCode = code
            return nil
        }
        vm.ip = "  192.168.1.100  "
        vm.accessCode = "  12345678  "

        _ = await vm.testConnection()
        #expect(testedIP == "192.168.1.100")
        #expect(testedCode == "12345678")
    }

    // MARK: - testAndSave

    @Test("testAndSave succeeds and saves credentials")
    func andSaveSuccess() async {
        let vm = OnboardingViewModel { _, _ in nil }
        vm.ip = "192.168.1.100"
        vm.accessCode = "12345678"

        let result = await vm.testAndSave()
        #expect(result)
        #expect(vm.connectionError == nil)
        #expect(!vm.isTesting)
        #expect(SharedSettings.printerIP == "192.168.1.100")
    }

    @Test("testAndSave fails and does not save")
    func andSaveFailure() async {
        SharedSettings.printerIP = ""
        let vm = OnboardingViewModel { _, _ in "Connection refused" }
        vm.ip = "192.168.1.100"
        vm.accessCode = "wrong"

        let result = await vm.testAndSave()
        #expect(!result)
        #expect(vm.connectionError == "Connection refused")
        #expect(SharedSettings.printerIP == "")
    }

    // MARK: - saveCredentials

    @Test("saveCredentials trims whitespace")
    func saveCredentialsTrimming() {
        let vm = OnboardingViewModel()
        vm.ip = "  192.168.1.100  "
        vm.accessCode = "  12345678  "
        vm.saveCredentials()

        #expect(SharedSettings.printerIP == "192.168.1.100")
        #expect(SharedSettings.printerAccessCode == "12345678")
    }

    @Test("saveCredentials saves printer type")
    func saveCredentialsPrinterType() {
        let vm = OnboardingViewModel()
        vm.ip = "192.168.1.100"
        vm.accessCode = "12345678"
        vm.printerTypeRaw = "rtsp"
        vm.saveCredentials()

        #expect(SharedSettings.printerType == .rtsp)
    }

    @Test("saveCredentials with invalid printer type keeps existing")
    func saveCredentialsInvalidPrinterType() {
        let previousType = SharedSettings.printerType
        let vm = OnboardingViewModel()
        vm.ip = "192.168.1.100"
        vm.accessCode = "12345678"
        vm.printerTypeRaw = "invalid_type"
        vm.saveCredentials()

        #expect(SharedSettings.printerType == previousType)
    }
}
