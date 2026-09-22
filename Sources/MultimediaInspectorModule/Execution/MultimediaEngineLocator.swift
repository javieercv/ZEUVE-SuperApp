import Foundation
import ZEUVEEngines

public struct MultimediaEnginePaths: Sendable, Equatable { public let ffmpeg: URL; public let ffprobe: URL }
public struct MultimediaEngineLocator: Sendable {
    private let diagnostics: EngineDiagnosticService
    public init(registry: EngineRegistry, diagnostics: EngineDiagnosticService? = nil) { self.diagnostics = diagnostics ?? EngineDiagnosticService(registry: registry) }
    public func ffprobe() async throws -> URL {
        let values = try await diagnostics.requireReady(["ffprobe"])
        guard let ffprobe = values["ffprobe"] else { throw MultimediaInspectorError.ffprobeUnavailable }
        return ffprobe
    }
    public func ffmpeg() async throws -> URL {
        let values = try await diagnostics.requireReady(["ffmpeg"])
        guard let ffmpeg = values["ffmpeg"] else { throw MultimediaInspectorError.ffmpegUnavailable }
        return ffmpeg
    }
    public func paths() async throws -> MultimediaEnginePaths {
        let values = try await diagnostics.requireReady(["ffmpeg", "ffprobe"])
        guard let ffmpeg = values["ffmpeg"], let ffprobe = values["ffprobe"] else { throw MultimediaInspectorError.ffmpegUnavailable }
        return MultimediaEnginePaths(ffmpeg: ffmpeg, ffprobe: ffprobe)
    }
}
