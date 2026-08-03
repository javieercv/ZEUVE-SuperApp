import Foundation
import ZEUVECore
import ZEUVEEngines

public actor YouTubeDownloadService {
    private let locator: YouTubeEngineLocator
    private let history: YouTubeHistoryService?
    private let logger: LocalLogger?
    private let runner: ExternalProcessRunner
    private let fileManager: FileManager
    private var cancellationRequested = false

    public init(
        locator: YouTubeEngineLocator,
        history: YouTubeHistoryService? = nil,
        logger: LocalLogger? = nil,
        runner: ExternalProcessRunner = ExternalProcessRunner(),
        fileManager: FileManager = .default
    ) {
        self.locator = locator
        self.history = history
        self.logger = logger
        self.runner = runner
        self.fileManager = fileManager
    }

    public func execute(
        plan: YouTubeDownloadPlan,
        proxyCredentials: YouTubeProxyCredentials? = nil,
        onProgress: @escaping @Sendable (YouTubeDownloadProgress) -> Void = { _ in }
    ) async throws -> YouTubeOperationResult {
        cancellationRequested = false
        let started = Date()
        let output = try YouTubePathValidator.validateOutputFolder(plan.outputFolder, fileManager: fileManager)
        let outputSecurityScope = SecurityScopedResourceAccess(output)
        defer { outputSecurityScope.stop() }
        let cookies = try YouTubePathValidator.validateCookiesFile(plan.cookiesFile, fileManager: fileManager)
        let cookiesSecurityScope = SecurityScopedResourceAccess(cookies)
        defer { cookiesSecurityScope.stop() }
        let engineStarted = Date()
        let engines = try await locator.paths()
        await logTiming(
            "Resolución de motores para descarga",
            startedAt: engineStarted,
            metadata: ["operacion": plan.id.uuidString]
        )
        let estimates = plan.items.compactMap(\.estimatedBytes)
        let estimatedTotal = estimates.count == plan.items.count ? estimates.reduce(0, +) : nil
        try YouTubeDiskSpaceChecker().verify(estimatedBytes: estimatedTotal, at: output)
        var itemResults: [YouTubeItemResult] = []
        var auxiliaryFiles: [URL] = []
        var warnings: [String] = []
        let formatSummary = YouTubeFormatSelector().selection(for: plan.settings).explanation

        for (offset, item) in plan.items.enumerated() {
            if cancellationRequested || Task.isCancelled { break }
            let itemIndex = offset + 1
            let progressCoalescer = LatestValueCoalescer<YouTubeDownloadProgress>(
                minimumIntervalNanoseconds: 100_000_000,
                delivery: onProgress
            )
            onProgress(.init(phase: .preparing, currentItem: item.title, itemIndex: itemIndex, itemTotal: plan.items.count, completedItems: completed(itemResults), failedItems: failed(itemResults), skippedItems: skipped(itemResults)))
            let workspace = try YouTubeTemporaryWorkspace(operationID: UUID(), fileManager: fileManager)
            do {
                let arguments = try YouTubeDownloadCommandBuilder().arguments(
                    item: item,
                    settings: plan.settings,
                    engines: engines,
                    downloadDirectory: workspace.download,
                    temporaryDirectory: workspace.temporary,
                    cookiesFile: cookies,
                    proxy: plan.proxyHost,
                    proxyCredentials: proxyCredentials
                )
                let stdoutDecoder = IncrementalLineDecoder()
                let stderrDecoder = IncrementalLineDecoder()
                let stderr = LockedDataCollector(maximumBytes: 1_048_576)
                let progressParser = YouTubeProgressParser()
                let completedBefore = completed(itemResults)
                let failedBefore = failed(itemResults)
                let skippedBefore = skipped(itemResults)
                let processStarted = Date()
                let result = try await runner.run(
                    ExternalProcessRequest(executable: engines.ytDLP, arguments: arguments, workingDirectory: workspace.root),
                    onStdout: { data in
                        if let lines = try? stdoutDecoder.append(data) {
                            for line in lines {
                                if let update = progressParser.parse(line: line, itemIndex: itemIndex, itemTotal: plan.items.count, title: item.title, completed: completedBefore, failed: failedBefore, skipped: skippedBefore) {
                                    progressCoalescer.submit(update)
                                }
                            }
                        }
                    },
                    onStderr: { data in
                        stderr.append(data)
                        if let lines = try? stderrDecoder.append(data) {
                            for line in lines {
                                if let update = progressParser.parse(line: line, itemIndex: itemIndex, itemTotal: plan.items.count, title: item.title, completed: completedBefore, failed: failedBefore, skipped: skippedBefore) {
                                    progressCoalescer.submit(update)
                                }
                            }
                        }
                    }
                )
                await logTiming(
                    "Descarga y posprocesado con yt-dlp",
                    startedAt: processStarted,
                    metadata: [
                        "id": item.canonicalID,
                        "indice": String(itemIndex),
                        "codigo_salida": String(result.exitCode)
                    ]
                )
                progressCoalescer.flush()
                guard result.exitCode == 0 else {
                    progressCoalescer.cancel()
                    let classified = YouTubeErrorClassifier().classify(stderr: String(decoding: stderr.data, as: UTF8.self))
                    itemResults.append(.init(canonicalID: item.canonicalID, title: item.title, status: .failed, errorReference: classified.technicalReference, userMessage: classified.userMessage))
                    try? workspace.clean(fileManager: fileManager)
                    continue
                }
                if plan.settings.metadata.saveInfoJSON {
                    _ = try YouTubeSafeMetadataWriter(fileManager: fileManager).writeInfo(
                        for: item,
                        settings: plan.settings,
                        formatSummary: formatSummary,
                        to: workspace.download
                    )
                }
                progressCoalescer.flush()
                onProgress(.init(phase: .publishing, currentItem: item.title, itemIndex: itemIndex, itemTotal: plan.items.count, completedItems: completed(itemResults), failedItems: failed(itemResults), skippedItems: skipped(itemResults)))
                let candidates = try YouTubeOutputPublisher(fileManager: fileManager).candidateFiles(in: workspace)
                let destination = try destinationFolder(for: item, base: output, settings: plan.settings)
                let verificationStarted = Date()
                try await verifyMediaFiles(candidates, ffprobe: engines.ffprobe)
                await logTiming(
                    "Validación de resultados con FFprobe",
                    startedAt: verificationStarted,
                    metadata: ["id": item.canonicalID, "archivos": String(candidates.count)]
                )
                let publishingStarted = Date()
                let published = try YouTubeOutputPublisher(fileManager: fileManager).publish(files: candidates, to: destination, policy: plan.settings.conflictPolicy)
                await logTiming(
                    "Publicación de resultados",
                    startedAt: publishingStarted,
                    metadata: ["id": item.canonicalID, "archivos": String(published.count)]
                )
                if published.isEmpty, plan.settings.conflictPolicy == .skip, !candidates.isEmpty {
                    itemResults.append(.init(
                        canonicalID: item.canonicalID,
                        title: item.title,
                        status: .skipped,
                        userMessage: "Se ha omitido porque ya existían todos los archivos de salida."
                    ))
                } else {
                    guard !published.isEmpty else { throw YouTubeDownloaderError.noPublishedFiles }
                    itemResults.append(.init(canonicalID: item.canonicalID, title: item.title, status: .completed, outputFiles: published))
                }
                try workspace.clean(fileManager: fileManager)
                progressCoalescer.cancel()
            } catch is CancellationError {
                progressCoalescer.cancel()
                itemResults.append(.init(canonicalID: item.canonicalID, title: item.title, status: .cancelled, userMessage: "Operación cancelada por el usuario."))
                try? workspace.clean(fileManager: fileManager)
                cancellationRequested = true
                break
            } catch {
                progressCoalescer.cancel()
                let reference = "YT-\(UUID().uuidString.prefix(8))"
                itemResults.append(.init(canonicalID: item.canonicalID, title: item.title, status: .failed, errorReference: reference, userMessage: error.localizedDescription))
                _ = try? await logger?.write(.error, category: "youtube", message: "Fallo de descarga", metadata: ["id": item.canonicalID, "referencia": reference])
                try? workspace.clean(fileManager: fileManager)
            }
        }

        if plan.settings.metadata.savePlaylistMetadata, !cancellationRequested, !Task.isCancelled {
            do {
                auxiliaryFiles = try await publishPlaylistMetadata(
                    plan: plan,
                    results: itemResults,
                    baseOutput: output
                )
            } catch {
                warnings.append("No se han podido publicar los metadatos sanitizados de la lista: \(error.localizedDescription)")
                _ = try? await logger?.write(
                    .warning,
                    category: "youtube",
                    message: "Fallo al publicar metadatos sanitizados de playlist",
                    metadata: ["operacion": plan.id.uuidString]
                )
            }
        }

        let result = YouTubeOperationResult(
            id: plan.id,
            startedAt: started,
            outputFolder: output,
            mode: plan.settings.mode,
            formatSummary: formatSummary,
            items: itemResults,
            auxiliaryFiles: auxiliaryFiles,
            warnings: warnings,
            wasCancelled: cancellationRequested || Task.isCancelled
        )
        _ = try? history?.save(result)
        return result
    }

    public func cancel() async throws {
        cancellationRequested = true
        try await runner.cancel()
    }

    private func destinationFolder(for item: YouTubeDownloadItem, base: URL, settings: YouTubeDownloadSettings) throws -> URL {
        guard settings.createPlaylistFolder, let playlist = item.playlistTitle, !playlist.isEmpty else { return base }
        let name = try YouTubeFilenamePolicy().sanitize(playlist)
        let folder = base.appendingPathComponent(name, isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func publishPlaylistMetadata(
        plan: YouTubeDownloadPlan,
        results: [YouTubeItemResult],
        baseOutput: URL
    ) async throws -> [URL] {
        let groups = Dictionary(grouping: plan.items.compactMap { item -> YouTubeDownloadItem? in
            guard let title = item.playlistTitle, !title.isEmpty else { return nil }
            return item
        }, by: { $0.playlistTitle! })
        guard !groups.isEmpty else { return [] }
        var statuses: [String: YouTubeItemResultStatus] = [:]
        for result in results { statuses[result.canonicalID] = result.status }
        var published: [URL] = []
        for title in groups.keys.sorted() {
            guard !cancellationRequested, !Task.isCancelled, let items = groups[title] else { break }
            let workspace = try YouTubeTemporaryWorkspace(operationID: UUID(), fileManager: fileManager)
            do {
                _ = try YouTubeSafeMetadataWriter(fileManager: fileManager).writePlaylist(
                    title: title,
                    items: items.sorted { ($0.playlistIndex ?? Int.max) < ($1.playlistIndex ?? Int.max) },
                    resultsByCanonicalID: statuses,
                    to: workspace.download
                )
                let destinationItem = items[0]
                let destination = try destinationFolder(for: destinationItem, base: baseOutput, settings: plan.settings)
                let files = try YouTubeOutputPublisher(fileManager: fileManager).candidateFiles(in: workspace)
                published += try YouTubeOutputPublisher(fileManager: fileManager).publish(
                    files: files,
                    to: destination,
                    policy: plan.settings.conflictPolicy
                )
                try workspace.clean(fileManager: fileManager)
            } catch {
                try? workspace.clean(fileManager: fileManager)
                throw error
            }
        }
        return published
    }

    private func verifyMediaFiles(_ files: [URL], ffprobe: URL) async throws {
        let mediaExtensions: Set<String> = ["mp4", "mkv", "webm", "m4a", "mp3", "flac", "wav", "opus", "mov"]
        for file in files where mediaExtensions.contains(file.pathExtension.lowercased()) {
            let result = try await runner.run(ExternalProcessRequest(executable: ffprobe, arguments: ["-v", "error", "-show_entries", "format=duration", "-of", "json", "-i", file.path]))
            guard result.exitCode == 0 else { throw YouTubeDownloaderError.noPublishedFiles }
        }
    }

    private func logTiming(_ message: String, startedAt: Date, metadata: [String: String]) async {
        guard let logger else { return }
        var values = metadata
        values["duracion_ms"] = String(Int(Date().timeIntervalSince(startedAt) * 1_000))
        _ = try? await logger.write(.debug, category: "youtube-performance", message: message, metadata: values)
    }

    nonisolated private func completed(_ values: [YouTubeItemResult]) -> Int { values.filter { $0.status == .completed }.count }
    nonisolated private func failed(_ values: [YouTubeItemResult]) -> Int { values.filter { $0.status == .failed }.count }
    nonisolated private func skipped(_ values: [YouTubeItemResult]) -> Int { values.filter { $0.status == .skipped }.count }
}
