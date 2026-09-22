import Foundation

struct YouTubeURLCanonicalization: Sendable, Equatable {
    let url: URL
    let identifier: String
    let kind: DownloadContentKind
    let playlistID: String?
}

enum YouTubeURLCanonicalizer {
    static func canonicalize(components: URLComponents, host: String) -> YouTubeURLCanonicalization? {
        let youtubeHosts: Set<String> = ["youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com", "youtu.be"]
        guard youtubeHosts.contains(host) else { return nil }
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name.lowercased(), $0.value ?? "") })
        let listID = sanitizedIdentifier(query["list"])
        if host == "youtu.be",
           let raw = components.path.split(separator: "/").first.map(String.init),
           let videoID = sanitizedIdentifier(raw) {
            return .init(
                url: URL(string: "https://www.youtube.com/watch?v=\(videoID)")!,
                identifier: videoID,
                kind: .video,
                playlistID: listID
            )
        }
        let path = components.path.lowercased()
        if path == "/playlist" || (listID != nil && query["v"] == nil), let listID {
            return .init(
                url: URL(string: "https://www.youtube.com/playlist?list=\(listID)")!,
                identifier: listID,
                kind: .playlist,
                playlistID: listID
            )
        }
        if path == "/watch", let videoID = sanitizedIdentifier(query["v"]) {
            return .init(
                url: URL(string: "https://www.youtube.com/watch?v=\(videoID)")!,
                identifier: videoID,
                kind: .video,
                playlistID: listID
            )
        }
        let parts = components.path.split(separator: "/").map(String.init)
        if let first = parts.first?.lowercased(),
           ["shorts", "embed"].contains(first),
           parts.count >= 2,
           let videoID = sanitizedIdentifier(parts[1]) {
            return .init(
                url: URL(string: "https://www.youtube.com/watch?v=\(videoID)")!,
                identifier: videoID,
                kind: .video,
                playlistID: listID
            )
        }
        return nil
    }

    private static func sanitizedIdentifier(_ value: String?) -> String? {
        guard let value, !value.isEmpty,
              value.range(of: "^[A-Za-z0-9_-]{6,128}$", options: .regularExpression) != nil else { return nil }
        return value
    }
}
