import Foundation

public enum UniversalURLNormalizer {
    private static let trackingNames: Set<String> = [
        "fbclid", "gclid", "dclid", "mc_cid", "mc_eid", "ref", "referrer"
    ]
    private static let transientNames: Set<String> = [
        "token", "access_token", "auth", "authorization", "sig", "signature",
        "expires", "expiry", "exp", "policy", "key-pair-id", "hdnts", "hdnea"
    ]

    public static func canonicalURL(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return url }
        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()
        components.fragment = nil
        if components.path.isEmpty { components.path = "/" }
        components.queryItems = normalizedQueryItems(components.queryItems, removeTransient: false)
        return components.url ?? url
    }

    public static func duplicateKey(for url: URL) -> String {
        guard var components = URLComponents(url: canonicalURL(url), resolvingAgainstBaseURL: true) else {
            return url.absoluteString
        }
        components.queryItems = normalizedQueryItems(components.queryItems, removeTransient: true)
        return components.string ?? url.absoluteString
    }

    public static func provenanceURL(_ url: URL) -> URL {
        guard var components = URLComponents(url: canonicalURL(url), resolvingAgainstBaseURL: true) else { return canonicalURL(url) }
        components.queryItems = normalizedQueryItems(components.queryItems, removeTransient: true)
        components.fragment = nil
        return components.url ?? canonicalURL(url)
    }

    public static func pageIdentifier(for url: URL) -> String? {
        let components = url.path.split(separator: "/").map(String.init)
        guard let last = components.last, !last.isEmpty else { return nil }
        return last.removingPercentEncoding ?? last
    }

    public static func stableIdentifier(for value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(format: "%016llx", hash)
    }

    public static func sanitizedLogURL(_ url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return url.host ?? "URL no disponible"
        }
        components.query = nil
        components.fragment = nil
        return components.string ?? (url.host ?? "URL no disponible")
    }

    private static func normalizedQueryItems(_ items: [URLQueryItem]?, removeTransient: Bool) -> [URLQueryItem]? {
        guard let items, !items.isEmpty else { return nil }
        let filtered = items.filter { item in
            let name = item.name.lowercased()
            if name.hasPrefix("utm_") || trackingNames.contains(name) { return false }
            if removeTransient && (transientNames.contains(name) || name.hasPrefix("x-amz-") || name.hasPrefix("x-goog-")) {
                return false
            }
            return true
        }
        guard !filtered.isEmpty else { return nil }
        return filtered.sorted {
            ($0.name.lowercased(), $0.value ?? "") < ($1.name.lowercased(), $1.value ?? "")
        }
    }
}
