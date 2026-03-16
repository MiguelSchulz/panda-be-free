import Foundation
import Network
import PandaLogger

/// Uploads files to Bambu Lab printers via implicit FTPS (port 990).
///
/// Uses `NWConnection` with TLS to implement the FTP command sequence
/// over an encrypted channel. Self-signed Bambu certificates are accepted.
public actor FTPSUploader {
    private static let ftpsPort: UInt16 = 990
    private static let username = "bblp"
    private static let commandTimeout: Duration = .seconds(30)
    private static let transferTimeout: Duration = .seconds(120)

    /// Read buffer for the control connection — TCP can deliver multiple
    /// FTP replies in a single read, so we buffer between calls.
    private var controlBuffer = ""

    public init() {}

    /// Upload file data to the printer's `/cache/` directory.
    @discardableResult
    public func upload(
        fileData: Data,
        filename: String,
        printerIP: String,
        accessCode: String,
        onProgress: (@MainActor (Double) -> Void)? = nil
    ) async throws -> String {
        let remotePath = "/cache/\(filename)"
        controlBuffer = ""

        SessionLogger.shared.log(.info, category: "FTPS", "Connecting to \(printerIP):\(Self.ftpsPort)")

        // Control connection
        let control = try await withTimeout(Self.commandTimeout) {
            try await self.connectTLS(host: printerIP, port: Self.ftpsPort)
        }
        defer { control.cancel() }

        _ = try await readResponse(control, timeout: Self.commandTimeout)

        // Login
        try await sendCommand(control, "USER \(Self.username)")
        try await expectReply(control, prefix: "331", or: "USER rejected")

        try await sendCommand(control, "PASS \(accessCode)")
        try await expectReply(control, prefix: "230", or: "PASS rejected")

        // Data channel protection (required by Bambu printers)
        try await sendCommand(control, "PBSZ 0")
        try await expectReply(control, prefix: "200", or: "PBSZ failed")

        try await sendCommand(control, "PROT P")
        try await expectReply(control, prefix: "200", or: "PROT P failed")

        // Create /cache directory (550 = already exists)
        try await sendCommand(control, "MKD /cache")
        let mkdResp = try await readResponse(control, timeout: Self.commandTimeout)
        if !mkdResp.hasPrefix("257"), !mkdResp.hasPrefix("550") {
            throw FTPSError.commandFailed("MKD", mkdResp)
        }

        // Binary mode
        try await sendCommand(control, "TYPE I")
        try await expectReply(control, prefix: "200", or: "TYPE I failed")

        // Passive mode
        try await sendCommand(control, "PASV")
        let pasvResp = try await readResponse(control, timeout: Self.commandTimeout)
        guard pasvResp.hasPrefix("227") else {
            throw FTPSError.commandFailed("PASV", pasvResp)
        }
        let (dataHost, dataPort) = try parsePASV(pasvResp, fallbackHost: printerIP)

        // Data connection
        let dataConn = try await withTimeout(Self.commandTimeout) {
            try await self.connectTLS(host: dataHost, port: dataPort)
        }

        // STOR
        try await sendCommand(control, "STOR \(remotePath)")
        let storResp = try await readResponse(control, timeout: Self.commandTimeout)
        guard storResp.hasPrefix("150") || storResp.hasPrefix("125") else {
            dataConn.cancel()
            throw FTPSError.commandFailed("STOR", storResp)
        }

        // Upload file data
        SessionLogger.shared.log(.info, category: "FTPS", "Uploading \(fileData.count) bytes to \(remotePath)")
        try await sendData(dataConn, fileData, onProgress: onProgress)

        // Close data connection to signal end of transfer (don't use TLS close_notify —
        // Bambu printers don't respond to it, causing a hang)
        dataConn.cancel()

        // Wait for transfer complete
        let transferResp = try await readResponse(control, timeout: Self.transferTimeout)
        guard transferResp.hasPrefix("226") else {
            throw FTPSError.transferFailed(transferResp)
        }

        try? await sendCommand(control, "QUIT")
        SessionLogger.shared.log(.info, category: "FTPS", "Upload complete: \(remotePath)")

        return remotePath
    }

    // MARK: - FTP Helpers

    /// Send a command and verify the response starts with the expected prefix.
    private func expectReply(
        _ connection: NWConnection,
        prefix: String,
        or errorMessage: String
    ) async throws {
        let resp = try await readResponse(connection, timeout: Self.commandTimeout)
        guard resp.hasPrefix(prefix) else {
            throw FTPSError.commandFailed(errorMessage, resp)
        }
    }

    // MARK: - NWConnection

    private func connectTLS(host: String, port: UInt16) async throws -> NWConnection {
        let tlsOptions = NWProtocolTLS.Options()
        let secOptions = tlsOptions.securityProtocolOptions

        sec_protocol_options_set_min_tls_protocol_version(secOptions, .TLSv12)
        sec_protocol_options_set_max_tls_protocol_version(secOptions, .TLSv13)

        // Accept self-signed Bambu certificates
        sec_protocol_options_set_verify_block(secOptions, { _, _, completionHandler in
            completionHandler(true)
        }, DispatchQueue.global())

        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.connectionTimeout = 15

        let params = NWParameters(tls: tlsOptions, tcp: tcpOptions)
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!,
            using: params
        )

        return try await withCheckedThrowingContinuation { continuation in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.stateUpdateHandler = nil
                    continuation.resume(returning: connection)
                case let .failed(error):
                    connection.stateUpdateHandler = nil
                    continuation.resume(throwing: FTPSError.connectionFailed(error.localizedDescription))
                case .cancelled:
                    connection.stateUpdateHandler = nil
                    continuation.resume(throwing: FTPSError.connectionFailed("Connection cancelled"))
                case let .waiting(error):
                    SessionLogger.shared.log(.warning, category: "FTPS", "Connection waiting: \(error.localizedDescription)")
                default:
                    break
                }
            }
            connection.start(queue: DispatchQueue.global())
        }
    }

    private func sendCommand(_ connection: NWConnection, _ command: String) async throws {
        let data = Data((command + "\r\n").utf8)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: FTPSError.sendFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    /// Read exactly one complete FTP reply from the control connection.
    private func readResponse(_ connection: NWConnection, timeout: Duration) async throws -> String {
        try await withTimeout(timeout) {
            while true {
                if let reply = await self.extractFirstReply() {
                    return reply
                }

                let chunk: String = try await withCheckedThrowingContinuation { continuation in
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, error in
                        if let error {
                            continuation.resume(throwing: FTPSError.receiveFailed(error.localizedDescription))
                        } else if let data, let text = String(data: data, encoding: .utf8) {
                            continuation.resume(returning: text)
                        } else {
                            continuation.resume(throwing: FTPSError.receiveFailed("No data received"))
                        }
                    }
                }
                await self.appendToControlBuffer(chunk)
            }
        }
    }

    private func appendToControlBuffer(_ text: String) {
        controlBuffer += text
    }

    /// Extract the first complete FTP reply from the buffer.
    ///
    /// Uses UTF-8 bytes directly because Swift treats `\r\n` as a single
    /// Character (grapheme cluster), which breaks character-level offset math.
    private func extractFirstReply() -> String? {
        let utf8 = controlBuffer.utf8
        let cr = UInt8(ascii: "\r")
        let lf = UInt8(ascii: "\n")
        let space = UInt8(ascii: " ")

        var lineStart = utf8.startIndex
        while lineStart < utf8.endIndex {
            guard let crIndex = utf8[lineStart...].firstIndex(of: cr),
                  utf8.index(after: crIndex) < utf8.endIndex,
                  utf8[utf8.index(after: crIndex)] == lf
            else {
                return nil
            }

            let lineEnd = utf8.index(crIndex, offsetBy: 2)
            let lineBytes = utf8[lineStart..<crIndex]

            // Final reply line: "NNN " (3 digits + space)
            if lineBytes.count >= 4,
               lineBytes.prefix(3).allSatisfy({ $0 >= 0x30 && $0 <= 0x39 }),
               lineBytes[lineBytes.index(lineBytes.startIndex, offsetBy: 3)] == space
            {
                let replyEnd = String.Index(lineEnd, within: controlBuffer) ?? controlBuffer.endIndex
                let reply = String(controlBuffer[controlBuffer.startIndex..<replyEnd])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                controlBuffer = String(controlBuffer[replyEnd...])
                return reply
            }

            lineStart = lineEnd
        }

        return nil
    }

    /// Send file data in chunks. All chunks use `.defaultMessage` — the Bambu printer's
    /// FTPS server doesn't respond to TLS close_notify, so we signal end-of-transfer
    /// by cancelling the connection instead of using `.finalMessage`.
    private func sendData(
        _ connection: NWConnection,
        _ data: Data,
        onProgress: (@MainActor (Double) -> Void)? = nil
    ) async throws {
        let chunkSize = 32768
        var offset = 0
        let total = data.count

        while offset < total {
            let end = min(offset + chunkSize, total)
            let chunk = data[offset..<end]

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                connection.send(
                    content: chunk,
                    contentContext: .defaultMessage,
                    isComplete: false,
                    completion: .contentProcessed { error in
                        if let error {
                            continuation.resume(throwing: FTPSError.sendFailed(error.localizedDescription))
                        } else {
                            continuation.resume()
                        }
                    }
                )
            }
            offset = end

            if let onProgress {
                let fraction = Double(offset) / Double(total)
                await onProgress(fraction)
            }
        }
    }

    private func parsePASV(_ response: String, fallbackHost: String) throws -> (String, UInt16) {
        guard let openParen = response.firstIndex(of: "("),
              let closeParen = response.firstIndex(of: ")")
        else {
            throw FTPSError.commandFailed("PASV", "Could not parse: \(response)")
        }

        let inner = response[response.index(after: openParen)..<closeParen]
        let parts = inner.split(separator: ",").compactMap { UInt16($0) }
        guard parts.count == 6 else {
            throw FTPSError.commandFailed("PASV", "Unexpected PASV format: \(response)")
        }

        let port = parts[4] * 256 + parts[5]
        return (fallbackHost, port)
    }

    // MARK: - Timeout

    /// Race an operation against a deadline. Uses unstructured concurrency because
    /// `withThrowingTaskGroup` waits for ALL child tasks — a stuck NWConnection
    /// callback would prevent the timeout from taking effect.
    private nonisolated func withTimeout<T: Sendable>(
        _ duration: Duration,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        let gate = TimeoutGate()

        return try await withCheckedThrowingContinuation { continuation in
            let operationTask = Task {
                do {
                    let result = try await operation()
                    if gate.claim() { continuation.resume(returning: result) }
                } catch {
                    if gate.claim() { continuation.resume(throwing: error) }
                }
            }

            Task {
                try? await Task.sleep(for: duration)
                if gate.claim() {
                    operationTask.cancel()
                    continuation.resume(throwing: FTPSError.timeout)
                }
            }
        }
    }
}

public enum FTPSError: LocalizedError {
    case connectionFailed(String)
    case loginFailed(String)
    case commandFailed(String, String)
    case transferFailed(String)
    case sendFailed(String)
    case receiveFailed(String)
    case timeout

    public var errorDescription: String? {
        switch self {
        case let .connectionFailed(detail):
            "FTPS connection failed: \(detail)"
        case let .loginFailed(detail):
            "FTPS login failed: \(detail)"
        case let .commandFailed(cmd, detail):
            "FTPS command \(cmd) failed: \(detail)"
        case let .transferFailed(detail):
            "File transfer failed: \(detail)"
        case let .sendFailed(detail):
            "FTPS send error: \(detail)"
        case let .receiveFailed(detail):
            "FTPS receive error: \(detail)"
        case .timeout:
            "FTPS operation timed out"
        }
    }
}

/// Thread-safe one-shot gate for timeout races.
private final class TimeoutGate: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if claimed { return false }
        claimed = true
        return true
    }
}
