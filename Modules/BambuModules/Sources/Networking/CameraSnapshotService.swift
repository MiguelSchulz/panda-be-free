import BambuModels
import CoreMedia
import CryptoKit
import Foundation
import Network
import os
import UIKit
import VideoToolbox

public enum CameraSnapshotError: Error, LocalizedError {
    case noConfiguration
    case connectionFailed(String)
    case authenticationFailed
    case timeout
    case noFrameReceived
    case decodingFailed

    public var errorDescription: String? {
        switch self {
        case .noConfiguration: "No printer configured"
        case let .connectionFailed(msg): "Connection failed: \(msg)"
        case .authenticationFailed: "Authentication failed"
        case .timeout: "Connection timed out"
        case .noFrameReceived: "No frame received"
        case .decodingFailed: "Failed to decode frame"
        }
    }
}

public enum CameraSnapshotService {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.bambubefree.app",
        category: "CameraSnapshot"
    )

    /// Capture a single JPEG snapshot from the printer camera.
    public static func captureSnapshot(
        ip: String,
        accessCode: String,
        printerType: PrinterType = .auto,
        timeoutSeconds: TimeInterval = 20
    ) async throws -> Data {
        switch printerType {
        case .tcp:
            return try await captureTCPSnapshot(ip: ip, accessCode: accessCode, timeout: timeoutSeconds)
        case .rtsp:
            return try await captureRTSPSnapshot(ip: ip, accessCode: accessCode, timeout: timeoutSeconds)
        case .auto:
            do {
                return try await captureTCPSnapshot(ip: ip, accessCode: accessCode, timeout: 5)
            } catch {
                logger.info("TCP/6000 failed (\(error.localizedDescription)), trying RTSP/322")
                return try await captureRTSPSnapshot(
                    ip: ip, accessCode: accessCode,
                    timeout: max(timeoutSeconds - 5, 10)
                )
            }
        }
    }

    // MARK: - TCP/6000 Snapshot (A1/P1)

    private static func captureTCPSnapshot(ip: String, accessCode: String, timeout: TimeInterval) async throws -> Data {
        let connection = try await connectTLS(host: ip, port: 6000, timeout: timeout)
        defer { connection.cancel() }

        // Build 80-byte auth packet per OpenBambuAPI spec
        var authPacket = Data(count: 80)
        // Offset 0-3: payload size = 0x40 (64) little-endian
        authPacket[0] = 0x40; authPacket[1] = 0x00; authPacket[2] = 0x00; authPacket[3] = 0x00
        // Offset 4-7: message type = 0x3000 little-endian
        authPacket[4] = 0x00; authPacket[5] = 0x30; authPacket[6] = 0x00; authPacket[7] = 0x00
        // Offset 8-15: zeros (already zeroed)
        // Offset 16-47: username "bblp" null-padded to 32 bytes
        let usernameBytes = Array("bblp".utf8)
        for (i, byte) in usernameBytes.enumerated() {
            authPacket[16 + i] = byte
        }
        // Offset 48-79: password null-padded to 32 bytes
        let passwordBytes = Array(accessCode.utf8)
        for (i, byte) in passwordBytes.prefix(32).enumerated() {
            authPacket[48 + i] = byte
        }

        try await send(connection: connection, data: authPacket)

        // Read 16-byte frame header
        let header = try await receive(connection: connection, length: 16, timeout: timeout)
        let jpegLength = Int(header[0]) | (Int(header[1]) << 8)
            | (Int(header[2]) << 16) | (Int(header[3]) << 24)

        guard jpegLength > 0, jpegLength < 10_000_000 else {
            throw CameraSnapshotError.authenticationFailed
        }

        // Read JPEG payload (may arrive in chunks)
        let jpegData = try await receive(connection: connection, length: jpegLength, timeout: timeout)

        // Verify JPEG magic bytes
        guard jpegData.count >= 2, jpegData[0] == 0xFF, jpegData[1] == 0xD8 else {
            throw CameraSnapshotError.decodingFailed
        }

        logger.info("TCP snapshot captured: \(jpegData.count) bytes")
        return jpegData
    }

    // MARK: - RTSP/322 Snapshot (X1/P2S)

    private static func captureRTSPSnapshot(ip: String, accessCode: String, timeout: TimeInterval) async throws -> Data {
        let connection = try await connectTLS(host: ip, port: 322, timeout: timeout)
        defer { connection.cancel() }

        var readBuffer = Data()
        var cseq = 0
        let baseURL = "rtsps://\(ip):322/streaming/live/1"
        let username = "bblp"

        var digestRealm = ""
        var digestNonce = ""
        var useDigestAuth = false

        // --- Buffered I/O ---

        func fillBuffer() async throws {
            let chunk: Data = try await withCheckedThrowingContinuation { cont in
                connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, error in
                    if let error { cont.resume(throwing: error) }
                    else if let data, !data.isEmpty { cont.resume(returning: data) }
                    else { cont.resume(throwing: CameraSnapshotError.noFrameReceived) }
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

        func readRTSPResponseHeader() async throws -> Data {
            while true {
                while readBuffer.isEmpty {
                    try await fillBuffer()
                }
                let first = readBuffer[readBuffer.startIndex]
                if first == 0x24 {
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

        // --- Auth ---

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

            try await send(connection: connection, data: Data(req.utf8))

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

            return (statusCode, headers, body)
        }

        // --- RTSP flow: DESCRIBE → SETUP → PLAY → capture first frame ---

        // 1. DESCRIBE
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
            desc = try await sendRTSP(
                method: "DESCRIBE", url: baseURL,
                extraHeaders: [("Accept", "application/sdp")]
            )
        }

        guard desc.status == 200 else {
            throw desc.status == 401
                ? CameraSnapshotError.authenticationFailed
                : CameraSnapshotError.connectionFailed("RTSP DESCRIBE failed (status \(desc.status))")
        }

        // Parse SDP
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
                }
            }
        }

        // 2. SETUP
        let setup = try await sendRTSP(
            method: "SETUP", url: trackURL,
            extraHeaders: [("Transport", "RTP/AVP/TCP;unicast;interleaved=0-1")]
        )
        guard setup.status == 200 else {
            throw CameraSnapshotError.connectionFailed("RTSP SETUP failed (status \(setup.status))")
        }

        let sessionId = setup.headers["Session"]?.components(separatedBy: ";").first ?? ""

        // 3. PLAY
        let play = try await sendRTSP(
            method: "PLAY", url: baseURL,
            extraHeaders: [("Session", sessionId), ("Range", "npt=0.000-")]
        )
        guard play.status == 200 else {
            throw CameraSnapshotError.connectionFailed("RTSP PLAY failed (status \(play.status))")
        }

        // Configure H.264 decoder
        var spsData: Data? = spropSPS
        var ppsData: Data? = spropPPS
        var formatDescription: CMVideoFormatDescription?
        var decompressionSession: VTDecompressionSession?

        func configureDecoder(sps: Data, pps: Data) {
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
            guard status == noErr, let desc else { return }
            formatDescription = desc

            let attrs: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            var session: VTDecompressionSession?
            VTDecompressionSessionCreate(
                allocator: nil,
                formatDescription: desc,
                decoderSpecification: nil,
                imageBufferAttributes: attrs as CFDictionary,
                outputCallback: nil,
                decompressionSessionOut: &session
            )
            decompressionSession = session
        }

        if let sps = spropSPS, let pps = spropPPS {
            configureDecoder(sps: sps, pps: pps)
        }

        /// Decode a single NAL unit and return JPEG data if it's a video slice
        func decodeNAL(_ nalData: Data) -> Data? {
            guard !nalData.isEmpty else { return nil }
            let nalType = nalData[nalData.startIndex] & 0x1F

            if nalType == 7 {
                if let pps = ppsData { configureDecoder(sps: nalData, pps: pps) }
                return nil
            }
            if nalType == 8 {
                if let sps = spsData { configureDecoder(sps: sps, pps: nalData) }
                return nil
            }

            guard nalType == 1 || nalType == 5,
                  let session = decompressionSession,
                  let fmtDesc = formatDescription else { return nil }

            let nalLength = UInt32(nalData.count)
            var lengthBE = nalLength.bigEndian
            let avccCount = 4 + nalData.count

            var blockBuffer: CMBlockBuffer?
            guard CMBlockBufferCreateWithMemoryBlock(
                allocator: nil, memoryBlock: nil, blockLength: avccCount,
                blockAllocator: nil, customBlockSource: nil,
                offsetToData: 0, dataLength: avccCount,
                flags: kCMBlockBufferAssureMemoryNowFlag,
                blockBufferOut: &blockBuffer
            ) == noErr, let blockBuffer else { return nil }

            withUnsafeBytes(of: &lengthBE) { ptr in
                CMBlockBufferReplaceDataBytes(
                    with: ptr.baseAddress!, blockBuffer: blockBuffer,
                    offsetIntoDestination: 0, dataLength: 4
                )
            }
            nalData.withUnsafeBytes { ptr in
                CMBlockBufferReplaceDataBytes(
                    with: ptr.baseAddress!, blockBuffer: blockBuffer,
                    offsetIntoDestination: 4, dataLength: nalData.count
                )
            }

            var sampleBuffer: CMSampleBuffer?
            var sampleSize = avccCount
            guard CMSampleBufferCreateReady(
                allocator: nil, dataBuffer: blockBuffer,
                formatDescription: fmtDesc, sampleCount: 1,
                sampleTimingEntryCount: 0, sampleTimingArray: nil,
                sampleSizeEntryCount: 1, sampleSizeArray: &sampleSize,
                sampleBufferOut: &sampleBuffer
            ) == noErr, let sampleBuffer else { return nil }

            var decodedJPEG: Data?
            var flagsOut: VTDecodeInfoFlags = []
            VTDecompressionSessionDecodeFrame(
                session, sampleBuffer: sampleBuffer,
                flags: [], infoFlagsOut: &flagsOut
            ) { status, _, imageBuffer, _, _ in
                guard status == noErr, let pixelBuffer = imageBuffer else { return }
                decodedJPEG = pixelBufferToJPEG(pixelBuffer)
            }
            return decodedJPEG
        }

        // 4. RTP receive loop — capture first decodable frame
        var nalAssembler = SnapshotNALAssembler()
        let deadline = Date.now.addingTimeInterval(timeout)

        while Date.now < deadline {
            // Find next interleaved frame marker
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

            let rtpMarkerBit = (packet[1] & 0x80) != 0
            let csrcCount = Int(packet[0] & 0x0F)
            let rtpHeaderLen = 12 + csrcCount * 4
            guard packet.count > rtpHeaderLen else { continue }

            let rtpPayload = Data(packet[rtpHeaderLen...])

            for nalUnit in nalAssembler.processRTPPayload(rtpPayload, markerBit: rtpMarkerBit) {
                if let jpegData = decodeNAL(nalUnit) {
                    if let session = decompressionSession {
                        VTDecompressionSessionInvalidate(session)
                    }
                    logger.info("RTSP snapshot captured: \(jpegData.count) bytes")
                    return jpegData
                }
            }
        }

        if let session = decompressionSession {
            VTDecompressionSessionInvalidate(session)
        }
        throw CameraSnapshotError.timeout
    }

    // MARK: - Network Helpers

    private static func connectTLS(host: String, port: UInt16, timeout: TimeInterval) async throws -> NWConnection {
        let tlsOptions = NWProtocolTLS.Options()
        sec_protocol_options_set_verify_block(
            tlsOptions.securityProtocolOptions,
            { _, _, completionHandler in completionHandler(true) },
            DispatchQueue.global()
        )

        let params = NWParameters(tls: tlsOptions, tcp: NWProtocolTCP.Options())
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: port),
            using: params
        )

        return try await withCheckedThrowingContinuation { cont in
            let resumed = OSAllocatedUnfairLock(initialState: false)
            connection.stateUpdateHandler = { state in
                let shouldHandle = resumed.withLock { r -> Bool in
                    guard !r else { return false }
                    r = true
                    return true
                }
                guard shouldHandle else { return }
                switch state {
                case .ready:
                    cont.resume(returning: connection)
                case let .failed(error):
                    cont.resume(throwing: CameraSnapshotError.connectionFailed(error.localizedDescription))
                case .waiting:
                    connection.cancel()
                    cont.resume(throwing: CameraSnapshotError.connectionFailed("Printer unreachable"))
                default:
                    resumed.withLock { $0 = false }
                }
            }
            connection.start(queue: DispatchQueue.global())

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                let shouldHandle = resumed.withLock { r -> Bool in
                    guard !r else { return false }
                    r = true
                    return true
                }
                guard shouldHandle else { return }
                connection.cancel()
                cont.resume(throwing: CameraSnapshotError.timeout)
            }
        }
    }

    private static func send(connection: NWConnection, data: Data) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume() }
            })
        }
    }

    private static func receive(connection: NWConnection, length: Int, timeout: TimeInterval) async throws -> Data {
        var buffer = Data()
        let deadline = Date.now.addingTimeInterval(timeout)

        while buffer.count < length {
            guard Date.now < deadline else { throw CameraSnapshotError.timeout }

            let chunk: Data = try await withCheckedThrowingContinuation { cont in
                connection.receive(
                    minimumIncompleteLength: 1,
                    maximumLength: min(65536, length - buffer.count)
                ) { data, _, _, error in
                    if let error { cont.resume(throwing: error) }
                    else if let data, !data.isEmpty { cont.resume(returning: data) }
                    else { cont.resume(throwing: CameraSnapshotError.noFrameReceived) }
                }
            }
            buffer.append(chunk)
        }

        return buffer
    }
}

// MARK: - CVPixelBuffer → JPEG

private func pixelBufferToJPEG(_ pixelBuffer: CVPixelBuffer, quality: CGFloat = 0.85) -> Data? {
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    let colorSpace = CGColorSpaceCreateDeviceRGB()

    guard let ctx = CGContext(
        data: baseAddress, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace,
        bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue
    ) else { return nil }

    guard let cgImage = ctx.makeImage() else { return nil }
    return UIImage(cgImage: cgImage).jpegData(compressionQuality: quality)
}

// MARK: - H.264 RTP Depacketization (RFC 6184)

private struct SnapshotNALAssembler {
    private var fuBuffer = Data()
    private var fuNRI: UInt8 = 0
    private var fuNALType: UInt8 = 0

    mutating func processRTPPayload(_ payload: Data, markerBit _: Bool) -> [Data] {
        guard !payload.isEmpty else { return [] }

        let firstByte = payload[payload.startIndex]
        let nalType = firstByte & 0x1F

        switch nalType {
        case 1...23:
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

        case 28: // FU-A
            guard payload.count >= 2 else { return [] }
            let fuHeader = payload[payload.startIndex + 1]
            let startBit = (fuHeader & 0x80) != 0
            let endBit = (fuHeader & 0x40) != 0
            let origNALType = fuHeader & 0x1F

            if startBit {
                fuBuffer.removeAll(keepingCapacity: true)
                fuNRI = firstByte & 0xE0
                fuNALType = origNALType
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
