import Foundation

public enum MQTTConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case error(String)
}
