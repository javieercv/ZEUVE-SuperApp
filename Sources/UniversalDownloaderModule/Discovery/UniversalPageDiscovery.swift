import Foundation
import ZEUVECore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum UniversalMediaCandidateKind: String, Sendable, Equatable, Codable {
    case directMedia
    case manifest
    case embeddedPlayer
    case metadata
}

public struct UniversalMediaCandidate: Sendable, Equatable, Identifiable {
    public let url: URL
    public let kind: UniversalMediaCandidateKind
    public let titleHint: String?

    public var id: String { UniversalURLNormalizer.duplicateKey(for: url) }

    public init(url: URL, kind: UniversalMediaCandidateKind, titleHint: String? = nil) {
        self.url = url
        self.kind = kind
        self.titleHint = titleHint
    }
}

public struct UniversalPageDiscoveryResult: Sendable, Equatable {
    public let pageTitle: String?
    public let candidates: [UniversalMediaCandidate]
    public let duplicateCount: Int

    public init(pageTitle: String?, candidates: [UniversalMediaCandidate], duplicateCount: Int) {
        self.pageTitle = pageTitle
        self.candidates = candidates
        self.duplicateCount = duplicateCount
    }
}

public struct UniversalHTMLMediaParser: Sendable {
    public init() {}

    public func parse(html: String, baseURL: URL) -> UniversalPageDiscoveryResult {
        let pageTitle = firstMatch(in: html, pattern: #"(?is)<title\b[^>]*>(.*?)</title>"#)
            .map(Self.decodeHTMLEntities)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        var values: [UniversalMediaCandidate] = []
        values += tagCandidates(html: html, tagName: "video", baseURL: baseURL, kind: .directMedia)
        values += tagCandidates(html: html, tagName: "source", baseURL: baseURL, kind: .directMedia)
        values += tagCandidates(html: html, tagName: "iframe", baseURL: baseURL, kind: .embeddedPlayer)
        values += metadataCandidates(html: html, baseURL: baseURL)
        values += jsonLDCandidates(html: html, baseURL: baseURL)
        values += rawMediaURLCandidates(html: html, baseURL: baseURL)

        var seen = Set<String>()
        var unique: [UniversalMediaCandidate] = []
        var duplicates = 0
        for candidate in values {
            let key = UniversalURLNormalizer.duplicateKey(for: candidate.url)
            if seen.insert(key).inserted {
                unique.append(candidate)
            } else {
                duplicates += 1
            }
        }
        return .init(pageTitle: pageTitle?.isEmpty == false ? pageTitle : nil, candidates: unique, duplicateCount: duplicates)
    }

    private func tagCandidates(html: String, tagName: String, baseURL: URL, kind: UniversalMediaCandidateKind) -> [UniversalMediaCandidate] {
        let pattern = "(?is)<\\s*" + NSRegularExpression.escapedPattern(for: tagName) + "\\b[^>]*>"
        return matches(in: html, pattern: pattern).compactMap { tag in
            let attributes = parseAttributes(tag)
            let raw = attributes["src"] ?? attributes["data-src"] ?? attributes["data-video-src"] ?? attributes["data-url"]
            guard let url = resolve(raw, relativeTo: baseURL), isCandidateURL(url, kind: kind) else { return nil }
            return .init(url: url, kind: inferredKind(for: url, fallback: kind), titleHint: attributes["title"])
        }
    }

    private func metadataCandidates(html: String, baseURL: URL) -> [UniversalMediaCandidate] {
        matches(in: html, pattern: #"(?is)<meta\b[^>]*>"#).compactMap { tag in
            let attributes = parseAttributes(tag)
            let name = (attributes["property"] ?? attributes["name"] ?? "").lowercased()
            let accepted = ["og:video", "og:video:url", "og:video:secure_url", "twitter:player", "twitter:player:stream"]
            guard accepted.contains(name), let url = resolve(attributes["content"], relativeTo: baseURL) else { return nil }
            return .init(url: url, kind: inferredKind(for: url, fallback: name.contains("player") ? .embeddedPlayer : .metadata))
        }
    }

    private func jsonLDCandidates(html: String, baseURL: URL) -> [UniversalMediaCandidate] {
        let scripts = matches(in: html, pattern: #"(?is)<script\b[^>]*type\s*=\s*[\"']application/ld\+json[\"'][^>]*>(.*?)</script>"#, captureGroup: 1)
        var urls: [URL] = []
        for script in scripts {
            guard let data = script.data(using: .utf8), let object = try? JSONSerialization.jsonObject(with: data) else { continue }
            collectJSONURLs(object, keys: ["contentUrl", "embedUrl"], baseURL: baseURL, into: &urls)
        }
        return urls.map { .init(url: $0, kind: inferredKind(for: $0, fallback: .metadata)) }
    }

    private func rawMediaURLCandidates(html: String, baseURL: URL) -> [UniversalMediaCandidate] {
        let encoded = matches(in: html, pattern: #"(?i)(https?:\\?/\\?/[^\"'<>\\s]+(?:\.m3u8|\.mpd|\.mp4|\.webm|\.mov|\.m4v)(?:\?[^\"'<>\\s]*)?)"#, captureGroup: 1)
        return encoded.compactMap { raw in
            let unescaped = raw.replacingOccurrences(of: "\\/", with: "/").replacingOccurrences(of: "&amp;", with: "&")
            guard let url = resolve(unescaped, relativeTo: baseURL) else { return nil }
            return .init(url: url, kind: inferredKind(for: url, fallback: .directMedia))
        }
    }

    private func collectJSONURLs(_ value: Any, keys: Set<String>, baseURL: URL, into urls: inout [URL]) {
        if let dictionary = value as? [String: Any] {
            for (key, item) in dictionary {
                if keys.contains(key), let string = item as? String, let url = resolve(string, relativeTo: baseURL) {
                    urls.append(url)
                }
                collectJSONURLs(item, keys: keys, baseURL: baseURL, into: &urls)
            }
        } else if let array = value as? [Any] {
            for item in array { collectJSONURLs(item, keys: keys, baseURL: baseURL, into: &urls) }
        }
    }

    private func parseAttributes(_ tag: String) -> [String: String] {
        let pattern = #"(?is)([A-Za-z_:][-A-Za-z0-9_:.]*)\s*=\s*(?:\"([^\"]*)\"|'([^']*)'|([^\s>]+))"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [:] }
        let ns = tag as NSString
        var result: [String: String] = [:]
        for match in regex.matches(in: tag, range: NSRange(location: 0, length: ns.length)) {
            guard match.numberOfRanges >= 5 else { continue }
            let name = ns.substring(with: match.range(at: 1)).lowercased()
            for index in 2...4 where match.range(at: index).location != NSNotFound {
                result[name] = Self.decodeHTMLEntities(ns.substring(with: match.range(at: index)))
                break
            }
        }
        return result
    }

    private func resolve(_ raw: String?, relativeTo baseURL: URL) -> URL? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        let decoded = Self.decodeHTMLEntities(raw).replacingOccurrences(of: "\\/", with: "/")
        let lower = decoded.lowercased()
        guard !lower.hasPrefix("data:"), !lower.hasPrefix("blob:"), !lower.hasPrefix("javascript:") else { return nil }
        return URL(string: decoded, relativeTo: baseURL)?.absoluteURL
    }

    private func isCandidateURL(_ url: URL, kind: UniversalMediaCandidateKind) -> Bool {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return false }
        if kind == .embeddedPlayer { return true }
        let path = url.path.lowercased()
        return [".mp4", ".webm", ".mov", ".m4v", ".mkv", ".avi", ".mpeg", ".mpg", ".m3u8", ".mpd", ".ts"]
            .contains(where: { path.hasSuffix($0) })
    }

    private func inferredKind(for url: URL, fallback: UniversalMediaCandidateKind) -> UniversalMediaCandidateKind {
        let path = url.path.lowercased()
        if path.hasSuffix(".m3u8") || path.hasSuffix(".mpd") { return .manifest }
        return fallback
    }

    private func matches(in text: String, pattern: String, captureGroup: Int = 0) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            guard captureGroup < match.numberOfRanges, match.range(at: captureGroup).location != NSNotFound else { return nil }
            return ns.substring(with: match.range(at: captureGroup))
        }
    }

    private func firstMatch(in text: String, pattern: String) -> String? {
        matches(in: text, pattern: pattern, captureGroup: 1).first
    }

    private static func decodeHTMLEntities(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}

public actor UniversalPageDiscoveryService {
    private let parser: UniversalHTMLMediaParser
    private let maximumHTMLBytes: Int

    public init(parser: UniversalHTMLMediaParser = .init(), maximumHTMLBytes: Int = 16 * 1024 * 1024) {
        self.parser = parser
        self.maximumHTMLBytes = maximumHTMLBytes
    }

    public func discover(
        pageURL: URL,
        cookiesFile: URL? = nil,
        proxy: String? = nil,
        proxyCredentials: DownloadProxyCredentials? = nil,
        timeoutSeconds: Int = 30
    ) async throws -> UniversalPageDiscoveryResult {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.timeoutIntervalForRequest = TimeInterval(max(1, min(timeoutSeconds, 300)))
        configuration.timeoutIntervalForResource = TimeInterval(max(1, min(timeoutSeconds * 2, 600)))
        if let proxy = try DownloadPathValidator.validateProxy(proxy), let components = URLComponents(string: proxy), let host = components.host {
            let port = components.port ?? ((components.scheme?.lowercased() == "https") ? 443 : 80)
            configuration.connectionProxyDictionary = [
                "HTTPEnable": 1, "HTTPProxy": host, "HTTPPort": port,
                "HTTPSEnable": 1, "HTTPSProxy": host, "HTTPSPort": port,
            ]
        }
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: pageURL)
        request.setValue("Mozilla/5.0 (Macintosh; Apple Silicon Mac OS X 14_0) AppleWebKit/605.1.15 Safari/605.1.15 \(ZEUVEProductInfo.httpUserAgentToken)", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml;q=0.9,*/*;q=0.1", forHTTPHeaderField: "Accept")
        if let cookiesFile,
           let data = try? Data(contentsOf: cookiesFile),
           let cookies = try? NetscapeCookieFile.parse(data),
           let header = NetscapeCookieFile.cookieHeader(for: pageURL, cookies: cookies) {
            request.setValue(header, forHTTPHeaderField: "Cookie")
        }
        if let credentials = proxyCredentials, !credentials.username.isEmpty,
           let auth = "\(credentials.username):\(credentials.password)".data(using: .utf8)?.base64EncodedString() {
            request.setValue("Basic \(auth)", forHTTPHeaderField: "Proxy-Authorization")
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...399).contains(http.statusCode) else {
            throw UniversalDownloaderError.analysisFailed("La página no ha respondido correctamente.")
        }
        let contentType = http.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        guard contentType.contains("text/html") || contentType.contains("application/xhtml") || contentType.isEmpty else {
            return .init(pageTitle: nil, candidates: [], duplicateCount: 0)
        }
        guard data.count <= maximumHTMLBytes else {
            throw UniversalDownloaderError.analysisFailed("La página HTML supera el límite de inspección segura de 16 MB.")
        }
        let encoding = String.Encoding.utf8
        guard let html = String(data: data, encoding: encoding) ?? String(data: data, encoding: .isoLatin1) else {
            throw UniversalDownloaderError.analysisFailed("La página utiliza una codificación no compatible.")
        }
        return parser.parse(html: html, baseURL: pageURL)
    }
}
