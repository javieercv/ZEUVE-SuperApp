import Foundation
import ZEUVECore
import ZEUVEEngines

public enum MediaArtworkSource: Sendable, Equatable {
    case original(streamIndex: Int)
    case external(url: URL, fingerprint: FileFingerprint, streamIndex: Int)

    public var originalStreamIndex: Int? { if case .original(let index) = self { return index }; return nil }
}

public struct MediaEditableArtwork: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let source: MediaArtworkSource
    public let codec: String
    public var title: String

    public init(id: UUID = UUID(), source: MediaArtworkSource, codec: String, title: String = "") {
        self.id = id; self.source = source; self.codec = codec.lowercased(); self.title = title
    }

    public static func from(stream: MediaInspectionStream) -> MediaEditableArtwork? {
        guard stream.codec_type == "video", stream.isAttachedPicture, let index = stream.index else { return nil }
        return .init(source: .original(streamIndex: index), codec: stream.codec_name ?? "unknown", title: stream.title ?? "")
    }
}

public struct MediaArtworkCompatibility: Sendable {
    public init() {}
    public func canAdd(_ artwork: MediaEditableArtwork, to container: EditableMediaContainer) -> Bool {
        switch container {
        case .mp4, .mov: return ["mjpeg", "jpeg", "png"].contains(artwork.codec)
        case .mkv, .webm: return false
        }
    }
}
