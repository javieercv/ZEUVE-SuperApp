import Foundation

public struct MultimediaWaveformBucket: Sendable, Equatable, Codable {
    public let minimum: Float
    public let maximum: Float
    public let rms: Float

    public init(minimum: Float, maximum: Float, rms: Float) {
        self.minimum = min(max(minimum.isFinite ? minimum : 0, -1), 1)
        self.maximum = min(max(maximum.isFinite ? maximum : 0, -1), 1)
        self.rms = min(max(rms.isFinite ? rms : 0, 0), 1)
    }

    public static let silence = MultimediaWaveformBucket(minimum: 0, maximum: 0, rms: 0)
}

public struct MultimediaWaveformResult: Sendable, Equatable {
    public let sourceID: String
    public let duration: TimeInterval
    public let buckets: [MultimediaWaveformBucket]

    public init(sourceID: String, duration: TimeInterval, buckets: [MultimediaWaveformBucket]) {
        self.sourceID = sourceID
        self.duration = max(duration.isFinite ? duration : 0, 0)
        self.buckets = buckets
    }
}

public struct MultimediaWaveformAnalysisRequest: Sendable, Equatable {
    public let source: MultimediaAudioPreviewSource
    public let channelSelection: SpectrogramChannelSelection
    public let maximumBuckets: Int

    public init(
        source: MultimediaAudioPreviewSource,
        channelSelection: SpectrogramChannelSelection = .mix,
        maximumBuckets: Int = 65_536
    ) {
        self.source = source
        self.channelSelection = channelSelection
        self.maximumBuckets = maximumBuckets
    }

    public var cacheKey: String {
        let channel: String
        switch channelSelection {
        case .mix: channel = "mix"
        case .channel(let index): channel = "ch:\(index)"
        }
        return "\(source.id)|\(channel)|\(maximumBuckets)"
    }
}

public enum MultimediaWaveformRenderSampler {
    /// Reduce una envolvente ya calculada para el ancho visual sin volver a decodificar audio.
    /// Cada grupo conserva el pico positivo más alto, el negativo más bajo y RMS combinado.
    public static func samples(
        from buckets: [MultimediaWaveformBucket],
        targetCount: Int
    ) -> [MultimediaWaveformBucket] {
        reduce(buckets[...], targetCount: targetCount)
    }

    /// Recorta primero la envolvente al intervalo temporal visible y después reduce únicamente
    /// esos buckets. El zoom no vuelve a decodificar PCM ni pierde los picos del intervalo.
    public static func samples(
        from result: MultimediaWaveformResult,
        visibleRange: AudioTimelineVisibleRange,
        targetCount: Int
    ) -> [MultimediaWaveformBucket] {
        guard !result.buckets.isEmpty, targetCount > 0 else { return [] }
        guard result.duration > 0, visibleRange.duration > 0 else {
            return reduce(result.buckets[...], targetCount: targetCount)
        }

        let bucketCount = result.buckets.count
        let lowerFraction = min(max(visibleRange.start / result.duration, 0), 1)
        let upperFraction = min(max(visibleRange.end / result.duration, lowerFraction), 1)
        let lower = min(Int(floor(lowerFraction * Double(bucketCount))), bucketCount - 1)
        let upperExclusive = min(
            max(Int(ceil(upperFraction * Double(bucketCount))), lower + 1),
            bucketCount
        )
        return reduce(result.buckets[lower..<upperExclusive], targetCount: targetCount)
    }

    private static func reduce(
        _ buckets: ArraySlice<MultimediaWaveformBucket>,
        targetCount: Int
    ) -> [MultimediaWaveformBucket] {
        guard !buckets.isEmpty, targetCount > 0 else { return [] }
        if buckets.count <= targetCount { return Array(buckets) }
        let count = min(targetCount, buckets.count)
        let start = buckets.startIndex
        return (0..<count).map { index in
            let lowerOffset = index * buckets.count / count
            let upperOffset = max((index + 1) * buckets.count / count, lowerOffset + 1)
            let lower = start + lowerOffset
            let upper = min(start + upperOffset, buckets.endIndex)
            let slice = buckets[lower..<upper]
            let minimum = slice.map(\.minimum).min() ?? 0
            let maximum = slice.map(\.maximum).max() ?? 0
            let rms = sqrt(slice.reduce(Float(0)) { $0 + $1.rms * $1.rms } / Float(max(slice.count, 1)))
            return MultimediaWaveformBucket(minimum: minimum, maximum: maximum, rms: rms)
        }
    }
}
