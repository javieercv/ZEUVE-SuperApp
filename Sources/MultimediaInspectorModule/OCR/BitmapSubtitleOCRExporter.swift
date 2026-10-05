import Foundation

public struct BitmapSubtitleOCRExporter: Sendable {
    public init() {}

    public func srtData(from draft: BitmapSubtitleOCRDraft) -> Data {
        let included = draft.events.filter {
            $0.included && $0.start.isFinite && $0.end.isFinite && $0.start >= 0 && $0.end > $0.start
                && !sanitize($0.text).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.sorted { $0.start < $1.start }
        let body = included.enumerated().map { index, event in
            "\(index + 1)\n\(timecode(event.start)) --> \(timecode(max(event.end, event.start + 0.05)))\n\(sanitize(event.text))\n"
        }.joined(separator: "\n")
        return Data(body.utf8)
    }

    public func writeSRT(from draft: BitmapSubtitleOCRDraft, to url: URL) throws {
        try srtData(from: draft).write(to: url, options: .atomic)
    }

    private func timecode(_ seconds: TimeInterval) -> String {
        let total = Int64(min(max(seconds, 0), Double(Int64.max / 2000)) * 1000.0 + 0.5)
        let hours = total / 3_600_000
        let minutes = (total / 60_000) % 60
        let secs = (total / 1000) % 60
        let millis = total % 1000
        return String(format: "%02lld:%02lld:%02lld,%03lld", hours, minutes, secs, millis)
    }

    private func sanitize(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").replacingOccurrences(of: "\u{0000}", with: "")
    }
}
