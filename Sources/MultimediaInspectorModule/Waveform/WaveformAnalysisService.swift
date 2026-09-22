import Foundation
import ZEUVEEngines

public actor MultimediaWaveformAnalysisService {
    private let runner: ExternalProcessRunner
    private let cache: MultimediaWaveformCache

    public init(runner: ExternalProcessRunner = .init()) {
        self.runner = runner
        cache = MultimediaWaveformCache()
    }

    public func analyze(
        ffmpeg: URL,
        request: MultimediaWaveformAnalysisRequest
    ) async throws -> MultimediaWaveformResult {
        guard request.maximumBuckets > 0, request.source.fingerprint.matches(request.source.url) else {
            throw MultimediaInspectorError.inputChanged(request.source.title)
        }
        if let cached = await cache.result(for: request.cacheKey) { return cached }

        let builder = FFmpegWaveformCommandBuilder()
        let configuration = try builder.configuration(for: request)
        let accumulator = try MultimediaWaveformAccumulator(
            sampleRate: configuration.sampleRate,
            channels: configuration.outputChannels,
            channelSelection: configuration.accumulatorChannelSelection,
            duration: request.source.duration,
            maximumBuckets: request.maximumBuckets
        )
        let consumer = WaveformPCMConsumer(channels: configuration.outputChannels, accumulator: accumulator)
        let result = try await runner.run(
            .init(executable: ffmpeg, arguments: configuration.arguments),
            onStdout: { consumer.append($0) }
        )
        try Task.checkCancellation()
        guard result.succeeded else { throw MultimediaInspectorError.processFailed }
        let waveform = consumer.finish(sourceID: request.source.id)
        await cache.insert(waveform, for: request.cacheKey)
        return waveform
    }

    public func cancel() async {
        try? await runner.cancel(gracePeriod: .milliseconds(250))
    }
}

private struct FFmpegWaveformConfiguration {
    let arguments: [String]
    let sampleRate: Double
    let outputChannels: Int
    let accumulatorChannelSelection: SpectrogramChannelSelection
}

private struct FFmpegWaveformCommandBuilder {
    func configuration(for request: MultimediaWaveformAnalysisRequest) throws -> FFmpegWaveformConfiguration {
        let source = request.source
        guard source.sampleRate > 0, source.channels > 0, source.channels <= 128 else {
            throw MultimediaInspectorError.invalidInput
        }
        if case .channel(let index) = request.channelSelection,
           !(0..<source.channels).contains(index) {
            throw MultimediaInspectorError.invalidInput
        }

        let outputChannels: Int
        let accumulatorSelection: SpectrogramChannelSelection
        switch request.channelSelection {
        case .mix:
            outputChannels = source.channels
            accumulatorSelection = .mix
        case .channel:
            outputChannels = 1
            accumulatorSelection = .channel(0)
        }

        // La envolvente es una ayuda de navegación, no una copia del PCM. Acotamos el caudal
        // conservando cada canal por separado para que la mezcla visual no pueda cancelar fase.
        let rateBudget = max(125, Int(floor(8_000.0 / Double(max(outputChannels, 1)))))
        let outputRate = min(Int(source.sampleRate.rounded()), min(2_000, rateBudget))
        var arguments = ["-hide_banner", "-nostdin", "-v", "error", "-i", source.url.path,
                         "-map", "0:\(source.streamIndex)", "-vn", "-sn", "-dn"]
        if case .channel(let index) = request.channelSelection {
            arguments += ["-af", "pan=mono|c0=c\(index)", "-ac", "1"]
        }
        arguments += ["-ar", String(outputRate), "-f", "f32le", "-acodec", "pcm_f32le", "pipe:1"]
        return .init(
            arguments: arguments,
            sampleRate: Double(outputRate),
            outputChannels: outputChannels,
            accumulatorChannelSelection: accumulatorSelection
        )
    }
}

private final class WaveformPCMConsumer: @unchecked Sendable {
    private let lock = NSLock()
    private let channels: Int
    private let accumulator: MultimediaWaveformAccumulator
    private var residual = Data()

    init(channels: Int, accumulator: MultimediaWaveformAccumulator) {
        self.channels = channels
        self.accumulator = accumulator
    }

    func append(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        var payload = residual
        payload.append(data)
        residual.removeAll(keepingCapacity: true)
        let bytesPerFrame = channels * MemoryLayout<Float>.size
        let usable = payload.count - (payload.count % bytesPerFrame)
        guard usable > 0 else {
            residual = payload
            return
        }
        if usable < payload.count { residual = Data(payload.suffix(payload.count - usable)) }
        var samples = [Float](repeating: 0, count: usable / MemoryLayout<Float>.size)
        samples.withUnsafeMutableBytes { destination in
            payload.withUnsafeBytes { source in
                destination.copyMemory(from: UnsafeRawBufferPointer(rebasing: source[..<usable]))
            }
        }
        accumulator.consume(interleaved: samples)
    }

    func finish(sourceID: String) -> MultimediaWaveformResult {
        lock.lock()
        residual.removeAll(keepingCapacity: false)
        lock.unlock()
        return accumulator.finish(sourceID: sourceID)
    }
}
