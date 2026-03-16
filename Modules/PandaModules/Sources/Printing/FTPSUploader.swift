import Foundation
import Network

/// Uploads files to Bambu Lab printers via implicit FTPS (port 990).
///
/// Uses `NWConnection` with TLS to implement the FTP command sequence
/// over an encrypted channel. Self-signed Bambu certificates are accepted.
public actor FTPSUploader {
    private static let ftpsPort: UInt16 = 990
    private static let username = "bblp"
    /// Timeout for connecting and individual FTP command responses.
    private static let commandTimeout: Duration = .seconds(30)
    /// Timeout for the file transfer completion response (226).
    private static let transferTimeout: Duration = .seconds(120)

    /// Persistent read buffer for the control connection. TCP can deliver
    /// multiple FTP replies in a single read (e.g. `150 ...\r\n226 ...\r\n`),
    /// so we buffer unread data between `readResponse` calls.
    private var controlBuffer = ""

    public init() {}

    /// Upload file data to the printer's `/cache/` directory.
    ///
    /// - Parameters:
    ///   - fileData: The file contents to upload.
    ///   - filename: The destination filename (e.g. `model.3mf`).
    ///   - printerIP: The printer's local IP address.
    ///   - accessCode: The printer's access code (used as FTP password).
    /// - Returns: The remote path of the uploaded file.
    @discardableResult
    public func upload(
        fileData: Data,
        filename: String,
        printerIP: String,
        accessCode: String
    ) async throws -> String {
        let remotePath = "/cache/\(filename)"
        controlBuffer = ""

        // Control connection
        let control = try await withTimeout(Self.commandTimeout) {
            try await self.connectTLS(host: printerIP, port: Self.ftpsPort)
        }
        defer { control.cancel() }

        // Read welcome banner
        _ = try await readResponse(control, timeout: Self.commandTimeout)

        // Login
        try await sendCommand(control, "USER \(Self.username)")
        let userResp = try await readResponse(control, timeout: Self.commandTimeout)
        guard userResp.hasPrefix("331") else {
            throw FTPSError.loginFailed("USER rejected: \(userResp)")
        }

        try await sendCommand(control, "PASS \(accessCode)")
        let passResp = try await readResponse(control, timeout: Self.commandTimeout)
        guard passResp.hasPrefix("230") else {
            throw FTPSError.loginFailed("PASS rejected: \(passResp)")
        }

        // Enable data channel protection (required by Bambu printers)
        try await sendCommand(control, "PBSZ 0")
        let pbszResp = try await readResponse(control, timeout: Self.commandTimeout)
        guard pbszResp.hasPrefix("200") else {
            throw FTPSError.commandFailed("PBSZ", pbszResp)
        }

        try await sendCommand(control, "PROT P")
        let protResp = try await readResponse(control, timeout: Self.commandTimeout)
        guard protResp.hasPrefix("200") else {
            throw FTPSError.commandFailed("PROT P", protResp)
        }

        // Create /cache directory (ignore 550 = already exists)
        try await sendCommand(control, "MKD /cache")
        let mkdResp = try await readResponse(control, timeout: Self.commandTimeout)
        if !mkdResp.hasPrefix("257"), !mkdResp.hasPrefix("550") {
            throw FTPSError.commandFailed("MKD", mkdResp)
        }

        // Binary mode
        try await sendCommand(control, "TYPE I")
        let typeResp = try await readResponse(control, timeout: Self.commandTimeout)
        guard typeResp.hasPrefix("200") else {
            throw FTPSError.commandFailed("TYPE I", typeResp)
        }

        // Passive mode — get data channel address
        try await sendCommand(control, "PASV")
        let pasvResp = try await readResponse(control, timeout: Self.commandTimeout)
        guard pasvResp.hasPrefix("227") else {
            throw FTPSError.commandFailed("PASV", pasvResp)
        }
        let (dataHost, dataPort) = try parsePASV(pasvResp, fallbackHost: printerIP)

        // Open data connection with TLS
        let dataConn = try await withTimeout(Self.commandTimeout) {
            try await self.connectTLS(host: dataHost, port: dataPort)
        }

        // STOR command
        try await sendCommand(control, "STOR \(remotePath)")
        let storResp = try await readResponse(control, timeout: Self.commandTimeout)
        guard storResp.hasPrefix("150") || storResp.hasPrefix("125") else {
            dataConn.cancel()
            throw FTPSError.commandFailed("STOR", storResp)
        }

        // Send file data in chunks
        try await sendData(dataConn, fileData)

        // Close data connection to signal end of transfer
        dataConn.cancel()

        // Wait for transfer complete (longer timeout — depends on file size)
        let transferResp = try await readResponse(control, timeout: Self.transferTimeout)
        guard transferResp.hasPrefix("226") else {
            throw FTPSError.transferFailed(transferResp)
        }

        // Quit
        try? await sendCommand(control, "QUIT")

        return remotePath
    }

    // MARK: - NWConnection helpers

    private func connectTLS(host: String, port: UInt16) async throws -> NWConnection {
        let tlsOptions = NWProtocolTLS.Options()

        // Accept self-signed Bambu certificates
        sec_protocol_options_set_verify_block(
            tlsOptions.securityProtocolOptions,
            { _, _, completionHandler in
                completionHandler(true)
            },
            DispatchQueue.global()
        )

        let params = NWParameters(tls: tlsOptions, tcp: .init())
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

    /// Read exactly one complete FTP response from the control connection.
    ///
    /// Uses `controlBuffer` to handle the case where TCP delivers multiple
    /// FTP replies in a single read. Returns only the first complete reply
    /// and leaves any remainder in the buffer for the next call.
    private func readResponse(_ connection: NWConnection, timeout: Duration) async throws -> String {
        try await withTimeout(timeout) {
            while true {
                // Check if we already have a complete reply in the buffer
                if let reply = await self.extractFirstReply() {
                    return reply
                }

                // Need more data from the network
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

    /// Try to extract the first complete FTP reply from `controlBuffer`.
    ///
    /// A complete reply ends with `\r\n` and the final line starts with
    /// 3 digits followed by a space (e.g. `230 Login successful\r\n`).
    /// Multi-line replies use `NNN-` for continuation and `NNN ` for the last line.
    /// Returns the reply text (trimmed) and removes it from the buffer, or nil
    /// if no complete reply is available yet.
    private func extractFirstReply() -> String? {
        let lines = controlBuffer.split(separator: "\r\n", omittingEmptySubsequences: false)

        // Walk lines looking for a final reply line (NNN<space>)
        var endIndex = controlBuffer.startIndex
        for line in lines {
            guard !line.isEmpty else {
                // Skip empty segments (from leading/trailing \r\n)
                endIndex = controlBuffer.index(endIndex, offsetBy: line.count + 2, limitedBy: controlBuffer.endIndex) ?? controlBuffer.endIndex
                continue
            }

            // Advance past this line + \r\n
            let lineEndCandidate = controlBuffer.index(endIndex, offsetBy: line.count + 2, limitedBy: controlBuffer.endIndex)
            guard let lineEnd = lineEndCandidate else {
                // Line isn't fully terminated by \r\n yet — need more data
                return nil
            }

            // Check if this is a final reply line: "NNN " pattern
            if line.count >= 4,
               line.prefix(3).allSatisfy(\.isNumber),
               line[line.index(line.startIndex, offsetBy: 3)] == " "
            {
                let reply = String(controlBuffer[controlBuffer.startIndex..<lineEnd])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                controlBuffer = String(controlBuffer[lineEnd...])
                return reply
            }

            endIndex = lineEnd
        }

        return nil
    }

    private func sendData(_ connection: NWConnection, _ data: Data) async throws {
        let chunkSize = 32768 // 32KB chunks
        var offset = 0

        while offset < data.count {
            let end = min(offset + chunkSize, data.count)
            let chunk = data[offset..<end]
            let isComplete = end == data.count

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                connection.send(
                    content: chunk,
                    contentContext: isComplete ? .finalMessage : .defaultMessage,
                    isComplete: isComplete,
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
        }
    }

    /// Parse PASV response like `227 Entering Passive Mode (192,168,1,1,4,1)` into host:port.
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

        // Use fallback host (the printer IP) — the PASV-reported IP may be unreachable
        let port = parts[4] * 256 + parts[5]
        return (fallbackHost, port)
    }

    // MARK: - Timeout helper

    private func withTimeout<T: Sendable>(
        _ duration: Duration,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(for: duration)
                throw FTPSError.timeout
            }
            guard let result = try await group.next() else {
                throw FTPSError.timeout
            }
            group.cancelAll()
            return result
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
