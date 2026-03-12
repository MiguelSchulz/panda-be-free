import BambuModels
import BambuUI
import CoreMedia
import CryptoKit
import Foundation
import Network
import os
import UIKit
import VideoToolbox

enum CameraConnectionState: Equatable {
    case disconnected
    case connecting
    case streaming
    case error(String)
}

@MainActor
@Observable
final class CameraStreamManager: CameraStreamProviding {
    var isStreaming: Bool {
        connectionState == .streaming
    }

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.bambubefree.app", category: "CameraStream")

    var connectionState: CameraConnectionState = .disconnected
    var currentFrame: UIImage?

    private var connection: NWConnection?
    // nonisolated(unsafe) allows cancellation from deinit; Task.cancel() is thread-safe.
    // swiftformat:disable:next nonisolatedUnsafe
    @ObservationIgnored nonisolated(unsafe) private var streamTask: Task<Void, Never>?
    private var decompressionSession: VTDecompressionSession?
    private var formatDescription: CMVideoFormatDescription?
    private var spsData: Data?
    private var ppsData: Data?

    func connect(ip: String, accessCode: String, printerType: PrinterType = .auto) {
        disconnect()
        connectionState = .connecting

        switch printerType {
        case .tcp:
            connectTCP(ip: ip, accessCode: accessCode)
        case .rtsp:
            connectRTSP(ip: ip, accessCode: accessCode)
        case .auto:
            // Try TCP/6000 first, fall back to RTSP/322
            connectWithAutoDetect(ip: ip, accessCode: accessCode)
        }
    }

    deinit {
        streamTask?.cancel()
    }

    func disconnect() {
        streamTask?.cancel()
        streamTask = nil
        connection?.cancel()
        connection = nil
        if let session = decompressionSession {
            VTDecompressionSessionInvalidate(session)
            decompressionSession = nil
        }
        formatDescription = nil
        spsData = nil
        ppsData = nil
        connectionState = .disconnected
        currentFrame = nil
    }

    // MARK: - Auto-Detect

    private func connectWithAutoDetect(ip: String, accessCode: String) {
        streamTask = Task { [weak self] in
            guard let self else { return }

            // Try TCP/6000 with a short timeout
            let tcpConnection = await self.tryTLSConnect(host: ip, port: 6000, timeout: 3)
            if let conn = tcpConnection {
                self.connection = conn
                await self.performTCPStreaming(ip: ip, accessCode: accessCode, connection: conn)
                return
            }

            // Fall back to RTSP/322
            self.logger.info("TCP/6000 unavailable, falling back to RTSP/322")
            self.connectRTSP(ip: ip, accessCode: accessCode)
        }
    }

    private func tryTLSConnect(host: String, port: UInt16, timeout: TimeInterval) async -> NWConnection? {
        let tlsOptions = NWProtocolTLS.Options()
        sec_protocol_options_set_verify_block(
            tlsOptions.securityProtocolOptions,
            { _, _, completionHandler in completionHandler(true) },
            DispatchQueue.global()
        )

        let params = NWParameters(tls: tlsOptions, tcp: NWProtocolTCP.Options())
        let conn = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: port),
            using: params
        )

        return await withCheckedContinuation { cont in
            let resumed = OSAllocatedUnfairLock(initialState: false)
            conn.stateUpdateHandler = { state in
                let shouldHandle = resumed.withLock { r -> Bool in
                    guard !r else { return false }
                    r = true
                    return true
                }
                guard shouldHandle else { return }
                switch state {
                case .ready:
                    cont.resume(returning: conn)
                case .failed, .waiting:
                    conn.cancel()
                    cont.resume(returning: nil)
                default:
                    resumed.withLock { $0 = false }
                }
            }
            conn.start(queue: DispatchQueue.global())

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                let shouldHandle = resumed.withLock { r -> Bool in
                    guard !r else { return false }
                    r = true
                    return true
                }
                guard shouldHandle else { return }
                conn.cancel()
                cont.resume(returning: nil)
            }
        }
    }

    // MARK: - TCP/6000 Streaming (A1/P1)

    private func connectTCP(ip: String, accessCode: String) {
        let tlsOptions = NWProtocolTLS.Options()
        sec_protocol_options_set_verify_block(
            tlsOptions.securityProtocolOptions,
            { _, _, completionHandler in completionHandler(true) },
            .main
        )

        let params = NWParameters(tls: tlsOptions, tcp: NWProtocolTCP.Options())
        let conn = NWConnection(
            host: NWEndpoint.Host(ip),
            port: NWEndpoint.Port(integerLiteral: 6000),
            using: params
        )
        self.connection = conn

        conn.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.handleTCPConnectionState(state, ip: ip, accessCode: accessCode)
            }
        }

        conn.start(queue: .main)
    }

    private func handleTCPConnectionState(
        _ state: NWConnection.State,
        ip: String,
        accessCode: String
    ) {
        switch state {
        case .ready:
            logger.info("TLS connection established to \(ip):6000")
            let conn = self.connection!
            streamTask = Task { [weak self] in
                await self?.performTCPStreaming(ip: ip, accessCode: accessCode, connection: conn)
            }
        case let .failed(error):
            logger.error("TCP connection failed: \(error.localizedDescription)")
            connectionState = .error(String(localized: "Connection failed: \(error.localizedDescription)"))
        case .waiting:
            connectionState = .error(String(localized: "Printer unreachable. Check IP address and that printer is on."))
        default:
            break
        }
    }

    private nonisolated func performTCPStreaming(ip _: String, accessCode: String, connection: NWConnection) async {
        // Build 80-byte auth packet
        var authPacket = Data(count: 80)
        authPacket[0] = 0x40; authPacket[1] = 0x00; authPacket[2] = 0x00; authPacket[3] = 0x00
        authPacket[4] = 0x00; authPacket[5] = 0x30; authPacket[6] = 0x00; authPacket[7] = 0x00
        let usernameBytes = Array("bblp".utf8)
        for (i, byte) in usernameBytes.enumerated() {
            authPacket[16 + i] = byte
        }
        let passwordBytes = Array(accessCode.utf8)
        for (i, byte) in passwordBytes.prefix(32).enumerated() {
            authPacket[48 + i] = byte
        }

        do {
            // Send auth
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                connection.send(content: authPacket, completion: .contentProcessed { error in
                    if let error { cont.resume(throwing: error) }
                    else { cont.resume() }
                })
            }

            // Continuous JPEG frame loop
            while !Task.isCancelled {
                // Read 16-byte frame header
                let header = try await receiveExactly(connection: connection, length: 16)
                let jpegLength = Int(header[0]) | (Int(header[1]) << 8)
                    | (Int(header[2]) << 16) | (Int(header[3]) << 24)

                guard jpegLength > 0, jpegLength < 10_000_000 else {
                    await MainActor.run {
                        self.connectionState = .error(String(localized: "Authentication failed. Check your access code."))
                    }
                    return
                }

                // Read JPEG payload
                let jpegData = try await receiveExactly(connection: connection, length: jpegLength)

                guard jpegData.count >= 2, jpegData[0] == 0xFF, jpegData[1] == 0xD8,
                      let image = UIImage(data: jpegData)
                else { continue }

                await MainActor.run {
                    if self.connectionState != .streaming {
                        self.connectionState = .streaming
                    }
                    self.currentFrame = image
                }
            }
        } catch {
            if !Task.isCancelled {
                await MainActor.run {
                    self.logger.error("TCP stream error: \(error.localizedDescription)")
                    self.connectionState = .error(String(localized: "Stream error: \(error.localizedDescription)"))
                }
            }
        }
    }

    private nonisolated func receiveExactly(connection: NWConnection, length: Int) async throws -> Data {
        var buffer = Data()
        while buffer.count < length {
            let chunk: Data = try await withCheckedThrowingContinuation { cont in
                connection.receive(
                    minimumIncompleteLength: 1,
                    maximumLength: min(65536, length - buffer.count)
                ) { data, _, _, error in
                    if let error { cont.resume(throwing: error) }
                    else if let data, !data.isEmpty { cont.resume(returning: data) }
                    else { cont.resume(throwing: NWError.posix(.ECONNRESET)) }
                }
            }
            buffer.append(chunk)
        }
        return buffer
    }

    // MARK: - RTSP/322 Connection (X1/P2S)

    private func connectRTSP(ip: String, accessCode: String) {
        let tlsOptions = NWProtocolTLS.Options()
        sec_protocol_options_set_verify_block(
            tlsOptions.securityProtocolOptions,
            { _, _, completionHandler in completionHandler(true) },
            .main
        )

        let params = NWParameters(tls: tlsOptions, tcp: NWProtocolTCP.Options())
        let conn = NWConnection(
            host: NWEndpoint.Host(ip),
            port: NWEndpoint.Port(integerLiteral: 322),
            using: params
        )
        self.connection = conn

        conn.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.handleRTSPConnectionState(state, ip: ip, accessCode: accessCode)
            }
        }

        conn.start(queue: .main)
    }

    private func handleRTSPConnectionState(
        _ state: NWConnection.State,
        ip: String,
        accessCode: String
    ) {
        switch state {
        case .ready:
            logger.info("TLS connection established to \(ip):322")
            let conn = self.connection!
            streamTask = Task { [weak self] in
                await self?.performRTSPStreaming(ip: ip, accessCode: accessCode, connection: conn)
            }
        case let .failed(error):
            logger.error("Connection failed: \(error.localizedDescription)")
            connectionState = .error(String(localized: "Connection failed: \(error.localizedDescription)"))
        case .waiting:
            connectionState = .error(String(localized: "Printer unreachable. Check IP address and that printer is on."))
        default:
            break
        }
    }

    // MARK: - H.264 Decoder Setup

    private func configureDecoder(sps: Data, pps: Data) {
        guard sps != spsData || pps != ppsData else { return }
        spsData = sps
        ppsData = pps

        if let old = decompressionSession {
            VTDecompressionSessionInvalidate(old)
            decompressionSession = nil
        }
        formatDescription = nil

        var desc: CMVideoFormatDescription?
        let status = sps.withUnsafeBytes { spsPtr in
            pps.withUnsafeBytes { ppsPtr in
                var paramSets: [UnsafePointer<UInt8>] = [
                    spsPtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    ppsPtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                ]
                var sizes = [sps.count, pps.count]
                return CMVideoFormatDescriptionCreateFromH264ParameterSets(
                    allocator: nil,
                    parameterSetCount: 2,
                    parameterSetPointers: &paramSets,
                    parameterSetSizes: &sizes,
                    nalUnitHeaderLength: 4,
                    formatDescriptionOut: &desc
                )
            }
        }

        guard status == noErr, let desc else {
            logger.error("Failed to create format description: \(status)")
            return
        }
        formatDescription = desc

        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ]

        var session: VTDecompressionSession?
        let sessionStatus = VTDecompressionSessionCreate(
            allocator: nil,
            formatDescription: desc,
            decoderSpecification: nil,
            imageBufferAttributes: attrs as CFDictionary,
            outputCallback: nil,
            decompressionSessionOut: &session
        )

        guard sessionStatus == noErr, let session else {
            logger.error("Failed to create decompression session: \(sessionStatus)")
            return
        }
        decompressionSession = session
        logger.info("H.264 decoder session created")
    }

    private func decodeNALUnit(_ nalData: Data) {
        guard let session = decompressionSession, let fmtDesc = formatDescription else { return }
        guard !nalData.isEmpty else { return }

        let nalType = nalData[nalData.startIndex] & 0x1F

        // Handle SPS/PPS in-band
        if nalType == 7 {
            let newSPS = nalData
            logger.debug("Got SPS in-band (\(newSPS.count) bytes)")
            if let pps = ppsData { configureDecoder(sps: newSPS, pps: pps) }
            return
        }
        if nalType == 8 {
            let newPPS = nalData
            logger.debug("Got PPS in-band (\(newPPS.count) bytes)")
            if let sps = spsData { configureDecoder(sps: sps, pps: newPPS) }
            return
        }

        // Only decode slice NALs (1 = non-IDR, 5 = IDR)
        guard nalType == 1 || nalType == 5 else { return }

        // Wrap NAL in AVCC format (4-byte big-endian length prefix)
        let nalLength = UInt32(nalData.count)
        var lengthBE = nalLength.bigEndian
        let avccCount = 4 + nalData.count

        // Create block buffer with owned memory
        var blockBuffer: CMBlockBuffer?
        guard CMBlockBufferCreateWithMemoryBlock(
            allocator: nil,
            memoryBlock: nil,
            blockLength: avccCount,
            blockAllocator: nil,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: avccCount,
            flags: kCMBlockBufferAssureMemoryNowFlag,
            blockBufferOut: &blockBuffer
        ) == noErr, let blockBuffer else { return }

        // Copy length prefix + NAL data into block buffer
        _ = withUnsafeBytes(of: &lengthBE) { ptr in
            CMBlockBufferReplaceDataBytes(
                with: ptr.baseAddress!, blockBuffer: blockBuffer,
                offsetIntoDestination: 0, dataLength: 4
            )
        }
        _ = nalData.withUnsafeBytes { ptr in
            CMBlockBufferReplaceDataBytes(
                with: ptr.baseAddress!, blockBuffer: blockBuffer,
                offsetIntoDestination: 4, dataLength: nalData.count
            )
        }

        // Create sample buffer
        var sampleBuffer: CMSampleBuffer?
        var sampleSize = avccCount
        guard CMSampleBufferCreateReady(
            allocator: nil,
            dataBuffer: blockBuffer,
            formatDescription: fmtDesc,
            sampleCount: 1,
            sampleTimingEntryCount: 0,
            sampleTimingArray: nil,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer
        ) == noErr, let sampleBuffer else { return }

        // Decode synchronously; lock satisfies @Sendable requirement on the callback
        let decodedImage = OSAllocatedUnfairLock<UIImage?>(initialState: nil)
        var flagsOut: VTDecodeInfoFlags = []
        VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer: sampleBuffer,
            flags: [],
            infoFlagsOut: &flagsOut
        ) { status, _, imageBuffer, _, _ in
            guard status == noErr, let pixelBuffer = imageBuffer else { return }
            decodedImage.withLock { $0 = pixelBufferToUIImage(pixelBuffer) }
        }

        if let image = decodedImage.withLock({ $0 }) {
            currentFrame = image
        }
    }

    // MARK: - RTSP Streaming

    private func performRTSPStreaming(ip: String, accessCode: String, connection: NWConnection) async {
        var readBuffer = Data()
        var cseq = 0

        let baseURL = "rtsps://\(ip):322/streaming/live/1"
        let username = "bblp"

        // Digest auth state
        var digestRealm = ""
        var digestNonce = ""
        var useDigestAuth = false

        // --- Buffered I/O ---

        func fillBuffer() async throws {
            let chunk: Data = try await withCheckedThrowingContinuation { cont in
                connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, error in
                    if let error { cont.resume(throwing: error) }
                    else if let data, !data.isEmpty { cont.resume(returning: data) }
                    else { cont.resume(throwing: NWError.posix(.ECONNRESET)) }
                }
            }
            readBuffer.append(chunk)
        }

        func readExactly(_ count: Int) async throws -> Data {
            while readBuffer.count < count {
                try await fillBuffer()
            }
            let result = Data(readBuffer.prefix(count))
            readBuffer.removeFirst(count)
            return result
        }

        /// Read RTSP text response, skipping any interleaved $ frames or stray CR/LF
        func readRTSPResponseHeader() async throws -> Data {
            // Skip interleaved data before the RTSP text response
            while true {
                while readBuffer.isEmpty {
                    try await fillBuffer()
                }
                let first = readBuffer[readBuffer.startIndex]
                if first == 0x24 { // '$' interleaved frame
                    while readBuffer.count < 4 {
                        try await fillBuffer()
                    }
                    let len = Int(UInt16(readBuffer[readBuffer.startIndex + 2]) << 8
                                | UInt16(readBuffer[readBuffer.startIndex + 3]))
                    let total = 4 + len
                    while readBuffer.count < total {
                        try await fillBuffer()
                    }
                    readBuffer.removeFirst(total)
                } else if first == 0x0D || first == 0x0A {
                    readBuffer.removeFirst(1)
                } else {
                    break
                }
            }

            // Read until \r\n\r\n
            let delimiter = Data([0x0D, 0x0A, 0x0D, 0x0A])
            while true {
                if let range = readBuffer.range(of: delimiter) {
                    let end = range.upperBound
                    let result = Data(readBuffer[readBuffer.startIndex..<end])
                    readBuffer.removeFirst(result.count)
                    return result
                }
                try await fillBuffer()
            }
        }

        // --- Auth helpers ---

        func md5Hex(_ string: String) -> String {
            let digest = Insecure.MD5.hash(data: Data(string.utf8))
            return digest.map { String(format: "%02x", $0) }.joined()
        }

        func buildAuthHeader(method: String, url: String) -> String {
            if useDigestAuth {
                let ha1 = md5Hex("\(username):\(digestRealm):\(accessCode)")
                let ha2 = md5Hex("\(method):\(url)")
                let response = md5Hex("\(ha1):\(digestNonce):\(ha2)")
                return "Digest username=\"\(username)\", realm=\"\(digestRealm)\", nonce=\"\(digestNonce)\", uri=\"\(url)\", response=\"\(response)\""
            } else {
                return "Basic \(Data("\(username):\(accessCode)".utf8).base64EncodedString())"
            }
        }

        func parseWWWAuthenticate(_ value: String) {
            if value.hasPrefix("Digest") {
                useDigestAuth = true
                if let r = value.range(of: "realm=\"") {
                    let after = value[r.upperBound...]
                    if let end = after.firstIndex(of: "\"") { digestRealm = String(after[..<end]) }
                }
                if let r = value.range(of: "nonce=\"") {
                    let after = value[r.upperBound...]
                    if let end = after.firstIndex(of: "\"") { digestNonce = String(after[..<end]) }
                }
                logger.info("Digest auth: realm=\(digestRealm), nonce=\(digestNonce)")
            }
        }

        // --- RTSP request/response ---

        func sendRTSP(
            method: String,
            url: String,
            extraHeaders: [(String, String)] = [],
            includeAuth: Bool = true
        ) async throws -> (status: Int, headers: [String: String], body: String) {
            cseq += 1
            var req = "\(method) \(url) RTSP/1.0\r\n"
            req += "CSeq: \(cseq)\r\n"
            if includeAuth {
                req += "Authorization: \(buildAuthHeader(method: method, url: url))\r\n"
            }
            req += "User-Agent: BambuBeFree/1.0\r\n"
            for (key, value) in extraHeaders {
                req += "\(key): \(value)\r\n"
            }
            req += "\r\n"

            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                connection.send(content: Data(req.utf8), completion: .contentProcessed { error in
                    if let error { cont.resume(throwing: error) }
                    else { cont.resume() }
                })
            }

            let headerData = try await readRTSPResponseHeader()
            let headerStr = String(data: headerData, encoding: .ascii) ?? ""
            let lines = headerStr.components(separatedBy: "\r\n")

            let statusCode: Int = {
                let parts = lines[0].split(separator: " ", maxSplits: 2)
                return parts.count >= 2 ? Int(parts[1]) ?? 0 : 0
            }()

            var headers: [String: String] = [:]
            for line in lines.dropFirst() {
                if let colon = line.firstIndex(of: ":") {
                    let key = line[line.startIndex..<colon].trimmingCharacters(in: .whitespaces)
                    let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                    headers[key] = value
                }
            }

            var body = ""
            if let cl = headers["Content-Length"], let length = Int(cl), length > 0 {
                let bodyData = try await readExactly(length)
                body = String(data: bodyData, encoding: .utf8) ?? ""
            }

            logger.info("RTSP \(method) → \(statusCode)")
            return (statusCode, headers, body)
        }

        // --- Main RTSP flow ---

        do {
            // 1. DESCRIBE without auth to get challenge
            let challenge = try await sendRTSP(
                method: "DESCRIBE", url: baseURL,
                extraHeaders: [("Accept", "application/sdp")],
                includeAuth: false
            )

            var desc = challenge
            if challenge.status == 401 {
                if let wwwAuth = challenge.headers["WWW-Authenticate"] {
                    parseWWWAuthenticate(wwwAuth)
                }
                logger.info("Got 401, retrying with \(useDigestAuth ? "Digest" : "Basic") auth")
                desc = try await sendRTSP(
                    method: "DESCRIBE", url: baseURL,
                    extraHeaders: [("Accept", "application/sdp")]
                )
            }

            guard desc.status == 200 else {
                connectionState = .error(
                    desc.status == 401
                        ? "Authentication failed. Check your access code."
                        : "RTSP DESCRIBE failed (status \(desc.status))"
                )
                return
            }

            logger.info("SDP response:\n\(desc.body)")

            // Parse SDP for track URL and SPS/PPS
            var trackURL = baseURL
            var spropSPS: Data?
            var spropPPS: Data?
            let sdpLines = desc.body.components(separatedBy: "\n")
            var inVideoSection = false

            for line in sdpLines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("m=video") { inVideoSection = true }
                guard inVideoSection else { continue }

                if trimmed.hasPrefix("a=control:") {
                    let control = String(trimmed.dropFirst("a=control:".count))
                    if control.hasPrefix("rtsp") || control.hasPrefix("rtsps") {
                        trackURL = control
                    } else if control != "*" {
                        trackURL = baseURL.hasSuffix("/") ? baseURL + control : baseURL + "/" + control
                    }
                }

                if trimmed.hasPrefix("a=fmtp:"),
                   let spropRange = trimmed.range(of: "sprop-parameter-sets=")
                {
                    let spropStr = String(trimmed[spropRange.upperBound...])
                        .components(separatedBy: ";").first ?? ""
                    let params = spropStr.components(separatedBy: ",")
                    if params.count >= 2 {
                        spropSPS = Data(base64Encoded: params[0])
                        spropPPS = Data(base64Encoded: params[1])
                        logger.info("SPS from SDP: \(spropSPS?.count ?? 0) bytes, PPS: \(spropPPS?.count ?? 0) bytes")
                    }
                }
            }

            // 2. SETUP
            let setup = try await sendRTSP(
                method: "SETUP", url: trackURL,
                extraHeaders: [("Transport", "RTP/AVP/TCP;unicast;interleaved=0-1")]
            )
            guard setup.status == 200 else {
                connectionState = .error(String(localized: "RTSP SETUP failed (status \(setup.status))"))
                return
            }

            let sessionId = setup.headers["Session"]?.components(separatedBy: ";").first ?? ""
            logger.info("RTSP session: \(sessionId)")

            // 3. PLAY
            let play = try await sendRTSP(
                method: "PLAY", url: baseURL,
                extraHeaders: [("Session", sessionId), ("Range", "npt=0.000-")]
            )
            guard play.status == 200 else {
                connectionState = .error(String(localized: "RTSP PLAY failed (status \(play.status))"))
                return
            }

            logger.info("RTSP PLAY started — receiving H.264 frames")
            connectionState = .streaming

            // Initialize H.264 decoder with SPS/PPS from SDP
            if let sps = spropSPS, let pps = spropPPS {
                configureDecoder(sps: sps, pps: pps)
            }

            // 4. RTP receive loop
            var nalAssembler = H264NALAssembler()

            while !Task.isCancelled {
                // Skip non-interleaved data to find next $ marker
                while true {
                    while readBuffer.isEmpty {
                        try await fillBuffer()
                    }
                    if readBuffer[readBuffer.startIndex] == 0x24 { break }
                    readBuffer.removeFirst(1)
                }

                let header = try await readExactly(4)
                let channel = header[1]
                let length = Int(UInt16(header[2]) << 8 | UInt16(header[3]))
                guard length > 0 else { continue }

                let packet = try await readExactly(length)
                guard channel == 0, packet.count >= 12 else { continue }

                // Parse RTP header
                let rtpMarkerBit = (packet[1] & 0x80) != 0
                let csrcCount = Int(packet[0] & 0x0F)
                let rtpHeaderLen = 12 + csrcCount * 4
                guard packet.count > rtpHeaderLen else { continue }

                let rtpPayload = Data(packet[rtpHeaderLen...])

                // Depacketize H.264 NAL units from RTP (RFC 6184)
                for nalUnit in nalAssembler.processRTPPayload(rtpPayload, markerBit: rtpMarkerBit) {
                    decodeNALUnit(nalUnit)
                }
            }

        } catch {
            if !Task.isCancelled {
                logger.error("RTSP stream error: \(error.localizedDescription)")
                connectionState = .error(String(localized: "Stream error: \(error.localizedDescription)"))
            }
        }
    }
}

// MARK: - CVPixelBuffer → UIImage

private func pixelBufferToUIImage(_ pixelBuffer: CVPixelBuffer) -> UIImage? {
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    let colorSpace = CGColorSpaceCreateDeviceRGB()

    guard let ctx = CGContext(
        data: baseAddress,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue
    ) else { return nil }

    guard let cgImage = ctx.makeImage() else { return nil }
    return UIImage(cgImage: cgImage)
}

// MARK: - H.264 RTP Depacketization (RFC 6184)

private struct H264NALAssembler {
    private var fuBuffer = Data()
    private var fuNRI: UInt8 = 0
    private var fuNALType: UInt8 = 0

    mutating func processRTPPayload(_ payload: Data, markerBit _: Bool) -> [Data] {
        guard !payload.isEmpty else { return [] }

        let firstByte = payload[payload.startIndex]
        let nalType = firstByte & 0x1F

        switch nalType {
        case 1...23:
            // Single NAL Unit Packet
            return [payload]

        case 24: // STAP-A
            var nals: [Data] = []
            var offset = payload.startIndex + 1
            while offset + 2 <= payload.endIndex {
                let nalLen = Int(UInt16(payload[offset]) << 8 | UInt16(payload[offset + 1]))
                offset += 2
                guard offset + nalLen <= payload.endIndex else { break }
                nals.append(Data(payload[offset..<(offset + nalLen)]))
                offset += nalLen
            }
            return nals

        case 28: // FU-A (fragmented NAL)
            guard payload.count >= 2 else { return [] }
            let fuHeader = payload[payload.startIndex + 1]
            let startBit = (fuHeader & 0x80) != 0
            let endBit = (fuHeader & 0x40) != 0
            let origNALType = fuHeader & 0x1F

            if startBit {
                fuBuffer.removeAll(keepingCapacity: true)
                fuNRI = firstByte & 0xE0
                fuNALType = origNALType
                // Reconstruct NAL header byte
                fuBuffer.append(fuNRI | fuNALType)
                fuBuffer.append(contentsOf: payload[(payload.startIndex + 2)...])
            } else {
                fuBuffer.append(contentsOf: payload[(payload.startIndex + 2)...])
            }

            if endBit {
                let nal = fuBuffer
                fuBuffer.removeAll(keepingCapacity: true)
                return [nal]
            }
            return []

        default:
            return []
        }
    }
}
