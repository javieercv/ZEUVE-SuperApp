import Foundation
import ZEUVEEngines

public struct YouTubeEngineLocator: Sendable {
    private let diagnosticsService: EngineDiagnosticService

    public init(registry: EngineRegistry, diagnosticsService: EngineDiagnosticService? = nil) {
        self.diagnosticsService = diagnosticsService ?? EngineDiagnosticService(registry: registry)
    }

    public static func bundled(diagnosticsService: EngineDiagnosticService? = nil) throws -> YouTubeEngineLocator {
        let registry = try EngineRegistry.bundled()
        return .init(registry: registry, diagnosticsService: diagnosticsService)
    }

    public func paths() async throws -> YouTubeEnginePaths {
        let urls = try await diagnosticsService.requireReady(["yt-dlp", "deno", "ffmpeg", "ffprobe"])
        guard let yt = urls["yt-dlp"], let deno = urls["deno"], let ffmpeg = urls["ffmpeg"], let ffprobe = urls["ffprobe"] else {
            throw YouTubeDownloaderError.enginesUnavailable
        }
        let cacheDirectory = try? YouTubeCacheDirectory.prepare()
        return .init(
            ytDLP: yt,
            deno: deno,
            ffmpeg: ffmpeg,
            ffprobe: ffprobe,
            cacheDirectory: cacheDirectory
        )
    }

    public func diagnostics(forceRefresh: Bool = false) async -> [EngineDiagnostic] {
        await diagnosticsService.diagnoseAll(forceRefresh: forceRefresh)
    }

    public func invalidateDiagnostics() async {
        await diagnosticsService.invalidateDiagnostics()
    }
}
