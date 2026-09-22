import Foundation

public struct AdultContentPolicy: Sendable {
    private static let knownDomains: Set<String> = [
        "erome.com", "pornhub.com", "xvideos.com", "xnxx.com", "redgifs.com",
        "xhamster.com", "youporn.com", "tube8.com", "spankbang.com", "rule34.xxx",
        "nhentai.net", "e-hentai.org", "exhentai.org", "motherless.com", "imagefap.com"
    ]

    public init() {}

    public func isAdult(url: URL, platform: UniversalDownloadPlatform, additionalDomains: [String] = []) -> Bool {
        if platform.isAdultPlatform { return true }
        guard let host = url.host?.lowercased() else { return false }
        let normalizedAdditional = additionalDomains.compactMap(Self.normalizedDomain)
        return (Self.knownDomains.union(normalizedAdditional)).contains { domain in
            host == domain || host.hasSuffix(".\(domain)")
        }
    }

    public func matchedDomain(url: URL, platform: UniversalDownloadPlatform, additionalDomains: [String] = []) -> String? {
        guard isAdult(url: url, platform: platform, additionalDomains: additionalDomains) else { return nil }
        return url.host?.lowercased() ?? platform.spanishName
    }

    private static func normalizedDomain(_ value: String) -> String? {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty else { return nil }
        if let url = URL(string: text.contains("://") ? text : "https://\(text)"), let host = url.host {
            text = host.lowercased()
        }
        while text.hasPrefix("www.") { text.removeFirst(4) }
        guard text.range(of: "^[a-z0-9.-]+$", options: .regularExpression) != nil else { return nil }
        return text
    }
}
