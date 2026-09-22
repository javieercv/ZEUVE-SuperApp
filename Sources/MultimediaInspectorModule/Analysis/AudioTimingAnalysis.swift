import Foundation
import ZEUVEEngines

public enum MultimediaTimeParser {
    public static func seconds(_ raw: String?) -> TimeInterval? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.uppercased() != "N/A", let value = Double(trimmed), value.isFinite else { return nil }
        return value
    }
}

public struct AudioTimingEntry: Sendable, Equatable, Codable, Identifiable {
    public let streamIndex: Int
    public let label: String
    public let startTime: TimeInterval?
    public let offsetFromReference: TimeInterval?
    public let duration: TimeInterval?
    public let durationDifference: TimeInterval?

    public var id: Int { streamIndex }

    public init(
        streamIndex: Int,
        label: String,
        startTime: TimeInterval?,
        offsetFromReference: TimeInterval?,
        duration: TimeInterval?,
        durationDifference: TimeInterval?
    ) {
        self.streamIndex = streamIndex
        self.label = label
        self.startTime = startTime
        self.offsetFromReference = offsetFromReference
        self.duration = duration
        self.durationDifference = durationDifference
    }
}

public struct AudioTimingAnalysis: Sendable, Equatable, Codable {
    public let referenceLabel: String
    public let referenceStartTime: TimeInterval?
    public let referenceDuration: TimeInterval?
    public let entries: [AudioTimingEntry]

    public init(referenceLabel: String, referenceStartTime: TimeInterval?, referenceDuration: TimeInterval?, entries: [AudioTimingEntry]) {
        self.referenceLabel = referenceLabel
        self.referenceStartTime = referenceStartTime
        self.referenceDuration = referenceDuration
        self.entries = entries
    }

    public var availableOffsetCount: Int { entries.compactMap(\.offsetFromReference).count }
}

public struct AudioTimingAnalyzer: Sendable {
    public init() {}

    public func analyze(_ inspection: MediaInspectionResult) -> AudioTimingAnalysis {
        let primaryVideo = inspection.videoStreams.first
        let formatStart = inspection.format?.startTimeSeconds
        let referenceStart = primaryVideo.flatMap { MultimediaTimeParser.seconds($0.start_time) } ?? formatStart
        let referenceDuration = primaryVideo?.durationSeconds ?? inspection.durationSeconds
        let referenceLabel = primaryVideo == nil ? "Contenedor" : "Vídeo principal"

        let entries = inspection.audioStreams.compactMap { stream -> AudioTimingEntry? in
            guard let index = stream.index else { return nil }
            let start = MultimediaTimeParser.seconds(stream.start_time)
            let offset: TimeInterval?
            if let start, let referenceStart { offset = start - referenceStart } else { offset = nil }
            let duration = stream.durationSeconds
            let durationDifference: TimeInterval?
            if let duration, let referenceDuration { durationDifference = duration - referenceDuration } else { durationDifference = nil }
            let labelParts = [stream.language, stream.title, stream.codec_name?.uppercased()].compactMap { value -> String? in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            return AudioTimingEntry(
                streamIndex: index,
                label: labelParts.isEmpty ? "Audio stream \(index)" : labelParts.joined(separator: " · "),
                startTime: start,
                offsetFromReference: offset,
                duration: duration,
                durationDifference: durationDifference
            )
        }
        return AudioTimingAnalysis(
            referenceLabel: referenceLabel,
            referenceStartTime: referenceStart,
            referenceDuration: referenceDuration,
            entries: entries
        )
    }
}
