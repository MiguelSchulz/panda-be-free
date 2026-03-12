import BambuModels
import CocoaMQTT
import Foundation

public final class BambuMQTTService: MQTTServiceProtocol, @unchecked Sendable {
    private var mqtt: CocoaMQTT?
    private var serialNumber: String?
    private var publishTopic: String?
    private let delegateHandler = DelegateHandler()

    public private(set) var connectionState: MQTTConnectionState = .disconnected

    // Continuations are set up eagerly in init so they're ready before connect()
    private var stateContinuation: AsyncStream<MQTTConnectionState>.Continuation?
    private var messageContinuation: AsyncStream<BambuMQTTPayload>.Continuation?

    public let stateStream: AsyncStream<MQTTConnectionState>
    public let messageStream: AsyncStream<BambuMQTTPayload>

    public init() {
        let (stateStream, stateContinuation) = AsyncStream.makeStream(
            of: MQTTConnectionState.self, bufferingPolicy: .bufferingNewest(1)
        )
        self.stateStream = stateStream
        self.stateContinuation = stateContinuation
        stateContinuation.onTermination = { _ in
            print("[MQTT] State stream terminated")
        }

        let (messageStream, messageContinuation) = AsyncStream.makeStream(
            of: BambuMQTTPayload.self, bufferingPolicy: .bufferingNewest(64)
        )
        self.messageStream = messageStream
        self.messageContinuation = messageContinuation
        messageContinuation.onTermination = { _ in
            print("[MQTT] Message stream terminated")
        }
    }

    public func connect(ip: String, accessCode: String) {
        disconnect()

        print("[MQTT] Connecting to \(ip):8883...")

        let clientId = "BambuBeFree_\(Int(Date().timeIntervalSince1970))"
        let client = CocoaMQTT(clientID: clientId, host: ip, port: 8883)
        client.username = "bblp"
        client.password = accessCode
        client.enableSSL = true
        client.allowUntrustCACertificate = true
        client.keepAlive = 60

        // Disable hostname verification — the printer's self-signed cert CN
        // is the serial number, not the IP address
        client.sslSettings = [
            kCFStreamSSLPeerName as String: "" as NSString,
        ]

        client.delegate = delegateHandler

        // Accept the printer's self-signed certificate (signed by "BBL CA")
        client.didReceiveTrust = { _, _, completionHandler in
            print("[MQTT] Trust evaluation — accepting self-signed certificate")
            completionHandler(true)
        }

        delegateHandler.onConnected = { [weak self] mqtt in
            print("[MQTT] Connected! Subscribing to device/+/report")
            self?.connectionState = .connected
            self?.stateContinuation?.yield(.connected)
            // Subscribe to all device reports to auto-discover serial number
            mqtt.subscribe("device/+/report")
            // If we already know the serial, request full state immediately
            if let serial = self?.serialNumber, !serial.isEmpty {
                print("[MQTT] Known serial: \(serial), sending pushAll")
                self?.publishTopic = "device/\(serial)/request"
                self?.sendCommand(.pushAll)
            }
        }

        delegateHandler.onDisconnected = { [weak self] in
            print("[MQTT] Disconnected")
            self?.connectionState = .disconnected
            self?.stateContinuation?.yield(.disconnected)
        }

        delegateHandler.onError = { [weak self] message in
            print("[MQTT] Error: \(message)")
            self?.connectionState = .error(message)
            self?.stateContinuation?.yield(.error(message))
        }

        delegateHandler.onMessage = { [weak self] topic, data in
            print("[MQTT] Message on topic: \(topic) (\(data.count) bytes)")
            // Auto-discover serial number from topic: device/{SERIAL}/report
            if self?.serialNumber == nil {
                let parts = topic.split(separator: "/")
                if parts.count == 3, parts[0] == "device", parts[2] == "report" {
                    let serial = String(parts[1])
                    print("[MQTT] Discovered serial: \(serial)")
                    self?.serialNumber = serial
                    self?.publishTopic = "device/\(serial)/request"
                    // Now that we have serial, request full state and version info
                    self?.sendCommand(.pushAll)
                    self?.sendCommand(.getVersion)
                }
            }

            if let payload = BambuMQTTPayload.parse(from: data) {
                print("[MQTT] Parsed payload — state: \(payload.gcodeState ?? "nil"), progress: \(payload.mcPercent ?? -1)%")
                self?.messageContinuation?.yield(payload)
            } else {
                print("[MQTT] Failed to parse payload")
            }
        }

        connectionState = .connecting
        stateContinuation?.yield(.connecting)
        self.mqtt = client
        let result = client.connect()
        print("[MQTT] connect() returned: \(result)")
    }

    public func disconnect() {
        mqtt?.disconnect()
        mqtt?.delegate = nil
        mqtt = nil
        serialNumber = nil
        publishTopic = nil
        connectionState = .disconnected
    }

    public func sendCommand(_ command: PrinterCommand) {
        guard let mqtt, let topic = publishTopic else { return }
        let data = command.payload()
        guard let jsonString = String(data: data, encoding: .utf8) else { return }
        print("[MQTT] Publishing to \(topic): \(jsonString.prefix(100))...")
        mqtt.publish(topic, withString: jsonString, qos: .qos1)
    }
}

// MARK: - Delegate Handler

/// Bridges CocoaMQTT delegate callbacks to closures.
private class DelegateHandler: CocoaMQTTDelegate {
    var onConnected: ((CocoaMQTT) -> Void)?
    var onDisconnected: (() -> Void)?
    var onError: ((String) -> Void)?
    var onMessage: ((String, Data) -> Void)?

    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        print("[MQTT] didConnectAck: \(ack)")
        if ack == .accept {
            onConnected?(mqtt)
        } else {
            let message = switch ack {
            case .badUsernameOrPassword: "Invalid access code"
            case .notAuthorized: "Not authorized"
            default: "Connection rejected: \(ack)"
            }
            onError?(message)
        }
    }

    func mqtt(_: CocoaMQTT, didPublishMessage _: CocoaMQTTMessage, id _: UInt16) {}
    func mqtt(_: CocoaMQTT, didPublishAck _: UInt16) {}

    func mqtt(_: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id _: UInt16) {
        guard let data = message.string?.data(using: .utf8) else { return }
        onMessage?(message.topic, data)
    }

    func mqtt(_: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {
        print("[MQTT] Subscribed — success: \(success), failed: \(failed)")
    }

    func mqtt(_: CocoaMQTT, didUnsubscribeTopics _: [String]) {}

    func mqttDidPing(_: CocoaMQTT) {}
    func mqttDidReceivePong(_: CocoaMQTT) {}

    func mqttDidDisconnect(_: CocoaMQTT, withError err: (any Error)?) {
        print("[MQTT] mqttDidDisconnect, error: \(err?.localizedDescription ?? "none")")
        if let err {
            let message = err.localizedDescription
            onError?(message)
        } else {
            onDisconnected?()
        }
    }
}
