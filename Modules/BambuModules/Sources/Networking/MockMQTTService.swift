import BambuModels
import Foundation

public final class MockMQTTService: MQTTServiceProtocol, @unchecked Sendable {
    public private(set) var connectionState: MQTTConnectionState = .disconnected
    private var messageContinuation: AsyncStream<BambuMQTTPayload>.Continuation?
    private var stateContinuation: AsyncStream<MQTTConnectionState>.Continuation?

    public var lastCommand: PrinterCommand?

    public let stateStream: AsyncStream<MQTTConnectionState>
    public let messageStream: AsyncStream<BambuMQTTPayload>

    public init() {
        let (stateStream, stateContinuation) = AsyncStream.makeStream(
            of: MQTTConnectionState.self, bufferingPolicy: .bufferingNewest(1)
        )
        self.stateStream = stateStream
        self.stateContinuation = stateContinuation

        let (messageStream, messageContinuation) = AsyncStream.makeStream(
            of: BambuMQTTPayload.self, bufferingPolicy: .bufferingNewest(64)
        )
        self.messageStream = messageStream
        self.messageContinuation = messageContinuation
    }

    public func connect(ip _: String, accessCode _: String) {
        connectionState = .connected
        stateContinuation?.yield(.connected)

        // Emit a mock printing state asynchronously to allow subscription
        Task { @MainActor [weak self] in
            var payload = BambuMQTTPayload()
            payload.gcodeState = "RUNNING"
            payload.mcPercent = 42
            payload.mcRemainingTime = 83
            payload.subtaskName = "Benchy"
            payload.layerNum = 150
            payload.totalLayerNum = 300
            payload.nozzleTemper = 220
            payload.nozzleTargetTemper = 220
            payload.bedTemper = 60
            payload.bedTargetTemper = 60
            payload.chamberTemper = 38
            payload.stgCur = 0
            self?.messageContinuation?.yield(payload)
        }
    }

    public func disconnect() {
        connectionState = .disconnected
        stateContinuation?.yield(.disconnected)
    }

    public func sendCommand(_ command: PrinterCommand) {
        lastCommand = command
    }

    public func emit(_ payload: sending BambuMQTTPayload) {
        messageContinuation?.yield(payload)
    }
}
