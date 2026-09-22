import Foundation
import ZEUVECore
import ZEUVEEngines

public actor UniversalDownloadAnalysisService {
    private let locator: UniversalDownloaderEngineLocator
    private let logger: LocalLogger?
    private let runner: ExternalProcessRunner
    private let discovery: UniversalPageDiscoveryService

    public init(
        locator: UniversalDownloaderEngineLocator,
        logger: LocalLogger? = nil,
        runner: ExternalProcessRunner = ExternalProcessRunner(),
        discovery: UniversalPageDiscoveryService = UniversalPageDiscoveryService()
    ) {
        self.locator = locator
        self.logger = logger
        self.runner = runner
        self.discovery = discovery
    }

    public func analyze(
        _ input: ValidatedDownloadURL,
        cookiesFile: URL? = nil,
        cookieHeaderFile: URL? = nil,
        browserCookies: DownloadBrowserCookieSource? = nil,
        proxy: String? = nil,
        proxyCredentials: DownloadProxyCredentials? = nil,
        catalogLimit: Int = 24,
        paginationCursor: String? = nil,
        browserFallbackEnabled: Bool = false,
        onPlaylistEntry: @escaping @Sendable (DownloadCatalogItem) -> Void = { _ in },
        onProgress: @escaping @Sendable (Int) -> Void = { _ in }
    ) async throws -> DownloadAnalysis {
        let cookiesSecurityScope = SecurityScopedResourceAccess(cookiesFile)
        let headerSecurityScope = SecurityScopedResourceAccess(cookieHeaderFile)
        defer {
            cookiesSecurityScope.stop()
            headerSecurityScope.stop()
        }

        let sessionSupplied = cookiesFile != nil || cookieHeaderFile != nil || browserCookies != nil
        await log(.info, "Inicio del análisis universal", input: input, extra: [
            "fase": "inicio",
            "plataforma": input.platform.rawValue,
            "sesion_aportada": sessionSupplied ? "sí" : "no",
        ])
        let engineStarted = Date()
        let engines = try await locator.paths()
        await logTiming("Resolución de motores para análisis", startedAt: engineStarted, input: input, extra: [
            "gallery_dl": engines.galleryDL == nil ? "no_disponible" : "disponible",
            "catalogo_instagram": engines.instagramCatalog == nil ? "no_disponible" : "disponible",
        ])

        if input.platform == .instagram, input.kind == .profile {
            var catalogAttempt: InstagramCatalogParseResult?
            var catalogFailure: Error?

            do {
                let result = try await analyzeInstagramProfile(
                    input,
                    engines: engines,
                    cookiesFile: cookiesFile,
                    cookieHeaderFile: cookieHeaderFile,
                    limit: catalogLimit,
                    cursor: paginationCursor
                )
                catalogAttempt = result
                if result.issueCode == nil {
                    for entry in result.analysis.playlistEntries { onPlaylistEntry(entry) }
                    onProgress(result.analysis.playlistEntries.count)
                    return result.analysis
                }
                await log(.warning, "El catálogo de Instagram no ha podido comprobar el perfil", input: input, extra: [
                    "motor": UniversalEngineKind.instagramCatalog.rawValue,
                    "codigo": result.issueCode ?? "sin_codigo",
                    "sesion_aportada": result.sessionSupplied ? "sí" : "no",
                    "sesion_validada": Self.logValue(result.sessionValidated),
                    "fallback": UniversalEngineKind.galleryDL.rawValue,
                ])
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                catalogFailure = error
                await log(.warning, "El catálogo de Instagram no ha resuelto el perfil", input: input, extra: [
                    "motor": UniversalEngineKind.instagramCatalog.rawValue,
                    "error": error.localizedDescription,
                    "sesion_aportada": sessionSupplied ? "sí" : "no",
                    "fallback": UniversalEngineKind.galleryDL.rawValue,
                ])
            }

            do {
                let fallback = try await analyzeWithGalleryDL(
                    input,
                    engines: engines,
                    cookiesFile: cookiesFile,
                    proxy: proxy,
                    proxyCredentials: proxyCredentials
                )
                await log(.info, "Perfil de Instagram resuelto mediante fallback", input: input, extra: [
                    "motor": UniversalEngineKind.galleryDL.rawValue,
                    "sesion_aportada": sessionSupplied ? "sí" : "no",
                    "resultados": String(fallback.playlistEntries.count),
                ])
                let publicProfile = sessionSupplied
                    ? fallback
                    : markingAuthenticationRestrictedSections(
                        fallback,
                        sections: [.stories, .highlights],
                        message: "El perfil público se ha analizado sin sesión. Stories y Destacadas no están disponibles."
                    )
                for entry in publicProfile.playlistEntries { onPlaylistEntry(entry) }
                onProgress(publicProfile.playlistEntries.count)
                return publicProfile
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                await log(.warning, "El fallback de Instagram tampoco ha resuelto el perfil", input: input, extra: [
                    "motor": UniversalEngineKind.galleryDL.rawValue,
                    "error": error.localizedDescription,
                    "sesion_aportada": sessionSupplied ? "sí" : "no",
                ])
                if let catalogAttempt {
                    return catalogAttempt.analysis
                }
                if let catalogFailure {
                    let classified = DownloadErrorClassifier().classify(stderr: catalogFailure.localizedDescription)
                    if classified.category == .authenticationRequired || classified.category == .profileUnverified {
                        return instagramPublicProfileUnavailableAnalysis(input: input, message: classified.userMessage)
                    }
                    throw catalogFailure
                }
                throw error
            }
        }

        // Un enlace concreto de Instagram se prueba siempre primero sin sesión,
        // incluso si el usuario conserva cookies para un perfil privado. Así el
        // contenido público no recibe credenciales innecesarias. La ruta normal
        // con sesión queda disponible únicamente si los motores anónimos confirman
        // que la cuenta o la publicación es privada.
        var concreteInstagramSessionFallback = false
        if input.platform == .instagram,
           input.kind != .profile,
           sessionSupplied {
            let anonymous = try await analyzeConcreteInstagramAnonymously(
               input,
               engines: engines,
               proxy: proxy,
               proxyCredentials: proxyCredentials,
               onPlaylistEntry: onPlaylistEntry,
               onProgress: onProgress
            )
            if let analysis = anonymous.analysis {
                return analysis
            }
            guard Self.shouldRetryConcreteInstagramWithSession(after: anonymous.failureMessages) else {
                let classified = anonymous.failureMessages.first.map {
                    DownloadErrorClassifier().classify(stderr: $0)
                }
                return instagramPublicContentUnavailableAnalysis(
                    input: input,
                    message: classified?.userMessage
                        ?? "Instagram no ha devuelto contenido multimedia público en este intento."
                )
            }
            concreteInstagramSessionFallback = true
        }

        let strategy = UniversalEngineRouter.strategy(for: input, browserFallbackEnabled: browserFallbackEnabled)
        var analyses: [DownloadAnalysis] = []
        var failures: [Error] = []

        for engine in strategy.ordered {
            guard !Task.isCancelled else { throw CancellationError() }
            do {
                let values: [DownloadAnalysis]
                switch engine {
                case .ytDLP:
                    values = try await analyzeWithYTDLP(
                        input,
                        engines: engines,
                        cookiesFile: cookiesFile,
                        browserCookies: browserCookies,
                        proxy: proxy,
                        proxyCredentials: proxyCredentials,
                        onPlaylistEntry: onPlaylistEntry,
                        onProgress: onProgress
                    )
                case .galleryDL:
                    values = [try await analyzeWithGalleryDL(
                        input,
                        engines: engines,
                        cookiesFile: cookiesFile,
                        proxy: proxy,
                        proxyCredentials: proxyCredentials
                    )]
                    for entry in values.flatMap(\.playlistEntries) { onPlaylistEntry(entry) }
                    onProgress(values.flatMap(\.playlistEntries).count)
                case .genericPage:
                    values = [] // The complementary HTML discovery below handles the generic extractor.
                case .browser:
                    throw UniversalDownloaderError.optionalEngineUnavailable(engine.rawValue)
                case .instagramCatalog:
                    if input.platform == .instagram, input.kind != .profile {
                        values = [try await analyzeInstagramDirect(
                            input,
                            engines: engines,
                            cookiesFile: cookiesFile,
                            cookieHeaderFile: cookieHeaderFile
                        )]
                        for entry in values.flatMap(\.playlistEntries) { onPlaylistEntry(entry) }
                        onProgress(values.flatMap(\.playlistEntries).count)
                    } else {
                        values = []
                    }
                }
                if !values.isEmpty {
                    analyses += values
                    // A specialized gallery result already contains every selected media URL.
                    if engine == .galleryDL { break }
                    if input.kind != .webpage { break }
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                failures.append(error)
                await log(.warning, "Un motor no ha resuelto la URL", input: input, extra: ["motor": engine.rawValue, "error": error.localizedDescription])
            }
        }

        var pageTitle: String?
        var discoveryDuplicateCount = 0
        if input.kind == .webpage || analyses.isEmpty {
            do {
                let result = try await discovery.discover(
                    pageURL: input.canonicalURL,
                    cookiesFile: cookiesFile,
                    proxy: proxy,
                    proxyCredentials: proxyCredentials
                )
                pageTitle = result.pageTitle
                discoveryDuplicateCount = result.duplicateCount
                var knownKeys = Set(analyses.flatMap(Self.sourceKeys))
                for candidate in result.candidates {
                    guard !Task.isCancelled else { throw CancellationError() }
                    let candidateKey = UniversalURLNormalizer.duplicateKey(for: candidate.url)
                    guard knownKeys.insert(candidateKey).inserted else {
                        discoveryDuplicateCount += 1
                        continue
                    }
                    do {
                        let validated = try UniversalDownloadInputValidator().validate(
                            candidate.url.absoluteString,
                            allowInsecureLocalNetwork: input.allowInsecureLocalNetwork,
                            platform: .automatic,
                            allowAdultContent: true
                        )
                        let values = try await analyzeWithYTDLP(
                            validated,
                            engines: engines,
                            cookiesFile: cookiesFile,
                            browserCookies: browserCookies,
                            proxy: proxy,
                            proxyCredentials: proxyCredentials,
                            onPlaylistEntry: onPlaylistEntry,
                            onProgress: onProgress
                        )
                        analyses += values
                        for key in values.flatMap(Self.sourceKeys) { knownKeys.insert(key) }
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        await log(.warning, "Candidato multimedia no analizable", input: input, extra: [
                            "candidato": UniversalURLNormalizer.sanitizedLogURL(candidate.url),
                            "tipo": candidate.kind.rawValue,
                            "error": error.localizedDescription,
                        ])
                    }
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                failures.append(error)
                await log(.warning, "La inspección HTML complementaria no se ha completado", input: input, extra: ["error": error.localizedDescription])
            }
        }

        guard !analyses.isEmpty else {
            if input.platform == .instagram {
                for failure in failures {
                    if Self.isConfirmedPrivateInstagramFailure(failure.localizedDescription) {
                        let classified = DownloadErrorClassifier().classify(stderr: failure.localizedDescription)
                        await log(.warning, "Instagram ha indicado que el contenido pertenece a una cuenta privada", input: input, extra: [
                            "sesion_aportada": sessionSupplied ? "sí" : "no",
                            "clasificacion": "privado_confirmado",
                        ])
                        return instagramAuthenticationAnalysis(input: input, message: classified.userMessage)
                    }
                }
                let classified = failures.first.map {
                    DownloadErrorClassifier().classify(stderr: $0.localizedDescription)
                }
                await log(.warning, "Los extractores no han resuelto el contenido público de Instagram", input: input, extra: [
                    "sesion_aportada": sessionSupplied ? "sí" : "no",
                    "clasificacion": classified?.category.rawValue ?? "sin_resultado",
                ])
                return instagramPublicContentUnavailableAnalysis(
                    input: input,
                    message: classified?.userMessage
                        ?? "Instagram no ha devuelto contenido multimedia público en este intento."
                )
            }
            if let first = failures.first { throw first }
            throw UniversalDownloaderError.analysisFailed("No se ha encontrado contenido multimedia descargable en la página.")
        }

        let merged = merge(
            analyses,
            input: input,
            pageTitle: pageTitle,
            discoveryDuplicateCount: discoveryDuplicateCount
        )
        let result = concreteInstagramSessionFallback
            ? markingRequiresAuthentication(merged)
            : merged
        await log(.info, "Análisis universal completado", input: input, extra: [
            "tipo_resultado": result.kind.rawValue,
            "elementos_unicos": String(result.playlistEntries.isEmpty ? 1 : result.playlistEntries.count),
            "duplicados_omitidos": String(result.duplicateCount),
        ])
        return result
    }

    public func importInstagramCookies(from browser: String, to output: URL) async throws -> Int {
        let allowed = ["safari", "chrome", "chromium", "brave", "edge", "firefox", "opera", "vivaldi", "arc"]
        let normalized = browser.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard allowed.contains(normalized) else {
            throw UniversalDownloaderError.analysisFailed("El navegador seleccionado no es compatible con la importación de sesión.")
        }
        let engines = try await locator.paths()
        guard let executable = engines.instagramCatalog else {
            throw UniversalDownloaderError.optionalEngineUnavailable("Catálogo de Instagram")
        }
        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let stdout = LockedDataCollector(maximumBytes: 64 * 1_024)
        let stderr = LockedDataCollector(maximumBytes: 256 * 1_024)
        let result = try await runner.run(
            ExternalProcessRequest(
                executable: executable,
                arguments: ["export-cookies", "--browser", normalized, "--output", output.path]
            ),
            onStdout: { stdout.append($0) },
            onStderr: { stderr.append($0) }
        )
        guard result.succeeded else {
            let message = String(decoding: stderr.data, as: UTF8.self)
            throw UniversalDownloaderError.analysisFailed(
                message.isEmpty ? "No se ha podido importar la sesión del navegador. Puede que macOS requiera permiso para leer sus datos." : message
            )
        }
        try InstagramSessionMaterial.secureExistingTemporaryFile(output)
        let lines = String(decoding: stdout.data, as: UTF8.self).split(whereSeparator: \.isNewline)
        for line in lines.reversed() {
            guard let data = line.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  object["record"] as? String == "cookie_export" else { continue }
            return object["count"] as? Int ?? 0
        }
        return 0
    }

    public func cancel() async throws { try await runner.cancel() }

    private func analyzeConcreteInstagramAnonymously(
        _ input: ValidatedDownloadURL,
        engines: DownloadEnginePaths,
        proxy: String?,
        proxyCredentials: DownloadProxyCredentials?,
        onPlaylistEntry: @escaping @Sendable (DownloadCatalogItem) -> Void,
        onProgress: @escaping @Sendable (Int) -> Void
    ) async throws -> (analysis: DownloadAnalysis?, failureMessages: [String]) {
        var failureMessages: [String] = []
        do {
            let value = try await analyzeInstagramDirect(
                input,
                engines: engines,
                cookiesFile: nil,
                cookieHeaderFile: nil
            )
            for entry in value.playlistEntries { onPlaylistEntry(entry) }
            onProgress(value.playlistEntries.count)
            await log(.info, "Contenido público de Instagram resuelto anónimamente", input: input, extra: [
                "motor": UniversalEngineKind.instagramCatalog.rawValue,
                "sesion_aportada": "no",
                "resultados": String(value.playlistEntries.count),
            ])
            return (value, [])
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            failureMessages.append(error.localizedDescription)
            await log(.warning, "El intento anónimo específico de Instagram no ha resuelto la URL", input: input, extra: [
                "motor": UniversalEngineKind.instagramCatalog.rawValue,
                "error": error.localizedDescription,
            ])
        }

        do {
            let value = try await analyzeWithGalleryDL(
                input,
                engines: engines,
                cookiesFile: nil,
                proxy: proxy,
                proxyCredentials: proxyCredentials
            )
            for entry in value.playlistEntries { onPlaylistEntry(entry) }
            onProgress(value.playlistEntries.count)
            await log(.info, "Contenido público de Instagram resuelto anónimamente", input: input, extra: [
                "motor": UniversalEngineKind.galleryDL.rawValue,
                "sesion_aportada": "no",
            ])
            return (value, [])
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            failureMessages.append(error.localizedDescription)
            await log(.warning, "El intento anónimo de Instagram con gallery-dl no ha resuelto la URL", input: input, extra: [
                "motor": UniversalEngineKind.galleryDL.rawValue,
                "error": error.localizedDescription,
            ])
        }

        do {
            let values = try await analyzeWithYTDLP(
                input,
                engines: engines,
                cookiesFile: nil,
                browserCookies: nil,
                proxy: proxy,
                proxyCredentials: proxyCredentials,
                onPlaylistEntry: onPlaylistEntry,
                onProgress: onProgress
            )
            guard !values.isEmpty else {
                failureMessages.append("yt-dlp no ha devuelto contenido multimedia.")
                return (nil, failureMessages)
            }
            await log(.info, "Contenido público de Instagram resuelto anónimamente", input: input, extra: [
                "motor": UniversalEngineKind.ytDLP.rawValue,
                "sesion_aportada": "no",
            ])
            return (merge(values, input: input, pageTitle: nil, discoveryDuplicateCount: 0), [])
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            failureMessages.append(error.localizedDescription)
            await log(.warning, "El intento anónimo de Instagram con yt-dlp no ha resuelto la URL", input: input, extra: [
                "motor": UniversalEngineKind.ytDLP.rawValue,
                "error": error.localizedDescription,
            ])
            return (nil, failureMessages)
        }
    }

    private func analyzeInstagramDirect(
        _ input: ValidatedDownloadURL,
        engines: DownloadEnginePaths,
        cookiesFile: URL?,
        cookieHeaderFile: URL?
    ) async throws -> DownloadAnalysis {
        let started = Date()
        let result = try await InstagramAnalysisAdapter(runner: runner).analyzeDirect(
            input: input,
            engines: engines,
            cookiesFile: cookiesFile,
            cookieHeaderFile: cookieHeaderFile
        )
        await logTiming("Resolución directa específica de Instagram", startedAt: started, input: input, extra: [
            "codigo_salida": String(result.process.exitCode),
        ])
        guard let parsed = result.parsed else {
            throw UniversalDownloaderError.analysisFailed(
                result.stderr.isEmpty ? "El motor específico de Instagram no ha devuelto contenido." : result.stderr
            )
        }
        guard result.process.succeeded, !parsed.analysis.playlistEntries.isEmpty else {
            throw UniversalDownloaderError.analysisFailed("El motor específico de Instagram no ha encontrado archivos descargables.")
        }
        return parsed.analysis
    }

    private func analyzeInstagramProfile(
        _ input: ValidatedDownloadURL,
        engines: DownloadEnginePaths,
        cookiesFile: URL?,
        cookieHeaderFile: URL?,
        limit: Int,
        cursor: String?
    ) async throws -> InstagramCatalogParseResult {
        let started = Date()
        let result = try await InstagramAnalysisAdapter(runner: runner).analyzeProfile(
            input: input,
            engines: engines,
            cookiesFile: cookiesFile,
            cookieHeaderFile: cookieHeaderFile,
            limit: limit,
            cursor: cursor
        )
        await logTiming("Catálogo progresivo de Instagram", startedAt: started, input: input, extra: ["codigo_salida": String(result.process.exitCode)])
        guard let parsed = result.parsed else {
            let classified = DownloadErrorClassifier().classify(stderr: result.stderr)
            throw UniversalDownloaderError.analysisFailed(result.stderr.isEmpty ? "Instagram no devolvió información del perfil." : classified.userMessage)
        }
        await log(.debug, "Resultado del catálogo de Instagram", input: input, extra: [
            "codigo": parsed.issueCode ?? "sin_codigo",
            "sesion_aportada": parsed.sessionSupplied ? "sí" : "no",
            "sesion_validada": Self.logValue(parsed.sessionValidated),
            "requiere_autenticacion": parsed.analysis.requiresAuthentication ? "sí" : "no",
            "resultados": String(parsed.analysis.playlistEntries.count),
        ])
        if result.process.exitCode != 0, parsed.issueCode == nil, !parsed.analysis.requiresAuthentication, parsed.analysis.playlistEntries.isEmpty {
            let classified = DownloadErrorClassifier().classify(stderr: result.stderr)
            throw UniversalDownloaderError.analysisFailed(result.stderr.isEmpty ? "No se ha podido catalogar el perfil de Instagram." : classified.userMessage)
        }
        return parsed
    }

    private func instagramPublicProfileUnavailableAnalysis(
        input: ValidatedDownloadURL,
        message: String
    ) -> DownloadAnalysis {
        let username = input.profileUsername
        return DownloadAnalysis(
            canonicalID: input.canonicalID,
            kind: .profile,
            title: username.map { "@\($0)" } ?? "Perfil de Instagram",
            uploader: username,
            description: message,
            availability: "unavailable",
            playlistTitle: username,
            playlistCount: 0,
            playlistEntries: [],
            sourceURL: input.canonicalURL,
            serviceName: "Instagram",
            extractor: "instagram-public-profile-unavailable",
            platform: .instagram,
            mediaKind: .gallery,
            engineKind: .instagramCatalog,
            profileUsername: username,
            isPrivateProfile: false,
            requiresAuthentication: false
        )
    }

    private func instagramPublicContentUnavailableAnalysis(
        input: ValidatedDownloadURL,
        message: String
    ) -> DownloadAnalysis {
        DownloadAnalysis(
            canonicalID: input.canonicalID,
            kind: input.kind,
            title: "Contenido de Instagram",
            description: message,
            availability: "unavailable",
            playlistCount: 0,
            playlistEntries: [],
            sourceURL: input.canonicalURL,
            serviceName: "Instagram",
            extractor: "instagram-public-content-unavailable",
            platform: .instagram,
            mediaKind: .gallery,
            engineKind: .ytDLP,
            requiresAuthentication: false
        )
    }

    private func markingRequiresAuthentication(_ analysis: DownloadAnalysis) -> DownloadAnalysis {
        DownloadAnalysis(
            canonicalID: analysis.canonicalID,
            kind: analysis.kind,
            title: analysis.title,
            uploader: analysis.uploader,
            channelID: analysis.channelID,
            duration: analysis.duration,
            publicationDate: analysis.publicationDate,
            thumbnailURL: analysis.thumbnailURL,
            description: analysis.description,
            formats: analysis.formats,
            subtitles: analysis.subtitles,
            chaptersCount: analysis.chaptersCount,
            liveStatus: analysis.liveStatus,
            ageLimit: analysis.ageLimit,
            availability: analysis.availability,
            playlistTitle: analysis.playlistTitle,
            playlistCount: analysis.playlistCount,
            playlistEntries: analysis.playlistEntries,
            sourceURL: analysis.sourceURL,
            serviceName: analysis.serviceName,
            extractor: analysis.extractor,
            duplicateCount: analysis.duplicateCount,
            downloadSource: analysis.downloadSource,
            pageOrigin: analysis.pageOrigin,
            resolvedMedia: analysis.resolvedMedia,
            platform: analysis.platform,
            mediaKind: analysis.mediaKind,
            engineKind: analysis.engineKind,
            profileUsername: analysis.profileUsername,
            isPrivateProfile: analysis.isPrivateProfile,
            requiresAuthentication: true,
            paginationCursor: analysis.paginationCursor,
            hasMoreEntries: analysis.hasMoreEntries,
            availableSections: analysis.availableSections,
            authenticationRestrictedSections: analysis.authenticationRestrictedSections
        )
    }

    static func isConfirmedPrivateInstagramFailure(_ message: String) -> Bool {
        let lower = message.lowercased()
        return lower.contains("private account")
            || lower.contains("private profile")
            || lower.contains("this account is private")
            || lower.contains("cuenta privada")
            || lower.contains("perfil privado")
            || lower.contains("private post")
    }

    static func shouldRetryConcreteInstagramWithSession(after failureMessages: [String]) -> Bool {
        failureMessages.contains(where: isConfirmedPrivateInstagramFailure)
    }

    private func markingAuthenticationRestrictedSections(
        _ analysis: DownloadAnalysis,
        sections: [UniversalCatalogSection],
        message: String
    ) -> DownloadAnalysis {
        let combined = Array(Set((analysis.authenticationRestrictedSections ?? []) + sections))
            .sorted { $0.rawValue < $1.rawValue }
        let description: String
        if let existing = analysis.description, !existing.isEmpty {
            description = existing.contains(message) ? existing : "\(existing)\n\(message)"
        } else {
            description = message
        }
        return DownloadAnalysis(
            canonicalID: analysis.canonicalID,
            kind: analysis.kind,
            title: analysis.title,
            uploader: analysis.uploader,
            channelID: analysis.channelID,
            duration: analysis.duration,
            publicationDate: analysis.publicationDate,
            thumbnailURL: analysis.thumbnailURL,
            description: description,
            formats: analysis.formats,
            subtitles: analysis.subtitles,
            chaptersCount: analysis.chaptersCount,
            liveStatus: analysis.liveStatus,
            ageLimit: analysis.ageLimit,
            availability: analysis.availability,
            playlistTitle: analysis.playlistTitle,
            playlistCount: analysis.playlistCount,
            playlistEntries: analysis.playlistEntries,
            sourceURL: analysis.sourceURL,
            serviceName: analysis.serviceName,
            extractor: analysis.extractor,
            duplicateCount: analysis.duplicateCount,
            downloadSource: analysis.downloadSource,
            pageOrigin: analysis.pageOrigin,
            resolvedMedia: analysis.resolvedMedia,
            platform: analysis.platform,
            mediaKind: analysis.mediaKind,
            engineKind: analysis.engineKind,
            profileUsername: analysis.profileUsername,
            isPrivateProfile: analysis.isPrivateProfile,
            requiresAuthentication: analysis.requiresAuthentication,
            paginationCursor: analysis.paginationCursor,
            hasMoreEntries: analysis.hasMoreEntries,
            availableSections: analysis.availableSections,
            authenticationRestrictedSections: combined
        )
    }

    private func instagramAuthenticationAnalysis(
        input: ValidatedDownloadURL,
        message: String
    ) -> DownloadAnalysis {
        let username = input.profileUsername
        return DownloadAnalysis(
            canonicalID: input.canonicalID,
            kind: input.kind,
            title: username.map { "@\($0)" } ?? "Contenido de Instagram",
            uploader: username,
            description: message,
            availability: "needs_auth",
            playlistTitle: username,
            playlistCount: 0,
            playlistEntries: [],
            sourceURL: input.canonicalURL,
            serviceName: "Instagram",
            extractor: "instagram-authentication",
            platform: .instagram,
            mediaKind: input.kind == .webpage ? .webpageMedia : .gallery,
            engineKind: input.kind == .profile ? .instagramCatalog : .galleryDL,
            profileUsername: username,
            requiresAuthentication: true
        )
    }

    private static func logValue(_ value: Bool?) -> String {
        switch value {
        case true: return "sí"
        case false: return "no"
        case nil: return "no_comprobada"
        }
    }

    private func analyzeWithGalleryDL(
        _ input: ValidatedDownloadURL,
        engines: DownloadEnginePaths,
        cookiesFile: URL?,
        proxy: String?,
        proxyCredentials: DownloadProxyCredentials?
    ) async throws -> DownloadAnalysis {
        let started = Date()
        let result = try await GalleryDLAnalysisAdapter(runner: runner).analyze(
            input: input,
            engines: engines,
            cookiesFile: cookiesFile,
            proxy: proxy,
            proxyCredentials: proxyCredentials
        )
        await logTiming("Análisis especializado con gallery-dl", startedAt: started, input: input, extra: ["codigo_salida": String(result.process.exitCode)])
        guard let analysis = result.analysis else {
            let classified = DownloadErrorClassifier().classify(stderr: result.stderr)
            throw UniversalDownloaderError.analysisFailed(result.stderr.isEmpty ? "gallery-dl no ha encontrado contenido compatible." : classified.userMessage)
        }
        return analysis
    }

    private func analyzeWithYTDLP(
        _ input: ValidatedDownloadURL,
        engines: DownloadEnginePaths,
        cookiesFile: URL?,
        browserCookies: DownloadBrowserCookieSource?,
        proxy: String?,
        proxyCredentials: DownloadProxyCredentials?,
        onPlaylistEntry: @escaping @Sendable (DownloadCatalogItem) -> Void,
        onProgress: @escaping @Sendable (Int) -> Void
    ) async throws -> [DownloadAnalysis] {
        let processStarted = Date()
        let result = try await YTDLPAnalysisAdapter(runner: runner).analyze(
            input: input,
            engines: engines,
            cookiesFile: cookiesFile,
            browserCookies: browserCookies,
            proxy: proxy,
            proxyCredentials: proxyCredentials,
            onAnalysis: { raw, count in
                let analysis = Self.annotated(raw, input: input)
                for entry in Self.entries(analysis) { onPlaylistEntry(entry) }
                onProgress(count)
            }
        )
        let values = result.analyses.map { Self.annotated($0, input: input) }
        await logTiming("Análisis con yt-dlp", startedAt: processStarted, input: input, extra: ["codigo_salida": String(result.process.exitCode), "resultados": String(values.count)])
        if values.isEmpty {
            if let failure = result.parseFailures.first, !failure.isEmpty {
                throw UniversalDownloaderError.analysisFailed(failure)
            }
            throw UniversalDownloaderError.analysisFailed(result.stderr.isEmpty ? "yt-dlp no devolvió contenido multimedia." : result.stderr)
        }
        return values
    }

    private func merge(
        _ analyses: [DownloadAnalysis],
        input: ValidatedDownloadURL,
        pageTitle: String?,
        discoveryDuplicateCount: Int
    ) -> DownloadAnalysis {
        let pageOrigin: DownloadPageOrigin? = input.kind == .webpage
            ? DownloadPageOrigin(
                pageURL: UniversalURLNormalizer.provenanceURL(input.canonicalURL),
                domain: input.host,
                pageIdentifier: UniversalURLNormalizer.pageIdentifier(for: input.canonicalURL)
            )
            : nil
        let flattened = analyses.flatMap(Self.entries)
        var seen = Set<String>()
        var unique: [DownloadCatalogItem] = []
        var duplicates = discoveryDuplicateCount
        for (offset, entry) in flattened.enumerated() {
            let key = Self.deduplicationKey(entry)
            if seen.insert(key).inserted {
                unique.append(DownloadCatalogItem(
                    canonicalID: entry.canonicalID,
                    playlistIndex: entry.playlistIndex ?? offset + 1,
                    title: entry.title,
                    duration: entry.duration,
                    uploader: entry.uploader,
                    availability: entry.availability,
                    isAvailable: entry.isAvailable,
                    sourceURL: entry.sourceURL,
                    serviceName: entry.serviceName,
                    extractor: entry.extractor,
                    downloadSource: input.kind == .webpage ? .pageDiscovered : entry.downloadSource,
                    pageOrigin: pageOrigin ?? entry.pageOrigin,
                    resolvedMedia: entry.resolvedMedia,
                    platform: entry.platform ?? input.platform,
                    mediaKind: entry.mediaKind,
                    thumbnailURL: entry.thumbnailURL,
                    engineKind: entry.engineKind,
                    catalogSection: entry.catalogSection,
                    folderComponents: entry.folderComponents,
                    expectedExtension: entry.expectedExtension,
                    safeMetadata: entry.safeMetadata
                ))
            } else {
                duplicates += 1
            }
        }

        if input.kind == .video, unique.count == 1, let original = analyses.first(where: { $0.kind == .video }) {
            return DownloadAnalysis(
                canonicalID: original.canonicalID,
                kind: .video,
                title: original.title,
                uploader: original.uploader,
                channelID: original.channelID,
                duration: original.duration,
                publicationDate: original.publicationDate,
                thumbnailURL: original.thumbnailURL,
                description: original.description,
                formats: original.formats,
                subtitles: original.subtitles,
                chaptersCount: original.chaptersCount,
                liveStatus: original.liveStatus,
                ageLimit: original.ageLimit,
                availability: original.availability,
                sourceURL: original.sourceURL ?? input.canonicalURL,
                serviceName: original.serviceName ?? input.host,
                extractor: original.extractor,
                duplicateCount: duplicates,
                downloadSource: .directContent,
                resolvedMedia: original.resolvedMedia,
                platform: original.platform ?? input.platform,
                mediaKind: original.mediaKind ?? .video,
                engineKind: original.engineKind ?? .ytDLP
            )
        }

        let title = pageTitle ?? analyses.compactMap(\.playlistTitle).first ?? analyses.first?.title ?? input.host
        let sections = Array(Set(unique.compactMap(\.catalogSection))).sorted { $0.rawValue < $1.rawValue }
        let restrictedSections = Array(Set(analyses.flatMap { $0.authenticationRestrictedSections ?? [] }))
            .sorted { $0.rawValue < $1.rawValue }
        return DownloadAnalysis(
            canonicalID: input.canonicalID,
            kind: input.kind == .profile ? .profile : (input.kind == .gallery ? .gallery : .playlist),
            title: title,
            uploader: analyses.compactMap(\.uploader).first,
            thumbnailURL: analyses.compactMap(\.thumbnailURL).first,
            description: analyses.compactMap(\.description).first,
            playlistTitle: title,
            playlistCount: unique.count,
            playlistEntries: unique,
            sourceURL: input.canonicalURL,
            serviceName: input.platform.spanishName,
            extractor: input.kind == .webpage ? "Página web" : analyses.first?.extractor,
            duplicateCount: duplicates,
            downloadSource: input.kind == .webpage ? .pageDiscovered : .directContent,
            pageOrigin: pageOrigin,
            platform: input.platform,
            mediaKind: .gallery,
            engineKind: analyses.first?.engineKind,
            profileUsername: input.profileUsername,
            availableSections: sections,
            authenticationRestrictedSections: restrictedSections.isEmpty ? nil : restrictedSections
        )
    }

    private static func annotated(_ analysis: DownloadAnalysis, input: ValidatedDownloadURL) -> DownloadAnalysis {
        let entries = analysis.playlistEntries.map { entry in
            DownloadCatalogItem(
                canonicalID: entry.canonicalID,
                playlistIndex: entry.playlistIndex,
                title: entry.title,
                duration: entry.duration,
                uploader: entry.uploader,
                availability: entry.availability,
                isAvailable: entry.isAvailable,
                sourceURL: entry.sourceURL,
                serviceName: entry.serviceName,
                extractor: entry.extractor,
                downloadSource: entry.downloadSource,
                pageOrigin: entry.pageOrigin,
                resolvedMedia: entry.resolvedMedia,
                platform: input.platform,
                mediaKind: entry.mediaKind ?? .video,
                thumbnailURL: entry.thumbnailURL,
                engineKind: .ytDLP,
                catalogSection: entry.catalogSection ?? .videos,
                folderComponents: entry.folderComponents,
                expectedExtension: entry.expectedExtension,
                safeMetadata: entry.safeMetadata
            )
        }
        return DownloadAnalysis(
            canonicalID: analysis.canonicalID,
            kind: analysis.kind,
            title: analysis.title,
            uploader: analysis.uploader,
            channelID: analysis.channelID,
            duration: analysis.duration,
            publicationDate: analysis.publicationDate,
            thumbnailURL: analysis.thumbnailURL,
            description: analysis.description,
            formats: analysis.formats,
            subtitles: analysis.subtitles,
            chaptersCount: analysis.chaptersCount,
            liveStatus: analysis.liveStatus,
            ageLimit: analysis.ageLimit,
            availability: analysis.availability,
            playlistTitle: analysis.playlistTitle,
            playlistCount: analysis.playlistCount,
            playlistEntries: entries,
            sourceURL: analysis.sourceURL,
            serviceName: analysis.serviceName,
            extractor: analysis.extractor,
            duplicateCount: analysis.duplicateCount,
            downloadSource: analysis.downloadSource,
            pageOrigin: analysis.pageOrigin,
            resolvedMedia: analysis.resolvedMedia,
            platform: input.platform,
            mediaKind: analysis.kind == .video ? .video : .gallery,
            engineKind: .ytDLP,
            profileUsername: input.profileUsername,
            isPrivateProfile: analysis.isPrivateProfile,
            requiresAuthentication: analysis.requiresAuthentication,
            paginationCursor: analysis.paginationCursor,
            hasMoreEntries: analysis.hasMoreEntries,
            availableSections: analysis.availableSections,
            authenticationRestrictedSections: analysis.authenticationRestrictedSections
        )
    }

    private static func entries(_ analysis: DownloadAnalysis) -> [DownloadCatalogItem] {
        if !analysis.playlistEntries.isEmpty { return analysis.playlistEntries }
        guard let url = analysis.sourceURL else { return [] }
        return [DownloadCatalogItem(
            canonicalID: analysis.canonicalID,
            title: analysis.title,
            duration: analysis.duration,
            uploader: analysis.uploader,
            availability: analysis.availability,
            isAvailable: analysis.isDownloadable,
            sourceURL: url,
            serviceName: analysis.serviceName,
            extractor: analysis.extractor,
            downloadSource: analysis.downloadSource,
            pageOrigin: analysis.pageOrigin,
            resolvedMedia: analysis.resolvedMedia,
            platform: analysis.platform,
            mediaKind: analysis.mediaKind,
            thumbnailURL: analysis.thumbnailURL,
            engineKind: analysis.engineKind,
            catalogSection: analysis.mediaKind?.mediaClass == .image ? .photos : .videos
        )]
    }

    private static func sourceKeys(_ analysis: DownloadAnalysis) -> [String] {
        entries(analysis).map { UniversalURLNormalizer.duplicateKey(for: $0.sourceURL) }
    }

    private static func deduplicationKey(_ entry: DownloadCatalogItem) -> String {
        if entry.canonicalID.contains(":"), !entry.canonicalID.hasPrefix("media:") { return "id:\(entry.canonicalID.lowercased())" }
        return "url:\(UniversalURLNormalizer.duplicateKey(for: entry.sourceURL))"
    }

    private func logTiming(_ message: String, startedAt: Date, input: ValidatedDownloadURL, extra: [String: String] = [:]) async {
        var metadata = extra
        metadata["duracion_ms"] = String(Int(Date().timeIntervalSince(startedAt) * 1_000))
        await log(.debug, message, input: input, extra: metadata)
    }

    private func log(_ level: LogLevel, _ message: String, input: ValidatedDownloadURL, extra: [String: String] = [:]) async {
        guard let logger else { return }
        var metadata = extra
        metadata["id"] = input.canonicalID
        metadata["tipo"] = input.kind.rawValue
        metadata["dominio"] = input.host
        metadata["url"] = UniversalURLNormalizer.sanitizedLogURL(input.canonicalURL)
        _ = try? await logger.write(level, category: "universal-downloader", message: message, metadata: metadata)
    }
}
