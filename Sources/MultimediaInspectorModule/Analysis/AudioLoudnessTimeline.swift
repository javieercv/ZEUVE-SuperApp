import Foundation

/// Muestra temporal compactable de EBU R128. Los valores representativos son medias
/// ponderadas y los extremos conservan los picos de los puntos que se hayan fusionado.
public struct AudioLoudnessTimelineSample: Sendable, Equatable, Codable, Identifiable {
    public let time: TimeInterval
    public let momentaryLUFS: Double?
    public let shortTermLUFS: Double?
    public let integratedLUFS: Double?
    public let momentaryMinimumLUFS: Double?
    public let momentaryMaximumLUFS: Double?
    public let shortTermMinimumLUFS: Double?
    public let shortTermMaximumLUFS: Double?
    public let sampleCount: Int

    public var id: TimeInterval { time }

    public init(
        time: TimeInterval,
        momentaryLUFS: Double?,
        shortTermLUFS: Double?,
        integratedLUFS: Double?,
        momentaryMinimumLUFS: Double? = nil,
        momentaryMaximumLUFS: Double? = nil,
        shortTermMinimumLUFS: Double? = nil,
        shortTermMaximumLUFS: Double? = nil,
        sampleCount: Int = 1
    ) {
        self.time = max(time.isFinite ? time : 0, 0)
        self.momentaryLUFS = Self.finite(momentaryLUFS)
        self.shortTermLUFS = Self.finite(shortTermLUFS)
        self.integratedLUFS = Self.finite(integratedLUFS)
        self.momentaryMinimumLUFS = Self.finite(momentaryMinimumLUFS) ?? Self.finite(momentaryLUFS)
        self.momentaryMaximumLUFS = Self.finite(momentaryMaximumLUFS) ?? Self.finite(momentaryLUFS)
        self.shortTermMinimumLUFS = Self.finite(shortTermMinimumLUFS) ?? Self.finite(shortTermLUFS)
        self.shortTermMaximumLUFS = Self.finite(shortTermMaximumLUFS) ?? Self.finite(shortTermLUFS)
        self.sampleCount = max(sampleCount, 1)
    }

    private static func finite(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        return value
    }
}

public struct AudioLoudnessTimeline: Sendable, Equatable, Codable {
    public let samples: [AudioLoudnessTimelineSample]
    public let durationAnalyzed: TimeInterval?

    public init(samples: [AudioLoudnessTimelineSample], durationAnalyzed: TimeInterval?) {
        self.samples = samples
        if let durationAnalyzed, durationAnalyzed.isFinite, durationAnalyzed >= 0 {
            self.durationAnalyzed = durationAnalyzed
        } else {
            self.durationAnalyzed = nil
        }
    }

    public var shortTermMinimumLUFS: Double? { samples.compactMap(\.shortTermMinimumLUFS).min() }
    public var shortTermMaximumLUFS: Double? { samples.compactMap(\.shortTermMaximumLUFS).max() }

    public var shortTermAverageLUFS: Double? {
        weightedAverage(samples.compactMap { sample in
            sample.shortTermLUFS.map { ($0, sample.sampleCount) }
        })
    }

    public var momentaryMinimumLUFS: Double? { samples.compactMap(\.momentaryMinimumLUFS).min() }
    public var momentaryMaximumLUFS: Double? { samples.compactMap(\.momentaryMaximumLUFS).max() }

    public func nearestSample(to time: TimeInterval) -> AudioLoudnessTimelineSample? {
        guard !samples.isEmpty else { return nil }
        var low = 0
        var high = samples.count - 1
        while low < high {
            let mid = (low + high) / 2
            if samples[mid].time < time { low = mid + 1 } else { high = mid }
        }
        let candidate = samples[low]
        guard low > 0 else { return candidate }
        let previous = samples[low - 1]
        return abs(previous.time - time) <= abs(candidate.time - time) ? previous : candidate
    }

    private func weightedAverage(_ values: [(Double, Int)]) -> Double? {
        guard !values.isEmpty else { return nil }
        let totalWeight = values.reduce(0) { $0 + $1.1 }
        guard totalWeight > 0 else { return nil }
        return values.reduce(0) { $0 + $1.0 * Double($1.1) } / Double(totalWeight)
    }
}

/// Acumulador acotado: cuando alcanza el límite fusiona pares adyacentes. La media
/// conserva la tendencia y cada muestra agregada retiene mínimos/máximos del intervalo.
final class AudioLoudnessTimelineAccumulator: @unchecked Sendable {
    private let maximumSamples: Int
    private var samples: [AudioLoudnessTimelineSample] = []

    init(maximumSamples: Int = 8_192) {
        self.maximumSamples = max(maximumSamples, 32)
    }

    func append(time: TimeInterval, momentary: Double?, shortTerm: Double?, integrated: Double?) {
        let sample = AudioLoudnessTimelineSample(
            time: time,
            momentaryLUFS: momentary,
            shortTermLUFS: shortTerm,
            integratedLUFS: integrated
        )
        guard sample.momentaryLUFS != nil || sample.shortTermLUFS != nil || sample.integratedLUFS != nil else { return }
        samples.append(sample)
        if samples.count > maximumSamples { compact() }
    }

    func finish(duration: TimeInterval?) -> AudioLoudnessTimeline? {
        guard !samples.isEmpty else { return nil }
        return AudioLoudnessTimeline(samples: samples, durationAnalyzed: duration)
    }

    private func compact() {
        var compacted: [AudioLoudnessTimelineSample] = []
        compacted.reserveCapacity((samples.count + 1) / 2)
        var index = 0
        while index < samples.count {
            if index + 1 < samples.count {
                compacted.append(Self.merge(samples[index], samples[index + 1]))
                index += 2
            } else {
                compacted.append(samples[index])
                index += 1
            }
        }
        samples = compacted
    }

    private static func merge(_ lhs: AudioLoudnessTimelineSample, _ rhs: AudioLoudnessTimelineSample) -> AudioLoudnessTimelineSample {
        let totalCount = lhs.sampleCount + rhs.sampleCount
        func average(_ a: Double?, _ aw: Int, _ b: Double?, _ bw: Int) -> Double? {
            switch (a, b) {
            case let (a?, b?): return (a * Double(aw) + b * Double(bw)) / Double(aw + bw)
            case let (a?, nil): return a
            case let (nil, b?): return b
            case (nil, nil): return nil
            }
        }
        func minimum(_ a: Double?, _ b: Double?) -> Double? {
            switch (a, b) {
            case let (a?, b?): return min(a, b)
            case let (a?, nil): return a
            case let (nil, b?): return b
            case (nil, nil): return nil
            }
        }
        func maximum(_ a: Double?, _ b: Double?) -> Double? {
            switch (a, b) {
            case let (a?, b?): return max(a, b)
            case let (a?, nil): return a
            case let (nil, b?): return b
            case (nil, nil): return nil
            }
        }
        return AudioLoudnessTimelineSample(
            time: rhs.time,
            momentaryLUFS: average(lhs.momentaryLUFS, lhs.sampleCount, rhs.momentaryLUFS, rhs.sampleCount),
            shortTermLUFS: average(lhs.shortTermLUFS, lhs.sampleCount, rhs.shortTermLUFS, rhs.sampleCount),
            integratedLUFS: rhs.integratedLUFS ?? lhs.integratedLUFS,
            momentaryMinimumLUFS: minimum(lhs.momentaryMinimumLUFS, rhs.momentaryMinimumLUFS),
            momentaryMaximumLUFS: maximum(lhs.momentaryMaximumLUFS, rhs.momentaryMaximumLUFS),
            shortTermMinimumLUFS: minimum(lhs.shortTermMinimumLUFS, rhs.shortTermMinimumLUFS),
            shortTermMaximumLUFS: maximum(lhs.shortTermMaximumLUFS, rhs.shortTermMaximumLUFS),
            sampleCount: totalCount
        )
    }
}
