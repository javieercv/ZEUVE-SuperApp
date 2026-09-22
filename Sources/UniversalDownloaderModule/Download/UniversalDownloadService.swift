import Foundation
import ZEUVECore
import ZEUVEEngines

public actor UniversalDownloadService {
    private let locator: UniversalDownloaderEngineLocator
    private let history: UniversalDownloadHistoryService?
    private let logger: LocalLogger?
    private let runner: ExternalProcessRunner
    private let fileManager: FileManager
    private let outputValidator: DownloadOutputValidator
    private var cancellationRequested = false
    private var adaptiveFragmentCeiling = 16

    public init(
        locator: UniversalDownloaderEngineLocator,
        history: UniversalDownloadHistoryService? = nil,
        logger: LocalLogger? = nil,
        runner: ExternalProcessRunner = ExternalProcessRunner(),
        fileManager: FileManager = .default
    ) {
        self.locator = locator
        self.history = history
        self.logger = logger
        self.runner = runner
        self.fileManager = fileManager
        self.outputValidator = DownloadOutputValidator(runner: runner)
    }

    public func execute(
        plan: UniversalDownloadPlan,
        proxyCredentials: DownloadProxyCredentials? = nil,
        onProgress: @escaping @Sendable (UniversalDownloadProgress) -> Void = { _ in },
        onWarning: @escaping @Sendable (String) -> Void = { _ in }
    ) async throws -> UniversalDownloadResult {
        cancellationRequested = false
        adaptiveFragmentCeiling = 16
        let started = Date()
        let output = try DownloadPathValidator.validateOutputFolder(plan.outputFolder, fileManager: fileManager)
        let outputSecurityScope = SecurityScopedResourceAccess(output)
        defer { outputSecurityScope.stop() }
        let cookies = try DownloadPathValidator.validateCookiesFile(plan.cookiesFile, fileManager: fileManager)
        let cookiesSecurityScope = SecurityScopedResourceAccess(cookies)
        defer { cookiesSecurityScope.stop() }
        let cookieHeader = plan.cookieHeaderFile
        let cookieHeaderSecurityScope = SecurityScopedResourceAccess(cookieHeader)
        defer { cookieHeaderSecurityScope.stop() }
        let engineStarted = Date()
        let engines = try await locator.paths()
        await logTiming(
            "Resolución de motores para descarga",
            startedAt: engineStarted,
            metadata: ["operacion": plan.id.uuidString]
        )
        let estimates = plan.items.compactMap(\.estimatedBytes)
        let estimatedTotal = estimates.count == plan.items.count ? estimates.reduce(0, +) : nil
        try DownloadDiskSpaceChecker().verify(estimatedBytes: estimatedTotal, at: output)
        var itemResults: [UniversalDownloadItemResult] = []
        var auxiliaryFiles: [URL] = []
        var warnings: [String] = []
        let containsDirectItems = plan.items.contains { !$0.isPageDiscovered }
        let formatSummary = YTDLPFormatSelector().summary(for: plan)

        for (offset, item) in plan.items.enumerated() {
            if cancellationRequested || Task.isCancelled { break }
            let itemIndex = offset + 1
            let progressCoalescer = LatestValueCoalescer<UniversalDownloadProgress>(
                minimumIntervalNanoseconds: 100_000_000,
                delivery: onProgress
            )
            onProgress(.init(phase: .preparing, currentItem: item.title, itemIndex: itemIndex, itemTotal: plan.items.count, completedItems: completed(itemResults), failedItems: failed(itemResults), skippedItems: skipped(itemResults)))
            let workspace = try DownloadWorkspace(operationID: UUID(), fileManager: fileManager)
            do {
                let itemSettings = plan.settings(for: item)
                let completedBefore = completed(itemResults)
                let failedBefore = failed(itemResults)
                let skippedBefore = skipped(itemResults)
                let downloadOutcome = try await downloadItem(
                    item,
                    settings: itemSettings,
                    engines: engines,
                    workspace: workspace,
                    cookies: cookies,
                    browserCookies: cookies == nil ? plan.browserCookies : nil,
                    cookieHeaderFile: cookieHeader,
                    proxy: plan.proxyHost,
                    proxyCredentials: proxyCredentials,
                    itemIndex: itemIndex,
                    itemTotal: plan.items.count,
                    completedBefore: completedBefore,
                    failedBefore: failedBefore,
                    skippedBefore: skippedBefore,
                    progressCoalescer: progressCoalescer,
                    onProgress: onProgress
                )
                progressCoalescer.flush()
                guard downloadOutcome.succeeded else {
                    progressCoalescer.cancel()
                    let classified = DownloadErrorClassifier().classify(stderr: downloadOutcome.stderr)
                    itemResults.append(.init(
                        canonicalID: item.canonicalID,
                        title: item.title,
                        status: .failed,
                        errorReference: classified.technicalReference,
                        userMessage: classified.userMessage
                    ))
                    _ = try? await logger?.write(
                        .error,
                        category: "universal-downloader",
                        message: "Los motores no han producido un archivo descargable",
                        metadata: [
                            "id": item.canonicalID,
                            "motor_inicial": item.engineKind.rawValue,
                            "referencia": classified.technicalReference,
                        ]
                    )
                    try? workspace.clean(fileManager: fileManager)
                    continue
                }
                let metadataWriter = DownloadSafeMetadataWriter(fileManager: fileManager)
                if itemSettings.metadata.saveInfoJSON {
                    _ = try metadataWriter.writeInfo(
                        for: item,
                        settings: itemSettings,
                        formatSummary: formatSummary,
                        to: workspace.download
                    )
                }
                if itemSettings.metadata.saveDescription {
                    _ = try metadataWriter.writeDescription(for: item, to: workspace.download)
                }
                progressCoalescer.flush()
                var candidates = try DownloadOutputPublisher(fileManager: fileManager).candidateFiles(in: workspace)
                var alreadyVerified = Set<URL>()
                if item.isPageDiscovered, itemSettings.pageSource.embedSourceMetadata, let origin = item.pageOrigin {
                    onProgress(.init(phase: .embeddingMetadata, currentItem: item.title, itemIndex: itemIndex, itemTotal: plan.items.count, completedItems: completed(itemResults), failedItems: failed(itemResults), skippedItems: skipped(itemResults)))
                    let metadataResult = await embedPageOriginMetadata(
                        in: candidates,
                        origin: origin,
                        includeDownloadDate: itemSettings.pageSource.includeDownloadDate,
                        ffmpeg: engines.ffmpeg,
                        ffprobe: engines.ffprobe
                    )
                    warnings.append(contentsOf: metadataResult.warnings)
                    alreadyVerified.formUnion(metadataResult.verifiedFiles.map { $0.standardizedFileURL })
                    if cancellationRequested || Task.isCancelled { throw CancellationError() }
                    candidates = try DownloadOutputPublisher(fileManager: fileManager).candidateFiles(in: workspace)
                }
                let destination = try destinationFolder(for: item, base: output, settings: itemSettings)
                onProgress(.init(phase: .verifying, currentItem: item.title, itemIndex: itemIndex, itemTotal: plan.items.count, completedItems: completed(itemResults), failedItems: failed(itemResults), skippedItems: skipped(itemResults)))
                let verificationStarted = Date()
                try await outputValidator.verifyMediaFiles(candidates.filter { !alreadyVerified.contains($0.standardizedFileURL) }, ffprobe: engines.ffprobe)
                await logTiming(
                    "Validación de resultados con FFprobe",
                    startedAt: verificationStarted,
                    metadata: ["id": item.canonicalID, "archivos": String(candidates.count)]
                )
                onProgress(.init(phase: .publishing, currentItem: item.title, itemIndex: itemIndex, itemTotal: plan.items.count, completedItems: completed(itemResults), failedItems: failed(itemResults), skippedItems: skipped(itemResults)))
                let publishingStarted = Date()
                let published = try DownloadOutputPublisher(fileManager: fileManager).publish(files: candidates, to: destination, policy: itemSettings.conflictPolicy)
                if item.isPageDiscovered, itemSettings.pageSource.applyMacOSWhereFrom, let origin = item.pageOrigin {
                    for file in published where DownloadOutputValidator.isMediaFile(file) {
                        do {
                            try MacOSWhereFromWriter.apply(originURL: origin.pageURL, to: file)
                        } catch {
                            warnings.append("\(file.lastPathComponent): no se ha podido guardar el atributo «De dónde»: \(error.localizedDescription)")
                        }
                    }
                }
                await logTiming(
                    "Publicación de resultados",
                    startedAt: publishingStarted,
                    metadata: ["id": item.canonicalID, "archivos": String(published.count)]
                )
                if item.mediaKind == .profilePicture,
                   item.safeMetadata["keep_local_profile_history"] == "true",
                   let username = item.safeMetadata["profile_username"] {
                    for file in published where DownloadOutputValidator.imageExtensions.contains(file.pathExtension.lowercased()) {
                        do {
                            _ = try InstagramProfilePictureHistoryStore(fileManager: fileManager).preserve(
                                file: file,
                                username: username,
                                sourcePage: item.safeMetadata["source_page"]
                            )
                        } catch {
                            warnings.append("\(file.lastPathComponent): no se ha podido conservar en el historial local de fotos de perfil: \(error.localizedDescription)")
                        }
                    }
                }
                if published.isEmpty, itemSettings.conflictPolicy == .skip, !candidates.isEmpty {
                    itemResults.append(.init(
                        canonicalID: item.canonicalID,
                        title: item.title,
                        status: .skipped,
                        userMessage: "Se ha omitido porque ya existían todos los archivos de salida."
                    ))
                } else {
                    guard !published.isEmpty else { throw UniversalDownloaderError.noPublishedFiles }
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
                _ = try? await logger?.write(.error, category: "universal-downloader", message: "Fallo de descarga", metadata: ["id": item.canonicalID, "referencia": reference])
                try? workspace.clean(fileManager: fileManager)
            }
        }

        if plan.items.contains(where: { plan.settings(for: $0).metadata.savePlaylistMetadata }), containsDirectItems, !cancellationRequested, !Task.isCancelled {
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
                    category: "universal-downloader",
                    message: "Fallo al publicar metadatos sanitizados de playlist",
                    metadata: ["operacion": plan.id.uuidString]
                )
            }
        }

        let result = UniversalDownloadResult(
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
        if let history, let failure = ZEUVEHistoryPersistence.attempt({ try history.save(result) }) {
            onWarning(failure.warning)
            _ = try? await logger?.write(
                .warning,
                category: "universal-downloader",
                message: "No se ha podido guardar el historial",
                metadata: failure.logMetadata
            )
        }
        return result
    }

    public func cancel() async throws {
        cancellationRequested = true
        try await runner.cancel()
    }

    private func downloadItem(
        _ item: UniversalDownloadItem,
        settings: UniversalDownloadSettings,
        engines: DownloadEnginePaths,
        workspace: DownloadWorkspace,
        cookies: URL?,
        browserCookies: DownloadBrowserCookieSource?,
        cookieHeaderFile: URL?,
        proxy: String?,
        proxyCredentials: DownloadProxyCredentials?,
        itemIndex: Int,
        itemTotal: Int,
        completedBefore: Int,
        failedBefore: Int,
        skippedBefore: Int,
        progressCoalescer: LatestValueCoalescer<UniversalDownloadProgress>,
        onProgress: @escaping @Sendable (UniversalDownloadProgress) -> Void
    ) async throws -> DownloadAttemptOutcome {
        let useSession = Self.shouldUseSession(for: item)
        let cookies = useSession ? cookies : nil
        let browserCookies = useSession ? browserCookies : nil
        let cookieHeaderFile = useSession ? cookieHeaderFile : nil

        if item.engineKind == .galleryDL, settings.mode == .original {
            guard let galleryDL = engines.galleryDL else {
                throw UniversalDownloaderError.optionalEngineUnavailable("gallery-dl")
            }
            onProgress(.init(
                phase: .downloading,
                currentItem: item.title,
                itemIndex: itemIndex,
                itemTotal: itemTotal,
                completedItems: completedBefore,
                failedItems: failedBefore,
                skippedItems: skippedBefore
            ))
            let arguments = try GalleryDLDownloadCommandBuilder().arguments(
                item: item,
                settings: settings,
                downloadDirectory: workspace.download,
                cookiesFile: cookies,
                proxy: proxy,
                proxyCredentials: proxyCredentials
            )
            let stderr = LockedDataCollector(maximumBytes: 1_048_576)
            let galleryStarted = Date()
            let result = try await runner.run(
                ExternalProcessRequest(executable: galleryDL, arguments: arguments, workingDirectory: workspace.root),
                onStdout: { _ in },
                onStderr: { stderr.append($0) }
            )
            let galleryError = String(decoding: stderr.data, as: UTF8.self)
            let galleryCandidates = try DownloadOutputPublisher(fileManager: fileManager).candidateFiles(in: workspace)
            await logTiming(
                "Descarga con gallery-dl",
                startedAt: galleryStarted,
                metadata: [
                    "id": item.canonicalID,
                    "codigo_salida": String(result.exitCode),
                    "archivos": String(galleryCandidates.count),
                    "plataforma": item.platform.rawValue,
                ]
            )

            if result.succeeded, !galleryCandidates.isEmpty {
                return DownloadAttemptOutcome(succeeded: true, stderr: galleryError)
            }

            guard TikTokDownloadFallbackPolicy.shouldRetryWithYTDLP(
                platform: item.platform,
                processSucceeded: result.succeeded,
                candidateCount: galleryCandidates.count
            ) else {
                let detail = galleryError.isEmpty
                    ? "gallery-dl terminó sin producir archivos."
                    : galleryError
                return DownloadAttemptOutcome(succeeded: false, stderr: detail)
            }

            try workspace.resetForRetry(fileManager: fileManager)
            await logPerformance(
                "gallery-dl no ha producido un TikTok; se activa el respaldo yt-dlp",
                metadata: [
                    "id": item.canonicalID,
                    "causa": result.succeeded ? "sin_archivos" : "fallo_motor",
                    "codigo_salida": String(result.exitCode),
                ]
            )
            let fallback = try await runDownloadAttempt(
                item,
                settings: settings,
                engines: engines,
                workspace: workspace,
                cookies: cookies,
                browserCookies: browserCookies,
                proxy: proxy,
                proxyCredentials: proxyCredentials,
                resolvedMedia: nil,
                fragments: settings.network.concurrentFragments,
                target: "tiktok_gallery_fallback",
                itemIndex: itemIndex,
                itemTotal: itemTotal,
                completedBefore: completedBefore,
                failedBefore: failedBefore,
                skippedBefore: skippedBefore,
                progressCoalescer: progressCoalescer,
                onProgress: onProgress
            )
            let fallbackCandidates = try DownloadOutputPublisher(fileManager: fileManager).candidateFiles(in: workspace)
            await logPerformance(
                "Resultado del respaldo TikTok con yt-dlp",
                metadata: [
                    "id": item.canonicalID,
                    "resultado": fallback.succeeded ? "proceso_correcto" : "fallo_motor",
                    "archivos": String(fallbackCandidates.count),
                ]
            )
            if fallback.succeeded, !fallbackCandidates.isEmpty {
                return fallback
            }

            let galleryDetail = galleryError.isEmpty
                ? "gallery-dl terminó sin producir archivos."
                : galleryError
            let fallbackDetail = fallback.stderr.isEmpty
                ? "yt-dlp terminó sin producir archivos."
                : fallback.stderr
            return DownloadAttemptOutcome(
                succeeded: false,
                stderr: "\(galleryDetail)\n\(fallbackDetail)"
            )
        }

        if settings.mode == .original,
           item.engineKind == .genericPage,
           let resolved = item.resolvedMedia,
           resolved.mediaURL != nil,
           !resolved.isSegmented,
           resolved.isExpired() != true {
            onProgress(.init(
                phase: .downloading,
                currentItem: item.title,
                itemIndex: itemIndex,
                itemTotal: itemTotal,
                completedItems: completedBefore,
                failedItems: failedBefore,
                skippedItems: skippedBefore
            ))
            do {
                _ = try await DirectHTTPDownloadService(fileManager: fileManager).download(
                    item: item,
                    to: workspace.download,
                    cookiesFile: cookies,
                    cookieHeaderFile: cookieHeaderFile,
                    proxy: proxy,
                    timeout: TimeInterval(settings.network.connectionTimeoutSeconds)
                )
                return DownloadAttemptOutcome(succeeded: true, stderr: "")
            } catch {
                return DownloadAttemptOutcome(succeeded: false, stderr: error.localizedDescription)
            }
        }

        // Las URLs firmadas de googlevideo pueden quedar ligadas a una estrategia
        // de cliente que permite analizar unos formatos pero devuelve 403 al
        // transferirlos completos. Para YouTube público se conserva la URL estable
        // y yt-dlp la resuelve de nuevo con la política anónima del command builder.
        let shouldResolveStableAnonymousYouTubeURL = item.platform == .youtube
            && cookies == nil
            && browserCookies == nil
        let usableResolved = !shouldResolveStableAnonymousYouTubeURL
            && item.resolvedMedia?.mediaURL != nil
            && item.resolvedMedia?.isExpired() != true
            ? item.resolvedMedia
            : nil
        if item.isPageDiscovered, item.resolvedMedia != nil, usableResolved == nil {
            await logPerformance("La referencia resuelta ha caducado; se vuelve a resolver solo este vídeo", metadata: ["id": item.canonicalID])
        }

        if let resolved = usableResolved {
            let levels: [Int]
            if resolved.isSegmented, settings.network.adaptivePageFragments {
                levels = YTDLPAdaptiveFragmentPolicy().levels(startingAt: adaptiveFragmentCeiling)
            } else {
                levels = [settings.network.concurrentFragments]
            }
            var lastFailure: DownloadAttemptOutcome?
            for (index, fragments) in levels.enumerated() {
                if index > 0 { try workspace.resetForRetry(fileManager: fileManager) }
                let outcome = try await runDownloadAttempt(
                    item, settings: settings, engines: engines, workspace: workspace, cookies: cookies, browserCookies: browserCookies, proxy: proxy,
                    proxyCredentials: proxyCredentials, resolvedMedia: resolved, fragments: fragments, target: "resuelto",
                    itemIndex: itemIndex, itemTotal: itemTotal, completedBefore: completedBefore, failedBefore: failedBefore,
                    skippedBefore: skippedBefore, progressCoalescer: progressCoalescer, onProgress: onProgress
                )
                if outcome.succeeded {
                    if resolved.isSegmented, settings.network.adaptivePageFragments { adaptiveFragmentCeiling = fragments }
                    return outcome
                }
                lastFailure = outcome
                guard resolved.isSegmented, settings.network.adaptivePageFragments, YTDLPAdaptiveFragmentPolicy().shouldReduce(after: outcome.stderr), index + 1 < levels.count else { break }
                await logPerformance("El servidor limita los fragmentos; se reduce el paralelismo", metadata: ["id": item.canonicalID, "fragmentos": String(fragments), "siguiente": String(levels[index + 1])])
            }
            try workspace.resetForRetry(fileManager: fileManager)
            await logPerformance("La referencia directa no ha respondido; se usa la URL estable como respaldo", metadata: ["id": item.canonicalID, "referencia_error": lastFailure.map { DownloadErrorClassifier().classify(stderr: $0.stderr).technicalReference } ?? "desconocida"])
        }

        return try await runDownloadAttempt(
            item, settings: settings, engines: engines, workspace: workspace, cookies: cookies, browserCookies: browserCookies, proxy: proxy,
            proxyCredentials: proxyCredentials, resolvedMedia: nil,
            fragments: item.isPageDiscovered && settings.network.adaptivePageFragments ? adaptiveFragmentCeiling : settings.network.concurrentFragments,
            target: "respaldo", itemIndex: itemIndex, itemTotal: itemTotal, completedBefore: completedBefore,
            failedBefore: failedBefore, skippedBefore: skippedBefore, progressCoalescer: progressCoalescer, onProgress: onProgress
        )
    }

    static func shouldUseSession(for item: UniversalDownloadItem) -> Bool {
        item.platform != .instagram || item.requiresAuthentication
    }

    private func runDownloadAttempt(
        _ item: UniversalDownloadItem,
        settings: UniversalDownloadSettings,
        engines: DownloadEnginePaths,
        workspace: DownloadWorkspace,
        cookies: URL?,
        browserCookies: DownloadBrowserCookieSource?,
        proxy: String?,
        proxyCredentials: DownloadProxyCredentials?,
        resolvedMedia: ResolvedMediaReference?,
        fragments: Int,
        target: String,
        itemIndex: Int,
        itemTotal: Int,
        completedBefore: Int,
        failedBefore: Int,
        skippedBefore: Int,
        progressCoalescer: LatestValueCoalescer<UniversalDownloadProgress>,
        onProgress: @escaping @Sendable (UniversalDownloadProgress) -> Void
    ) async throws -> DownloadAttemptOutcome {
        onProgress(.init(phase: .connecting, currentItem: item.title, itemIndex: itemIndex, itemTotal: itemTotal, completedItems: completedBefore, failedItems: failedBefore, skippedItems: skippedBefore))
        let arguments = try YTDLPDownloadCommandBuilder().arguments(
            item: item, settings: settings, engines: engines, downloadDirectory: workspace.download,
            temporaryDirectory: workspace.temporary, cookiesFile: cookies, browserCookies: browserCookies,
            proxy: proxy, proxyCredentials: proxyCredentials,
            resolvedMedia: resolvedMedia, concurrentFragmentsOverride: fragments
        )
        let stdoutDecoder = IncrementalLineDecoder()
        let stderrDecoder = IncrementalLineDecoder()
        let stderr = LockedDataCollector(maximumBytes: 1_048_576)
        let progressParser = YTDLPProgressParser()
        let milestones = DownloadMilestones()
        let processStarted = Date()
        let result = try await runner.run(
            ExternalProcessRequest(executable: engines.ytDLP, arguments: arguments, workingDirectory: workspace.root),
            onStdout: { data in
                if let lines = try? stdoutDecoder.append(data) {
                    for line in lines {
                        if let update = progressParser.parse(line: line, itemIndex: itemIndex, itemTotal: itemTotal, title: item.title, completed: completedBefore, failed: failedBefore, skipped: skippedBefore) {
                            milestones.observe(update)
                            progressCoalescer.submit(update)
                        }
                    }
                }
            },
            onStderr: { data in
                stderr.append(data)
                if let lines = try? stderrDecoder.append(data) {
                    for line in lines {
                        if let update = progressParser.parse(line: line, itemIndex: itemIndex, itemTotal: itemTotal, title: item.title, completed: completedBefore, failed: failedBefore, skipped: skippedBefore) {
                            milestones.observe(update)
                            progressCoalescer.submit(update)
                        }
                    }
                }
            }
        )
        let values = milestones.snapshot
        var metadata = [
            "id": item.canonicalID, "indice": String(itemIndex), "codigo_salida": String(result.exitCode),
            "objetivo": target, "fragmentos": String(fragments),
            "bytes": values.downloadedBytes.map(String.init) ?? "desconocido"
        ]
        if let firstByte = values.firstByteAt { metadata["primer_byte_ms"] = String(Int(firstByte.timeIntervalSince(processStarted) * 1_000)) }
        await logTiming("Descarga y posprocesado con yt-dlp", startedAt: processStarted, metadata: metadata)
        return DownloadAttemptOutcome(succeeded: result.succeeded, stderr: String(decoding: stderr.data, as: UTF8.self))
    }

    private func logPerformance(_ message: String, metadata: [String: String]) async {
        _ = try? await logger?.write(.debug, category: "universal-downloader-performance", message: message, metadata: metadata)
    }

    private func destinationFolder(for item: UniversalDownloadItem, base: URL, settings: UniversalDownloadSettings) throws -> URL {
        if !item.folderComponents.isEmpty {
            var folder = base
            for component in item.folderComponents {
                let safe = try DownloadFilenamePolicy().sanitize(component)
                folder.appendPathComponent(safe, isDirectory: true)
            }
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            return folder
        }
        guard settings.createPlaylistFolder, let playlist = item.playlistTitle, !playlist.isEmpty else { return base }
        let name = try DownloadFilenamePolicy().sanitize(playlist)
        let folder = base.appendingPathComponent(name, isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func publishPlaylistMetadata(
        plan: UniversalDownloadPlan,
        results: [UniversalDownloadItemResult],
        baseOutput: URL
    ) async throws -> [URL] {
        let groups = Dictionary(grouping: plan.items.compactMap { item -> UniversalDownloadItem? in
            guard !item.isPageDiscovered,
                  let title = item.playlistTitle,
                  !title.isEmpty else { return nil }
            return item
        }, by: { $0.playlistTitle! })
        guard !groups.isEmpty else { return [] }
        var statuses: [String: DownloadItemResultStatus] = [:]
        for result in results { statuses[result.canonicalID] = result.status }
        var published: [URL] = []
        for title in groups.keys.sorted() {
            guard !cancellationRequested, !Task.isCancelled, let items = groups[title] else { break }
            let workspace = try DownloadWorkspace(operationID: UUID(), fileManager: fileManager)
            do {
                _ = try DownloadSafeMetadataWriter(fileManager: fileManager).writePlaylist(
                    title: title,
                    items: items.sorted { ($0.playlistIndex ?? Int.max) < ($1.playlistIndex ?? Int.max) },
                    resultsByCanonicalID: statuses,
                    to: workspace.download
                )
                let destinationItem = items[0]
                let destinationSettings = plan.settings(for: destinationItem)
                let destination = try destinationFolder(for: destinationItem, base: baseOutput, settings: destinationSettings)
                let files = try DownloadOutputPublisher(fileManager: fileManager).candidateFiles(in: workspace)
                published += try DownloadOutputPublisher(fileManager: fileManager).publish(
                    files: files,
                    to: destination,
                    policy: destinationSettings.conflictPolicy
                )
                try workspace.clean(fileManager: fileManager)
            } catch {
                try? workspace.clean(fileManager: fileManager)
                throw error
            }
        }
        return published
    }

    private func embedPageOriginMetadata(
        in files: [URL],
        origin: DownloadPageOrigin,
        includeDownloadDate: Bool,
        ffmpeg: URL,
        ffprobe: URL
    ) async -> PageOriginMetadataResult {
        var warnings: [String] = []
        var verifiedFiles = Set<URL>()
        let builder = DownloadOriginMetadataCommandBuilder()
        let expectedURL = UniversalURLNormalizer.provenanceURL(origin.pageURL).absoluteString
        for file in files where DownloadOutputValidator.isMediaFile(file) {
            let temporary = file.deletingLastPathComponent().appendingPathComponent(
                ".zeuve-origin-\(UUID().uuidString).\(file.pathExtension)",
                isDirectory: false
            )
            do {
                let process = try await runner.run(ExternalProcessRequest(
                    executable: ffmpeg,
                    arguments: builder.arguments(
                        input: file,
                        output: temporary,
                        origin: origin,
                        includeDownloadDate: includeDownloadDate
                    )
                ))
                guard process.exitCode == 0, fileManager.fileExists(atPath: temporary.path) else {
                    throw NSError(
                        domain: "com.zeuve.universal-downloader.origin-metadata",
                        code: Int(process.exitCode),
                        userInfo: [NSLocalizedDescriptionKey: "El contenedor no ha aceptado los metadatos de procedencia."]
                    )
                }
                let metadataOutput = LockedDataCollector(maximumBytes: 262_144)
                let verification = try await runner.run(
                    ExternalProcessRequest(
                        executable: ffprobe,
                        arguments: builder.verificationArguments(file: temporary)
                    ),
                    onStdout: { metadataOutput.append($0) }
                )
                let metadataText = String(decoding: metadataOutput.data, as: UTF8.self)
                guard verification.exitCode == 0, metadataText.contains(expectedURL), metadataText.contains("duration") else {
                    throw NSError(
                        domain: "com.zeuve.universal-downloader.origin-metadata",
                        code: Int(verification.exitCode),
                        userInfo: [NSLocalizedDescriptionKey: "No se ha podido verificar la procedencia dentro del archivo."]
                    )
                }
                let backup = file.deletingLastPathComponent().appendingPathComponent(".zeuve-origin-backup-\(UUID().uuidString)")
                try fileManager.moveItem(at: file, to: backup)
                do {
                    try fileManager.moveItem(at: temporary, to: file)
                    try fileManager.removeItem(at: backup)
                    verifiedFiles.insert(file.standardizedFileURL)
                } catch {
                    try? fileManager.removeItem(at: file)
                    try? fileManager.moveItem(at: backup, to: file)
                    throw error
                }
            } catch {
                try? fileManager.removeItem(at: temporary)
                warnings.append("\(file.lastPathComponent): el vídeo se conserva sin cambios porque no se ha podido incrustar la procedencia: \(error.localizedDescription)")
            }
        }
        return PageOriginMetadataResult(warnings: warnings, verifiedFiles: verifiedFiles)
    }

    private func logTiming(_ message: String, startedAt: Date, metadata: [String: String]) async {
        guard let logger else { return }
        var values = metadata
        values["duracion_ms"] = String(Int(Date().timeIntervalSince(startedAt) * 1_000))
        _ = try? await logger.write(.debug, category: "universal-downloader-performance", message: message, metadata: values)
    }

    nonisolated private func completed(_ values: [UniversalDownloadItemResult]) -> Int { values.filter { $0.status == .completed }.count }
    nonisolated private func failed(_ values: [UniversalDownloadItemResult]) -> Int { values.filter { $0.status == .failed }.count }
    nonisolated private func skipped(_ values: [UniversalDownloadItemResult]) -> Int { values.filter { $0.status == .skipped }.count }


}


private struct DownloadAttemptOutcome: Sendable {
    let succeeded: Bool
    let stderr: String
}

private struct PageOriginMetadataResult: Sendable {
    let warnings: [String]
    let verifiedFiles: Set<URL>
}

private final class DownloadMilestones: @unchecked Sendable {
    private let lock = NSLock()
    private var firstByte: Date?
    private var bytes: Int64?

    func observe(_ progress: UniversalDownloadProgress) {
        lock.lock()
        defer { lock.unlock() }
        if let downloaded = progress.downloadedBytes, downloaded > 0 {
            if firstByte == nil { firstByte = Date() }
            bytes = max(bytes ?? 0, downloaded)
        }
    }

    var snapshot: (firstByteAt: Date?, downloadedBytes: Int64?) {
        lock.lock()
        defer { lock.unlock() }
        return (firstByte, bytes)
    }
}
