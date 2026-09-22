import Foundation
import ZEUVECore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Descarga archivos multimedia ya resueltos sin recodificarlos ni cargarlos completos en memoria.
/// Se utiliza para fotografías y archivos directos descubiertos por extractores de galerías.
public struct DirectHTTPDownloadService: Sendable {
    private let fileManagerBox: SendableFileManager
    private var fileManager: FileManager { fileManagerBox.fileManager }

    public init(fileManager: FileManager = .default) {
        fileManagerBox = SendableFileManager(fileManager)
    }

    public func download(
        item: UniversalDownloadItem,
        to directory: URL,
        cookiesFile: URL? = nil,
        cookieHeaderFile: URL? = nil,
        proxy: String? = nil,
        timeout: TimeInterval = 60
    ) async throws -> URL {
        guard let media = item.resolvedMedia,
              let mediaURL = media.mediaURL,
              media.kind == .directFile || media.kind == .unknown else {
            throw UniversalDownloaderError.noPublishedFiles
        }
        guard let scheme = mediaURL.scheme?.lowercased(), ["https", "http"].contains(scheme) else {
            throw UniversalDownloaderError.malformedURL(mediaURL.absoluteString)
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = max(timeout, 600)
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        if let proxyDictionary = Self.proxyDictionary(from: proxy) {
            configuration.connectionProxyDictionary = proxyDictionary
        }

        var request = URLRequest(url: mediaURL)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue(ZEUVEProductInfo.httpUserAgentToken, forHTTPHeaderField: "User-Agent")
        for (name, value) in media.httpHeaders where Self.allowedHeader(name) {
            request.setValue(value, forHTTPHeaderField: name)
        }
        if request.value(forHTTPHeaderField: "Cookie") == nil,
           let cookieHeaderFile,
           let rawHeader = try? String(contentsOf: cookieHeaderFile, encoding: .utf8),
           let normalizedHeader = Self.normalizedCookieHeader(rawHeader) {
            request.setValue(normalizedHeader, forHTTPHeaderField: "Cookie")
        }
        if request.value(forHTTPHeaderField: "Cookie") == nil,
           let cookiesFile,
           let cookies = try? NetscapeCookieFile.parse(Data(contentsOf: cookiesFile)),
           let header = NetscapeCookieFile.cookieHeader(for: mediaURL, cookies: cookies) {
            request.setValue(header, forHTTPHeaderField: "Cookie")
        }

        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let (temporaryURL, response) = try await session.download(for: request)
        guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(
                domain: "com.zeuve.universal-downloader.direct-media",
                code: code,
                userInfo: [NSLocalizedDescriptionKey: "El servidor no ha entregado el archivo multimedia (HTTP \(code))."]
            )
        }

        let expected = Self.extensionName(
            explicit: item.expectedExtension ?? media.extensionName,
            mimeType: response.mimeType,
            url: mediaURL
        )
        let rawBase = item.outputFilenameBase ?? item.title
        let safeBase = (try? DownloadFilenamePolicy().sanitize(rawBase)) ?? "contenido"
        let destination = directory.appendingPathComponent("\(safeBase).\(expected)", isDirectory: false)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: temporaryURL, to: destination)
        let values = try destination.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true, (values.fileSize ?? 0) > 0 else {
            try? fileManager.removeItem(at: destination)
            throw UniversalDownloaderError.noPublishedFiles
        }
        return destination
    }

    private static func normalizedCookieHeader(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let value: String
        if trimmed.lowercased().hasPrefix("cookie:") {
            value = String(trimmed.dropFirst("cookie:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            value = trimmed
        }
        guard !value.isEmpty, !value.contains("\n"), !value.contains("\r") else { return nil }
        return value
    }

    static func extensionName(explicit: String?, mimeType: String?, url: URL) -> String {
        let mime = mimeType?.lowercased() ?? ""
        let byMIME: [String: String] = [
            "image/jpeg": "jpg", "image/png": "png", "image/webp": "webp",
            "image/gif": "gif", "image/avif": "avif", "image/heic": "heic",
            "image/tiff": "tiff", "video/mp4": "mp4", "video/webm": "webm",
            "video/quicktime": "mov", "audio/mpeg": "mp3", "audio/mp4": "m4a",
            "audio/ogg": "opus"
        ]
        // El CDN puede negociar un formato distinto al sufijo de la URL (por
        // ejemplo, WebP desde una ruta terminada en .jpg). El Content-Type de
        // la respuesta es la evidencia autoritativa del archivo recibido.
        if let value = byMIME[mime] { return value }
        let cleanedExplicit = explicit?
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
            .lowercased()
        if let cleanedExplicit, cleanedExplicit.range(of: "^[a-z0-9]{1,8}$", options: .regularExpression) != nil {
            return normalizedExtension(cleanedExplicit)
        }
        let urlExtension = url.pathExtension.lowercased()
        if urlExtension.range(of: "^[a-z0-9]{1,8}$", options: .regularExpression) != nil {
            return normalizedExtension(urlExtension)
        }
        return "bin"
    }

    private static func normalizedExtension(_ value: String) -> String {
        value == "jpeg" ? "jpg" : value
    }

    private static func allowedHeader(_ name: String) -> Bool {
        let lower = name.lowercased()
        return !["host", "content-length", "connection", "proxy-authorization"].contains(lower)
    }

    private static func proxyDictionary(from value: String?) -> [AnyHashable: Any]? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let normalized = value.contains("://") ? value : "http://\(value)"
        guard let url = URL(string: normalized), let host = url.host, let port = url.port else { return nil }
        return [
            "HTTPEnable": true,
            "HTTPProxy": host,
            "HTTPPort": port,
            "HTTPSEnable": true,
            "HTTPSProxy": host,
            "HTTPSPort": port
        ]
    }
}

private final class SendableFileManager: @unchecked Sendable {
    let fileManager: FileManager

    init(_ fileManager: FileManager) {
        self.fileManager = fileManager
    }
}
