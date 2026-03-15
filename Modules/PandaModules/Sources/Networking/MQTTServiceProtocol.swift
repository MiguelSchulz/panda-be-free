import Foundation
import PandaModels

/// MQTT service abstraction for printer communication.
/// - Note: `stateStream` and `messageStream` are single-consumer `AsyncStream`s.
///   Only one `for await` loop should read from each stream at a time.
public protocol MQTTServiceProtocol: AnyObject, Sendable {
    var connectionState: MQTTConnectionState { get }
    var stateStream: AsyncStream<MQTTConnectionState> { get }
    var messageStream: AsyncStream<PandaMQTTPayload> { get }

    func connect(ip: String, accessCode: String, serial: String)
    func disconnect()
    func sendCommand(_ command: PrinterCommand)
}
