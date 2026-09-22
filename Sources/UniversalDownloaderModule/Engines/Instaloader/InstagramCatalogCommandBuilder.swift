import Foundation

public struct InstagramCatalogCommandBuilder: Sendable {
    public init() {}

    public func arguments(
        username: String,
        limit: Int,
        cursor: String? = nil,
        cookiesFile: URL? = nil,
        cookieHeaderFile: URL? = nil,
        includeStories: Bool = true,
        includeHighlights: Bool = true,
        includeReels: Bool = true,
        includeProfilePicture: Bool = true
    ) throws -> [String] {
        var result = [
            "catalog",
            "--username", username,
            "--limit", String(max(1, min(limit, 500)))
        ]
        if let cursor, !cursor.isEmpty { result += ["--cursor", cursor] }
        if includeStories { result.append("--stories") }
        if includeHighlights { result.append("--highlights") }
        if includeReels { result.append("--reels") }
        if includeProfilePicture { result.append("--profile-picture") }
        if let cookiesFile = try DownloadPathValidator.validateCookiesFile(cookiesFile) {
            result += ["--cookies", cookiesFile.path]
        }
        if let cookieHeaderFile {
            result += ["--cookie-header-file", cookieHeaderFile.path]
        }
        return result
    }

    public func directArguments(
        for input: ValidatedDownloadURL,
        cookiesFile: URL? = nil,
        cookieHeaderFile: URL? = nil
    ) throws -> [String] {
        guard input.platform == .instagram,
              input.kind != .profile,
              let shortcode = Self.shortcode(from: input.canonicalURL) else {
            throw UniversalDownloaderError.analysisFailed("El enlace directo de Instagram no contiene un identificador válido.")
        }
        let path = input.canonicalURL.path.lowercased()
        var result = [
            "direct",
            "--shortcode", shortcode,
            "--source-url", input.canonicalURL.absoluteString,
            "--content-kind", (path.contains("/reel/") || path.contains("/reels/")) ? "reel" : "post",
        ]
        if let cookiesFile = try DownloadPathValidator.validateCookiesFile(cookiesFile) {
            result += ["--cookies", cookiesFile.path]
        }
        if let cookieHeaderFile {
            result += ["--cookie-header-file", cookieHeaderFile.path]
        }
        return result
    }

    public static func shortcode(from url: URL) -> String? {
        let parts = url.path.split(separator: "/").map(String.init)
        guard let marker = parts.firstIndex(where: { ["p", "reel", "reels", "tv"].contains($0.lowercased()) }),
              parts.indices.contains(marker + 1) else { return nil }
        let value = parts[marker + 1]
        guard value.range(of: "^[A-Za-z0-9_-]{3,64}$", options: .regularExpression) != nil else { return nil }
        return value
    }
}
