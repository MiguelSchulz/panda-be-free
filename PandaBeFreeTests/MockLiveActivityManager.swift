import Foundation
import PandaModels
import PandaNotifications

final class MockLiveActivityManager: LiveActivityManaging, @unchecked Sendable {
    private(set) var startCalls: [(contentState: PrinterAttributes.ContentState, printerName: String)] = []
    private(set) var updateCalls: [PrinterAttributes.ContentState] = []
    private(set) var endCalls: [PrinterAttributes.ContentState] = []
    var activeOverride = false

    var isActivityActive: Bool {
        activeOverride
    }

    func startIfNeeded(contentState: PrinterAttributes.ContentState, printerName: String) async {
        startCalls.append((contentState: contentState, printerName: printerName))
    }

    func update(contentState: PrinterAttributes.ContentState) async {
        updateCalls.append(contentState)
    }

    func endIfNeeded(contentState: PrinterAttributes.ContentState) async {
        endCalls.append(contentState)
    }

    func reset() {
        startCalls.removeAll()
        updateCalls.removeAll()
        endCalls.removeAll()
    }
}
