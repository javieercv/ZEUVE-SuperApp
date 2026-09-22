import Foundation

public struct FFmpegChapterMetadataBuilder: Sendable {
    public init() {}

    public func write(chapters: [PlannedChapter], to url: URL) throws {
        var lines = [";FFMETADATA1"]
        for chapter in chapters {
            lines.append("")
            lines.append("[CHAPTER]")
            lines.append("TIMEBASE=1/1000")
            lines.append("START=\(milliseconds(chapter.startTime))")
            lines.append("END=\(milliseconds(chapter.endTime))")
            var tags = chapter.preservedTags.filter { $0.key.caseInsensitiveCompare("title") != .orderedSame }
            tags["title"] = chapter.title
            for key in tags.keys.sorted() {
                guard let value = tags[key] else { continue }
                lines.append("\(escape(key))=\(escape(value))")
            }
        }
        let data = Data((lines.joined(separator: "\n") + "\n").utf8)
        try data.write(to: url, options: .atomic)
    }

    public func escape(_ value: String) -> String {
        var result = ""
        result.reserveCapacity(value.count)
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\\": result += "\\\\"
            case "=": result += "\\="
            case ";": result += "\\;"
            case "#": result += "\\#"
            case "\n": result += "\\\n"
            case "\r": continue
            default: result.unicodeScalars.append(scalar)
            }
        }
        return result
    }

    private func milliseconds(_ seconds: Double) -> Int64 {
        Int64((seconds * 1000).rounded())
    }
}
