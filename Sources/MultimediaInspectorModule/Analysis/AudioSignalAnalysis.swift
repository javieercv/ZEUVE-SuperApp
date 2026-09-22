import Foundation

public struct AudioSignalAnalysisConfiguration: Sendable, Equatable, Codable {
    public let silenceThresholdDBFS: Double
    public let minimumSilenceDuration: TimeInterval
    public let clippingThresholdDBFS: Double
    public let minimumConsecutiveClippedSamples: Int

    public init(
        silenceThresholdDBFS: Double = -60,
        minimumSilenceDuration: TimeInterval = 0.5,
        clippingThresholdDBFS: Double = -0.1,
        minimumConsecutiveClippedSamples: Int = 3
    ) {
        self.silenceThresholdDBFS = min(max(silenceThresholdDBFS.isFinite ? silenceThresholdDBFS : -60, -120), -10)
        self.minimumSilenceDuration = min(max(minimumSilenceDuration.isFinite ? minimumSilenceDuration : 0.5, 0.05), 30)
        self.clippingThresholdDBFS = min(max(clippingThresholdDBFS.isFinite ? clippingThresholdDBFS : -0.1, -6), 0)
        self.minimumConsecutiveClippedSamples = min(max(minimumConsecutiveClippedSamples, 2), 64)
    }

    var silenceThresholdAmplitude: Float {
        Float(pow(10, silenceThresholdDBFS / 20))
    }

    var clippingThresholdAmplitude: Float {
        Float(pow(10, clippingThresholdDBFS / 20))
    }
}

public struct AudioSilenceSegment: Sendable, Equatable, Codable {
    public let startTime: TimeInterval
    public let endTime: TimeInterval

    public init(startTime: TimeInterval, endTime: TimeInterval) {
        let start = max(startTime.isFinite ? startTime : 0, 0)
        self.startTime = start
        self.endTime = max(endTime.isFinite ? endTime : start, start)
    }

    public var duration: TimeInterval { max(endTime - startTime, 0) }
}

public struct AudioClippingEvent: Sendable, Equatable, Codable {
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let channelIndex: Int
    public let peakDBFS: Double
    public let sampleCount: Int

    public init(
        startTime: TimeInterval,
        endTime: TimeInterval,
        channelIndex: Int,
        peakDBFS: Double,
        sampleCount: Int
    ) {
        let start = max(startTime.isFinite ? startTime : 0, 0)
        self.startTime = start
        self.endTime = max(endTime.isFinite ? endTime : start, start)
        self.channelIndex = max(channelIndex, 0)
        self.peakDBFS = peakDBFS.isFinite ? peakDBFS : 0
        self.sampleCount = max(sampleCount, 0)
    }

    public var duration: TimeInterval { max(endTime - startTime, 0) }
}

public struct AudioSignalAnalysisResult: Sendable, Equatable, Codable {
    public let sourceID: String
    public let durationAnalyzed: TimeInterval
    public let silenceSegments: [AudioSilenceSegment]
    public let clippingEvents: [AudioClippingEvent]
    public let totalSilenceDuration: TimeInterval
    public let omittedSilenceSegments: Int
    public let omittedClippingEvents: Int

    public init(
        sourceID: String,
        durationAnalyzed: TimeInterval,
        silenceSegments: [AudioSilenceSegment],
        clippingEvents: [AudioClippingEvent],
        totalSilenceDuration: TimeInterval? = nil,
        omittedSilenceSegments: Int = 0,
        omittedClippingEvents: Int = 0
    ) {
        self.sourceID = sourceID
        self.durationAnalyzed = max(durationAnalyzed.isFinite ? durationAnalyzed : 0, 0)
        self.silenceSegments = silenceSegments
        self.clippingEvents = clippingEvents
        let detectedSilence = totalSilenceDuration ?? silenceSegments.reduce(0) { $0 + $1.duration }
        self.totalSilenceDuration = max(detectedSilence.isFinite ? detectedSilence : 0, 0)
        self.omittedSilenceSegments = max(omittedSilenceSegments, 0)
        self.omittedClippingEvents = max(omittedClippingEvents, 0)
    }

    public var silenceSegmentCount: Int { silenceSegments.count + omittedSilenceSegments }
    public var clippingEventCount: Int { clippingEvents.count + omittedClippingEvents }
    public var hasPossibleClipping: Bool { clippingEventCount > 0 }
}

/// Analiza PCM interleaved a resolución completa sin conservar el audio en memoria.
/// El silencio se evalúa por ventanas RMS y exige que todos los canales estén por debajo
/// del umbral. El posible clipping se localiza por canal y requiere muestras consecutivas.
final class AudioSignalAnalysisAccumulator: @unchecked Sendable {
    private struct ClippingRun {
        var startFrame: Int64?
        var count = 0
        var peak: Float = 0
    }

    private struct MergedClippingEvent {
        var startFrame: Int64
        var endFrame: Int64
        var peak: Float
        var sampleCount: Int
        let channelIndex: Int
    }

    private let lock = NSLock()
    private let sampleRate: Double
    private let channels: Int
    private let configuration: AudioSignalAnalysisConfiguration
    private let silenceWindowFrames: Int
    private let clippingMergeGapFrames: Int64
    private let maximumSilenceSegments: Int
    private let maximumClippingEvents: Int

    private var remainder: [Float] = []
    private var totalFrames: Int64 = 0

    private var silenceWindowStartFrame: Int64 = 0
    private var silenceWindowFrameCount = 0
    private var silenceWindowSquares: [Double]
    private var currentSilenceStartFrame: Int64?
    private var silenceSegments: [AudioSilenceSegment] = []
    private var detectedSilenceDuration: TimeInterval = 0
    private var omittedSilenceSegments = 0

    private var clippingRuns: [ClippingRun]
    private var pendingClippingEvents: [MergedClippingEvent?]
    private var clippingEvents: [AudioClippingEvent] = []
    private var omittedClippingEvents = 0
    private var cancelled = false
    private var completed = false

    init(
        sampleRate: Double,
        channels: Int,
        configuration: AudioSignalAnalysisConfiguration,
        silenceWindowDuration: TimeInterval = 0.01,
        clippingMergeGap: TimeInterval = 0.02,
        maximumSilenceSegments: Int = 5_000,
        maximumClippingEvents: Int = 2_000
    ) throws {
        guard sampleRate.isFinite, sampleRate > 0, channels > 0, channels <= 128 else {
            throw MultimediaInspectorError.invalidInput
        }
        self.sampleRate = sampleRate
        self.channels = channels
        self.configuration = configuration
        silenceWindowFrames = max(Int((sampleRate * max(silenceWindowDuration, 0.001)).rounded()), 1)
        clippingMergeGapFrames = max(Int64((sampleRate * max(clippingMergeGap, 0)).rounded()), 0)
        self.maximumSilenceSegments = max(maximumSilenceSegments, 1)
        self.maximumClippingEvents = max(maximumClippingEvents, 1)
        silenceWindowSquares = [Double](repeating: 0, count: channels)
        clippingRuns = [ClippingRun](repeating: .init(), count: channels)
        pendingClippingEvents = [MergedClippingEvent?](repeating: nil, count: channels)
    }

    var processedFrames: Int64 { lock.withLock { totalFrames } }
    var processedDuration: TimeInterval { Double(processedFrames) / sampleRate }

    func cancel() { lock.withLock { cancelled = true } }

    func consume(_ values: [Float]) {
        lock.withLock {
            guard !cancelled, !completed, !values.isEmpty else { return }
            values.withUnsafeBufferPointer { input in
                var offset = 0
                if !remainder.isEmpty {
                    let take = min(channels - remainder.count, input.count)
                    remainder.append(contentsOf: input.prefix(take))
                    offset += take
                    if remainder.count == channels {
                        remainder.withUnsafeBufferPointer { consumeFrames($0, count: 1) }
                        remainder.removeAll(keepingCapacity: true)
                    }
                }

                let frameCount = (input.count - offset) / channels
                if frameCount > 0 {
                    let upper = offset + frameCount * channels
                    consumeFrames(UnsafeBufferPointer(rebasing: input[offset..<upper]), count: frameCount)
                    offset = upper
                }
                if offset < input.count { remainder.append(contentsOf: input[offset...]) }
            }
        }
    }

    func finish(sourceID: String) -> AudioSignalAnalysisResult {
        lock.withLock {
            guard !completed else {
                return makeResult(sourceID: sourceID)
            }
            completed = true
            if !cancelled {
                if silenceWindowFrameCount > 0 { flushSilenceWindow(endFrame: totalFrames) }
                finishSilenceCandidate(endFrame: totalFrames)
                for channel in 0..<channels {
                    flushClippingRun(channel: channel, endFrameExclusive: totalFrames)
                    finalizePendingClippingEvent(channel: channel)
                }
            } else {
                silenceSegments.removeAll()
                clippingEvents.removeAll()
                omittedSilenceSegments = 0
                omittedClippingEvents = 0
            detectedSilenceDuration = 0
            }
            remainder.removeAll(keepingCapacity: false)
            return makeResult(sourceID: sourceID)
        }
    }

    private func consumeFrames(_ input: UnsafeBufferPointer<Float>, count: Int) {
        guard let base = input.baseAddress else { return }
        for frameOffset in 0..<count {
            let frameIndex = totalFrames
            let frame = base + frameOffset * channels
            for channel in 0..<channels {
                let raw = frame[channel]
                let sample = raw.isFinite ? raw : 0
                let magnitude = abs(sample)
                silenceWindowSquares[channel] += Double(sample) * Double(sample)
                consumeClippingSample(magnitude, channel: channel, frameIndex: frameIndex)
            }
            silenceWindowFrameCount += 1
            totalFrames += 1
            if silenceWindowFrameCount >= silenceWindowFrames {
                flushSilenceWindow(endFrame: totalFrames)
            }
        }
    }

    private func flushSilenceWindow(endFrame: Int64) {
        guard silenceWindowFrameCount > 0 else { return }
        let divisor = Double(silenceWindowFrameCount)
        let threshold = Double(configuration.silenceThresholdAmplitude)
        let isSilent = silenceWindowSquares.allSatisfy { sqrt(max($0 / divisor, 0)) <= threshold }

        if isSilent {
            if currentSilenceStartFrame == nil { currentSilenceStartFrame = silenceWindowStartFrame }
        } else {
            finishSilenceCandidate(endFrame: silenceWindowStartFrame)
        }

        silenceWindowSquares.withUnsafeMutableBufferPointer { $0.initialize(repeating: 0) }
        silenceWindowFrameCount = 0
        silenceWindowStartFrame = endFrame
    }

    private func finishSilenceCandidate(endFrame: Int64) {
        guard let startFrame = currentSilenceStartFrame else { return }
        currentSilenceStartFrame = nil
        guard endFrame > startFrame else { return }
        let duration = Double(endFrame - startFrame) / sampleRate
        guard duration + 1e-9 >= configuration.minimumSilenceDuration else { return }
        let segment = AudioSilenceSegment(
            startTime: Double(startFrame) / sampleRate,
            endTime: Double(endFrame) / sampleRate
        )
        detectedSilenceDuration += segment.duration
        if silenceSegments.count < maximumSilenceSegments {
            silenceSegments.append(segment)
        } else {
            omittedSilenceSegments += 1
        }
    }

    private func consumeClippingSample(_ magnitude: Float, channel: Int, frameIndex: Int64) {
        if magnitude >= configuration.clippingThresholdAmplitude {
            if clippingRuns[channel].count == 0 { clippingRuns[channel].startFrame = frameIndex }
            clippingRuns[channel].count += 1
            clippingRuns[channel].peak = max(clippingRuns[channel].peak, magnitude)
        } else {
            flushClippingRun(channel: channel, endFrameExclusive: frameIndex)
        }
    }

    private func flushClippingRun(channel: Int, endFrameExclusive: Int64) {
        let run = clippingRuns[channel]
        defer { clippingRuns[channel] = .init() }
        guard let startFrame = run.startFrame,
              run.count >= configuration.minimumConsecutiveClippedSamples,
              endFrameExclusive > startFrame else { return }

        let endFrame = max(endFrameExclusive - 1, startFrame)
        if var pending = pendingClippingEvents[channel] {
            let gap = startFrame - pending.endFrame - 1
            if gap <= clippingMergeGapFrames {
                pending.endFrame = max(pending.endFrame, endFrame)
                pending.peak = max(pending.peak, run.peak)
                pending.sampleCount += run.count
                pendingClippingEvents[channel] = pending
                return
            }
            finalizePendingClippingEvent(channel: channel)
        }
        pendingClippingEvents[channel] = .init(
            startFrame: startFrame,
            endFrame: endFrame,
            peak: run.peak,
            sampleCount: run.count,
            channelIndex: channel
        )
    }

    private func finalizePendingClippingEvent(channel: Int) {
        guard let pending = pendingClippingEvents[channel] else { return }
        pendingClippingEvents[channel] = nil
        let peakDBFS = 20 * log10(max(Double(pending.peak), 1e-12))
        let event = AudioClippingEvent(
            startTime: Double(pending.startFrame) / sampleRate,
            endTime: Double(pending.endFrame + 1) / sampleRate,
            channelIndex: pending.channelIndex,
            peakDBFS: peakDBFS,
            sampleCount: pending.sampleCount
        )
        if clippingEvents.count < maximumClippingEvents {
            clippingEvents.append(event)
        } else {
            omittedClippingEvents += 1
        }
    }

    private func makeResult(sourceID: String) -> AudioSignalAnalysisResult {
        AudioSignalAnalysisResult(
            sourceID: sourceID,
            durationAnalyzed: Double(totalFrames) / sampleRate,
            silenceSegments: silenceSegments,
            clippingEvents: clippingEvents.sorted {
                if $0.startTime == $1.startTime { return $0.channelIndex < $1.channelIndex }
                return $0.startTime < $1.startTime
            },
            totalSilenceDuration: detectedSilenceDuration,
            omittedSilenceSegments: omittedSilenceSegments,
            omittedClippingEvents: omittedClippingEvents
        )
    }
}
