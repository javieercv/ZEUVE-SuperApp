import Foundation
import ZEUVEEngines
import ZEUVECore

public struct MediaProbeDisposition: Codable, Sendable, Equatable {
    public let attached_pic: Int?
}

public struct MediaProbeStream: Codable, Sendable, Equatable {
    public let index: Int?
    public let codec_name: String?
    public let codec_type: String?
    public let width: Int?
    public let height: Int?
    public let pix_fmt: String?
    public let sample_rate: String?
    public let channels: Int?
    public let avg_frame_rate: String?
    public let r_frame_rate: String?
    public let nb_frames: String?
    public let duration: String?
    public let disposition: MediaProbeDisposition?
}

public struct MediaProbeFormat: Codable, Sendable, Equatable {
    public let duration: String?
    public let size: String?
    public let format_name: String?
}

public struct MediaProbeResult: Codable, Sendable, Equatable {
    public let streams: [MediaProbeStream]
    public let format: MediaProbeFormat?

    public var durationSeconds: Double? {
        if let raw = format?.duration, let value = Double(raw), value.isFinite { return value }
        for stream in streams {
            if let raw = stream.duration, let value = Double(raw), value.isFinite { return value }
        }
        return nil
    }

    public var videoStream: MediaProbeStream? {
        streams.first { $0.codec_type == "video" && $0.disposition?.attached_pic != 1 }
            ?? streams.first { $0.codec_type == "video" }
    }
    public var audioStream: MediaProbeStream? { streams.first { $0.codec_type == "audio" } }
    public var attachedPictureStream: MediaProbeStream? {
        streams.first { $0.codec_type == "video" && $0.disposition?.attached_pic == 1 }
    }

    public var frameRate: Double? {
        guard let raw = videoStream?.avg_frame_rate ?? videoStream?.r_frame_rate else { return nil }
        let parts = raw.split(separator: "/")
        if parts.count == 2, let numerator = Double(parts[0]), let denominator = Double(parts[1]), denominator != 0 {
            return numerator / denominator
        }
        return Double(raw)
    }

    public var estimatedFrameCount: Int64? {
        if let raw = videoStream?.nb_frames, let count = Int64(raw), count > 0 { return count }
        guard let durationSeconds, let frameRate, durationSeconds > 0, frameRate > 0 else { return nil }
        return Int64((durationSeconds * frameRate).rounded())
    }

    public var requiresHighBitDepthFrameOutput: Bool {
        guard let pixel = videoStream?.pix_fmt?.lowercased() else { return false }
        return pixel.contains("10") || pixel.contains("12") || pixel.contains("14") || pixel.contains("16") || pixel.contains("p010")
    }
}

public actor MediaProbeService {
    private let runner: ExternalProcessRunner
    private var cache: [CacheKey: MediaProbeResult] = [:]

    public init(runner: ExternalProcessRunner = ExternalProcessRunner()) {
        self.runner = runner
    }

    public func probe(url: URL, ffprobe: URL, fingerprint: FileFingerprint? = nil) async throws -> MediaProbeResult {
        let resolvedFingerprint = try fingerprint ?? FileFingerprint.read(from: url)
        let key = CacheKey(path: url.standardizedFileURL.path, fingerprint: resolvedFingerprint)
        if let cached = cache[key] { return cached }
        let collector = LimitedOutputCollector(maximumBytes: 8 * 1_024 * 1_024)
        let errors = LimitedOutputCollector(maximumBytes: 512 * 1_024)
        let result = try await runner.run(
            ExternalProcessRequest(
                executable: ffprobe,
                arguments: [
                    "-v", "error",
                    "-show_streams",
                    "-show_format",
                    "-of", "json",
                    url.path,
                ]
            ),
            onStdout: { collector.append($0) },
            onStderr: { errors.append($0) }
        )
        guard result.exitCode == 0 else {
            throw UniversalConverterError.processFailed(errors.string.isEmpty ? "FFprobe no ha podido leer el archivo." : errors.string)
        }
        let data = collector.data
        guard !data.isEmpty else { throw UniversalConverterError.invalidResult("FFprobe no devolvió información.") }
        let decoded: MediaProbeResult
        do { decoded = try JSONDecoder().decode(MediaProbeResult.self, from: data) }
        catch { throw UniversalConverterError.invalidResult("La información multimedia no es válida: \(error.localizedDescription)") }
        cache[key] = decoded
        return decoded
    }

    public func invalidate(url: URL? = nil) {
        guard let url else { cache.removeAll(); return }
        cache = cache.filter { $0.key.path != url.standardizedFileURL.path }
    }

    public func cancel() async { try? await runner.cancel() }

    private struct CacheKey: Hashable, Sendable {
        let path: String
        let fingerprint: FileFingerprintKey
        init(path: String, fingerprint: FileFingerprint) {
            self.path = path
            self.fingerprint = .init(size: fingerprint.size, modified: fingerprint.modificationTimeNanoseconds)
        }
    }
    private struct FileFingerprintKey: Hashable, Sendable { let size: Int64; let modified: Int64 }
}

public final class LimitedOutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private let maximumBytes: Int
    private var storage = Data()
    private var exceeded = false

    public init(maximumBytes: Int) { self.maximumBytes = max(1_024, maximumBytes) }
    public func append(_ data: Data) {
        lock.lock(); defer { lock.unlock() }
        guard !exceeded else { return }
        let remaining = maximumBytes - storage.count
        if data.count > remaining {
            if remaining > 0 { storage.append(data.prefix(remaining)) }
            exceeded = true
        } else { storage.append(data) }
    }
    public var data: Data { lock.lock(); defer { lock.unlock() }; return storage }
    public var string: String { String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) }
    public var didExceedLimit: Bool { lock.lock(); defer { lock.unlock() }; return exceeded }
}
