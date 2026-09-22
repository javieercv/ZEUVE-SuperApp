import Foundation
import ZEUVEEngines

public enum AudioComparisonSlot: String, CaseIterable, Sendable, Codable, Identifiable {
    case a
    case b

    public var id: String { rawValue }
    public var displayName: String { rawValue.uppercased() }
}

public struct AudioTrackComparisonMetrics: Sendable, Equatable {
    public let codec: String
    public let bitRate: Int64?
    public let sampleRate: Double?
    public let channels: Int?
    public let channelLayout: String?
    public let duration: TimeInterval?
    public let integratedLUFS: Double?
    public let loudnessRangeLU: Double?
    public let truePeakDBTP: Double?
    public let samplePeakDBFS: Double?
    public let silenceSegmentCount: Int?
    public let totalSilenceDuration: TimeInterval?
    public let clippingEventCount: Int?

    public init(
        track: MediaEditableTrack,
        stream: MediaInspectionStream?,
        loudness: AudioLoudnessResult?,
        signal: AudioSignalAnalysisResult?
    ) {
        codec = track.codec.uppercased()
        bitRate = stream?.bitRateValue
        sampleRate = track.sampleRate ?? stream?.sampleRateValue
        channels = track.channels ?? stream?.channels
        channelLayout = track.channelLayout ?? stream?.channel_layout
        duration = track.duration ?? stream?.durationSeconds
        integratedLUFS = loudness?.integratedLUFS
        loudnessRangeLU = loudness?.loudnessRangeLU
        truePeakDBTP = loudness?.truePeakDBTP
        samplePeakDBFS = loudness?.samplePeakDBFS
        silenceSegmentCount = signal.map(\.silenceSegmentCount)
        totalSilenceDuration = signal?.totalSilenceDuration
        clippingEventCount = signal.map(\.clippingEventCount)
    }
}
