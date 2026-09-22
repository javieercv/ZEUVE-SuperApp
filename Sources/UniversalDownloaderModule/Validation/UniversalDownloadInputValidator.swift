import Foundation

public struct DownloadURLValidationResult: Sendable, Equatable {
    public let accepted: [ValidatedDownloadURL]
    public let duplicates: [String]
    public let rejected: [String: String]

    public init(accepted: [ValidatedDownloadURL], duplicates: [String], rejected: [String: String]) {
        self.accepted = accepted
        self.duplicates = duplicates
        self.rejected = rejected
    }
}

public struct UniversalDownloadInputValidator: Sendable {
    public init() {}

    public func validate(
        text: String,
        allowInsecureLocalNetwork: Bool = false,
        platform: UniversalDownloadPlatform = .automatic,
        allowAdultContent: Bool = false,
        additionalAdultDomains: [String] = []
    ) -> DownloadURLValidationResult {
        let candidates = candidates(from: text, platform: platform)
        var accepted: [ValidatedDownloadURL] = []
        var seen = Set<String>()
        var duplicates: [String] = []
        var rejected: [String: String] = [:]
        for candidate in candidates {
            do {
                let value = try validate(
                    candidate,
                    allowInsecureLocalNetwork: allowInsecureLocalNetwork,
                    platform: platform,
                    allowAdultContent: allowAdultContent,
                    additionalAdultDomains: additionalAdultDomains
                )
                let duplicateKey = "\(value.platform.rawValue):\(value.canonicalID)"
                if seen.insert(duplicateKey).inserted {
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

    public func validate(
        _ raw: String,
        allowInsecureLocalNetwork: Bool = false,
        platform requestedPlatform: UniversalDownloadPlatform = .automatic,
        allowAdultContent: Bool = false,
        additionalAdultDomains: [String] = []
    ) throws -> ValidatedDownloadURL {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw UniversalDownloaderError.emptyInput }

        if requestedPlatform == .instagram, Self.looksLikeInstagramUsername(trimmed) {
            guard let username = Self.normalizedInstagramUsername(trimmed) else {
                throw UniversalDownloaderError.invalidInstagramUsername
            }
            let url = URL(string: "https://www.instagram.com/\(username)/")!
            return .init(
                original: url,
                canonicalURL: url,
                canonicalID: "instagram-profile:\(username.lowercased())",
                kind: .profile,
                host: "www.instagram.com",
                allowInsecureLocalNetwork: false,
                platform: .instagram,
                profileUsername: username,
                isAdultContent: false
            )
        }

        guard let inputURL = Self.normalizedInputURL(trimmed),
              let components = URLComponents(url: inputURL, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(),
              !host.isEmpty else {
            throw UniversalDownloaderError.malformedURL(trimmed)
        }
        guard scheme == "https" || scheme == "http" else {
            throw UniversalDownloaderError.unsupportedScheme(scheme)
        }

        let local = Self.isLocalHost(host)
        if scheme == "http" && !allowInsecureLocalNetwork {
            throw UniversalDownloaderError.unsupportedScheme(scheme)
        }
        if local && !allowInsecureLocalNetwork {
            throw UniversalDownloaderError.unsupportedHost(host)
        }

        let detectedPlatform = UniversalDownloadPlatform.detect(from: inputURL)
        let effectivePlatform: UniversalDownloadPlatform = requestedPlatform == .automatic ? detectedPlatform : requestedPlatform
        // «Página web» permite usar el flujo genérico, pero no debe borrar la semántica
        // de una plataforma reconocida. Instagram necesita conservar perfil/publicación/story
        // para escoger el motor correcto y mostrar la autenticación adecuada.
        let contentPlatform: UniversalDownloadPlatform = effectivePlatform == .webpage ? detectedPlatform : effectivePlatform
        if requestedPlatform != .automatic,
           requestedPlatform != .webpage,
           detectedPlatform != .webpage,
           detectedPlatform != requestedPlatform {
            throw UniversalDownloaderError.platformMismatch(
                expected: requestedPlatform.spanishName,
                detected: detectedPlatform.spanishName
            )
        }

        let adultPolicy = AdultContentPolicy()
        let adult = adultPolicy.isAdult(url: inputURL, platform: contentPlatform, additionalDomains: additionalAdultDomains)
        if adult && !allowAdultContent {
            throw UniversalDownloaderError.adultContentDisabled(
                adultPolicy.matchedDomain(url: inputURL, platform: contentPlatform, additionalDomains: additionalAdultDomains)
                    ?? contentPlatform.spanishName
            )
        }

        if Self.isLiveURL(components: components, platform: contentPlatform) {
            throw UniversalDownloaderError.liveContentUnsupported
        }

        if effectivePlatform.requiresConcreteURL,
           Self.looksLikeProfileOrHomeURL(components: components, platform: contentPlatform) {
            throw UniversalDownloaderError.platformRequiresConcreteURL(effectivePlatform.spanishName)
        }

        if contentPlatform == .instagram,
           let profile = Self.instagramProfile(components: components),
           !Self.isInstagramDirectContentPath(components.path) {
            let url = URL(string: "https://www.instagram.com/\(profile)/")!
            return .init(
                original: inputURL,
                canonicalURL: url,
                canonicalID: "instagram-profile:\(profile.lowercased())",
                kind: .profile,
                host: host,
                allowInsecureLocalNetwork: allowInsecureLocalNetwork,
                platform: .instagram,
                profileUsername: profile,
                isAdultContent: adult
            )
        }

        let specialized = YouTubeURLCanonicalizer.canonicalize(components: components, host: host)
        let canonical = specialized?.url ?? UniversalURLNormalizer.canonicalURL(inputURL)
        let kind = specialized?.kind ?? Self.inferredKind(components: components, platform: contentPlatform)
        let playlistID = specialized?.playlistID ?? Self.playlistIdentifier(components: components)
        let id = specialized?.identifier
            ?? Self.platformSpecificIdentifier(components: components, platform: contentPlatform)
            ?? UniversalURLNormalizer.stableIdentifier(for: UniversalURLNormalizer.duplicateKey(for: canonical))
        return .init(
            original: inputURL,
            canonicalURL: canonical,
            canonicalID: id,
            kind: kind,
            playlistID: playlistID,
            host: host,
            allowInsecureLocalNetwork: allowInsecureLocalNetwork,
            platform: contentPlatform,
            profileUsername: nil,
            isAdultContent: adult
        )
    }

    private func candidates(from text: String, platform: UniversalDownloadPlatform) -> [String] {
        if platform == .instagram {
            return text
                .split(whereSeparator: { $0.isNewline || $0 == "," || $0 == ";" })
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        return text
            .split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == ";" })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private static func normalizedInputURL(_ raw: String) -> URL? {
        if let url = URL(string: raw), url.scheme != nil { return url }
        if raw.contains(".") { return URL(string: "https://\(raw)") }
        return nil
    }

    private static func looksLikeInstagramUsername(_ value: String) -> Bool {
        let stripped = value.hasPrefix("@") ? String(value.dropFirst()) : value
        return !value.contains("://") && !value.contains("/") && normalizedInstagramUsername(stripped) != nil
    }

    private static func normalizedInstagramUsername(_ value: String) -> String? {
        var username = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if username.hasPrefix("@") { username.removeFirst() }
        guard username.count <= 30,
              username.range(of: "^[A-Za-z0-9._]+$", options: .regularExpression) != nil,
              !username.hasPrefix("."), !username.hasSuffix("."), !username.contains("..") else { return nil }
        return username
    }

    private static func instagramProfile(components: URLComponents) -> String? {
        let excluded: Set<String> = ["p", "reel", "reels", "stories", "explore", "accounts", "direct", "about", "developer", "web"]
        let parts = components.path.split(separator: "/").map(String.init)
        guard let first = parts.first, !excluded.contains(first.lowercased()), parts.count <= 2 else { return nil }
        return normalizedInstagramUsername(first)
    }

    private static func isInstagramDirectContentPath(_ path: String) -> Bool {
        let lower = path.lowercased()
        return lower.hasPrefix("/p/") || lower.hasPrefix("/reel/") || lower.hasPrefix("/reels/") || lower.hasPrefix("/stories/")
    }

    private static func isLiveURL(components: URLComponents, platform: UniversalDownloadPlatform) -> Bool {
        let path = components.path.lowercased()
        switch platform {
        case .youtube:
            return path.hasPrefix("/live/") && !(components.queryItems ?? []).contains { $0.name == "v" }
        case .twitch:
            return !path.contains("/videos/") && !path.contains("/clip/") && !path.contains("/clips/")
        default:
            return path.contains("/live/") || path.hasSuffix("/live")
        }
    }

    private static func looksLikeProfileOrHomeURL(components: URLComponents, platform: UniversalDownloadPlatform) -> Bool {
        let parts = components.path.split(separator: "/").map(String.init)
        switch platform {
        case .tiktok:
            return parts.count == 1 && parts[0].hasPrefix("@")
        case .pinterest:
            return parts.count <= 1 || (parts.count == 2 && parts[1].isEmpty)
        case .x:
            return parts.count == 1 && !parts[0].lowercased().contains("status")
        case .facebook:
            return !components.path.lowercased().contains("/watch")
                && !components.path.lowercased().contains("/videos/")
                && !components.path.lowercased().contains("/reel/")
                && !components.path.lowercased().contains("/posts/")
        case .reddit:
            return !components.path.lowercased().contains("/comments/") && !components.path.lowercased().contains("/gallery/")
        case .twitch:
            return !components.path.lowercased().contains("/videos/") && !components.path.lowercased().contains("/clip")
        case .vimeo:
            return parts.first.map { Int($0) } == nil
        case .dailymotion:
            return !components.path.lowercased().contains("/video/")
        case .soundcloud:
            return parts.count < 2
        case .tumblr:
            return !components.path.lowercased().contains("/post/")
        case .threads:
            return !components.path.lowercased().contains("/post/")
        case .snapchat:
            return !components.path.lowercased().contains("/spotlight/") && !components.path.lowercased().contains("/story/")
        case .erome:
            let lower = components.path.lowercased()
            return lower.hasPrefix("/u/") || lower == "/" || lower.isEmpty
        default:
            return false
        }
    }

    private static func platformSpecificIdentifier(components: URLComponents, platform: UniversalDownloadPlatform) -> String? {
        let parts = components.path.split(separator: "/").map(String.init)
        let candidate: String?
        switch platform {
        case .instagram:
            candidate = parts.dropFirst().first ?? parts.last
        case .tiktok:
            candidate = parts.last
        case .pinterest:
            candidate = parts.last
        case .x:
            candidate = parts.last
        case .facebook, .reddit, .vimeo, .dailymotion, .tumblr, .threads, .snapchat, .erome:
            candidate = parts.last
        case .youtube, .twitch, .soundcloud, .webpage, .automatic:
            candidate = nil
        }
        guard let candidate, !candidate.isEmpty else { return nil }
        return "\(platform.rawValue):\(candidate)"
    }

    private static func inferredKind(components: URLComponents, platform: UniversalDownloadPlatform) -> DownloadContentKind {
        let path = components.path.lowercased()
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name.lowercased(), $0.value ?? "") })
        if platform == .instagram && isInstagramDirectContentPath(path) { return .gallery }
        if platform == .tiktok && path.contains("/video/") { return .video }
        if platform == .tiktok && path.contains("/photo/") { return .gallery }
        if platform == .erome || platform == .pinterest { return .gallery }
        if platform == .youtube && (path == "/watch" || path.contains("/shorts/") || path.contains("/embed/")) { return .video }
        if path == "/playlist" || query["list"] != nil { return .playlist }
        let mediaExtensions = [".mp4", ".webm", ".mov", ".m4v", ".mkv", ".avi", ".mpeg", ".mpg", ".m3u8", ".mpd", ".jpg", ".jpeg", ".png", ".webp", ".gif", ".mp3", ".m4a", ".flac", ".wav", ".opus"]
        if mediaExtensions.contains(where: { path.hasSuffix($0) }) { return .video }
        return .webpage
    }

    private static func playlistIdentifier(components: URLComponents) -> String? {
        components.queryItems?.first(where: { $0.name.lowercased() == "list" })?.value
    }

    private static func isLocalHost(_ host: String) -> Bool {
        if host == "localhost" || host.hasSuffix(".local") { return true }
        if host == "::1" { return true }
        if host.contains(":") {
            let lower = host.lowercased()
            if lower.hasPrefix("fe8") || lower.hasPrefix("fe9") || lower.hasPrefix("fea") || lower.hasPrefix("feb") { return true }
            if lower.hasPrefix("fc") || lower.hasPrefix("fd") { return true }
        }
        let parts = host.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4 else { return false }
        if parts[0] == 10 || parts[0] == 127 { return true }
        if parts[0] == 169 && parts[1] == 254 { return true }
        if parts[0] == 172 && (16...31).contains(parts[1]) { return true }
        if parts[0] == 192 && parts[1] == 168 { return true }
        return false
    }
}
