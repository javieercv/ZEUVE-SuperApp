import Foundation
import ZEUVEEngines
import ZEUVEOperations

struct SpectralAnomalyCandidate: Sendable, Equatable {
    var start: TimeInterval
    var end: TimeInterval
    var maximumSeverity: Double
    var severitySum: Double
    var sampleCount: Int
}

final class SpectralAnomalyAccumulator: @unchecked Sendable {
    private let maximumRetained: Int
    private let groupingGap: TimeInterval
    private var pending: SpectralAnomalyCandidate?
    private(set) var totalCount = 0
    private(set) var retained: [SpectralAnomaly] = []

    init(maximumRetained: Int = 256, groupingGap: TimeInterval = 0.12) {
        self.maximumRetained = max(maximumRetained, 1)
        self.groupingGap = max(groupingGap, 0)
    }

    func record(start: TimeInterval, end: TimeInterval, severity: Double) {
        let normalizedSeverity = min(max(severity, 0), 1)
        if var pending, start <= pending.end + groupingGap {
            pending.end = max(pending.end, end)
            pending.maximumSeverity = max(pending.maximumSeverity, normalizedSeverity)
            pending.severitySum += normalizedSeverity
            pending.sampleCount += 1
            self.pending = pending
        } else {
            finalizePending()
            pending = .init(
                start: start,
                end: end,
                maximumSeverity: normalizedSeverity,
                severitySum: normalizedSeverity,
                sampleCount: 1
            )
        }
    }

    func finish() -> (total: Int, retained: [SpectralAnomaly], truncated: Bool) {
        finalizePending()
        return (totalCount, retained.sorted { $0.start < $1.start }, totalCount > retained.count)
    }

    private func finalizePending() {
        guard let pending else { return }
        self.pending = nil
        totalCount += 1
        let average = pending.severitySum / Double(max(pending.sampleCount, 1))
        let anomaly = SpectralAnomaly(
            start: pending.start,
            end: pending.end,
            severity: max(pending.maximumSeverity, average),
            title: "Cambio espectral brusco",
            detail: "Varias ventanas próximas muestran un cambio excepcional del centroide espectral. El intervalo se agrupa para no contar repetidamente el mismo transitorio."
        )
        if retained.count < maximumRetained {
            retained.append(anomaly)
        } else if let weakest = retained.indices.min(by: { retained[$0].severity < retained[$1].severity }),
                  retained[weakest].severity < anomaly.severity {
            retained[weakest] = anomaly
        }
    }
}

final class AudioSourceQualityAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private let sampleRate: Double
    private let fftSize: Int
    private let hop: Int
    private let expectedDuration: TimeInterval?
    private let analyzer: SpectrogramFFTAnalyzer
    private var samples: [Float] = []
    private var processedSamples: Int64 = 0
    private var activeWindows = 0
    private var discardedWindows = 0
    private var broadbandWindows = 0
    private var rolloffHistogram: [Int]
    private var bandwidthHistogram: [Int]
    private var occupancyCounts: [Int]
    private var normalizedEnergySums: [Double]
    private var highRatioHistogram = [Int](repeating: 0, count: 512)
    private var activeSegments = Set<Int>()
    private var previousCentroid: Double?
    private let anomalyAccumulator = SpectralAnomalyAccumulator()

    init(sampleRate: Double, fftSize: Int = 4096, expectedDuration: TimeInterval? = nil) throws {
        self.sampleRate = sampleRate; self.fftSize = fftSize; self.hop = fftSize / 2
        self.expectedDuration = expectedDuration.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        self.analyzer = try SpectrogramFFTAnalyzer(fftSize: fftSize, window: .hann, dynamicRange: .init(minimumDB: -160, maximumDB: 12))
        let binCount = fftSize / 2 + 1
        self.rolloffHistogram = [Int](repeating: 0, count: binCount)
        self.bandwidthHistogram = [Int](repeating: 0, count: binCount)
        self.occupancyCounts = [Int](repeating: 0, count: binCount)
        self.normalizedEnergySums = [Double](repeating: 0, count: binCount)
    }

    func append(_ chunk: [Float]) {
        lock.withLock {
            samples.append(contentsOf: chunk)
            while samples.count >= fftSize {
                let window = Array(samples.prefix(fftSize))
                process(window)
                samples.removeFirst(min(hop, samples.count))
                processedSamples += Int64(hop)
            }
            if samples.count > fftSize * 2 { samples = Array(samples.suffix(fftSize)) }
        }
    }

    func finish() -> AudioSourceQualityAnalysis {
        lock.withLock {
            let duration = Double(processedSamples) / sampleRate
            let anomalySummary = anomalyAccumulator.finish()
            let minimumBroadbandWindows = max(4, Int((Double(activeWindows) * 0.05).rounded(.up)))
            guard activeWindows >= 4, broadbandWindows >= minimumBroadbandWindows else {
                let detail = activeWindows < 4
                    ? "No hay suficientes ventanas con señal útil para extraer un indicio fiable."
                    : "La señal no contiene suficiente ocupación espectral para estimar un límite de banda fiable; un tono o contenido muy estrecho no se interpreta como cutoff."
                return .init(
                    indication: .insufficientEvidence,
                    confidence: confidence(duration: duration, consistency: 0),
                    analyzedDuration: duration,
                    activeWindowCount: activeWindows,
                    discardedWindowCount: discardedWindows,
                    spectralRolloffHz: histogramFrequency(rolloffHistogram, quantile: 0.5),
                    effectiveBandwidthHz: nil,
                    persistentCutoffCandidateHz: nil,
                    highBandEnergyRatio: histogramRatio(highRatioHistogram, quantile: 0.5),
                    evidence: [.init(title: "Cobertura espectral insuficiente", detail: detail, weight: 0)],
                    totalAnomalyCount: anomalySummary.total,
                    anomalies: anomalySummary.retained,
                    anomaliesWereTruncated: anomalySummary.truncated
                )
            }

            let nyquist = sampleRate / 2
            let rolloff = histogramFrequency(rolloffHistogram, quantile: 0.5)
            let high = histogramRatio(highRatioHistogram, quantile: 0.5)
            let occupancy = occupancyCounts.map { Double($0) / Double(max(activeWindows, 1)) }
            let effectiveBin = highestSustainedBin(values: occupancy, threshold: 0.05)
            let effectiveBandwidth = effectiveBin.map { Double($0) * sampleRate / Double(fftSize) }
            let candidateBin = histogramIndex(bandwidthHistogram, quantile: 0.5)
            let stability: Double
            let dropDB: Double
            let persistentCutoff: Double?
            if let candidateBin {
                let tolerance = max(3, Int(Double(occupancy.count) * 0.015))
                let lower = max(candidateBin - tolerance, 0)
                let upper = min(candidateBin + tolerance, bandwidthHistogram.count - 1)
                let stableCount = bandwidthHistogram[lower ... upper].reduce(0, +)
                stability = Double(stableCount) / Double(max(broadbandWindows, 1))
                let lowerOccupancy = mean(occupancy, range: max(1, candidateBin - 32) ..< max(2, candidateBin - 3))
                let upperOccupancy = mean(occupancy, range: min(candidateBin + 8, occupancy.count) ..< min(candidateBin + 48, occupancy.count))
                let belowEnergy = mean(normalizedEnergySums, range: max(1, candidateBin - 32) ..< max(2, candidateBin - 3)) / Double(max(activeWindows, 1))
                let aboveEnergy = mean(normalizedEnergySums, range: min(candidateBin + 8, normalizedEnergySums.count) ..< min(candidateBin + 48, normalizedEnergySums.count)) / Double(max(activeWindows, 1))
                dropDB = 10 * log10(max(belowEnergy, 1e-15) / max(aboveEnergy, 1e-15))
                let farAbove = mean(occupancy, range: min(candidateBin + 8, occupancy.count) ..< occupancy.count)
                let isPersistent = Double(candidateBin) / Double(max(occupancy.count - 1, 1)) < 0.90 &&
                    stability >= 0.55 && lowerOccupancy >= 0.10 &&
                    upperOccupancy <= max(0.02, lowerOccupancy * 0.25) && farAbove <= 0.04 && dropDB >= 18
                persistentCutoff = isPersistent ? Double(candidateBin) * sampleRate / Double(fftSize) : nil
            } else {
                stability = 0
                dropDB = 0
                persistentCutoff = nil
            }

            var evidence: [AudioQualityEvidence] = []
            var score = 0.0
            if let persistentCutoff {
                let normalizedCutoff = persistentCutoff / max(nyquist, 1)
                let frequencySeverity = min(max((0.88 - normalizedCutoff) / 0.55, 0), 1)
                let depth = min(max(dropDB / 40, 0), 1)
                score = frequencySeverity * (0.50 + 0.25 * stability + 0.25 * depth)
                evidence.append(.init(
                    title: "Caída espectral persistente",
                    detail: "Se observa una caída sostenida alrededor de \(Int(persistentCutoff)) Hz, con persistencia temporal del \(Int((stability * 100).rounded())) % y poca ocupación por encima. Puede deberse al contenido, filtrado o una fuente con pérdida; por sí sola no demuestra una compresión previa.",
                    weight: score
                ))
            }
            let indication: AudioLossySourceIndication
            switch score {
            case ..<0.18: indication = .noClearIndications
            case ..<0.38: indication = .mild
            case ..<0.62: indication = .moderate
            default: indication = .strong
            }
            if evidence.isEmpty {
                evidence.append(.init(title: "Sin patrón concluyente", detail: "No se observa una caída espectral suficientemente profunda, continua y persistente para sugerir por sí sola una fuente previamente comprimida con pérdida.", weight: 0))
            }
            return .init(
                indication: indication,
                confidence: confidence(duration: duration, consistency: persistentCutoff == nil ? 1 : stability),
                analyzedDuration: duration,
                activeWindowCount: activeWindows,
                discardedWindowCount: discardedWindows,
                spectralRolloffHz: rolloff,
                effectiveBandwidthHz: effectiveBandwidth,
                persistentCutoffCandidateHz: persistentCutoff,
                highBandEnergyRatio: high,
                evidence: evidence,
                totalAnomalyCount: anomalySummary.total,
                anomalies: anomalySummary.retained,
                anomaliesWereTruncated: anomalySummary.truncated
            )
        }
    }

    private func process(_ input: [Float]) {
        let meanSquare = input.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(max(input.count, 1))
        let rmsDBFS = 10 * log10(max(meanSquare, 1e-15))
        guard rmsDBFS >= -75 else {
            discardedWindows += 1
            previousCentroid = nil
            return
        }
        let power = analyzer.analyzePower(input)
        let total = power.reduce(0.0) { $0 + Double($1) }
        guard total > 1e-12, let peak = power.max(), peak > 0 else {
            discardedWindows += 1
            previousCentroid = nil
            return
        }
        activeWindows += 1
        let binHz = sampleRate / Double(fftSize)
        var cumulative = 0.0
        var cutoff = 0.0
        var weighted = 0.0
        var highEnergy = 0.0
        let highStart = Int(Double(power.count - 1) * 0.75)
        var occupied = [Bool](repeating: false, count: power.count)
        for (i, value) in power.enumerated() {
            let p = Double(value)
            cumulative += p
            weighted += p * Double(i) * binHz
            if i >= highStart { highEnergy += p }
            if cutoff == 0, cumulative / total >= 0.995 { cutoff = Double(i) * binHz }
            let relativeDB = 10 * log10(max(p, 1e-20) / max(Double(peak), 1e-20))
            if i > 0, relativeDB >= -55 {
                occupied[i] = true
                occupancyCounts[i] += 1
            }
            normalizedEnergySums[i] += p / total
        }
        if cutoff == 0 { cutoff = sampleRate / 2 }
        let rolloffBin = min(max(Int((cutoff / binHz).rounded()), 0), rolloffHistogram.count - 1)
        rolloffHistogram[rolloffBin] += 1
        let highRatio = min(max(highEnergy / total, 0), 1)
        highRatioHistogram[min(Int((highRatio * Double(highRatioHistogram.count - 1)).rounded()), highRatioHistogram.count - 1)] += 1
        let occupiedCount = occupied.dropFirst().filter { $0 }.count
        if occupiedCount >= max(24, Int(Double(max(power.count - 1, 1)) * 0.025)),
           let edge = highestSustainedBin(flags: occupied) {
            broadbandWindows += 1
            bandwidthHistogram[edge] += 1
        }
        let centroid = weighted / total
        if let previousCentroid, previousCentroid > 100 {
            let ratio = abs(centroid - previousCentroid) / previousCentroid
            if ratio > 0.55 {
                let time = Double(processedSamples) / sampleRate
                anomalyAccumulator.record(start: time, end: time + Double(fftSize) / sampleRate, severity: min(1, ratio / 1.5))
            }
        }
        previousCentroid = centroid
        let time = Double(processedSamples) / sampleRate
        if let expectedDuration {
            activeSegments.insert(min(max(Int((time / expectedDuration) * 12), 0), 11))
        } else {
            activeSegments.insert(min(Int(time / 5), 11))
        }
    }

    private func histogramFrequency(_ histogram: [Int], quantile: Double) -> Double? {
        histogramIndex(histogram, quantile: quantile).map { Double($0) * sampleRate / Double(fftSize) }
    }

    private func histogramRatio(_ histogram: [Int], quantile: Double) -> Double? {
        histogramIndex(histogram, quantile: quantile).map { Double($0) / Double(max(histogram.count - 1, 1)) }
    }

    private func histogramIndex(_ histogram: [Int], quantile: Double) -> Int? {
        let total = histogram.reduce(0, +)
        guard total > 0 else { return nil }
        let target = max(Int((Double(total) * min(max(quantile, 0), 1)).rounded(.up)), 1)
        var cumulative = 0
        for (index, count) in histogram.enumerated() {
            cumulative += count
            if cumulative >= target { return index }
        }
        return histogram.indices.last
    }

    private func highestSustainedBin(flags: [Bool]) -> Int? {
        let values = flags.map { $0 ? 1.0 : 0.0 }
        return highestSustainedBin(values: values, threshold: 0.55)
    }

    private func highestSustainedBin(values: [Double], threshold: Double) -> Int? {
        guard values.count > 10 else { return nil }
        let radius = 4
        for index in stride(from: values.count - 1 - radius, through: 1 + radius, by: -1) {
            let local = values[(index - radius) ... (index + radius)].reduce(0, +) / Double(radius * 2 + 1)
            if local >= threshold { return min(index + radius, values.count - 1) }
        }
        return nil
    }

    private func mean(_ values: [Double], range: Range<Int>) -> Double {
        let lower = min(max(range.lowerBound, 0), values.count)
        let upper = min(max(range.upperBound, lower), values.count)
        guard upper > lower else { return 0 }
        return values[lower ..< upper].reduce(0, +) / Double(upper - lower)
    }

    private func confidence(duration: TimeInterval, consistency: Double) -> Double {
        let activeDuration = Double(activeWindows * hop) / sampleRate
        let durationFactor = min(max(activeDuration / 30, 0), 1)
        let coverage: Double
        if let expectedDuration {
            coverage = min(max(duration / expectedDuration, 0), 1)
        } else {
            coverage = durationFactor
        }
        let temporalCoverage = min(Double(activeSegments.count) / 12, 1)
        let usefulRatio = activeWindows > 0 ? Double(broadbandWindows) / Double(activeWindows) : 0
        let base = 0.30 * durationFactor + 0.30 * coverage + 0.20 * temporalCoverage + 0.20 * min(usefulRatio * 2, 1)
        return min(0.95, max(0, base * (0.70 + 0.30 * min(max(consistency, 0), 1))))
    }
}

public actor AudioSourceQualityAnalysisService {
    private let runner: ExternalProcessRunner
    private let coordinator: OperationCoordinator?
    private var operationID: UUID?

    public init(runner: ExternalProcessRunner = .init(), coordinator: OperationCoordinator? = nil) {
        self.runner = runner
        self.coordinator = coordinator
    }

    public func analyze(ffmpeg: URL, request: AudioSourceQualityRequest) async throws -> AudioSourceQualityAnalysis {
        guard request.fingerprint.matches(request.url) else { throw MultimediaInspectorError.inputChanged(request.url.lastPathComponent) }
        guard request.sampleRate.isFinite, request.sampleRate >= 8_000, request.channels > 0 else { throw MultimediaInspectorError.invalidInput }
        let activeID = try await coordinator?.begin(moduleID: multimediaInspectorModuleIdentifier, name: "Análisis espectral avanzado")
        operationID = activeID
        do {
            let accumulator = try AudioSourceQualityAccumulator(
                sampleRate: request.sampleRate,
                expectedDuration: request.duration
            )
            let decoder = Float32LEStreamDecoder { accumulator.append($0) }
            let args = [
                "-hide_banner", "-nostdin", "-v", "error", "-i", request.url.path,
                "-map", "0:\(request.streamIndex)", "-vn", "-sn", "-dn", "-ac", "1",
                "-ar", String(Int(request.sampleRate.rounded())), "-f", "f32le", "-acodec", "pcm_f32le", "pipe:1"
            ]
            let result = try await runner.run(.init(executable: ffmpeg, arguments: args), onStdout: { decoder.append($0) })
            decoder.finish()
            guard result.succeeded else { throw MultimediaInspectorError.processFailed }
            let output = accumulator.finish()
            if let activeID, let coordinator { try? await coordinator.finish(id: activeID) }
            operationID = nil
            return output
        } catch {
            if let activeID, let coordinator { try? await coordinator.finish(id: activeID) }
            operationID = nil
            throw error
        }
    }

    public func cancel() async {
        if let operationID, let coordinator { try? await coordinator.requestCancellation(id: operationID) }
        try? await runner.cancel()
    }
}
