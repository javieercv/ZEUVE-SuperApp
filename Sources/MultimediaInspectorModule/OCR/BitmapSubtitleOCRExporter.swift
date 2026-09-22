import Foundation

public struct BitmapSubtitleOCRExporter: Sendable {
    public init() {}

    public func srtData(from draft: BitmapSubtitleOCRDraft) -> Data {
        let included = draft.events.filter(\.included).sorted { $0.start < $1.start }
        let body = included.enumerated().map { index, event in
            "\(index + 1)\n\(timecode(event.start)) --> \(timecode(max(event.end, event.start + 0.05)))\n\(sanitize(event.text))\n"
        }.joined(separator: "\n")
        return Data(body.utf8)
    }

    public func writeSRT(from draft: BitmapSubtitleOCRDraft, to url: URL) throws {
        try srtData(from: draft).write(to: url, options: .atomic)
    }

    private func timecode(_ seconds: TimeInterval) -> String {
        let value = max(0, seconds)
        let hours = Int(value / 3600)
        let minutes = Int(value.truncatingRemainder(dividingBy: 3600) / 60)
        let secs = Int(value.truncatingRemainder(dividingBy: 60))
        let millis = Int((value - floor(value)) * 1000.0)
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, secs, millis)
    }

    private func sanitize(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").replacingOccurrences(of: "\u{0000}", with: "")
    }
}
