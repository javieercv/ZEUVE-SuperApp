import Foundation
import ZEUVEEngines

public actor FFmpegPCMDecoder {
    private let runner: ExternalProcessRunner
    public init(runner: ExternalProcessRunner = ExternalProcessRunner()) { self.runner = runner }

    public func decode(ffmpeg: URL, request: SpectrogramAnalysisRequest, isolateSelectedChannel: Bool = false, onPCM: @escaping @Sendable ([Float]) -> Void) async throws {
        try Task.checkCancellation()
        var args = ["-hide_banner", "-nostdin", "-v", "error"]
        if request.startTime > 0 { args += ["-ss", String(format: "%.6f", request.startTime)] }
        args += ["-i", request.url.path]
        if let duration = request.duration, duration > 0 { args += ["-t", String(format: "%.6f", duration)] }
        if isolateSelectedChannel, case .channel(let channel) = request.channelSelection {
            guard (0..<request.channels).contains(channel) else { throw MultimediaInspectorError.invalidInput }
            args += ["-af", "pan=mono|c0=c\(channel)"]
        }
        args += ["-map", "0:\(request.streamIndex)", "-vn", "-sn", "-dn", "-f", "f32le", "-acodec", "pcm_f32le", "pipe:1"]
        let decoder = Float32LEStreamDecoder(consumer: onPCM)
        let result = try await runner.run(.init(executable: ffmpeg, arguments: args), onStdout: { decoder.append($0) })
        decoder.finish()
        guard result.succeeded else { throw MultimediaInspectorError.processFailed }
    }
    public func cancel() async { try? await runner.cancel() }
}

/// Lock único: conserva orden, buffer reutilizable y como máximo tres bytes residuales.
final class Float32LEStreamDecoder: @unchecked Sendable {
    private let lock = NSLock()
    private var residualBits: UInt32 = 0
    private var residualBytes = 0
    private var values: [Float] = []
    private let consumer: @Sendable ([Float]) -> Void
    init(consumer: @escaping @Sendable ([Float]) -> Void) { self.consumer = consumer }

    func append(_ data: Data) {
        lock.withLock {
            let count = (residualBytes + data.count) / 4
            if values.count != count { values = [Float](repeating: 0, count: count) }
            data.withUnsafeBytes { raw in
                var input = 0, output = 0
                if residualBytes > 0 {
                    while residualBytes < 4, input < raw.count {
                        residualBits |= UInt32(raw[input]) << (residualBytes * 8)
                        residualBytes += 1; input += 1
                    }
                    if residualBytes == 4 {
                        values[0] = Float(bitPattern: residualBits); output = 1
                        residualBytes = 0; residualBits = 0
                    }
                }
                let floats = (raw.count - input) / 4
                if floats > 0 {
                    values.withUnsafeMutableBytes { destination in
                        // memcpy admite entrada no alineada; Float vive en almacenamiento alineado.
                        destination.baseAddress!.advanced(by: output * 4).copyMemory(from: raw.baseAddress!.advanced(by: input), byteCount: floats * 4)
                    }
                    #if _endian(big)
                    for index in output..<(output + floats) { values[index] = Float(bitPattern: values[index].bitPattern.byteSwapped) }
                    #endif
                    input += floats * 4
                }
                while input < raw.count {
                    residualBits |= UInt32(raw[input]) << (residualBytes * 8)
                    residualBytes += 1; input += 1
                }
            }
            if !values.isEmpty { consumer(values) }
        }
    }
    func finish() { lock.withLock { residualBits = 0; residualBytes = 0; values.removeAll() } }
}
