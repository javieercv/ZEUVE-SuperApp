import Foundation

public struct YTDLPAnalysisCommandBuilder: Sendable {
    public init() {}

    public func arguments(
        for url: ValidatedDownloadURL,
        engines: DownloadEnginePaths,
        cookiesFile: URL? = nil,
        browserCookies: DownloadBrowserCookieSource? = nil,
        proxy: String? = nil,
        proxyCredentials: DownloadProxyCredentials? = nil
    ) throws -> [String] {
        var result = common(engines: engines)
        result += [
            "--skip-download", "--ignore-errors", "--flat-playlist",
            "--lazy-playlist", "--dump-json"
        ]
        appendPrivateOptions(
            to: &result,
            cookiesFile: try DownloadPathValidator.validateCookiesFile(cookiesFile),
            browserCookies: cookiesFile == nil ? browserCookies : nil,
            proxy: try validatedProxyValue(proxy, credentials: proxyCredentials)
        )
        appendAnonymousYouTubeClientPolicy(
            to: &result,
            platform: url.platform,
            hasSession: cookiesFile != nil || browserCookies != nil
        )
        result += ["--", url.canonicalURL.absoluteString]
        return result
    }

    private func common(engines: DownloadEnginePaths) -> [String] {
        var result = [
            "--ignore-config", "--no-update", "--no-warnings",
            "--js-runtimes", "deno:\(engines.deno.path)",
            "--ffmpeg-location", engines.ffmpeg.path,
        ]
        appendCachePolicy(to: &result, engines: engines)
        return result
    }
}

public struct YTDLPDownloadCommandBuilder: Sendable {
    public init() {}

    public func arguments(
        item: UniversalDownloadItem,
        settings: UniversalDownloadSettings,
        engines: DownloadEnginePaths,
        downloadDirectory: URL,
        temporaryDirectory: URL,
        cookiesFile: URL?,
        browserCookies: DownloadBrowserCookieSource? = nil,
        proxy: String?,
        proxyCredentials: DownloadProxyCredentials? = nil,
        resolvedMedia: ResolvedMediaReference? = nil,
        concurrentFragmentsOverride: Int? = nil
    ) throws -> [String] {
        let selector = YTDLPFormatSelector()
        let effectiveSettings = selector.effectiveSettings(for: item, settings: settings)
        let selection = selector.selection(for: item, settings: settings)
        var result = [
            "--ignore-config", "--no-update", "--newline", "--no-playlist",
            "--no-overwrites", "--no-continue", "--trim-filenames", "180",
            "--js-runtimes", "deno:\(engines.deno.path)",
            "--ffmpeg-location", engines.ffmpeg.path,
            "--paths", "home:\(downloadDirectory.path)",
            "--paths", "temp:\(temporaryDirectory.path)",
            "--output", try outputTemplate(item: item, settings: effectiveSettings),
            "--format", selection.selector,
            "--progress-template", "download:ZEUVE_PROGRESS|%(progress._percent_str)s|%(progress.downloaded_bytes)s|%(progress.total_bytes)s|%(progress.total_bytes_estimate)s|%(progress.speed)s|%(progress.eta)s",
            "--print", "after_move:ZEUVE_FILE|%(filepath)j",
            "--retries", String(max(0, min(effectiveSettings.network.retryCount, 100))),
            "--fragment-retries", String(max(0, min(effectiveSettings.network.fragmentRetryCount, 100))),
            "--socket-timeout", String(max(1, min(effectiveSettings.network.connectionTimeoutSeconds, 300))),
            "--concurrent-fragments", String(max(1, min(concurrentFragmentsOverride ?? effectiveSettings.network.concurrentFragments, 16))),
        ]
        appendCachePolicy(to: &result, engines: engines)
        if let merge = selection.mergeOutputFormat { result += ["--merge-output-format", merge] }
        if let limit = normalizedSpeedLimit(effectiveSettings.network.speedLimit) { result += ["--limit-rate", limit] }
        if effectiveSettings.mode == .original {
            appendOriginalPageDownloadPolicy(to: &result)
        } else {
            appendAudio(to: &result, settings: effectiveSettings)
            appendSubtitles(to: &result, settings: effectiveSettings)
            appendMetadata(to: &result, settings: effectiveSettings)
        }
        let safeCookies = try DownloadPathValidator.validateCookiesFile(cookiesFile)
        let safeProxy = try validatedProxyValue(proxy, credentials: proxyCredentials)
        appendPrivateOptions(
            to: &result,
            cookiesFile: safeCookies,
            browserCookies: safeCookies == nil ? browserCookies : nil,
            proxy: safeProxy
        )
        appendAnonymousYouTubeClientPolicy(
            to: &result,
            platform: item.platform,
            hasSession: safeCookies != nil || browserCookies != nil
        )
        if let resolvedMedia { appendRequestHeaders(to: &result, headers: resolvedMedia.httpHeaders) }
        result += ["--", (resolvedMedia?.mediaURL ?? item.sourceURL).absoluteString]
        return result
    }

    public func redacted(arguments: [String]) -> [String] {
        var result = arguments
        let secretOptions = ["--cookies", "--cookies-from-browser", "--proxy", "--add-header"]
        for option in secretOptions {
            var index = 0
            while index < result.count {
                if result[index] == option, index + 1 < result.count { result[index + 1] = "<oculto>"; index += 2 }
                else { index += 1 }
            }
        }
        return result
    }

    private func appendOriginalPageDownloadPolicy(to result: inout [String]) {
        result += [
            "--no-embed-metadata",
            "--no-embed-thumbnail",
            "--no-write-thumbnail",
            "--no-embed-chapters",
            "--no-write-subs",
            "--no-write-auto-subs",
            "--no-write-description",
            "--no-write-info-json",
            "--no-write-playlist-metafiles",
            "--no-mtime",
        ]
    }

    private func appendAudio(to result: inout [String], settings: UniversalDownloadSettings) {
        guard settings.mode == .audio, settings.audioOutput != .original else { return }
        result += ["--extract-audio", "--audio-format", settings.audioOutput.rawValue]
        if settings.audioOutput == .mp3 { result += ["--audio-quality", settings.mp3Bitrate.ytDLPValue] }
    }

    private func appendSubtitles(to result: inout [String], settings: UniversalDownloadSettings) {
        let selection = settings.subtitles
        guard !selection.languages.isEmpty else { return }
        result += ["--write-subs", "--sub-langs", selection.languages.joined(separator: ",")]
        if selection.includeAutomatic { result.append("--write-auto-subs") }
        if selection.convertToSRT { result += ["--convert-subs", "srt"] }
        if selection.embed { result.append("--embed-subs") }
    }

    private func appendMetadata(to result: inout [String], settings: UniversalDownloadSettings) {
        let options = settings.metadata
        if options.embedMetadata { result.append("--embed-metadata") }
        if options.embedThumbnail { result.append("--embed-thumbnail") }
        if options.saveThumbnail { result.append("--write-thumbnail") }
        if options.preservePublicationDate { result.append("--mtime") } else { result.append("--no-mtime") }
        if options.addChapters { result.append("--embed-chapters") }
        if options.saveDescription { result.append("--write-description") }
        // ZEUVE genera sus propios JSON sanitizados. Los JSON nativos de yt-dlp
        // pueden contener URLs temporales, firmas u otros datos de sesión.
        result.append("--no-write-info-json")
        result.append("--no-write-playlist-metafiles")
    }

    private func outputTemplate(item: UniversalDownloadItem, settings: UniversalDownloadSettings) throws -> String {
        if item.isPageDiscovered {
            let base = try DownloadFilenamePolicy().sanitize(item.outputFilenameBase ?? item.title, maximumUTF8Bytes: 170)
            return DownloadFilenamePolicy().escapedOutputTemplateLiteral(base) + ".%(ext)s"
        }
        let index = settings.numberPlaylistItems
            ? item.playlistIndex.map { String(format: "%04d - ", $0) } ?? ""
            : ""
        switch settings.filenamePreset {
        case .title: return "\(index)%(title).180B.%(ext)s"
        case .titleAndID: return "\(index)%(title).160B [%(id)s].%(ext)s"
        case .dateAndTitle: return "\(index)%(upload_date>%Y-%m-%d)s - %(title).150B [%(id)s].%(ext)s"
        case .channelAndTitle: return "\(index)%(channel,uploader).60B - %(title).120B [%(id)s].%(ext)s"
        case .playlistIndexAndTitle: return "\(index)%(title).150B [%(id)s].%(ext)s"
        case .playlistAndIndexAndTitle: return "%(playlist_title|Colección).80B/\(index)%(title).140B [%(id)s].%(ext)s"
        }
    }

    private func appendRequestHeaders(to result: inout [String], headers: [String: String]) {
        for name in headers.keys.sorted() {
            guard let value = headers[name],
                  name.range(of: "^[A-Za-z0-9-]{1,64}$", options: .regularExpression) != nil,
                  value.utf8.count <= 8_192,
                  !value.contains("\r"), !value.contains("\n") else { continue }
            result += ["--add-header", "\(name):\(value)"]
        }
    }

    private func normalizedSpeedLimit(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              value.range(of: "^[0-9]+([KMG])?$", options: [.regularExpression, .caseInsensitive]) != nil else { return nil }
        return value.uppercased()
    }


}

private func validatedProxyValue(_ proxy: String?, credentials: DownloadProxyCredentials?) throws -> String? {
    guard let proxy = try DownloadPathValidator.validateProxy(proxy) else { return nil }
    guard let credentials, !credentials.username.isEmpty else { return proxy }
    guard var components = URLComponents(string: proxy) else { throw UniversalDownloaderError.invalidProxy }
    components.user = credentials.username
    components.password = credentials.password
    guard let value = components.string else { throw UniversalDownloaderError.invalidProxy }
    return value
}

private func appendPrivateOptions(
    to result: inout [String],
    cookiesFile: URL?,
    browserCookies: DownloadBrowserCookieSource?,
    proxy: String?
) {
    if let cookiesFile { result += ["--cookies", cookiesFile.path] }
    if let browserCookies { result += ["--cookies-from-browser", browserCookies.rawValue] }
    if let proxy { result += ["--proxy", proxy] }
}

private func appendCachePolicy(to result: inout [String], engines: DownloadEnginePaths) {
    if let cacheDirectory = engines.cacheDirectory {
        result += ["--cache-dir", cacheDirectory.path]
    } else {
        result.append("--no-cache-dir")
    }
}

private func appendAnonymousYouTubeClientPolicy(
    to result: inout [String],
    platform: UniversalDownloadPlatform,
    hasSession: Bool
) {
    guard platform == .youtube, !hasSession else { return }
    // YouTube puede anunciar formatos HTTPS que después rechaza con HTTP 403
    // cuando cambian sus requisitos de entrega. Estos clientes proporcionan una
    // ruta pública sin leer cookies: embedded para formatos directos y Safari
    // como respaldo HLS cuando el vídeo no admite reproducción insertada.
    result += ["--extractor-args", "youtube:player_client=web_embedded,web_safari"]
}
