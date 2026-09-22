import Foundation
import ZEUVECore
import ZEUVEOperations
import ZEUVEEngines

public struct FFmpegSignalAnalysisCommandBuilder: Sendable {
    public init() {}

    public func arguments(source: MultimediaAudioPreviewSource) -> [String] {
        [
            "-hide_banner", "-nostdin", "-v", "error",
            "-i", source.url.path,
            "-map", "0:\(source.streamIndex)", "-vn", "-sn", "-dn",
            "-f", "f32le", "-acodec", "pcm_f32le", "pipe:1",
        ]
    }
}

public actor AudioSignalAnalysisService {
    private let coordinator: OperationCoordinator
    private let engines: MultimediaEngineLocator
    private let runner: ExternalProcessRunner
    private let commandBuilder: FFmpegSignalAnalysisCommandBuilder
    private var activeOperationID: UUID?
    private var activeAccumulator: AudioSignalAnalysisAccumulator?

    public init(
        coordinator: OperationCoordinator,
        engineRegistry: EngineRegistry,
        diagnostics: EngineDiagnosticService? = nil,
        runner: ExternalProcessRunner = .init(),
        commandBuilder: FFmpegSignalAnalysisCommandBuilder = .init()
    ) {
        self.coordinator = coordinator
        engines = MultimediaEngineLocator(registry: engineRegistry, diagnostics: diagnostics)
        self.runner = runner
        self.commandBuilder = commandBuilder
    }

    public func analyze(
        source: MultimediaAudioPreviewSource,
        configuration: AudioSignalAnalysisConfiguration,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> AudioSignalAnalysisResult {
        guard source.fingerprint.matches(source.url) else {
            throw MultimediaInspectorError.inputChanged(source.title)
        }
        guard source.sampleRate.isFinite, source.sampleRate > 0, source.channels > 0 else {
            throw MultimediaInspectorError.invalidInput
        }
        let accumulator = try AudioSignalAnalysisAccumulator(
            sampleRate: source.sampleRate,
            channels: source.channels,
            configuration: configuration
        )
        let ffmpeg = try await engines.ffmpeg()
        let operationID = try await coordinator.begin(
            moduleID: multimediaInspectorModuleIdentifier,
            name: "Analizando señal de audio"
        )
        activeOperationID = operationID
        activeAccumulator = accumulator
        let duration = source.duration
        let progressTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if let duration, duration > 0 {
                    let fraction = min(max(accumulator.processedDuration / duration, 0), 0.99)
                    progress?(fraction)
                    try? await self.coordinator.update(
                        id: operationID,
                        progress: .init(
                            completed: Int((fraction * 1000).rounded()),
                            total: 1000,
                            phase: "Analizando silencios y posible clipping"
                        )
                    )
                }
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
        defer { progressTask.cancel() }

        let decoder = Float32LEStreamDecoder { accumulator.consume($0) }
        do {
            let processResult = try await withTaskCancellationHandler {
                try await runner.run(
                    .init(executable: ffmpeg, arguments: commandBuilder.arguments(source: source)),
                    onStdout: { decoder.append($0) }
                )
            } onCancel: {
                accumulator.cancel()
            }
            decoder.finish()
            try Task.checkCancellation()
            if await coordinator.shouldCancel(id: operationID) { throw MultimediaInspectorError.cancelled }
            guard processResult.succeeded else { throw MultimediaInspectorError.processFailed }
            guard source.fingerprint.matches(source.url) else {
                throw MultimediaInspectorError.inputChanged(source.title)
            }

            let result = accumulator.finish(sourceID: source.id)
            progress?(1)
            try? await coordinator.update(
                id: operationID,
                progress: .init(completed: 1000, total: 1000, phase: "Análisis de señal completado")
            )
            try await coordinator.finish(id: operationID)
            activeOperationID = nil
            activeAccumulator = nil
            return result
        } catch {
            accumulator.cancel()
            decoder.finish()
            try? await coordinator.finish(id: operationID)
            activeOperationID = nil
            activeAccumulator = nil
            if error is CancellationError { throw MultimediaInspectorError.cancelled }
            throw error
        }
    }

    public func cancel() async {
        activeAccumulator?.cancel()
        if let id = activeOperationID { try? await coordinator.requestCancellation(id: id) }
        try? await runner.cancel(gracePeriod: .milliseconds(250))
    }
}
