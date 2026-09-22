import Foundation
import ZEUVEEngines

public struct MediaEditableChapter: Identifiable, Sendable, Equatable, Codable {
    public let id: UUID
    public let originalIndex: Int?
    public var startTime: Double
    public var title: String
    public var preservedTags: [String: String]

    public init(
        id: UUID = UUID(),
        originalIndex: Int? = nil,
        startTime: Double,
        title: String,
        preservedTags: [String: String] = [:]
    ) {
        self.id = id
        self.originalIndex = originalIndex
        self.startTime = startTime
        self.title = title
        self.preservedTags = preservedTags
    }

    public static func from(_ chapter: MediaInspectionChapter, offset: Int) -> MediaEditableChapter? {
        guard let start = MultimediaChapterTimeParser.seconds(chapter.start_time) else { return nil }
        let tags = chapter.tags ?? [:]
        let rawTitle = tags.first { $0.key.caseInsensitiveCompare("title") == .orderedSame }?.value
        let title = rawTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        return MediaEditableChapter(
            originalIndex: offset,
            startTime: start,
            title: (title?.isEmpty == false ? title! : "Capítulo \(offset + 1)"),
            preservedTags: tags
        )
    }
}

public enum MultimediaChapterTimeParser {
    public static func seconds(_ raw: String?) -> Double? {
        guard let raw, let value = Double(raw), value.isFinite, value >= 0 else { return nil }
        return value
    }
}
