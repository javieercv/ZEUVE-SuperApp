import Foundation
import ZEUVEEngines

final class FFmpegDiagnosticCollector: @unchecked Sendable {
    private let lock = NSLock()
    private let decoder = IncrementalLineDecoder(maximumBufferedBytes: 512 * 1_024)
    private let storage: LimitedOutputCollector
    private var closed = false

    init(maximumBytes: Int) {
        storage = LimitedOutputCollector(maximumBytes: maximumBytes)
    }

    func append(_ data: Data) {
        lock.lock(); defer { lock.unlock() }
        guard !closed else { return }
        if let lines = try? decoder.append(data) { append(lines: lines) }
    }

    func finish() {
        lock.lock(); defer { lock.unlock() }
        guard !closed else { return }
        if let final = decoder.finish(), !final.isEmpty { append(lines: [final]) }
        closed = true
    }

    var string: String { storage.string }

    private func append(lines: [String]) {
        for line in lines where !isProgressOrFrameInfo(line) {
            storage.append(Data((line + "\n").utf8))
        }
    }

    private func isProgressOrFrameInfo(_ line: String) -> Bool {
        if line.contains("showinfo") { return true }
        let prefixes = [
            "frame=", "fps=", "stream_", "bitrate=", "total_size=", "out_time_us=",
            "out_time_ms=", "out_time=", "dup_frames=", "drop_frames=", "speed=", "progress="
        ]
        return prefixes.contains { line.hasPrefix($0) }
    }
}

struct ItemProgressUpdate: Sendable {
    let fraction: Double?
    let phase: String
}

final class FFmpegProgressMonitor: @unchecked Sendable {
    private let lock = NSLock()
    private let decoder = IncrementalLineDecoder(maximumBufferedBytes: 512 * 1_024)
    private let duration: Double?
    private let callback: @Sendable (Double?, Int?) -> Void
    private var capturedError: Error?
    private var latestFrameCount: Int?
    private var finished = false

    init(duration: Double?, callback: @escaping @Sendable (Double?, Int?) -> Void) {
        self.duration = duration
        self.callback = callback
    }

    func append(_ data: Data) {
        lock.lock(); defer { lock.unlock() }
        guard capturedError == nil, !finished else { return }
        do { try consume(lines: decoder.append(data)) }
        catch { capturedError = error }
    }

    func finish(success: Bool) throws {
        lock.lock(); defer { lock.unlock() }
        guard !finished else {
            if let capturedError { throw capturedError }
            return
        }
        if let final = decoder.finish(), !final.isEmpty { try consume(lines: [final]) }
        finished = true
        if let capturedError { throw capturedError }
        if success { callback(1, latestFrameCount) }
    }

    private func consume(lines: [String]) throws {
        for line in lines {
            if line.hasPrefix("frame="), let value = Int(line.dropFirst("frame=".count).trimmingCharacters(in: .whitespaces)) {
                latestFrameCount = max(value, 0)
                callback(nil, latestFrameCount)
            } else if line.hasPrefix("out_time_us="), let duration, duration > 0,
                      let value = Double(line.dropFirst("out_time_us=".count)) {
                callback(min(max(value / 1_000_000 / duration, 0), 1), latestFrameCount)
            } else if line == "progress=end" {
                callback(1, latestFrameCount)
            }
        }
    }
}
