import Foundation
import ZEUVEEngines

public struct UniversalDownloaderEngineLocator: Sendable {
    private let registry: EngineRegistry
    private let diagnosticsService: EngineDiagnosticService
    private let overrideManager: EngineOverrideManager

    public init(
        registry: EngineRegistry,
        diagnosticsService: EngineDiagnosticService? = nil,
        overrideManager: EngineOverrideManager = EngineOverrideManager()
    ) {
        self.registry = registry
        self.diagnosticsService = diagnosticsService ?? EngineDiagnosticService(registry: registry)
        self.overrideManager = overrideManager
    }

    public static func bundled(diagnosticsService: EngineDiagnosticService? = nil) throws -> UniversalDownloaderEngineLocator {
        let registry = try EngineRegistry.bundled()
        return .init(registry: registry, diagnosticsService: diagnosticsService)
    }

    public func paths() async throws -> DownloadEnginePaths {
        let urls = try await diagnosticsService.requireReady(["yt-dlp", "deno", "ffmpeg", "ffprobe"])
        guard let yt = urls["yt-dlp"], let deno = urls["deno"], let ffmpeg = urls["ffmpeg"], let ffprobe = urls["ffprobe"] else {
            throw UniversalDownloaderError.enginesUnavailable
        }
        let cacheDirectory = try? YTDLPCacheDirectory.prepare()
        return .init(
            ytDLP: overrideURL(named: "yt-dlp") ?? yt,
            deno: overrideURL(named: "deno") ?? deno,
            ffmpeg: overrideURL(named: "ffmpeg") ?? ffmpeg,
            ffprobe: overrideURL(named: "ffprobe") ?? ffprobe,
            galleryDL: await optionalReadyURL(named: "gallery-dl"),
            instagramCatalog: await optionalReadyURL(named: "instaloader-zeuve"),
            browserHelper: await optionalReadyURL(named: "playwright-browser"),
            cacheDirectory: cacheDirectory
        )
    }

    public func diagnostics(forceRefresh: Bool = false) async -> [EngineDiagnostic] {
        await diagnosticsService.diagnoseAll(forceRefresh: forceRefresh)
    }

    public func invalidateDiagnostics() async {
        await diagnosticsService.invalidateDiagnostics()
    }

    private func optionalReadyURL(named name: String) async -> URL? {
        if let override = overrideURL(named: name) { return override }
        guard registry.manifest.engines.contains(where: { $0.name == name }) else { return nil }
        let diagnostics = await diagnosticsService.diagnoseAll(forceRefresh: false)
        guard diagnostics.first(where: { $0.descriptor.name == name })?.isReady == true else { return nil }
        return try? registry.executableURL(named: name)
    }

    private func overrideURL(named name: String) -> URL? {
        (try? overrideManager.activeExecutable(named: name)) ?? nil
    }
}
