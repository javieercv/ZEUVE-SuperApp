import Foundation

public struct NetscapeCookie: Sendable, Equatable {
    public let domain: String
    public let includeSubdomains: Bool
    public let path: String
    public let secure: Bool
    public let expires: Int64
    public let name: String
    public let value: String

    public func matches(_ url: URL, now: Date = Date()) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let cookieDomain = domain.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        let domainMatches = host == cookieDomain || (includeSubdomains && host.hasSuffix("." + cookieDomain))
        guard domainMatches else { return false }
        if secure && url.scheme?.lowercased() != "https" { return false }
        if expires > 0 && expires < Int64(now.timeIntervalSince1970) { return false }
        let requestPath = url.path.isEmpty ? "/" : url.path
        return requestPath.hasPrefix(path.isEmpty ? "/" : path)
    }
}

public enum NetscapeCookieFile {
    public static func parse(_ data: Data) throws -> [NetscapeCookie] {
        guard let text = String(data: data, encoding: .utf8) else {
            throw UniversalDownloaderError.cookiesFileUnavailable
        }
        var cookies: [NetscapeCookie] = []
        var sawHeader = false
        for rawLine in text.split(whereSeparator: \.isNewline) {
            var line = String(rawLine)
            if line.hasPrefix("# Netscape HTTP Cookie File") || line.hasPrefix("# HTTP Cookie File") {
                sawHeader = true
                continue
            }
            if line.hasPrefix("#HttpOnly_") {
                line.removeFirst("#HttpOnly_".count)
            } else if line.hasPrefix("#") || line.trimmingCharacters(in: .whitespaces).isEmpty {
                continue
            }
            let columns = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard columns.count >= 7,
                  let expires = Int64(columns[4]) else {
                throw UniversalDownloaderError.cookiesFileUnavailable
            }
            cookies.append(.init(
                domain: columns[0],
                includeSubdomains: columns[1].uppercased() == "TRUE",
                path: columns[2],
                secure: columns[3].uppercased() == "TRUE",
                expires: expires,
                name: columns[5],
                value: columns[6...].joined(separator: "\t")
            ))
        }
        guard sawHeader || !cookies.isEmpty else { throw UniversalDownloaderError.cookiesFileUnavailable }
        return cookies
    }

    public static func cookieHeader(for url: URL, cookies: [NetscapeCookie]) -> String? {
        let values = cookies.filter { $0.matches(url) }.map { "\($0.name)=\($0.value)" }
        return values.isEmpty ? nil : values.joined(separator: "; ")
    }
}
