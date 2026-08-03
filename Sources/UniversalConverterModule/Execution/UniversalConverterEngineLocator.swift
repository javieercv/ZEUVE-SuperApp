import Foundation
import ZEUVEEngines

public struct UniversalConverterEnginePaths: Sendable, Equatable {
    public let ffmpeg: URL?
    public let ffprobe: URL?
    public let pandoc: URL?
    public let calibre: URL?
    public let ghostscript: URL?

    public init(
        ffmpeg: URL? = nil,
        ffprobe: URL? = nil,
        pandoc: URL? = nil,
        calibre: URL? = nil,
        ghostscript: URL? = nil
    ) {
        self.ffmpeg = ffmpeg
        self.ffprobe = ffprobe
        self.pandoc = pandoc
        self.calibre = calibre
        self.ghostscript = ghostscript
    }
}

public struct UniversalConverterEngineRequirements: Sendable, Equatable {
    public var media = false
    public var pandoc = false
    public var calibre = false
    public var ghostscript = false

    public init() {}
}

public struct UniversalConverterEngineLocator: Sendable {
    private let registry: EngineRegistry
    private let diagnostics: EngineDiagnosticService
    private let ffmpegCapabilities: FFmpegCapabilityProbe

    public init(
        registry: EngineRegistry,
        diagnosticsService: EngineDiagnosticService? = nil,
        ffmpegCapabilities: FFmpegCapabilityProbe = FFmpegCapabilityProbe()
    ) {
        self.registry = registry
        diagnostics = diagnosticsService ?? EngineDiagnosticService(registry: registry)
        self.ffmpegCapabilities = ffmpegCapabilities
    }

    public static func bundled(diagnosticsService: EngineDiagnosticService? = nil) throws -> UniversalConverterEngineLocator {
        let registry = try EngineRegistry.bundled()
        return .init(registry: registry, diagnosticsService: diagnosticsService)
    }

    public func paths(requirements: UniversalConverterEngineRequirements) async throws -> UniversalConverterEnginePaths {
        let ffmpeg: URL?
        let ffprobe: URL?
        if requirements.media {
            let media = try await diagnostics.requireReady(["ffmpeg", "ffprobe"])
            guard let readyFFmpeg = media["ffmpeg"], let readyFFprobe = media["ffprobe"] else {
                throw UniversalConverterError.engineUnavailable("FFmpeg y FFprobe no están disponibles.")
            }
            ffmpeg = readyFFmpeg
            ffprobe = readyFFprobe
        } else {
            ffmpeg = nil
            ffprobe = nil
        }

        let pandoc = await optionalExecutable(
            name: "pandoc",
            directRelativePaths: ["pandoc/pandoc", "pandoc/bin/pandoc"]
        )
        let calibre = await optionalExecutable(
            name: "calibre",
            directRelativePaths: [
                "calibre/Calibre.app/Contents/MacOS/ebook-convert",
                "calibre/ebook-convert",
                "calibre/bin/ebook-convert",
            ]
        )
        let ghostscript = await optionalExecutable(
            name: "ghostscript",
            directRelativePaths: ["ghostscript/bin/gs", "ghostscript/gs"]
        )

        if requirements.pandoc, pandoc == nil {
            throw UniversalConverterError.dependencyMissing("Pandoc")
        }
        if requirements.calibre, calibre == nil {
            throw UniversalConverterError.dependencyMissing("Calibre")
        }
        if requirements.ghostscript, ghostscript == nil {
            throw UniversalConverterError.dependencyMissing("Ghostscript")
        }

        return .init(
            ffmpeg: ffmpeg,
            ffprobe: ffprobe,
            pandoc: pandoc,
            calibre: calibre,
            ghostscript: ghostscript
        )
    }

    public func paths(requireMedia: Bool = true) async throws -> UniversalConverterEnginePaths {
        var requirements = UniversalConverterEngineRequirements()
        requirements.media = requireMedia
        return try await paths(requirements: requirements)
    }

    public func availability(forceRefresh: Bool = false) async -> ConverterEngineAvailability {
        let snapshot = await diagnosticsSnapshot(forceRefresh: forceRefresh)
        let ready = Set(snapshot.filter(\.isReady).map { $0.descriptor.name.lowercased() })
        let directPandoc = await optionalExecutable(name: "pandoc", directRelativePaths: ["pandoc/pandoc", "pandoc/bin/pandoc"]) != nil
        let directCalibre = await optionalExecutable(name: "calibre", directRelativePaths: ["calibre/Calibre.app/Contents/MacOS/ebook-convert", "calibre/ebook-convert", "calibre/bin/ebook-convert"]) != nil
        let directGhostscript = await optionalExecutable(name: "ghostscript", directRelativePaths: ["ghostscript/bin/gs", "ghostscript/gs"]) != nil
        let mediaReady = ready.contains("ffmpeg") && ready.contains("ffprobe")
        var capabilities = FFmpegCapabilities()
        if mediaReady, let executable = try? await diagnostics.requireReady(["ffmpeg"])["ffmpeg"] {
            capabilities = (try? await ffmpegCapabilities.inspect(executable: executable, forceRefresh: forceRefresh)) ?? FFmpegCapabilities()
        }
        return ConverterEngineAvailability(
            ffmpeg: mediaReady,
            imageIO: Self.nativeImageIOAvailable,
            pdfKit: Self.nativePDFKitAvailable,
            pandoc: ready.contains("pandoc") || directPandoc,
            calibre: ready.contains("calibre") || directCalibre,
            ghostscript: ready.contains("ghostscript") || directGhostscript,
            videoToolbox: Self.videoToolboxAvailable && capabilities.hasVideoToolboxH264,
            softwareH264: capabilities.hasSoftwareH264,
            webPEncoder: capabilities.hasWebPEncoder
        )
    }

    public func diagnosticsSnapshot(forceRefresh: Bool = false) async -> [EngineDiagnostic] {
        await diagnostics.diagnoseAll(forceRefresh: forceRefresh)
    }

    private func optionalExecutable(name: String, directRelativePaths: [String]) async -> URL? {
        for relativePath in directRelativePaths {
            let direct = registry.resourceRoot.appendingPathComponent(relativePath).standardizedFileURL
            if FileManager.default.isExecutableFile(atPath: direct.path) { return direct }
        }
        guard (try? registry.descriptor(named: name)) != nil else { return nil }
        return try? await diagnostics.requireReady([name])[name]
    }

    private static var nativeImageIOAvailable: Bool {
        #if canImport(ImageIO)
        true
        #else
        false
        #endif
    }

    private static var nativePDFKitAvailable: Bool {
        #if canImport(PDFKit)
        true
        #else
        false
        #endif
    }

    private static var videoToolboxAvailable: Bool {
        #if canImport(VideoToolbox)
        true
        #else
        false
        #endif
    }
}
