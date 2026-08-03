import Foundation
import ZEUVECore
import ZEUVEEngines

public actor YouTubeAnalysisService {
    private let locator: YouTubeEngineLocator
    private let logger: LocalLogger?
    private let runner: ExternalProcessRunner
    private let parser = YouTubeAnalysisParser()

    public init(
        locator: YouTubeEngineLocator,
        logger: LocalLogger? = nil,
        runner: ExternalProcessRunner = ExternalProcessRunner()
    ) {
        self.locator = locator
        self.logger = logger
        self.runner = runner
    }

    public func analyze(
        _ input: ValidatedYouTubeURL,
        cookiesFile: URL? = nil,
        proxy: String? = nil,
        proxyCredentials: YouTubeProxyCredentials? = nil,
        onPlaylistEntry: @escaping @Sendable (YouTubePlaylistEntry) -> Void = { _ in },
        onProgress: @escaping @Sendable (Int) -> Void = { _ in }
    ) async throws -> YouTubeMediaAnalysis {
        let cookiesSecurityScope = SecurityScopedResourceAccess(cookiesFile)
        defer { cookiesSecurityScope.stop() }
        let engineStarted = Date()
        let engines = try await locator.paths()
        await logTiming("Resolución de motores para análisis", startedAt: engineStarted, input: input)
        let arguments = try YouTubeAnalysisCommandBuilder().arguments(
            for: input,
            engines: engines,
            cookiesFile: cookiesFile,
            proxy: proxy,
            proxyCredentials: proxyCredentials
        )
        let stderr = LockedDataCollector(maximumBytes: 1_048_576)

        if input.kind == .playlist {
            let decoder = IncrementalLineDecoder(maximumBufferedBytes: 2_097_152)
            let entries = LockedArray<YouTubePlaylistEntry>()
            let metadata = LockedArray<YouTubeMediaAnalysis>()
            let parseFailure = LockedArray<String>()
            let processStarted = Date()
            let result = try await runner.run(
                ExternalProcessRequest(executable: engines.ytDLP, arguments: arguments),
                onStdout: { [parser] data in
                    do {
                        for line in try decoder.append(data) where !line.isEmpty {
                            let lineData = Data(line.utf8)
                            let entry = try parser.parsePlaylistEntry(data: lineData)
                            entries.append(entry)
                            if let analysis = try? parser.parse(data: lineData) { metadata.append(analysis) }
                            onPlaylistEntry(entry)
                            onProgress(entries.count)
                        }
                    } catch {
                        parseFailure.append(error.localizedDescription)
                    }
                },
                onStderr: { stderr.append($0) }
            )
            await logTiming(
                "Análisis de lista con yt-dlp",
                startedAt: processStarted,
                input: input,
                extra: ["codigo_salida": String(result.exitCode), "elementos": String(entries.count)]
            )
            guard result.exitCode == 0 || !entries.values.isEmpty else {
                throw YouTubeDownloaderError.analysisFailed(String(decoding: stderr.data, as: UTF8.self))
            }
            guard parseFailure.values.isEmpty else {
                throw YouTubeDownloaderError.analysisFailed(parseFailure.values.first ?? "Salida no válida")
            }
            let values = entries.values
            guard !values.isEmpty else { throw YouTubeDownloaderError.analysisFailed("La lista no contiene elementos accesibles.") }
            let first = metadata.values.first
            return YouTubeMediaAnalysis(
                canonicalID: input.canonicalID,
                kind: .playlist,
                title: first?.playlistTitle ?? "Lista de reproducción",
                uploader: first?.uploader,
                playlistTitle: first?.playlistTitle ?? "Lista de reproducción",
                playlistCount: values.count,
                playlistEntries: values
            )
        }

        let stdout = LockedDataCollector(maximumBytes: 32 * 1024 * 1024)
        let processStarted = Date()
        let result = try await runner.run(
            ExternalProcessRequest(executable: engines.ytDLP, arguments: arguments),
            onStdout: { stdout.append($0) },
            onStderr: { stderr.append($0) }
        )
        await logTiming(
            "Análisis de vídeo con yt-dlp",
            startedAt: processStarted,
            input: input,
            extra: ["codigo_salida": String(result.exitCode)]
        )
        guard result.exitCode == 0 else {
            throw YouTubeDownloaderError.analysisFailed(String(decoding: stderr.data, as: UTF8.self))
        }
        let analysis = try parser.parse(data: stdout.data)
        guard analysis.liveStatus.canDownloadInVersion020 else { return analysis }
        return analysis
    }

    public func cancel() async throws { try await runner.cancel() }

    private func logTiming(
        _ message: String,
        startedAt: Date,
        input: ValidatedYouTubeURL,
        extra: [String: String] = [:]
    ) async {
        guard let logger else { return }
        var metadata = extra
        metadata["id"] = input.canonicalID
        metadata["tipo"] = input.kind.rawValue
        metadata["duracion_ms"] = String(Int(Date().timeIntervalSince(startedAt) * 1_000))
        _ = try? await logger.write(.debug, category: "youtube-performance", message: message, metadata: metadata)
    }
}

private final class LockedArray<Element>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Element] = []
    func append(_ value: Element) { lock.lock(); storage.append(value); lock.unlock() }
    var values: [Element] { lock.lock(); defer { lock.unlock() }; return storage }
    var count: Int { lock.lock(); defer { lock.unlock() }; return storage.count }
}
