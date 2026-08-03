import Foundation

public struct YouTubeEnginePaths: Sendable, Equatable {
    public let ytDLP: URL
    public let deno: URL
    public let ffmpeg: URL
    public let ffprobe: URL
    public let cacheDirectory: URL?

    public init(ytDLP: URL, deno: URL, ffmpeg: URL, ffprobe: URL, cacheDirectory: URL? = nil) {
        self.ytDLP = ytDLP.standardizedFileURL
        self.deno = deno.standardizedFileURL
        self.ffmpeg = ffmpeg.standardizedFileURL
        self.ffprobe = ffprobe.standardizedFileURL
        self.cacheDirectory = cacheDirectory?.standardizedFileURL
    }
}

public struct YouTubeAnalysisCommandBuilder: Sendable {
    public init() {}

    public func arguments(
        for url: ValidatedYouTubeURL,
        engines: YouTubeEnginePaths,
        cookiesFile: URL? = nil,
        proxy: String? = nil,
        proxyCredentials: YouTubeProxyCredentials? = nil
    ) throws -> [String] {
        var result = common(engines: engines)
        result += ["--skip-download", "--ignore-errors"]
        if url.kind == .playlist {
            result += ["--flat-playlist", "--lazy-playlist", "--dump-json"]
        } else {
            result += ["--no-playlist", "--dump-single-json"]
        }
        appendPrivateOptions(
            to: &result,
            cookiesFile: try YouTubePathValidator.validateCookiesFile(cookiesFile),
            proxy: try validatedProxyValue(proxy, credentials: proxyCredentials)
        )
        result += ["--", url.canonicalURL.absoluteString]
        return result
    }

    private func common(engines: YouTubeEnginePaths) -> [String] {
        var result = [
            "--ignore-config", "--no-update", "--no-warnings",
            "--js-runtimes", "deno:\(engines.deno.path)",
            "--ffmpeg-location", engines.ffmpeg.path,
        ]
        appendCachePolicy(to: &result, engines: engines)
        return result
    }
}

public struct YouTubeDownloadCommandBuilder: Sendable {
    public init() {}

    public func arguments(
        item: YouTubeDownloadItem,
        settings: YouTubeDownloadSettings,
        engines: YouTubeEnginePaths,
        downloadDirectory: URL,
        temporaryDirectory: URL,
        cookiesFile: URL?,
        proxy: String?,
        proxyCredentials: YouTubeProxyCredentials? = nil
    ) throws -> [String] {
        let selection = YouTubeFormatSelector().selection(for: settings)
        var result = [
            "--ignore-config", "--no-update", "--newline", "--no-playlist",
            "--no-overwrites", "--no-continue", "--trim-filenames", "180",
            "--js-runtimes", "deno:\(engines.deno.path)",
            "--ffmpeg-location", engines.ffmpeg.path,
            "--paths", "home:\(downloadDirectory.path)",
            "--paths", "temp:\(temporaryDirectory.path)",
            "--output", outputTemplate(item: item, settings: settings),
            "--format", selection.selector,
            "--progress-template", "download:ZEUVE_PROGRESS|%(progress._percent_str)s|%(progress.downloaded_bytes)s|%(progress.total_bytes)s|%(progress.total_bytes_estimate)s|%(progress.speed)s|%(progress.eta)s",
            "--print", "after_move:ZEUVE_FILE|%(filepath)j",
            "--retries", String(max(0, min(settings.network.retryCount, 100))),
            "--fragment-retries", String(max(0, min(settings.network.fragmentRetryCount, 100))),
            "--socket-timeout", String(max(1, min(settings.network.connectionTimeoutSeconds, 300))),
            "--concurrent-fragments", String(max(1, min(settings.network.concurrentFragments, 16))),
        ]
        appendCachePolicy(to: &result, engines: engines)
        if let merge = selection.mergeOutputFormat { result += ["--merge-output-format", merge] }
        if let limit = normalizedSpeedLimit(settings.network.speedLimit) { result += ["--limit-rate", limit] }
        appendAudio(to: &result, settings: settings)
        appendSubtitles(to: &result, settings: settings)
        appendMetadata(to: &result, settings: settings)
        let safeCookies = try YouTubePathValidator.validateCookiesFile(cookiesFile)
        let safeProxy = try validatedProxyValue(proxy, credentials: proxyCredentials)
        appendPrivateOptions(to: &result, cookiesFile: safeCookies, proxy: safeProxy)
        result += ["--", item.sourceURL.absoluteString]
        return result
    }

    public func redacted(arguments: [String]) -> [String] {
        var result = arguments
        let secretOptions = ["--cookies", "--proxy"]
        for option in secretOptions {
            var index = 0
            while index < result.count {
                if result[index] == option, index + 1 < result.count { result[index + 1] = "<oculto>"; index += 2 }
                else { index += 1 }
            }
        }
        return result
    }

    private func appendAudio(to result: inout [String], settings: YouTubeDownloadSettings) {
        guard settings.mode == .audio, settings.audioOutput != .original else { return }
        result += ["--extract-audio", "--audio-format", settings.audioOutput.rawValue]
        if settings.audioOutput == .mp3 { result += ["--audio-quality", settings.mp3Bitrate.ytDLPValue] }
    }

    private func appendSubtitles(to result: inout [String], settings: YouTubeDownloadSettings) {
        let selection = settings.subtitles
        guard !selection.languages.isEmpty else { return }
        result += ["--write-subs", "--sub-langs", selection.languages.joined(separator: ",")]
        if selection.includeAutomatic { result.append("--write-auto-subs") }
        if selection.convertToSRT { result += ["--convert-subs", "srt"] }
        if selection.embed { result.append("--embed-subs") }
    }

    private func appendMetadata(to result: inout [String], settings: YouTubeDownloadSettings) {
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

    private func outputTemplate(item: YouTubeDownloadItem, settings: YouTubeDownloadSettings) -> String {
        let index = settings.numberPlaylistItems
            ? item.playlistIndex.map { String(format: "%04d - ", $0) } ?? ""
            : ""
        switch settings.filenamePreset {
        case .title: return "\(index)%(title).180B.%(ext)s"
        case .titleAndID: return "\(index)%(title).160B [%(id)s].%(ext)s"
        case .dateAndTitle: return "\(index)%(upload_date>%Y-%m-%d)s - %(title).150B [%(id)s].%(ext)s"
        case .channelAndTitle: return "\(index)%(channel,uploader).60B - %(title).120B [%(id)s].%(ext)s"
        case .playlistIndexAndTitle: return "\(index)%(title).150B [%(id)s].%(ext)s"
        case .playlistAndIndexAndTitle: return "\(index)%(title).140B [%(id)s].%(ext)s"
        }
    }

    private func normalizedSpeedLimit(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              value.range(of: "^[0-9]+([KMG])?$", options: [.regularExpression, .caseInsensitive]) != nil else { return nil }
        return value.uppercased()
    }


}

private func validatedProxyValue(_ proxy: String?, credentials: YouTubeProxyCredentials?) throws -> String? {
    guard let proxy = try YouTubePathValidator.validateProxy(proxy) else { return nil }
    guard let credentials, !credentials.username.isEmpty else { return proxy }
    guard var components = URLComponents(string: proxy) else { throw YouTubeDownloaderError.invalidProxy }
    components.user = credentials.username
    components.password = credentials.password
    guard let value = components.string else { throw YouTubeDownloaderError.invalidProxy }
    return value
}

private func appendPrivateOptions(to result: inout [String], cookiesFile: URL?, proxy: String?) {
    if let cookiesFile { result += ["--cookies", cookiesFile.path] }
    if let proxy { result += ["--proxy", proxy] }
}

private func appendCachePolicy(to result: inout [String], engines: YouTubeEnginePaths) {
    if let cacheDirectory = engines.cacheDirectory {
        result += ["--cache-dir", cacheDirectory.path]
    } else {
        result.append("--no-cache-dir")
    }
}
