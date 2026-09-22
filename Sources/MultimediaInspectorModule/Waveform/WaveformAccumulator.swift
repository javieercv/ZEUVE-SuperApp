import Foundation

public final class MultimediaWaveformAccumulator: @unchecked Sendable {
    private struct MutableBucket {
        var minimum: Float = 0
        var maximum: Float = 0
        var sumSquares: Double = 0
        var sampleCount: Int = 0

        mutating func include(_ values: UnsafeBufferPointer<Float>) {
            guard !values.isEmpty else { return }
            var frameSquares = 0.0
            for value in values {
                let safe = value.isFinite ? min(max(value, -1), 1) : 0
                minimum = min(minimum, safe)
                maximum = max(maximum, safe)
                frameSquares += Double(safe * safe)
            }
            sumSquares += frameSquares / Double(values.count)
            sampleCount += 1
        }

        mutating func includeSingle(_ value: Float) {
            let safe = value.isFinite ? min(max(value, -1), 1) : 0
            minimum = min(minimum, safe)
            maximum = max(maximum, safe)
            sumSquares += Double(safe * safe)
            sampleCount += 1
        }

        func result() -> MultimediaWaveformBucket {
            let rms = sampleCount > 0 ? Float(sqrt(sumSquares / Double(sampleCount))) : 0
            return MultimediaWaveformBucket(minimum: minimum, maximum: maximum, rms: rms)
        }
    }

    private let lock = NSLock()
    private let sampleRate: Double
    private let channels: Int
    private let selectedChannel: Int?
    private let duration: TimeInterval?
    private let maximumBuckets: Int
    private var fixedBuckets: [MutableBucket]?
    private var dynamicBuckets: [MutableBucket] = []
    private var dynamicCurrent = MutableBucket()
    private var dynamicFramesInCurrent = 0
    private var frameIndex: Int64 = 0
    private let expectedFrames: Int64?
    private var dynamicFramesPerBucket = 64

    public init(
        sampleRate: Double,
        channels: Int,
        channelSelection: SpectrogramChannelSelection,
        duration: TimeInterval?,
        maximumBuckets: Int = 65_536
    ) throws {
        guard sampleRate.isFinite, sampleRate > 0, channels > 0, channels <= 128, maximumBuckets > 0 else {
            throw MultimediaInspectorError.invalidInput
        }
        if case .channel(let index) = channelSelection {
            guard (0..<channels).contains(index) else { throw MultimediaInspectorError.invalidInput }
            selectedChannel = index
        } else {
            selectedChannel = nil
        }
        self.sampleRate = sampleRate
        self.channels = channels
        self.duration = duration.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        self.maximumBuckets = min(max(maximumBuckets, 64), 65_536)
        if let duration = self.duration {
            let desired = min(self.maximumBuckets, max(128, Int(ceil(duration * 60))))
            fixedBuckets = Array(repeating: MutableBucket(), count: desired)
            expectedFrames = max(Int64((duration * sampleRate).rounded(.up)), 1)
        } else {
            fixedBuckets = nil
            expectedFrames = nil
        }
    }

    public func consume(interleaved samples: [Float]) {
        samples.withUnsafeBufferPointer { consume(interleaved: $0) }
    }

    public func consume(interleaved samples: UnsafeBufferPointer<Float>) {
        guard !samples.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        let frameCount = samples.count / channels
        guard frameCount > 0 else { return }

        for frame in 0..<frameCount {
            let base = frame * channels
            let frameSlice = UnsafeBufferPointer(rebasing: samples[base..<(base + channels)])
            if let expectedFrames, fixedBuckets != nil {
                let bucketCount = fixedBuckets!.count
                let rawIndex = Int((frameIndex * Int64(bucketCount)) / expectedFrames)
                let bucketIndex = min(max(rawIndex, 0), bucketCount - 1)
                if let selectedChannel {
                    fixedBuckets![bucketIndex].includeSingle(frameSlice[selectedChannel])
                } else {
                    fixedBuckets![bucketIndex].include(frameSlice)
                }
            } else {
                if let selectedChannel { dynamicCurrent.includeSingle(frameSlice[selectedChannel]) }
                else { dynamicCurrent.include(frameSlice) }
                dynamicFramesInCurrent += 1
                if dynamicFramesInCurrent >= dynamicFramesPerBucket {
                    dynamicBuckets.append(dynamicCurrent)
                    dynamicCurrent = MutableBucket()
                    dynamicFramesInCurrent = 0
                    compactDynamicIfNeeded()
                }
            }
            frameIndex += 1
        }
    }

    public func finish(sourceID: String) -> MultimediaWaveformResult {
        lock.lock()
        defer { lock.unlock() }
        let resultBuckets: [MultimediaWaveformBucket]
        if let fixedBuckets {
            resultBuckets = fixedBuckets.map { $0.result() }
        } else {
            if dynamicFramesInCurrent > 0 {
                dynamicBuckets.append(dynamicCurrent)
                dynamicCurrent = MutableBucket()
                dynamicFramesInCurrent = 0
            }
            while dynamicBuckets.count > maximumBuckets { compactDynamic() }
            resultBuckets = dynamicBuckets.map { $0.result() }
        }
        let measuredDuration = Double(frameIndex) / sampleRate
        return MultimediaWaveformResult(
            sourceID: sourceID,
            duration: duration ?? measuredDuration,
            buckets: resultBuckets
        )
    }

    private func compactDynamicIfNeeded() {
        guard dynamicBuckets.count > maximumBuckets * 2 else { return }
        compactDynamicForStreaming()
    }

    /// Compacts full buckets while preserving a uniform time width for future buckets.
    /// If the current level has an odd trailing bucket, it becomes the partially-filled
    /// bucket of the next level instead of being left beside wider compacted buckets.
    private func compactDynamicForStreaming() {
        guard dynamicBuckets.count > 1 else { return }
        let previousFramesPerBucket = dynamicFramesPerBucket
        var compacted: [MutableBucket] = []
        compacted.reserveCapacity((dynamicBuckets.count + 1) / 2)
        var index = 0
        while index + 1 < dynamicBuckets.count {
            var a = dynamicBuckets[index]
            let b = dynamicBuckets[index + 1]
            a.minimum = min(a.minimum, b.minimum)
            a.maximum = max(a.maximum, b.maximum)
            a.sumSquares += b.sumSquares
            a.sampleCount += b.sampleCount
            compacted.append(a)
            index += 2
        }

        if index < dynamicBuckets.count {
            dynamicCurrent = dynamicBuckets[index]
            dynamicFramesInCurrent = previousFramesPerBucket
        } else {
            dynamicCurrent = MutableBucket()
            dynamicFramesInCurrent = 0
        }
        dynamicBuckets = compacted
        dynamicFramesPerBucket = min(previousFramesPerBucket * 2, Int.max / 2)
    }

    private func compactDynamic() {
        guard dynamicBuckets.count > 1 else { return }
        var compacted: [MutableBucket] = []
        compacted.reserveCapacity((dynamicBuckets.count + 1) / 2)
        var index = 0
        while index < dynamicBuckets.count {
            if index + 1 < dynamicBuckets.count {
                var a = dynamicBuckets[index]
                let b = dynamicBuckets[index + 1]
                a.minimum = min(a.minimum, b.minimum)
                a.maximum = max(a.maximum, b.maximum)
                a.sumSquares += b.sumSquares
                a.sampleCount += b.sampleCount
                compacted.append(a)
                index += 2
            } else {
                compacted.append(dynamicBuckets[index])
                index += 1
            }
        }
        dynamicBuckets = compacted
    }
}
