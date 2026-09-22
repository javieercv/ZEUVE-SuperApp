import Foundation
import ZEUVECore
import ZEUVEOperations
import ZEUVEEngines

public actor MultimediaBatchProcessor {
    public typealias ProgressHandler = @Sendable (_ status: MultimediaBatchItemStatus, _ phase: String, _ fraction: Double?) -> Void

    private let coordinator: OperationCoordinator
    private let inspector: MediaInspectionService
    private let engines: MultimediaEngineLocator
    private let signalService: AudioSignalAnalysisService
    private let loudnessService: AudioLoudnessAnalysisService
    private let spectrogramService: SpectrogramAnalysisService
    private let spectrogramExportService: SpectrogramExportService
    private let reportExporter: MultimediaTechnicalReportExporter
    private var cancellationRequested = false

    public init(
        coordinator: OperationCoordinator,
        engineRegistry: EngineRegistry,
        diagnostics: EngineDiagnosticService? = nil,
        history: MultimediaInspectorHistoryService,
        inspector: MediaInspectionService = .init(),
        reportExporter: MultimediaTechnicalReportExporter = .init()
    ) {
        self.coordinator = coordinator
        self.inspector = inspector
        engines = MultimediaEngineLocator(registry: engineRegistry, diagnostics: diagnostics)
        signalService = AudioSignalAnalysisService(coordinator: coordinator, engineRegistry: engineRegistry, diagnostics: diagnostics)
        loudnessService = AudioLoudnessAnalysisService(coordinator: coordinator, engineRegistry: engineRegistry, diagnostics: diagnostics)
        spectrogramService = SpectrogramAnalysisService(coordinator: coordinator, engineRegistry: engineRegistry, diagnostics: diagnostics)
        spectrogramExportService = SpectrogramExportService(coordinator: coordinator, history: history)
        self.reportExporter = reportExporter
    }

    public func resetCancellation() {
        cancellationRequested = false
    }

    public func process(
        item: MultimediaBatchItem,
        configuration rawConfiguration: MultimediaBatchConfiguration,
        outputDirectory: URL?,
        protectedOriginals: [URL],
        progress: @escaping ProgressHandler = { _, _, _ in }
    ) async throws -> MultimediaBatchProcessOutcome {
        try checkCancellation()
        guard item.fingerprint.matches(item.url) else {
            throw MultimediaInspectorError.inputChanged(item.url.lastPathComponent)
        }
        var normalizedConfiguration = rawConfiguration
        normalizedConfiguration.normalize()
        let configuration = normalizedConfiguration
        progress(.inspecting, "Inspeccionando con FFprobe…", nil)
        let ffprobe = try await engines.ffprobe()
        let inspection = try await inspector.inspect(url: item.url, ffprobe: ffprobe, fingerprint: item.fingerprint, useCache: false)
        try checkCancellation()
        guard item.fingerprint.matches(item.url) else {
            throw MultimediaInspectorError.inputChanged(item.url.lastPathComponent)
        }

        let summary = MultimediaBatchInspectionSummary(
            container: inspection.format?.format_long_name ?? inspection.format?.format_name,
            durationSeconds: inspection.durationSeconds,
            videoStreams: inspection.videoStreams.count,
            audioStreams: inspection.audioStreams.count,
            subtitleStreams: inspection.subtitleStreams.count
        )
        guard !inspection.streams.isEmpty else {
            return .skipped(summary, reason: "No contiene streams multimedia compatibles.")
        }

        let requiresOutput = configuration.exportSpectrogram || configuration.reportFormat != nil
        if requiresOutput, outputDirectory == nil { throw MultimediaInspectorError.invalidInput }

        var warnings: [String] = []
        var generatedOutputs: [URL] = []
        var signalItems: [AudioSignalReportItem] = []
        var loudnessItems: [AudioLoudnessReportItem] = []
        var spectrogramResult: SpectrogramResult?

        let audioStream = inspection.audioStreams.count == 1 ? inspection.audioStreams[0] : nil
        let wantsAudioAnalysis = configuration.analyzeSignal || configuration.analyzeLoudness || configuration.exportSpectrogram
        if wantsAudioAnalysis, inspection.audioStreams.count > 1 {
            warnings.append("Se omitió el análisis automático de audio porque existen varias pistas; ZEUVE no selecciona una silenciosamente.")
        } else if wantsAudioAnalysis, inspection.audioStreams.isEmpty {
            warnings.append("Se omitió el análisis de audio porque el archivo no contiene pistas de audio.")
        }

        if let stream = audioStream, wantsAudioAnalysis {
            let source = try makeSource(url: item.url, fingerprint: item.fingerprint, stream: stream, inspection: inspection)
            let label = reportLabel(stream: stream)

            if configuration.analyzeSignal {
                progress(.analyzingSignal, "Analizando silencios y posible clipping…", 0)
                let signalConfiguration = AudioSignalAnalysisConfiguration(
                    silenceThresholdDBFS: configuration.signalSilenceThresholdDBFS,
                    minimumSilenceDuration: configuration.signalMinimumSilenceDuration,
                    clippingThresholdDBFS: configuration.signalClippingThresholdDBFS,
                    minimumConsecutiveClippedSamples: configuration.signalMinimumConsecutiveClippedSamples
                )
                let result = try await runWhenCoordinatorIsFree(progress: progress) {
                    try await self.signalService.analyze(source: source, configuration: signalConfiguration) { fraction in
                        progress(.analyzingSignal, "Analizando silencios y posible clipping…", fraction)
                    }
                }
                signalItems = [.init(label: label, result: result)]
            }

            if configuration.analyzeLoudness {
                progress(.analyzingLoudness, "Analizando sonoridad EBU R128…", 0)
                let result = try await runWhenCoordinatorIsFree(progress: progress) {
                    try await self.loudnessService.analyze(source: source) { fraction in
                        progress(.analyzingLoudness, "Analizando sonoridad EBU R128…", fraction)
                    }
                }
                loudnessItems = [.init(label: label, result: result)]
            }

            if configuration.exportSpectrogram {
                guard let sampleRate = stream.sampleRateValue, let channels = stream.channels, let index = stream.index else {
                    warnings.append("No se pudo generar el espectrograma porque la pista no declara sample rate o canales válidos.")
                    spectrogramResult = nil
                    if configuration.reportFormat == nil {
                        return .completed(.init(summary: summary, warning: warnings.joined(separator: " "), generatedOutputs: generatedOutputs))
                    }
                    return try await finishReportOnly(
                        item: item,
                        inspection: inspection,
                        summary: summary,
                        configuration: configuration,
                        outputDirectory: outputDirectory,
                        protectedOriginals: protectedOriginals,
                        signalItems: signalItems,
                        loudnessItems: loudnessItems,
                        warnings: warnings,
                        generatedOutputs: generatedOutputs,
                        progress: progress
                    )
                }
                progress(.generatingSpectrogram, "Generando espectrograma…", 0)
                let request = SpectrogramAnalysisRequest(
                    url: item.url,
                    streamIndex: index,
                    sampleRate: sampleRate,
                    channels: channels,
                    channelSelection: configuration.spectrogramChannel == .mix ? .mix : .channel(0),
                    window: configuration.spectrogramWindow,
                    fftSize: configuration.spectrogramFFTSize,
                    dynamicRange: .init(
                        minimumDB: configuration.spectrogramDynamicRange.lowerBound,
                        maximumDB: configuration.spectrogramDynamicRange.upperBound
                    ),
                    duration: inspection.durationSeconds,
                    maximumColumns: configuration.spectrogramMaximumColumns
                )
                spectrogramResult = try await runWhenCoordinatorIsFree(progress: progress) {
                    try await self.spectrogramService.analyze(request) { fraction in
                        progress(.generatingSpectrogram, "Generando espectrograma…", fraction)
                    }
                }
                try checkCancellation()
                guard item.fingerprint.matches(item.url) else { throw MultimediaInspectorError.inputChanged(item.url.lastPathComponent) }
                if let spectrogramResult, let outputDirectory {
                    progress(.exporting, "Exportando espectrograma PNG…", nil)
                    let proposed = MultimediaBatchOutputPolicy().spectrogramURL(for: item.url, directory: outputDirectory)
                    let exported = try await runWhenCoordinatorIsFree(progress: progress) {
                        try await self.spectrogramExportService.export(
                            result: spectrogramResult,
                            frequencyScale: configuration.spectrogramFrequencyScale,
                            proposedOutput: proposed,
                            protectedOriginals: protectedOriginals,
                            width: configuration.spectrogramExportWidth,
                            height: configuration.spectrogramExportHeight,
                            recordHistory: false
                        )
                    }
                    generatedOutputs.append(exported.outputURL)
                    if let warning = exported.historyWarning { warnings.append(warning) }
                }
            }
        }

        return try await finishReportOnly(
            item: item,
            inspection: inspection,
            summary: summary,
            configuration: configuration,
            outputDirectory: outputDirectory,
            protectedOriginals: protectedOriginals,
            signalItems: signalItems,
            loudnessItems: loudnessItems,
            warnings: warnings,
            generatedOutputs: generatedOutputs,
            progress: progress
        )
    }

    private func finishReportOnly(
        item: MultimediaBatchItem,
        inspection: MediaInspectionResult,
        summary: MultimediaBatchInspectionSummary,
        configuration: MultimediaBatchConfiguration,
        outputDirectory: URL?,
        protectedOriginals: [URL],
        signalItems: [AudioSignalReportItem],
        loudnessItems: [AudioLoudnessReportItem],
        warnings: [String],
        generatedOutputs: [URL],
        progress: @escaping ProgressHandler
    ) async throws -> MultimediaBatchProcessOutcome {
        var outputs = generatedOutputs
        if let format = configuration.reportFormat, let outputDirectory {
            try checkCancellation()
            progress(.exporting, "Exportando informe técnico…", nil)
            let context = MultimediaTechnicalReportContext(
                fileName: item.url.lastPathComponent,
                inspection: inspection,
                timing: AudioTimingAnalyzer().analyze(inspection),
                loudness: loudnessItems,
                signal: signalItems
            )
            let proposed = MultimediaBatchOutputPolicy().reportURL(for: item.url, format: format, directory: outputDirectory)
            let output = try reportExporter.export(
                context: context,
                format: format,
                proposedOutput: proposed,
                protectedOriginals: protectedOriginals,
                sections: configuration.reportSections
            )
            outputs.append(output)
        }
        try checkCancellation()
        guard item.fingerprint.matches(item.url) else { throw MultimediaInspectorError.inputChanged(item.url.lastPathComponent) }
        if configuration.exportSpectrogram {
            await spectrogramService.clearCache()
        }
        return .completed(.init(summary: summary, warning: warnings.isEmpty ? nil : warnings.joined(separator: " "), generatedOutputs: outputs))
    }

    private func makeSource(
        url: URL,
        fingerprint: FileFingerprint,
        stream: MediaInspectionStream,
        inspection: MediaInspectionResult
    ) throws -> MultimediaAudioPreviewSource {
        guard let index = stream.index, let sampleRate = stream.sampleRateValue, let channels = stream.channels, sampleRate > 0, channels > 0 else {
            throw MultimediaInspectorError.invalidInput
        }
        return MultimediaAudioPreviewSource(
            url: url,
            fingerprint: fingerprint,
            streamIndex: index,
            sampleRate: sampleRate,
            channels: channels,
            duration: stream.durationSeconds ?? inspection.durationSeconds,
            channelLayout: stream.channel_layout,
            title: reportLabel(stream: stream)
        )
    }

    private func reportLabel(stream: MediaInspectionStream) -> String {
        let values = [stream.language, stream.title, stream.codec_name?.uppercased()].compactMap { raw -> String? in
            guard let raw, !raw.isEmpty else { return nil }
            return raw
        }
        return values.isEmpty ? "Pista de audio" : values.joined(separator: " · ")
    }

    private func runWhenCoordinatorIsFree<T: Sendable>(
        progress: @escaping ProgressHandler,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        while true {
            try checkCancellation()
            if let active = await coordinator.current() {
                progress(.waiting, "Esperando a que termine «\(active.name)»…", nil)
                try await Task.sleep(for: .milliseconds(200))
                continue
            }
            do {
                return try await operation()
            } catch OperationCoordinatorError.busy {
                progress(.waiting, "Esperando a que termine la operación actual…", nil)
                try await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    public func cancel() async {
        cancellationRequested = true
        await inspector.cancel()
        await signalService.cancel()
        await loudnessService.cancel()
        await spectrogramService.cancel()
        await spectrogramExportService.cancel()
    }

    private func checkCancellation() throws {
        if cancellationRequested || Task.isCancelled { throw MultimediaInspectorError.cancelled }
    }
}
