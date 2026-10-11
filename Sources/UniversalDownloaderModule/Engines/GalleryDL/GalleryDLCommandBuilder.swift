import Foundation

public struct GalleryDLAnalysisCommandBuilder: Sendable {
    public init() {}

    public func arguments(
        for input: ValidatedDownloadURL,
        cookiesFile: URL?,
        proxy: String?,
        proxyCredentials: DownloadProxyCredentials? = nil,
        timeoutSeconds: Int = 20
    ) throws -> [String] {
        var result = [
            "--config-ignore",
            "--dump-json",
            "--simulate",
            "--no-mtime",
            "--sleep-request", "0.5",
            "--retries", "2",
            "--http-timeout", String(max(1, min(timeoutSeconds, 300)))
        ]
        appendPrivateOptions(
            to: &result,
            cookiesFile: try DownloadPathValidator.validateCookiesFile(cookiesFile),
            proxy: try validatedGalleryProxy(proxy, credentials: proxyCredentials)
        )
        result += ["--", input.canonicalURL.absoluteString]
        return result
    }
}

public struct GalleryDLDownloadCommandBuilder: Sendable {
    public init() {}

    public func arguments(
        item: UniversalDownloadItem,
        settings: UniversalDownloadSettings,
        downloadDirectory: URL,
        cookiesFile: URL?,
        proxy: String?,
        proxyCredentials: DownloadProxyCredentials? = nil
    ) throws -> [String] {
        let safeBase = try DownloadFilenamePolicy().sanitize(item.outputFilenameBase ?? item.title, maximumUTF8Bytes: 160)
        var result = [
            "--config-ignore",
            "--destination", downloadDirectory.path,
            "--directory", "",
            "--filename", DownloadFilenamePolicy().escapedOutputTemplateLiteral(safeBase) + ".{extension}",
            "--no-part",
            "--no-mtime",
            "--retries", String(max(0, min(settings.network.retryCount, 100))),
            "--http-timeout", String(max(1, min(settings.network.connectionTimeoutSeconds, 300)))
        ]
        if let selector = item.gallerySelector {
            guard selector.index > 0,
                  ["file_id", "num", "filename"].contains(where: { selector.identity[$0]?.isEmpty == false }) else {
                throw UniversalDownloaderError.unavailableMedia("La selección no identifica un recurso único. Vuelve a analizar el enlace.")
            }
            // gallery-dl aplica el filtro antes de contar --range. La identidad
            // selecciona el recurso y el rango limita la salida a una coincidencia.
            result += ["--filter", try identityFilter(selector.identity), "--range", "1"]
        } else if let index = item.playlistIndex, index > 0 {
            result += ["--range", String(index)]
        }
        appendPrivateOptions(
            to: &result,
            cookiesFile: try DownloadPathValidator.validateCookiesFile(cookiesFile),
            proxy: try validatedGalleryProxy(proxy, credentials: proxyCredentials)
        )
        result += ["--", item.sourceURL.absoluteString]
        return result
    }

    private func identityFilter(_ identity: [String: String]) throws -> String {
        let keys: Set<String> = ["id", "post_id", "shortcode", "tweet_id", "pin_id", "album_id", "file_id", "num", "filename"]
        return try identity.sorted { $0.key < $1.key }.map { key, value in
            guard keys.contains(key), !value.isEmpty, value.utf8.count <= 256,
                  !value.contains("\n"), !value.contains("\r") else { throw UniversalDownloaderError.unsafeOutputName }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.withoutEscapingSlashes]
            let quoted = String(decoding: try encoder.encode(value), as: UTF8.self)
            if let number = Int64(value) { return "(\(key) == \(quoted) or \(key) == \(number))" }
            return "\(key) == \(quoted)"
        }.joined(separator: " and ")
    }

    public func redacted(arguments: [String]) -> [String] {
        var result = arguments
        for option in ["--cookies", "--proxy"] {
            var index = 0
            while index < result.count {
                if result[index] == option, index + 1 < result.count {
                    result[index + 1] = "<oculto>"
                    index += 2
                } else {
                    index += 1
                }
            }
        }
        return result
    }
}

private func validatedGalleryProxy(_ proxy: String?, credentials: DownloadProxyCredentials?) throws -> String? {
    guard let proxy = try DownloadPathValidator.validateProxy(proxy) else { return nil }
    guard let credentials, !credentials.username.isEmpty else { return proxy }
    guard var components = URLComponents(string: proxy) else { throw UniversalDownloaderError.invalidProxy }
    components.user = credentials.username
    components.password = credentials.password
    guard let value = components.string else { throw UniversalDownloaderError.invalidProxy }
    return value
}

private func appendPrivateOptions(to result: inout [String], cookiesFile: URL?, proxy: String?) {
    if let cookiesFile { result += ["--cookies", cookiesFile.path] }
    if let proxy { result += ["--proxy", proxy] }
}
