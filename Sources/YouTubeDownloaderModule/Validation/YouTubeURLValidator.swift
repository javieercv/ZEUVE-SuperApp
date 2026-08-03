import Foundation

public struct YouTubeURLValidationResult: Sendable, Equatable {
    public let accepted: [ValidatedYouTubeURL]
    public let duplicates: [String]
    public let rejected: [String: String]

    public init(accepted: [ValidatedYouTubeURL], duplicates: [String], rejected: [String: String]) {
        self.accepted = accepted
        self.duplicates = duplicates
        self.rejected = rejected
    }
}

public struct YouTubeURLValidator: Sendable {
    private static let approvedHosts: Set<String> = [
        "youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com", "youtu.be"
    ]

    public init() {}

    public func validate(text: String) -> YouTubeURLValidationResult {
        let candidates = text
            .split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == ";" })
            .map(String.init)
            .filter { !$0.isEmpty }
        var accepted: [ValidatedYouTubeURL] = []
        var seen = Set<String>()
        var duplicates: [String] = []
        var rejected: [String: String] = [:]
        for candidate in candidates {
            do {
                let value = try validate(candidate)
                if seen.insert(value.id).inserted {
                    accepted.append(value)
                } else {
                    duplicates.append(candidate)
                }
            } catch {
                rejected[candidate] = error.localizedDescription
            }
        }
        return .init(accepted: accepted, duplicates: duplicates, rejected: rejected)
    }

    public func validate(_ raw: String) throws -> ValidatedYouTubeURL {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw YouTubeDownloaderError.emptyInput }
        guard let components = URLComponents(string: trimmed), let scheme = components.scheme?.lowercased() else {
            throw YouTubeDownloaderError.malformedURL(trimmed)
        }
        guard scheme == "https" || scheme == "http" else {
            throw YouTubeDownloaderError.unsupportedScheme(scheme)
        }
        guard let host = components.host?.lowercased(), Self.approvedHosts.contains(host) else {
            throw YouTubeDownloaderError.unsupportedHost(components.host ?? "desconocido")
        }
        guard scheme == "https" else {
            throw YouTubeDownloaderError.unsupportedScheme(scheme)
        }
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        let playlistID = sanitizeIdentifier(query["list"])

        if host == "youtu.be" {
            let id = sanitizeIdentifier(components.path.split(separator: "/").first.map(String.init))
            guard let id else { throw YouTubeDownloaderError.missingVideoIdentifier }
            return video(original: trimmed, id: id, playlistID: playlistID)
        }

        let path = components.path.lowercased()
        if path == "/playlist" || (query["list"] != nil && query["v"] == nil) {
            guard let playlistID else { throw YouTubeDownloaderError.missingPlaylistIdentifier }
            let canonical = URL(string: "https://www.youtube.com/playlist?list=\(playlistID)")!
            return .init(original: URL(string: trimmed)!, canonicalURL: canonical, canonicalID: playlistID, kind: .playlist, playlistID: playlistID)
        }
        if path == "/watch" {
            guard let id = sanitizeIdentifier(query["v"]) else { throw YouTubeDownloaderError.missingVideoIdentifier }
            return video(original: trimmed, id: id, playlistID: playlistID)
        }
        let pathParts = components.path.split(separator: "/").map(String.init)
        if let first = pathParts.first?.lowercased(), ["shorts", "live", "embed"].contains(first), pathParts.count >= 2,
           let id = sanitizeIdentifier(pathParts[1]) {
            return video(original: trimmed, id: id, playlistID: playlistID)
        }
        throw YouTubeDownloaderError.malformedURL(trimmed)
    }

    private func video(original: String, id: String, playlistID: String?) -> ValidatedYouTubeURL {
        let canonical = URL(string: "https://www.youtube.com/watch?v=\(id)")!
        return .init(original: URL(string: original)!, canonicalURL: canonical, canonicalID: id, kind: .video, playlistID: playlistID)
    }

    private func sanitizeIdentifier(_ value: String?) -> String? {
        guard let value, !value.isEmpty,
              value.range(of: "^[A-Za-z0-9_-]{6,128}$", options: .regularExpression) != nil else { return nil }
        return value
    }
}
