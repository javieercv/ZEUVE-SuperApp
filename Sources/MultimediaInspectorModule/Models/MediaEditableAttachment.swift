import Foundation
import ZEUVECore
import ZEUVEEngines

public enum MediaAttachmentSource: Sendable, Equatable, Codable {
    case original(streamIndex: Int)
    case external(url: URL, fingerprint: FileFingerprint)

    public var originalStreamIndex: Int? {
        if case .original(let index) = self { return index }
        return nil
    }
}

public struct MediaEditableAttachment: Identifiable, Sendable, Equatable, Codable {
    public let id: UUID
    public let source: MediaAttachmentSource
    public var filename: String
    public var mimeType: String
    public let codec: String

    public init(
        id: UUID = UUID(),
        source: MediaAttachmentSource,
        filename: String,
        mimeType: String,
        codec: String = "attachment"
    ) {
        self.id = id
        self.source = source
        self.filename = filename
        self.mimeType = mimeType
        self.codec = codec
    }

    public static func from(stream: MediaInspectionStream, offset: Int) -> MediaEditableAttachment? {
        guard let index = stream.index, stream.codec_type == "attachment" else { return nil }
        let tags = stream.tags ?? [:]
        let filename = tags.firstValue(caseInsensitiveKey: "filename")
            ?? tags.firstValue(caseInsensitiveKey: "title")
            ?? "adjunto-\(offset + 1)"
        let mime = tags.firstValue(caseInsensitiveKey: "mimetype")
            ?? tags.firstValue(caseInsensitiveKey: "mime_type")
            ?? "application/octet-stream"
        return .init(
            source: .original(streamIndex: index),
            filename: filename,
            mimeType: mime,
            codec: stream.codec_name ?? "attachment"
        )
    }
}

private extension Dictionary where Key == String, Value == String {
    func firstValue(caseInsensitiveKey key: String) -> String? {
        first { $0.key.caseInsensitiveCompare(key) == .orderedSame }?.value
    }
}
