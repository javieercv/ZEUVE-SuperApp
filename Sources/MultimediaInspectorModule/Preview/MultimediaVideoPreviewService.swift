import Foundation
import ZEUVEEngines

private final class VideoFrameAssembler: @unchecked Sendable {
    private let lock = NSLock()
    private let frameSize: Int
    private let width: Int
    private let height: Int
    private let fps: Double
    private let start: TimeInterval
    private var residual = Data()
    private var frameIndex: Int64 = 0
    private let maximumResidualBytes: Int
    private let maximumBufferedFrames: Int
    private let onFrame: @Sendable (MultimediaVideoPreviewFrame) -> Void

    init(width: Int, height: Int, fps: Double, start: TimeInterval, maximumBufferedFrames: Int, onFrame: @escaping @Sendable (MultimediaVideoPreviewFrame) -> Void) {
        self.width = width
        self.height = height
        self.fps = max(1, fps)
        self.start = start
        self.frameSize = width * height * 4
        self.maximumBufferedFrames = min(max(maximumBufferedFrames, 1), 8)
        self.maximumResidualBytes = max(self.frameSize * (self.maximumBufferedFrames + 1), 1_048_576)
        self.onFrame = onFrame
    }

    func append(_ data: Data) {
        lock.lock()
        residual.append(data)
        if residual.count > maximumResidualBytes + frameSize {
            residual.removeAll(keepingCapacity: true)
            lock.unlock()
            return
        }
        var frames: [MultimediaVideoPreviewFrame] = []
        while residual.count >= frameSize {
            let pixels = residual.prefix(frameSize)
            residual.removeFirst(frameSize)
            let timestamp = start + Double(frameIndex) / fps
            frameIndex += 1
            frames.append(.init(pixelsBGRA: Data(pixels), width: width, height: height, timestamp: timestamp))
            if frames.count > maximumBufferedFrames { frames.removeFirst(frames.count - maximumBufferedFrames) }
        }
        lock.unlock()
        for frame in frames { onFrame(frame) }
    }
}

public actor MultimediaVideoPreviewService {
    private static let cancellationGracePeriod: Duration = .milliseconds(50)
    private let runner: ExternalProcessRunner
    private let builder: FFmpegVideoPreviewCommandBuilder
    private var decodeTask: Task<Void, Never>?
    private var generation: UInt64 = 0
    private var currentSource: MultimediaVideoPreviewSource?
    private var currentFrame: MultimediaVideoPreviewFrame?
    private var state: MultimediaPreviewPlaybackState = .idle
    private var terminalError: String?
    private var pauseAfterFirstFrame = false

    public init(runner: ExternalProcessRunner = ExternalProcessRunner(), builder: FFmpegVideoPreviewCommandBuilder = .init()) {
        self.runner = runner
        self.builder = builder
    }

    public func start(
        ffmpeg: URL,
        source: MultimediaVideoPreviewSource,
        from position: TimeInterval,
        limits: MultimediaVideoPreviewLimits,
        decoder: MultimediaVideoPreviewDecoder = .automatic,
        playbackRate: Double = 1,
        shouldPlay: Bool = true
    ) async throws {
        guard source.fingerprint.matches(source.url) else { throw MultimediaInspectorError.inputChanged(source.title) }
        await stop()
        generation &+= 1
        let ticket = generation
        currentSource = source
        currentFrame = nil
        terminalError = nil
        pauseAfterFirstFrame = !shouldPlay
        state = .loading
        let prepared = try builder.prepare(source: source, from: position, limits: limits, decoder: decoder, playbackRate: playbackRate)
        var normalizedLimits = limits
        normalizedLimits.normalize()
        let assembler = VideoFrameAssembler(width: prepared.outputWidth, height: prepared.outputHeight, fps: prepared.outputFPS, start: prepared.startPosition, maximumBufferedFrames: normalizedLimits.maximumBufferedFrames) { [weak self] frame in
            Task { await self?.accept(frame: frame, generation: ticket) }
        }
        decodeTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await runner.run(
                    .init(executable: ffmpeg, arguments: prepared.arguments),
                    onStdout: { assembler.append($0) },
                    cancellationGracePeriod: Self.cancellationGracePeriod
                )
                if !result.succeeded, decoder != .software, !Task.isCancelled {
                    let fallback = try builder.prepare(source: source, from: position, limits: limits, decoder: .software, playbackRate: playbackRate)
                    let fallbackAssembler = VideoFrameAssembler(width: fallback.outputWidth, height: fallback.outputHeight, fps: fallback.outputFPS, start: fallback.startPosition, maximumBufferedFrames: normalizedLimits.maximumBufferedFrames) { [weak self] frame in
                        Task { await self?.accept(frame: frame, generation: ticket) }
                    }
                    let fallbackResult = try await runner.run(
                        .init(executable: ffmpeg, arguments: fallback.arguments),
                        onStdout: { fallbackAssembler.append($0) },
                        cancellationGracePeriod: Self.cancellationGracePeriod
                    )
                    await self.finish(generation: ticket, succeeded: fallbackResult.succeeded, message: fallbackResult.succeeded ? nil : "FFmpeg no ha podido decodificar el vídeo de previsualización.")
                } else {
                    await self.finish(generation: ticket, succeeded: result.succeeded, message: result.succeeded ? nil : "FFmpeg no ha podido decodificar el vídeo de previsualización.")
                }
            } catch is CancellationError {
                await self.finish(generation: ticket, succeeded: false, message: nil)
            } catch {
                await self.finish(generation: ticket, succeeded: false, message: (error as? LocalizedError)?.errorDescription ?? "La previsualización de vídeo ha fallado.")
            }
        }
    }

    public func seek(ffmpeg: URL, to position: TimeInterval, limits: MultimediaVideoPreviewLimits, decoder: MultimediaVideoPreviewDecoder = .automatic, playbackRate: Double = 1) async throws {
        guard let source = currentSource else { return }
        try await start(ffmpeg: ffmpeg, source: source, from: position, limits: limits, decoder: decoder, playbackRate: playbackRate)
    }

    /// Detiene la decodificación conservando la fuente y el último fotograma.
    /// Reanudar crea una nueva ejecución de FFmpeg desde el playhead compartido.
    public func pause() async {
        guard state == .playing || state == .loading else { return }
        generation &+= 1
        decodeTask?.cancel()
        decodeTask = nil
        pauseAfterFirstFrame = false
        terminalError = nil
        state = .paused
        try? await runner.cancel(gracePeriod: Self.cancellationGracePeriod)
    }

    public func stop() async {
        generation &+= 1
        decodeTask?.cancel()
        decodeTask = nil
        currentFrame = nil
        currentSource = nil
        terminalError = nil
        pauseAfterFirstFrame = false
        state = .idle
        try? await runner.cancel(gracePeriod: Self.cancellationGracePeriod)
    }

    public func snapshot(position: TimeInterval) -> MultimediaVideoPreviewSnapshot {
        .init(state: state, sourceID: currentSource?.id, position: position, duration: currentSource?.duration, frame: currentFrame, errorMessage: terminalError)
    }

    private func accept(frame: MultimediaVideoPreviewFrame, generation ticket: UInt64) async {
        guard ticket == generation else { return }
        // Mantener solo el frame más reciente acota la memoria y aplica backpressure por descarte.
        currentFrame = frame
        if pauseAfterFirstFrame {
            await pause()
        } else {
            state = .playing
        }
    }

    private func finish(generation ticket: UInt64, succeeded: Bool, message: String?) {
        guard ticket == generation else { return }
        if succeeded {
            state = .finished
        } else if let message {
            state = .failed
            terminalError = message
        }
        decodeTask = nil
    }
}
