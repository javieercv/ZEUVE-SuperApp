import Foundation
import ZEUVECore
import ZEUVEOperations
import ZEUVEEngines

public struct AudioLoudnessResult: Sendable, Equatable, Codable {
    public let sourceID: String
    public let integratedLUFS: Double?
    public let loudnessRangeLU: Double?
    public let truePeakDBTP: Double?
    public let samplePeakDBFS: Double?
    public let durationAnalyzed: TimeInterval?
    public let timeline: AudioLoudnessTimeline?

    public init(
        sourceID: String,
        integratedLUFS: Double?,
        loudnessRangeLU: Double?,
        truePeakDBTP: Double?,
        samplePeakDBFS: Double?,
        durationAnalyzed: TimeInterval?,
        timeline: AudioLoudnessTimeline? = nil
    ) {
        self.sourceID = sourceID
        self.integratedLUFS = integratedLUFS
        self.loudnessRangeLU = loudnessRangeLU
        self.truePeakDBTP = truePeakDBTP
        self.samplePeakDBFS = samplePeakDBFS
        self.durationAnalyzed = durationAnalyzed
        self.timeline = timeline
    }
}

public struct FFmpegLoudnessCommandBuilder: Sendable {
    public init() {}

    public func arguments(source: MultimediaAudioPreviewSource) -> [String] {
        [
            "-hide_banner", "-nostdin", "-nostats", "-v", "info",
            "-i", source.url.path,
            "-map", "0:\(source.streamIndex)", "-vn", "-sn", "-dn",
            "-af", "ebur128=peak=true,astats=metadata=0:reset=0:measure_perchannel=none:measure_overall=Peak_level",
            "-f", "null", "-",
        ]
    }
}

public struct AudioLoudnessParser: Sendable {
    public init() {}

    public func parse(lines: [String], sourceID: String, fallbackDuration: TimeInterval? = nil) -> AudioLoudnessResult? {
        let collector = LoudnessLineCollector()
        for line in lines { collector.consume(line: line) }
        return collector.result(sourceID: sourceID, fallbackDuration: fallbackDuration)
    }
}

public actor AudioLoudnessAnalysisService {
    private let coordinator: OperationCoordinator
    private let engines: MultimediaEngineLocator
    private let runner: ExternalProcessRunner
    private let commandBuilder: FFmpegLoudnessCommandBuilder
    private var activeOperationID: UUID?

    public init(
        coordinator: OperationCoordinator,
        engineRegistry: EngineRegistry,
        diagnostics: EngineDiagnosticService? = nil,
        runner: ExternalProcessRunner = .init(),
        commandBuilder: FFmpegLoudnessCommandBuilder = .init()
    ) {
        self.coordinator = coordinator
        engines = MultimediaEngineLocator(registry: engineRegistry, diagnostics: diagnostics)
        self.runner = runner
        self.commandBuilder = commandBuilder
    }

    public func analyze(
        source: MultimediaAudioPreviewSource,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> AudioLoudnessResult {
        guard source.fingerprint.matches(source.url) else { throw MultimediaInspectorError.inputChanged(source.title) }
        guard source.sampleRate.isFinite, source.sampleRate > 0, source.channels > 0 else {
            throw MultimediaInspectorError.invalidInput
        }
        let ffmpeg = try await engines.ffmpeg()
        let operationID = try await coordinator.begin(moduleID: multimediaInspectorModuleIdentifier, name: "Analizando sonoridad")
        activeOperationID = operationID
        let collector = LoudnessLineCollector()
        let decoder = IncrementalLineDecoder(maximumBufferedBytes: 256 * 1024)
        let duration = source.duration
        let progressTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if let duration, duration > 0, let seconds = collector.lastObservedTime {
                    let fraction = min(max(seconds / duration, 0), 0.99)
                    progress?(fraction)
                    try? await self.coordinator.update(
                        id: operationID,
                        progress: .init(completed: Int((fraction * 1000).rounded()), total: 1000, phase: "Analizando sonoridad")
                    )
                }
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
        defer { progressTask.cancel() }

        do {
            let result = try await runner.run(
                .init(executable: ffmpeg, arguments: commandBuilder.arguments(source: source)),
                onStderr: { data in
                    if let lines = try? decoder.append(data) {
                        for line in lines { collector.consume(line: line) }
                    }
                }
            )
            if let tail = decoder.finish() { collector.consume(line: tail) }
            try Task.checkCancellation()
            if await coordinator.shouldCancel(id: operationID) { throw MultimediaInspectorError.cancelled }
            guard result.succeeded else { throw MultimediaInspectorError.processFailed }
            guard let parsed = collector.result(sourceID: source.id, fallbackDuration: source.duration) else {
                throw MultimediaInspectorError.inspectionFailed
            }
            progress?(1)
            try? await coordinator.update(id: operationID, progress: .init(completed: 1000, total: 1000, phase: "Sonoridad completada"))
            try await coordinator.finish(id: operationID)
            activeOperationID = nil
            return parsed
        } catch {
            try? await coordinator.finish(id: operationID)
            activeOperationID = nil
            if error is CancellationError { throw MultimediaInspectorError.cancelled }
            throw error
        }
    }

    public func cancel() async {
        if let id = activeOperationID { try? await coordinator.requestCancellation(id: id) }
        try? await runner.cancel(gracePeriod: .milliseconds(250))
    }
}

private final class LoudnessLineCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var integrated: Double?
    private var lra: Double?
    private var truePeak: Double?
    private var samplePeak: Double?
    private var observedTime: TimeInterval?
    private let timelineAccumulator = AudioLoudnessTimelineAccumulator()

    var lastObservedTime: TimeInterval? { lock.withLock { observedTime } }

    func consume(line: String) {
        let payload: String = {
            if let bracket = line.lastIndex(of: "]") { return String(line[line.index(after: bracket)...]).trimmingCharacters(in: .whitespaces) }
            return line.trimmingCharacters(in: .whitespaces)
        }()
        lock.withLock {
            if let value = Self.value(after: "I:", in: payload), payload.hasPrefix("I:") { integrated = value }
            if let value = Self.value(after: "LRA:", in: payload), payload.hasPrefix("LRA:") { lra = value }
            if let value = Self.value(after: "Peak:", in: payload), payload.hasPrefix("Peak:") { truePeak = value }
            if let value = Self.value(after: "Peak level dB:", in: payload), payload.contains("Peak level dB:") { samplePeak = value }
            if let time = Self.value(after: "t:", in: payload), time >= 0 {
                observedTime = time
                if payload.contains("M:") || payload.contains("S:") {
                    timelineAccumulator.append(
                        time: time,
                        momentary: Self.value(after: "M:", in: payload),
                        shortTerm: Self.value(after: "S:", in: payload),
                        integrated: Self.value(after: "I:", in: payload)
                    )
                }
            }
        }
    }

    func result(sourceID: String, fallbackDuration: TimeInterval?) -> AudioLoudnessResult? {
        lock.withLock {
            let duration = observedTime ?? fallbackDuration
            let timeline = timelineAccumulator.finish(duration: duration)
            guard integrated != nil || lra != nil || truePeak != nil || samplePeak != nil || timeline != nil else { return nil }
            return AudioLoudnessResult(
                sourceID: sourceID,
                integratedLUFS: integrated,
                loudnessRangeLU: lra,
                truePeakDBTP: truePeak,
                samplePeakDBFS: samplePeak,
                durationAnalyzed: duration,
                timeline: timeline
            )
        }
    }

    private static func value(after marker: String, in line: String) -> Double? {
        guard let range = line.range(of: marker) else { return nil }
        let remainder = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
        let token = remainder.split(whereSeparator: { $0 == " " || $0 == "\t" }).first.map(String.init)
        guard let token, token.uppercased() != "-INF", token.uppercased() != "INF", let value = Double(token), value.isFinite else { return nil }
        return value
    }
}
