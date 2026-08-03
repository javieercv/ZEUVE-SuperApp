import Foundation
import ZEUVEEngines

public struct FFmpegCapabilities: Codable, Sendable, Equatable {
    public let encoders: Set<String>
    public let muxers: Set<String>
    public let filters: Set<String>

    public init(encoders: Set<String> = [], muxers: Set<String> = [], filters: Set<String> = []) {
        self.encoders = encoders
        self.muxers = muxers
        self.filters = filters
    }

    public var hasSoftwareH264: Bool { encoders.contains("libx264") }
    public var hasVideoToolboxH264: Bool { encoders.contains("h264_videotoolbox") }
    public var hasWebPEncoder: Bool { encoders.contains("libwebp") || encoders.contains("libwebp_anim") }
    public var hasAPNGEncoder: Bool { encoders.contains("apng") && muxers.contains("apng") }
    public var hasGIFEncoder: Bool { encoders.contains("gif") && muxers.contains("gif") }
}

public actor FFmpegCapabilityProbe {
    private let runner: ExternalProcessRunner
    private var cache: [String: FFmpegCapabilities] = [:]

    public init(runner: ExternalProcessRunner = ExternalProcessRunner()) {
        self.runner = runner
    }

    public func inspect(executable: URL, forceRefresh: Bool = false) async throws -> FFmpegCapabilities {
        let key = try cacheKey(for: executable)
        if !forceRefresh, let cached = cache[key] { return cached }
        let encoders = try await list(executable: executable, argument: "-encoders", parser: Self.parseEncoders)
        let muxers = try await list(executable: executable, argument: "-muxers", parser: Self.parseMuxers)
        let filters = try await list(executable: executable, argument: "-filters", parser: Self.parseFilters)
        let result = FFmpegCapabilities(encoders: encoders, muxers: muxers, filters: filters)
        cache = [key: result]
        return result
    }

    public func invalidate() { cache.removeAll() }

    private func list(
        executable: URL,
        argument: String,
        parser: @Sendable (String) -> Set<String>
    ) async throws -> Set<String> {
        let collector = LimitedOutputCollector(maximumBytes: 8 * 1_024 * 1_024)
        let request = ExternalProcessRequest(
            executable: executable,
            arguments: ["-hide_banner", argument],
            environment: ["LC_ALL": "C", "LANG": "C"]
        )
        let result = try await runner.run(request, onStdout: { collector.append($0) }, onStderr: { collector.append($0) })
        guard result.succeeded else { throw UniversalConverterError.processFailed("FFmpeg no ha podido enumerar sus capacidades.") }
        return parser(collector.string)
    }

    private func cacheKey(for executable: URL) throws -> String {
        let values = try executable.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return "\(executable.standardizedFileURL.path)|\(values.fileSize ?? -1)|\(values.contentModificationDate?.timeIntervalSince1970 ?? 0)"
    }

    static func parseEncoders(_ output: String) -> Set<String> {
        parseNames(output, flagLength: 6)
    }

    static func parseMuxers(_ output: String) -> Set<String> {
        parseNames(output, flagLength: 1)
    }

    static func parseFilters(_ output: String) -> Set<String> {
        parseNames(output, flagLength: 3)
    }

    private static func parseNames(_ output: String, flagLength: Int) -> Set<String> {
        var result: Set<String> = []
        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("--"), !line.hasPrefix("Encoders:"), !line.hasPrefix("Muxers:"), !line.hasPrefix("Filters:") else { continue }
            let parts = line.split(whereSeparator: \.isWhitespace)
            guard parts.count >= 2 else { continue }
            let flags = String(parts[0])
            guard flags.count >= flagLength, flags.allSatisfy({ $0 == "." || $0.isLetter }) else { continue }
            let names = parts[1].split(separator: ",")
            for name in names where !name.isEmpty { result.insert(String(name)) }
        }
        return result
    }
}
