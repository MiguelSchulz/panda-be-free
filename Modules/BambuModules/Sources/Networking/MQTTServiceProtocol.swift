import BambuModels
import Foundation

public protocol MQTTServiceProtocol: AnyObject, Sendable {
    var connectionState: MQTTConnectionState { get }
    var stateStream: AsyncStream<MQTTConnectionState> { get }
    var messageStream: AsyncStream<BambuMQTTPayload> { get }

    func connect(ip: String, accessCode: String)
    func disconnect()
    func sendCommand(_ command: PrinterCommand)
}
