import Foundation
import ZEUVEEngines
import ZEUVECore

public struct MultimediaSubtitlePreviewEvent: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let start: TimeInterval
    public let end: TimeInterval
    public let text: String

    public init(id: UUID = UUID(), start: TimeInterval, end: TimeInterval, text: String) {
        self.id = id
        self.start = start
        self.end = end
        self.text = text
    }
}

private final class SubtitlePreviewCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()
    func append(_ data: Data) { lock.lock(); storage.append(data); lock.unlock() }
    func data() -> Data { lock.lock(); defer { lock.unlock() }; return storage }
}

public actor MultimediaSubtitlePreviewService {
    private let runner: ExternalProcessRunner

    public init(runner: ExternalProcessRunner = .init()) { self.runner = runner }

    public func load(ffmpeg: URL, url: URL, fingerprint: FileFingerprint, streamIndex: Int) async throws -> [MultimediaSubtitlePreviewEvent] {
        guard fingerprint.matches(url) else { throw MultimediaInspectorError.inputChanged(url.lastPathComponent) }
        let collector = SubtitlePreviewCollector()
        let result = try await runner.run(.init(executable: ffmpeg, arguments: [
            "-hide_banner", "-nostdin", "-v", "error",
            "-i", url.path,
            "-map", "0:\(streamIndex)",
            "-c:s", "srt", "-f", "srt", "pipe:1",
        ]), onStdout: { collector.append($0) })
        guard result.succeeded else { throw MultimediaInspectorError.previewUnavailable }
        guard let string = String(data: collector.data(), encoding: .utf8) else { return [] }
        return Self.parseSRT(string)
    }

    public func cancel() async { try? await runner.cancel(gracePeriod: .milliseconds(250)) }

    public static func parseSRT(_ value: String) -> [MultimediaSubtitlePreviewEvent] {
        let normalized = value.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        return normalized.components(separatedBy: "\n\n").compactMap { block in
            var lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            guard !lines.isEmpty else { return nil }
            if Int(lines[0].trimmingCharacters(in: .whitespacesAndNewlines)) != nil { lines.removeFirst() }
            guard let timing = lines.first else { return nil }
            lines.removeFirst()
            let pair = timing.components(separatedBy: " --> ")
            guard pair.count == 2, let start = parseTime(pair[0]), let end = parseTime(pair[1]) else { return nil }
            let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return .init(start: start, end: max(end, start), text: text)
        }
    }

    private static func parseTime(_ raw: String) -> TimeInterval? {
        let cleaned = raw.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces).first ?? raw
        let fields = cleaned.replacingOccurrences(of: ",", with: ".").split(separator: ":")
        guard fields.count == 3, let h = Double(fields[0]), let m = Double(fields[1]), let s = Double(fields[2]) else { return nil }
        return h * 3600 + m * 60 + s
    }
}
