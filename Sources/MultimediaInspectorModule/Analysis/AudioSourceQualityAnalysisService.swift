import Foundation
import ZEUVEEngines
import ZEUVEOperations

private final class AudioSourceQualityAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private let sampleRate: Double
    private let fftSize: Int
    private let hop: Int
    private let analyzer: SpectrogramFFTAnalyzer
    private var samples: [Float] = []
    private var processedSamples: Int64 = 0
    private var windows = 0
    private var cutoffValues: [Double] = []
    private var highRatios: [Double] = []
    private var previousCentroid: Double?
    private var anomalies: [SpectralAnomaly] = []

    init(sampleRate: Double, fftSize: Int = 4096) throws {
        self.sampleRate = sampleRate; self.fftSize = fftSize; self.hop = fftSize / 2
        self.analyzer = try SpectrogramFFTAnalyzer(fftSize: fftSize, window: .hann, dynamicRange: .init(minimumDB: -160, maximumDB: 12))
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
            guard windows >= 4 else {
                return .init(indication: .insufficientEvidence, confidence: 0, analyzedDuration: duration, effectiveBandwidthHz: nil, highBandEnergyRatio: nil, evidence: [.init(title: "Cobertura insuficiente", detail: "No hay suficientes ventanas espectrales para extraer un indicio fiable.", weight: 0)], anomalies: anomalies)
            }
            let cutoff = median(cutoffValues)
            let high = median(highRatios)
            var evidence: [AudioQualityEvidence] = []
            var score = 0.0
            let nyquist = sampleRate / 2
            if cutoff < nyquist * 0.72 {
                let severity = min(1, (nyquist * 0.72 - cutoff) / max(nyquist * 0.35, 1))
                score += 0.50 * severity
                evidence.append(.init(title: "Ancho de banda efectivo reducido", detail: "La energía útil cae de forma persistente alrededor de \(Int(cutoff)) Hz frente a un Nyquist de \(Int(nyquist)) Hz. Por sí solo no demuestra una compresión previa.", weight: severity))
            }
            if high < 0.002 && sampleRate >= 44_100 {
                let severity = min(1, (0.002 - high) / 0.002)
                score += 0.30 * severity
                evidence.append(.init(title: "Muy poca energía en la banda alta", detail: "La fracción mediana de energía del 75–100 % de la banda analizada es \(String(format: "%.4f", high * 100)) %. Puede deberse al contenido, filtrado o a una fuente con pérdida.", weight: severity))
            }
            let stability = cutoffStability(cutoffValues, center: cutoff)
            if stability > 0.8 && cutoff < nyquist * 0.8 {
                score += 0.20 * stability
                evidence.append(.init(title: "Corte espectral persistente", detail: "El límite de banda permanece estable durante gran parte del material, lo que refuerza el indicio sin convertirlo en una certeza.", weight: stability))
            }
            let indication: AudioLossySourceIndication
            switch score {
            case ..<0.18: indication = .noClearIndications
            case ..<0.38: indication = .mild
            case ..<0.62: indication = .moderate
            default: indication = .strong
            }
            if evidence.isEmpty { evidence.append(.init(title: "Sin patrón concluyente", detail: "No se observa un patrón espectral suficientemente consistente para sugerir una fuente previamente comprimida con pérdida.", weight: 0)) }
            return .init(indication: indication, confidence: min(0.95, max(0.25, Double(windows) / 120) * min(1, 0.5 + stability * 0.5)), analyzedDuration: duration, effectiveBandwidthHz: cutoff, highBandEnergyRatio: high, evidence: evidence, anomalies: anomalies)
        }
    }

    private func process(_ input: [Float]) {
        let power = analyzer.analyzePower(input)
        let total = power.reduce(0.0) { $0 + Double($1) }
        guard total > 1e-12 else { return }
        windows += 1
        let binHz = sampleRate / Double(fftSize)
        var cumulative = 0.0
        var cutoff = 0.0
        var weighted = 0.0
        var highEnergy = 0.0
        let highStart = Int(Double(power.count - 1) * 0.75)
        for (i, value) in power.enumerated() {
            let p = Double(value)
            cumulative += p
            weighted += p * Double(i) * binHz
            if i >= highStart { highEnergy += p }
            if cutoff == 0, cumulative / total >= 0.995 { cutoff = Double(i) * binHz }
        }
        if cutoff == 0 { cutoff = sampleRate / 2 }
        cutoffValues.append(cutoff)
        highRatios.append(highEnergy / total)
        let centroid = weighted / total
        if let previousCentroid, previousCentroid > 100 {
            let ratio = abs(centroid - previousCentroid) / previousCentroid
            if ratio > 0.55, anomalies.count < 256 {
                let time = Double(processedSamples) / sampleRate
                anomalies.append(.init(start: time, end: time + Double(fftSize) / sampleRate, severity: min(1, ratio / 1.5), title: "Cambio espectral brusco", detail: "El centroide espectral cambia de forma excepcional respecto a la ventana anterior."))
            }
        }
        previousCentroid = centroid
        if cutoffValues.count > 4096 { cutoffValues.removeFirst(cutoffValues.count - 4096) }
        if highRatios.count > 4096 { highRatios.removeFirst(highRatios.count - 4096) }
    }

    private func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted(); let m = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[m-1] + sorted[m]) / 2 : sorted[m]
    }

    private func cutoffStability(_ values: [Double], center: Double) -> Double {
        guard !values.isEmpty, center > 0 else { return 0 }
        let within = values.filter { abs($0 - center) / center <= 0.08 }.count
        return Double(within) / Double(values.count)
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
            let accumulator = try AudioSourceQualityAccumulator(sampleRate: request.sampleRate)
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
