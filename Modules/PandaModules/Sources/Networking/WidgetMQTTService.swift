import CocoaMQTT
import Foundation
import PandaModels

/// One-shot MQTT service for widget timeline refresh.
/// Connects, fetches printer state via pushAll, disconnects.
public enum WidgetMQTTService {
    public enum SnapshotError: Error, LocalizedError {
        case notConfigured
        case connectionFailed(String)
        case timeout
        case noData

        public var errorDescription: String? {
            switch self {
            case .notConfigured: "Printer not configured"
            case let .connectionFailed(msg): "Connection failed: \(msg)"
            case .timeout: "Connection timed out"
            case .noData: "No data received"
            }
        }
    }

    /// Retains the active session so it isn't deallocated while the async
    /// MQTT connection is in flight.  Without this, the SnapshotSession (a
    /// local inside withCheckedThrowingContinuation) would be freed as soon
    /// as the closure returns, niling out CocoaMQTT's weak delegate and
    /// causing the continuation to never resume.
    fileprivate nonisolated(unsafe) static var activeSession: AnyObject?
    fileprivate nonisolated(unsafe) static var activeCommandSession: AnyObject?

    /// Send a single command to the printer via a one-shot MQTT connection.
    /// Connects, discovers the serial from the first message, sends the command, and disconnects.
    public static func sendCommand(
        _ command: PrinterCommand,
        ip: String,
        accessCode: String,
        serial: String,
        timeout: TimeInterval = 5
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let session = CommandSession(
                command: command,
                ip: ip,
                accessCode: accessCode,
                serial: serial,
                timeout: timeout,
                continuation: continuation
            )
            activeCommandSession = session
            session.start()
        }
    }

    /// Fetch the current printer state via a one-shot MQTT connection.
    /// Returns a snapshot suitable for caching and widget display.
    public static func fetchSnapshot(
        ip: String,
        accessCode: String,
        serial: String,
        timeout: TimeInterval = 5
    ) async throws -> PrinterStateSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            let session = SnapshotSession(
                ip: ip,
                accessCode: accessCode,
                serial: serial,
                timeout: timeout,
                continuation: continuation
            )
            activeSession = session
            session.start()
        }
    }
}

// MARK: - Snapshot Session

/// Manages a single MQTT connect→subscribe→pushAll→receive→disconnect cycle.
/// Bridges CocoaMQTT delegate callbacks into a single CheckedContinuation.
private final class SnapshotSession: @unchecked Sendable {
    private let ip: String
    private let accessCode: String
    private let serial: String
    private let timeout: TimeInterval
    private var continuation: CheckedContinuation<PrinterStateSnapshot, Error>?
    private var mqtt: CocoaMQTT?
    private let delegate = SessionDelegate()
    private let printerState = PrinterState()
    private var hasReceivedPrintData = false
    private var timeoutTask: Task<Void, Never>?
    private var discoveredSerial: String?

    private var hasSerial: Bool { !serial.isEmpty }

    init(ip: String, accessCode: String, serial: String, timeout: TimeInterval,
         continuation: CheckedContinuation<PrinterStateSnapshot, Error>)
    {
        self.ip = ip
        self.accessCode = accessCode
        self.serial = serial
        self.timeout = timeout
        self.continuation = continuation
    }

    func start() {
        let clientId = "PandaWidget_\(Int(Date.now.timeIntervalSince1970))"
        let client = CocoaMQTT(clientID: clientId, host: ip, port: 8883)
        client.username = "bblp"
        client.password = accessCode
        client.enableSSL = true
        client.allowUntrustCACertificate = true
        client.keepAlive = 30
        client.sslSettings = [
            kCFStreamSSLPeerName as String: "" as NSString,
        ]
        client.delegate = delegate

        client.didReceiveTrust = { _, _, completionHandler in
            completionHandler(true)
        }

        let reportTopic = hasSerial ? "device/\(serial)/report" : "device/+/report"
        delegate.onConnected = { [weak self] mqtt in
            mqtt.subscribe(reportTopic)
            if self?.hasSerial == true {
                self?.sendPushAll(serial: self!.serial)
            }
        }

        delegate.onMessage = { [weak self] topic, data in
            self?.handleMessage(topic: topic, data: data)
        }

        delegate.onError = { [weak self] message in
            self?.finish(with: .failure(WidgetMQTTService.SnapshotError.connectionFailed(message)))
        }

        delegate.onDisconnected = { [weak self] in
            // Only treat as error if we haven't already finished
            self?.finish(with: .failure(WidgetMQTTService.SnapshotError.connectionFailed("Disconnected")))
        }

        self.mqtt = client

        // Start timeout
        timeoutTask = Task { [weak self, timeout] in
            try? await Task.sleep(for: .seconds(timeout))
            self?.finish(with: .failure(WidgetMQTTService.SnapshotError.timeout))
        }

        _ = client.connect()
    }

    private func handleMessage(topic: String, data: Data) {
        // Auto-discover serial from first message topic when not provided
        if !hasSerial, discoveredSerial == nil {
            let parts = topic.split(separator: "/")
            if parts.count == 3, parts[0] == "device", parts[2] == "report" {
                discoveredSerial = String(parts[1])
                sendPushAll(serial: discoveredSerial!)
            }
            return
        }

        guard let payload = PandaMQTTPayload.parse(from: data) else { return }
        printerState.apply(payload)

        // We need at least gcode_state to have useful print data
        if payload.gcodeState != nil {
            hasReceivedPrintData = true
        }

        // Wait until we have print data before finishing
        if hasReceivedPrintData {
            let snapshot = PrinterStateSnapshot(from: printerState)
            finish(with: .success(snapshot))
        }
    }

    private func sendPushAll(serial: String) {
        guard let mqtt else { return }
        let topic = "device/\(serial)/request"

        let pushAllData = PrinterCommand.pushAll.payload()
        if let json = String(data: pushAllData, encoding: .utf8) {
            mqtt.publish(topic, withString: json, qos: .qos1)
        }

        let versionData = PrinterCommand.getVersion.payload()
        if let json = String(data: versionData, encoding: .utf8) {
            mqtt.publish(topic, withString: json, qos: .qos1)
        }
    }

    private func finish(with result: Result<PrinterStateSnapshot, Error>) {
        // Guard against double resume
        guard let cont = continuation else { return }
        continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        mqtt?.disconnect()
        mqtt?.delegate = nil
        mqtt = nil
        WidgetMQTTService.activeSession = nil
        cont.resume(with: result)
    }
}

// MARK: - Command Session

/// Manages a single MQTT connect→subscribe→send command→disconnect cycle.
/// Used for one-shot commands like toggling the chamber light from a widget.
private final class CommandSession: @unchecked Sendable {
    private let command: PrinterCommand
    private let ip: String
    private let accessCode: String
    private let serial: String
    private let timeout: TimeInterval
    private var continuation: CheckedContinuation<Void, Error>?
    private var mqtt: CocoaMQTT?
    private let delegate = SessionDelegate()
    private var timeoutTask: Task<Void, Never>?
    private var commandPublished = false

    private var hasSerial: Bool { !serial.isEmpty }

    init(command: PrinterCommand, ip: String, accessCode: String, serial: String, timeout: TimeInterval,
         continuation: CheckedContinuation<Void, Error>)
    {
        self.command = command
        self.ip = ip
        self.accessCode = accessCode
        self.serial = serial
        self.timeout = timeout
        self.continuation = continuation
    }

    func start() {
        let clientId = "PandaWidgetCmd_\(Int(Date.now.timeIntervalSince1970))"
        let client = CocoaMQTT(clientID: clientId, host: ip, port: 8883)
        client.username = "bblp"
        client.password = accessCode
        client.enableSSL = true
        client.allowUntrustCACertificate = true
        client.keepAlive = 30
        client.sslSettings = [
            kCFStreamSSLPeerName as String: "" as NSString,
        ]
        client.delegate = delegate

        client.didReceiveTrust = { _, _, completionHandler in
            completionHandler(true)
        }

        let reportTopic = hasSerial ? "device/\(serial)/report" : "device/+/report"
        delegate.onConnected = { [weak self] mqtt in
            mqtt.subscribe(reportTopic)
            if self?.hasSerial == true {
                self?.publishCommand(serial: self!.serial)
            }
        }

        delegate.onMessage = { [weak self] topic, _ in
            self?.handleMessage(topic: topic)
        }

        delegate.onPublishAck = { [weak self] _ in
            guard self?.commandPublished == true else { return }
            self?.finish(with: .success(()))
        }

        delegate.onError = { [weak self] message in
            self?.finish(with: .failure(WidgetMQTTService.SnapshotError.connectionFailed(message)))
        }

        delegate.onDisconnected = { [weak self] in
            self?.finish(with: .failure(WidgetMQTTService.SnapshotError.connectionFailed("Disconnected")))
        }

        self.mqtt = client

        timeoutTask = Task { [weak self, timeout] in
            try? await Task.sleep(for: .seconds(timeout))
            self?.finish(with: .failure(WidgetMQTTService.SnapshotError.timeout))
        }

        _ = client.connect()
    }

    private func handleMessage(topic: String) {
        // Auto-discover serial from first message when not provided
        guard !hasSerial, !commandPublished else { return }
        let parts = topic.split(separator: "/")
        guard parts.count == 3, parts[0] == "device", parts[2] == "report" else { return }
        publishCommand(serial: String(parts[1]))
    }

    private func publishCommand(serial: String) {
        guard let mqtt, !commandPublished else { return }
        commandPublished = true
        let requestTopic = "device/\(serial)/request"
        let payload = command.payload()
        if let json = String(data: payload, encoding: .utf8) {
            mqtt.publish(requestTopic, withString: json, qos: .qos1)
        }
    }

    private func finish(with result: Result<Void, Error>) {
        guard let cont = continuation else { return }
        continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        mqtt?.disconnect()
        mqtt?.delegate = nil
        mqtt = nil
        WidgetMQTTService.activeCommandSession = nil
        cont.resume(with: result)
    }
}

// MARK: - Session Delegate

private class SessionDelegate: CocoaMQTTDelegate {
    var onConnected: ((CocoaMQTT) -> Void)?
    var onDisconnected: (() -> Void)?
    var onError: ((String) -> Void)?
    var onMessage: ((String, Data) -> Void)?
    var onPublishAck: ((UInt16) -> Void)?

    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        if ack == .accept {
            onConnected?(mqtt)
        } else {
            let message = switch ack {
            case .badUsernameOrPassword: "Invalid access code"
            case .notAuthorized: "Not authorized"
            default: "Connection rejected"
            }
            onError?(message)
        }
    }

    func mqtt(_: CocoaMQTT, didPublishMessage _: CocoaMQTTMessage, id _: UInt16) {}
    func mqtt(_: CocoaMQTT, didPublishAck id: UInt16) {
        onPublishAck?(id)
    }

    func mqtt(_: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id _: UInt16) {
        guard let data = message.string?.data(using: .utf8) else { return }
        onMessage?(message.topic, data)
    }

    func mqtt(_: CocoaMQTT, didSubscribeTopics _: NSDictionary, failed _: [String]) {}
    func mqtt(_: CocoaMQTT, didUnsubscribeTopics _: [String]) {}
    func mqttDidPing(_: CocoaMQTT) {}
    func mqttDidReceivePong(_: CocoaMQTT) {}

    func mqttDidDisconnect(_: CocoaMQTT, withError err: (any Error)?) {
        if let err {
            onError?(err.localizedDescription)
        } else {
            onDisconnected?()
        }
    }
}
