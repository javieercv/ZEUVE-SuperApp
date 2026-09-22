import Foundation
import ZEUVECore
import ZEUVEEngines

public enum MediaTrackKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case video, audio, subtitle
    public var id: String { rawValue }
    public var displayName: String { switch self { case .video: return "Vídeo"; case .audio: return "Audio"; case .subtitle: return "Subtítulo" } }
}

public enum MediaTrackSource: Codable, Sendable, Equatable {
    case original(streamIndex: Int)
    case external(url: URL, fingerprint: FileFingerprint, streamIndex: Int)

    public var streamIndex: Int {
        switch self { case .original(let index), .external(_, _, let index): return index }
    }

    public var isOriginal: Bool {
        if case .original = self { return true }
        return false
    }
}

public struct MediaEditableTrack: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let kind: MediaTrackKind
    public let source: MediaTrackSource
    public let codec: String
    public var language: String
    public var title: String
    public var isDefault: Bool
    public var isForced: Bool
    public let preservedDispositions: [String]

    // Datos técnicos de solo lectura usados por la inspección y la previsualización.
    // No forman parte de la intención editable del draft.
    public let sampleRate: Double?
    public let channels: Int?
    public let channelLayout: String?
    public let duration: Double?
    public let width: Int?
    public let height: Int?
    public let frameRate: Double?

    public init(
        id: UUID = UUID(),
        kind: MediaTrackKind,
        source: MediaTrackSource,
        codec: String,
        language: String = "",
        title: String = "",
        isDefault: Bool = false,
        isForced: Bool = false,
        preservedDispositions: [String] = [],
        sampleRate: Double? = nil,
        channels: Int? = nil,
        channelLayout: String? = nil,
        duration: Double? = nil,
        width: Int? = nil,
        height: Int? = nil,
        frameRate: Double? = nil
    ) {
        self.id = id
        self.kind = kind
        self.source = source
        self.codec = codec
        self.language = language
        self.title = title
        self.isDefault = isDefault
        self.isForced = isForced
        self.preservedDispositions = preservedDispositions
        self.sampleRate = sampleRate
        self.channels = channels
        self.channelLayout = channelLayout
        self.duration = duration
        self.width = width
        self.height = height
        self.frameRate = frameRate
    }

    public static func from(stream: MediaInspectionStream, kind: MediaTrackKind) -> MediaEditableTrack? {
        guard let index = stream.index else { return nil }
        return MediaEditableTrack(
            kind: kind,
            source: .original(streamIndex: index),
            codec: stream.codec_name ?? "unknown",
            language: stream.language ?? "",
            title: stream.title ?? "",
            isDefault: stream.isDefault,
            isForced: kind == .subtitle && stream.isForced,
            preservedDispositions: dispositionNames(stream.disposition),
            sampleRate: stream.sampleRateValue,
            channels: stream.channels,
            channelLayout: stream.channel_layout,
            duration: stream.durationSeconds,
            width: stream.width,
            height: stream.height,
            frameRate: stream.frameRate
        )
    }

    public static func dispositionNames(_ d: MediaDisposition?) -> [String] {
        guard let d else { return [] }
        return [
            ("dub", d.dub), ("original", d.original), ("comment", d.comment), ("lyrics", d.lyrics),
            ("karaoke", d.karaoke), ("hearing_impaired", d.hearing_impaired), ("visual_impaired", d.visual_impaired),
            ("clean_effects", d.clean_effects), ("timed_thumbnails", d.timed_thumbnails), ("non_diegetic", d.non_diegetic),
            ("captions", d.captions), ("descriptions", d.descriptions), ("metadata", d.metadata), ("dependent", d.dependent), ("still_image", d.still_image)
        ].compactMap { $0.1 == 1 ? $0.0 : nil }
    }
}

public struct ExternalTrackCandidate: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let url: URL
    public let fingerprint: FileFingerprint
    public let stream: MediaInspectionStream
    public let kind: MediaTrackKind
    public init(id: UUID = UUID(), url: URL, fingerprint: FileFingerprint, stream: MediaInspectionStream, kind: MediaTrackKind) {
        self.id = id
        self.url = url
        self.fingerprint = fingerprint
        self.stream = stream
        self.kind = kind
    }
}
