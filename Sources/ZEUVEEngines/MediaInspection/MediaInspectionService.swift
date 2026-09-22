import Foundation
import ZEUVECore

public enum MediaInspectionParser {
    public static func decode(_ data: Data) throws -> MediaInspectionResult {
        guard !data.isEmpty else { throw MediaInspectionError.emptyOutput }
        do {
            return try JSONDecoder().decode(MediaInspectionResult.self, from: data)
        } catch {
            throw MediaInspectionError.invalidOutput
        }
    }
}

public actor MediaInspectionService {
    private let runner: ExternalProcessRunner
    private var cache: [CacheKey: MediaInspectionResult] = [:]

    public init(runner: ExternalProcessRunner = ExternalProcessRunner()) {
        self.runner = runner
    }

    public func inspect(
        url: URL,
        ffprobe: URL,
        fingerprint: FileFingerprint? = nil,
        useCache: Bool = true
    ) async throws -> MediaInspectionResult {
        guard url.isFileURL else { throw MediaInspectionError.invalidInput }
        let resolvedFingerprint: FileFingerprint
        do {
            resolvedFingerprint = try fingerprint ?? FileFingerprint.read(from: url)
        } catch {
            throw MediaInspectionError.invalidInput
        }

        let key = CacheKey(path: url.standardizedFileURL.resolvingSymlinksInPath().path, fingerprint: resolvedFingerprint)
        if useCache, let cached = cache[key] { return cached }

        let stdout = BoundedDataCollector(maximumBytes: 16 * 1_024 * 1_024)
        let stderr = BoundedDataCollector(maximumBytes: 256 * 1_024)
        let result = try await runner.run(
            ExternalProcessRequest(
                executable: ffprobe,
                arguments: [
                    "-v", "error",
                    "-show_streams",
                    "-show_format",
                    "-show_chapters",
                    "-show_programs",
                    "-of", "json",
                    url.path,
                ]
            ),
            onStdout: { stdout.append($0) },
            onStderr: { stderr.append($0) }
        )
        guard result.exitCode == 0 else {
            throw MediaInspectionError.processFailed(exitCode: result.exitCode)
        }
        guard !stdout.didExceedLimit else { throw MediaInspectionError.outputTooLarge }
        let decoded = try MediaInspectionParser.decode(stdout.data)
        if useCache {
            cache = cache.filter { $0.key.path != key.path || $0.key == key }
            cache[key] = decoded
        }
        return decoded
    }

    public func invalidate(url: URL? = nil) {
        guard let url else {
            cache.removeAll(keepingCapacity: false)
            return
        }
        let canonical = url.standardizedFileURL.resolvingSymlinksInPath().path
        cache = cache.filter { $0.key.path != canonical }
    }

    public func cachedEntryCount() -> Int { cache.count }
    public func cancel() async { try? await runner.cancel() }

    private struct CacheKey: Hashable, Sendable {
        let path: String
        let size: Int64
        let modified: Int64

        init(path: String, fingerprint: FileFingerprint) {
            self.path = path
            size = fingerprint.size
            modified = fingerprint.modificationTimeNanoseconds
        }
    }
}

private final class BoundedDataCollector: @unchecked Sendable {
    private let lock = NSLock()
    private let maximumBytes: Int
    private var storage = Data()
    private var exceeded = false

    init(maximumBytes: Int) {
        self.maximumBytes = max(1_024, maximumBytes)
    }

    func append(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        guard !exceeded else { return }
        let remaining = maximumBytes - storage.count
        if data.count > remaining {
            if remaining > 0 { storage.append(data.prefix(remaining)) }
            exceeded = true
        } else {
            storage.append(data)
        }
    }

    var data: Data {
        lock.lock(); defer { lock.unlock() }
        return storage
    }

    var didExceedLimit: Bool {
        lock.lock(); defer { lock.unlock() }
        return exceeded
    }
}
