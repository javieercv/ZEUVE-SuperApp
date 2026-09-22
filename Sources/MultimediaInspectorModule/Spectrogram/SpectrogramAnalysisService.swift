import Foundation
import ZEUVECore
import ZEUVEOperations
import ZEUVEEngines

public actor SpectrogramAnalysisService {
    private let coordinator: OperationCoordinator
    private let decoder: FFmpegPCMDecoder
    private let engines: MultimediaEngineLocator
    private var activeOperationID: UUID?
    private var activeAccumulator: SpectrogramAccumulator?
    public private(set) var lastAnalysisDiagnostics: SpectrogramDiagnostics?
    private var cache: [CacheEntry] = []
    private struct CacheEntry {
        let request: SpectrogramAnalysisRequest
        let fingerprint: FileFingerprint
        let result: SpectrogramResult
        var bytes: Int { result.columns.reduce(0) { $0 + $1.decibels.count * MemoryLayout<Float>.stride } }
    }

    public init(coordinator: OperationCoordinator, engineRegistry: EngineRegistry, diagnostics: EngineDiagnosticService? = nil) {
        self.coordinator = coordinator; decoder = .init(); engines = .init(registry: engineRegistry, diagnostics: diagnostics)
    }

    public func analyze(_ request: SpectrogramAnalysisRequest, onProgress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> SpectrogramResult {
        try Task.checkCancellation()
        guard request.url.isFileURL,
              request.streamIndex >= 0,
              request.sampleRate.isFinite, request.sampleRate > 0,
              request.channels > 0,
              request.fftSize >= 256 else { throw MultimediaInspectorError.invalidInput }
        var isolateChannel = false
        var dspRequest = request
        if request.channels > 2, case .channel(let channel) = request.channelSelection {
            guard (0..<request.channels).contains(channel) else { throw MultimediaInspectorError.invalidInput }
            isolateChannel = true
            dspRequest = .init(url: request.url, streamIndex: request.streamIndex, sampleRate: request.sampleRate,
                channels: 1, channelSelection: .channel(0), window: request.window, fftSize: request.fftSize,
                dynamicRange: request.dynamicRange, startTime: request.startTime, duration: request.duration,
                maximumColumns: request.maximumColumns)
        }
        let accumulator = try SpectrogramAccumulator(request: dspRequest, onProgress: onProgress)
        let fingerprint = try FileFingerprint.read(from: request.url)
        var key = request
        key.dynamicRange = .init() // Rango = interpretación; no forma parte del análisis.
        cache.removeAll { $0.request.url == key.url && $0.fingerprint != fingerprint }
        if let index = cache.firstIndex(where: { $0.request == key && $0.fingerprint == fingerprint }) {
            let entry = cache.remove(at: index); cache.append(entry)
            lastAnalysisDiagnostics = .init(fftExecutions: 0, pcmFrames: 0, columns: entry.result.columns.count, processedChannels: 0, decodedDuration: 0)
            onProgress(1)
            return entry.result.displaying(dynamicRange: request.dynamicRange)
        }
        let paths = try await engines.paths()
        try Task.checkCancellation()
        let id = try await coordinator.begin(moduleID: multimediaInspectorModuleIdentifier, name: "Analizando espectrograma")
        activeOperationID = id; activeAccumulator = accumulator
        do {
            try await withTaskCancellationHandler {
                try await decoder.decode(ffmpeg: paths.ffmpeg, request: request, isolateSelectedChannel: isolateChannel, onPCM: { accumulator.consume($0) })
            } onCancel: { accumulator.cancel() }
            try Task.checkCancellation()
            if await coordinator.shouldCancel(id: id) { throw MultimediaInspectorError.cancelled }
            onProgress(0.97)
            let result = accumulator.finish()
            guard fingerprint.matches(request.url) else { throw MultimediaInspectorError.invalidInput }
            lastAnalysisDiagnostics = accumulator.diagnostics
            try await coordinator.finish(id: id)
            activeOperationID = nil; activeAccumulator = nil
            cache.append(.init(request: key, fingerprint: fingerprint, result: result))
            while cache.count > 4 || cache.reduce(0, { $0 + $1.bytes }) > SpectrogramAnalysisPlanner.maximumModelBytes { cache.removeFirst() }
            onProgress(1)
            return result
        } catch {
            accumulator.cancel()
            try? await coordinator.finish(id: id)
            activeOperationID = nil; activeAccumulator = nil
            if error is CancellationError { throw MultimediaInspectorError.cancelled }
            throw error
        }
    }
    public func clearCache() { cache.removeAll() }
    public func cancel() async {
        activeAccumulator?.cancel()
        if let id = activeOperationID { try? await coordinator.requestCancellation(id: id) }
        await decoder.cancel()
    }
}
