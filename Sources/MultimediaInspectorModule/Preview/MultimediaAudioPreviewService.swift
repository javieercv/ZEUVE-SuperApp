import Foundation
import ZEUVECore
import ZEUVEEngines

#if canImport(AVFoundation)
import AVFoundation
#endif

public enum MultimediaPreviewPlaybackState: String, Sendable, Equatable {
    case idle, loading, playing, paused, finished, failed
}

enum PreviewPlaybackContinuity {
    static func shouldPlayAfterReplacement(from state: MultimediaPreviewPlaybackState) -> Bool {
        switch state {
        case .paused, .finished:
            return false
        case .idle, .loading, .playing, .failed:
            return true
        }
    }
}

public struct MultimediaAudioPreviewSource: Sendable, Equatable, Identifiable {
    public let url: URL
    public let fingerprint: FileFingerprint
    public let streamIndex: Int
    public let sampleRate: Double
    public let channels: Int
    public let duration: TimeInterval?
    public let channelLayout: String?
    public let title: String

    /// Identidad efímera sin persistir ni exponer la ruta completa del usuario.
    public var id: String { Self.identity(url: url, fingerprint: fingerprint, streamIndex: streamIndex) }

    public static func identity(url: URL, fingerprint: FileFingerprint, streamIndex: Int) -> String {
        let pathToken = url.standardizedFileURL.path.hashValue
        return "\(pathToken):\(fingerprint.size):\(fingerprint.modificationTimeNanoseconds):\(streamIndex)"
    }

    public init(
        url: URL,
        fingerprint: FileFingerprint,
        streamIndex: Int,
        sampleRate: Double,
        channels: Int,
        duration: TimeInterval?,
        channelLayout: String? = nil,
        title: String
    ) {
        self.url = url.standardizedFileURL
        self.fingerprint = fingerprint
        self.streamIndex = streamIndex
        self.sampleRate = sampleRate
        self.channels = channels
        self.duration = duration
        self.channelLayout = channelLayout
        self.title = title
    }
}

public struct MultimediaAudioPreviewSnapshot: Sendable, Equatable {
    public let state: MultimediaPreviewPlaybackState
    public let position: TimeInterval
    public let duration: TimeInterval?
    public let sourceID: String?
    public let title: String?
    public let errorMessage: String?

    public init(
        state: MultimediaPreviewPlaybackState,
        position: TimeInterval,
        duration: TimeInterval?,
        sourceID: String?,
        title: String?,
        errorMessage: String? = nil
    ) {
        self.state = state
        self.position = position
        self.duration = duration
        self.sourceID = sourceID
        self.title = title
        self.errorMessage = errorMessage
    }

    public static let idle = MultimediaAudioPreviewSnapshot(
        state: .idle,
        position: 0,
        duration: nil,
        sourceID: nil,
        title: nil
    )
}

/// Serializa la limpieza entre reemplazos y entrega un ticket que deja de ser válido en cuanto
/// llega una petición posterior. Al estar separado de AVFoundation puede probarse con operaciones
/// controladas sin fingir que un cambio de `-map` demuestra el ciclo completo de reproducción.
actor PreviewSourceReplacementGate {
    struct Ticket: Sendable, Equatable { fileprivate let generation: UInt64 }

    private var generation: UInt64 = 0
    private var cleanupTail: Task<Void, Never>?

    func beginReplacement(cleanup: @escaping @Sendable () async -> Void) async throws -> Ticket {
        generation &+= 1
        let ticket = Ticket(generation: generation)
        let previous = cleanupTail
        let task = Task {
            _ = await previous?.result
            await cleanup()
        }
        cleanupTail = task
        await task.value
        if cleanupTail != nil, generation == ticket.generation { cleanupTail = nil }
        try Task.checkCancellation()
        guard generation == ticket.generation else { throw CancellationError() }
        return ticket
    }

    func invalidate(cleanup: @escaping @Sendable () async -> Void) async {
        generation &+= 1
        let invalidationGeneration = generation
        let previous = cleanupTail
        let task = Task {
            _ = await previous?.result
            await cleanup()
        }
        cleanupTail = task
        await task.value
        if generation == invalidationGeneration { cleanupTail = nil }
    }

    func isCurrent(_ ticket: Ticket) -> Bool { generation == ticket.generation }
}

/// Reproductor auxiliar de inspección. No publica archivos, no crea historial y no reserva
/// OperationCoordinator para poder convivir con la inspección y el análisis espectral.
public actor MultimediaAudioPreviewService {
    private let runner: ExternalProcessRunner
    private let commandBuilder: FFmpegAudioPreviewCommandBuilder

    #if canImport(AVFoundation)
    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var timePitch: AVAudioUnitTimePitch?
    private var scheduler: PreviewPCMBufferScheduler?
    private var decodeTask: Task<Void, Never>?
    private var currentSource: MultimediaAudioPreviewSource?
    private var currentFFmpeg: URL?
    private var currentChannel: SpectrogramChannelSelection = .mix
    private var basePosition: TimeInterval = 0
    private var playbackState: MultimediaPreviewPlaybackState = .idle
    private var terminalError: String?
    private var volume: Float = 1
    private var playbackRate: Float = 1
    private let replacementGate = PreviewSourceReplacementGate()
    #endif

    public init(
        runner: ExternalProcessRunner = ExternalProcessRunner(),
        commandBuilder: FFmpegAudioPreviewCommandBuilder = FFmpegAudioPreviewCommandBuilder()
    ) {
        self.runner = runner
        self.commandBuilder = commandBuilder
    }

    public func start(
        ffmpeg: URL,
        source: MultimediaAudioPreviewSource,
        from position: TimeInterval = 0,
        channelSelection: SpectrogramChannelSelection = .mix
    ) async throws {
        try await replaceSource(
            ffmpeg: ffmpeg,
            with: source,
            startingAt: position,
            channelSelection: channelSelection
        )
    }

    /// Sustituye la sesión vigente como una sola operación lógica. Cada petición invalida las
    /// anteriores antes de esperar el cierre de FFmpeg/AVAudioEngine, de modo que la última
    /// selección es la única autorizada para crear y publicar una sesión nueva.
    public func replaceSource(
        ffmpeg: URL,
        with source: MultimediaAudioPreviewSource,
        startingAt position: TimeInterval = 0,
        channelSelection: SpectrogramChannelSelection = .mix,
        preservePlaybackState: Bool = false
    ) async throws {
        #if canImport(AVFoundation)
        try Task.checkCancellation()
        guard source.fingerprint.matches(source.url) else {
            throw MultimediaInspectorError.inputChanged(source.title)
        }
        let shouldPlay = preservePlaybackState
            ? PreviewPlaybackContinuity.shouldPlayAfterReplacement(from: playbackState)
            : true
        let arguments = try commandBuilder.arguments(
            source: source,
            from: position,
            channelSelection: channelSelection
        )
        let outputChannels = commandBuilder.outputChannelCount(
            source: source,
            channelSelection: channelSelection
        )

        let resources = detachPlaybackResources(clearContext: true)
        let runner = self.runner
        let ticket = try await replacementGate.beginReplacement {
            try? await runner.cancel(gracePeriod: .milliseconds(250))
            await resources.finishCleanup()
        }
        try Task.checkCancellation()
        guard await replacementGate.isCurrent(ticket) else { throw CancellationError() }
        let clampedPosition = min(max(position, 0), source.duration ?? max(position, 0))
        playbackState = shouldPlay ? .loading : .paused
        terminalError = nil
        currentSource = source
        currentFFmpeg = ffmpeg
        currentChannel = channelSelection
        basePosition = clampedPosition

        // Una sustitución iniciada mientras la sesión estaba pausada deja preparada la nueva
        // fuente en el mismo instante, pero no arranca FFmpeg ni AVAudioEngine. Así se conserva
        // de verdad el estado Pausa y se evita reproducir un fragmento antes de volver a pausar.
        guard shouldPlay else { return }

        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: source.sampleRate,
            channels: AVAudioChannelCount(outputChannels)
        ) else {
            playbackState = .failed
            throw MultimediaInspectorError.previewUnavailable
        }

        let audioEngine = AVAudioEngine()
        let audioPlayer = AVAudioPlayerNode()
        let pitch = AVAudioUnitTimePitch()
        pitch.rate = playbackRate
        audioEngine.attach(audioPlayer)
        audioEngine.attach(pitch)
        audioEngine.connect(audioPlayer, to: pitch, format: format)
        audioEngine.connect(pitch, to: audioEngine.mainMixerNode, format: format)
        audioEngine.mainMixerNode.outputVolume = volume
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            playbackState = .failed
            terminalError = "No se ha podido iniciar la salida de audio."
            throw MultimediaInspectorError.previewUnavailable
        }

        let bufferScheduler = PreviewPCMBufferScheduler(
            player: audioPlayer,
            format: format,
            channels: outputChannels
        )
        engine = audioEngine
        player = audioPlayer
        timePitch = pitch
        scheduler = bufferScheduler
        audioPlayer.play()
        playbackState = .playing

        decodeTask = Task { [weak self] in
            do {
                try Task.checkCancellation()
                let result = try await runner.run(
                    .init(executable: ffmpeg, arguments: arguments),
                    onStdout: { bufferScheduler.append($0) }
                )
                if result.succeeded {
                    bufferScheduler.finish()
                    await self?.decodeCompleted(error: nil, ticket: ticket)
                } else {
                    bufferScheduler.cancel()
                    await self?.decodeCompleted(
                        error: MultimediaInspectorError.processFailed.localizedDescription,
                        ticket: ticket
                    )
                }
            } catch is CancellationError {
                bufferScheduler.cancel()
            } catch {
                bufferScheduler.cancel()
                await self?.decodeCompleted(
                    error: (error as? LocalizedError)?.errorDescription ?? "La previsualización de audio ha fallado.",
                    ticket: ticket
                )
            }
        }
        #else
        throw MultimediaInspectorError.previewUnavailable
        #endif
    }

    /// Pausar detiene también FFmpeg. Reanudar vuelve a abrir el stream desde la posición retenida,
    /// evitando mantener decodificación o buffers activos mientras el usuario no escucha.
    public func pause() async {
        #if canImport(AVFoundation)
        guard playbackState == .playing || playbackState == .loading else { return }
        let position = currentPosition()
        let resources = detachPlaybackResources(clearContext: false)
        let runner = self.runner
        await replacementGate.invalidate {
            try? await runner.cancel(gracePeriod: .milliseconds(250))
            await resources.finishCleanup()
        }
        basePosition = position
        playbackState = .paused
        terminalError = nil
        #endif
    }

    public func resume() async throws {
        #if canImport(AVFoundation)
        guard playbackState == .paused,
              let source = currentSource,
              let ffmpeg = currentFFmpeg else { return }
        let channel = currentChannel
        let position = basePosition
        try await start(ffmpeg: ffmpeg, source: source, from: position, channelSelection: channel)
        #else
        throw MultimediaInspectorError.previewUnavailable
        #endif
    }

    public func seek(to position: TimeInterval, preservePlaybackState: Bool = false) async throws {
        #if canImport(AVFoundation)
        guard let source = currentSource, let ffmpeg = currentFFmpeg else { return }
        let channel = currentChannel
        try await replaceSource(
            ffmpeg: ffmpeg,
            with: source,
            startingAt: position,
            channelSelection: channel,
            preservePlaybackState: preservePlaybackState
        )
        #else
        throw MultimediaInspectorError.previewUnavailable
        #endif
    }

    public func setVolume(_ value: Float) {
        #if canImport(AVFoundation)
        volume = min(max(value, 0), 1)
        engine?.mainMixerNode.outputVolume = volume
        #endif
    }

    public func setPlaybackRate(_ value: Float) {
        #if canImport(AVFoundation)
        playbackRate = min(max(value.isFinite ? value : 1, 0.5), 2)
        timePitch?.rate = playbackRate
        #endif
    }

    public func stop() async {
        #if canImport(AVFoundation)
        let resources = detachPlaybackResources(clearContext: true)
        let runner = self.runner
        await replacementGate.invalidate {
            try? await runner.cancel(gracePeriod: .milliseconds(250))
            await resources.finishCleanup()
        }
        playbackState = .idle
        terminalError = nil
        #endif
    }

    public func snapshot() -> MultimediaAudioPreviewSnapshot {
        #if canImport(AVFoundation)
        var position = currentPosition()
        if let duration = currentSource?.duration { position = min(position, duration) }
        if scheduler?.isDrained == true, playbackState == .playing {
            playbackState = terminalError == nil ? .finished : .failed
        }
        return .init(
            state: playbackState,
            position: position,
            duration: currentSource?.duration,
            sourceID: currentSource?.id,
            title: currentSource?.title,
            errorMessage: terminalError
        )
        #else
        return .idle
        #endif
    }

    #if canImport(AVFoundation)
    private func currentPosition() -> TimeInterval {
        var position = basePosition
        if let player,
           let renderTime = player.lastRenderTime,
           let playerTime = player.playerTime(forNodeTime: renderTime),
           playerTime.sampleRate > 0 {
            position += Double(playerTime.sampleTime) / playerTime.sampleRate
        }
        return max(position, 0)
    }

    private func detachPlaybackResources(clearContext: Bool) -> DetachedPreviewPlaybackResources {
        // Retira primero la sesión del estado compartido. Una limpieza que termine tarde solo
        // puede tocar estos recursos capturados y nunca el player/engine de una sesión posterior.
        let resources = DetachedPreviewPlaybackResources(
            decodeTask: decodeTask,
            scheduler: scheduler,
            player: player,
            timePitch: timePitch,
            engine: engine
        )
        decodeTask = nil
        scheduler = nil
        player = nil
        timePitch = nil
        engine = nil
        if clearContext {
            currentSource = nil
            currentFFmpeg = nil
            basePosition = 0
        }

        resources.cancelImmediately()
        return resources
    }

    private func decodeCompleted(error: String?, ticket: PreviewSourceReplacementGate.Ticket) async {
        guard await replacementGate.isCurrent(ticket) else { return }
        terminalError = error
        if error != nil { playbackState = .failed }
    }
    #endif
}

#if canImport(AVFoundation)
private final class DetachedPreviewPlaybackResources: @unchecked Sendable {
    private let decodeTask: Task<Void, Never>?
    private let scheduler: PreviewPCMBufferScheduler?
    private let player: AVAudioPlayerNode?
    private let timePitch: AVAudioUnitTimePitch?
    private let engine: AVAudioEngine?

    init(
        decodeTask: Task<Void, Never>?,
        scheduler: PreviewPCMBufferScheduler?,
        player: AVAudioPlayerNode?,
        timePitch: AVAudioUnitTimePitch?,
        engine: AVAudioEngine?
    ) {
        self.decodeTask = decodeTask
        self.scheduler = scheduler
        self.player = player
        self.timePitch = timePitch
        self.engine = engine
    }

    func cancelImmediately() {
        scheduler?.cancel()
        decodeTask?.cancel()
    }

    func finishCleanup() async {
        _ = await decodeTask?.result
        player?.stop()
        engine?.stop()
        if let player, let engine { engine.detach(player) }
        if let timePitch, let engine { engine.detach(timePitch) }
    }
}

private final class PreviewPCMBufferScheduler: @unchecked Sendable {
    private let player: AVAudioPlayerNode
    private let format: AVAudioFormat
    private let channels: Int
    private let slots = DispatchSemaphore(value: 6)
    private let lock = NSLock()
    private var residual = Data()
    private var cancelled = false
    private var decodeFinished = false
    private var outstanding = 0

    init(player: AVAudioPlayerNode, format: AVAudioFormat, channels: Int) {
        self.player = player
        self.format = format
        self.channels = channels
    }

    func append(_ data: Data) {
        guard !data.isEmpty else { return }
        let payload: Data = lock.withLock {
            guard !cancelled else { return Data() }
            if residual.isEmpty { return data }
            var combined = residual
            combined.append(data)
            residual.removeAll(keepingCapacity: true)
            return combined
        }
        guard !payload.isEmpty else { return }

        let bytesPerFrame = channels * MemoryLayout<Float>.size
        let usableBytes = payload.count - (payload.count % bytesPerFrame)
        if usableBytes < payload.count {
            lock.withLock {
                residual = Data(payload.suffix(payload.count - usableBytes))
            }
        }
        guard usableBytes > 0 else { return }

        slots.wait()
        if lock.withLock({ cancelled }) {
            slots.signal()
            return
        }

        let frameCount = usableBytes / bytesPerFrame
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(frameCount)
        ), let channelsData = buffer.floatChannelData else {
            slots.signal()
            return
        }
        buffer.frameLength = AVAudioFrameCount(frameCount)
        // `Data` no garantiza una alineación apropiada para enlazar directamente su memoria como
        // `Float`. Copiamos el bloque PCM a almacenamiento Float alineado antes de desinterlevarlo.
        var interleaved = [Float](repeating: 0, count: frameCount * channels)
        interleaved.withUnsafeMutableBytes { destination in
            payload.withUnsafeBytes { source in
                destination.copyMemory(from: UnsafeRawBufferPointer(rebasing: source[..<usableBytes]))
            }
        }
        interleaved.withUnsafeBufferPointer { samples in
            for frame in 0..<frameCount {
                let base = frame * channels
                for channel in 0..<channels {
                    channelsData[channel][frame] = samples[base + channel]
                }
            }
        }

        lock.withLock { outstanding += 1 }
        player.scheduleBuffer(buffer) { [weak self] in
            guard let self else { return }
            self.lock.withLock { self.outstanding = max(0, self.outstanding - 1) }
            self.slots.signal()
        }
    }

    func finish() {
        lock.withLock {
            decodeFinished = true
            residual.removeAll(keepingCapacity: false)
        }
    }

    func cancel() {
        let alreadyCancelled = lock.withLock { () -> Bool in
            if cancelled { return true }
            cancelled = true
            residual.removeAll(keepingCapacity: false)
            return false
        }
        if !alreadyCancelled {
            // Desbloquea cualquier callback de stdout que estuviera esperando back-pressure.
            for _ in 0..<8 { slots.signal() }
        }
    }

    var isDrained: Bool {
        lock.withLock { decodeFinished && outstanding == 0 }
    }
}
#endif
