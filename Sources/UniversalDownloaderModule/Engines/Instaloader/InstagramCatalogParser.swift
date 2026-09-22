import Foundation

public struct InstagramCatalogParseResult: Sendable {
    public let analysis: DownloadAnalysis
    public let issueCode: String?
    public let sessionSupplied: Bool
    public let sessionValidated: Bool?

    public init(
        analysis: DownloadAnalysis,
        issueCode: String? = nil,
        sessionSupplied: Bool = false,
        sessionValidated: Bool? = nil
    ) {
        self.analysis = analysis
        self.issueCode = issueCode
        self.sessionSupplied = sessionSupplied
        self.sessionValidated = sessionValidated
    }
}

public struct InstagramDirectParseResult: Sendable {
    public let analysis: DownloadAnalysis
    public let issueCode: String?
    public let sessionSupplied: Bool

    public init(analysis: DownloadAnalysis, issueCode: String? = nil, sessionSupplied: Bool = false) {
        self.analysis = analysis
        self.issueCode = issueCode
        self.sessionSupplied = sessionSupplied
    }
}

public struct InstagramCatalogParser: Sendable {
    public init() {}

    public func parse(
        data: Data,
        input: ValidatedDownloadURL
    ) throws -> DownloadAnalysis {
        try parseResult(data: data, input: input).analysis
    }

    public func parseResult(
        data: Data,
        input: ValidatedDownloadURL
    ) throws -> InstagramCatalogParseResult {
        guard let username = input.profileUsername else {
            throw UniversalDownloaderError.invalidInstagramUsername
        }
        let lines = String(decoding: data, as: UTF8.self).split(whereSeparator: \.isNewline)
        var profile: [String: Any] = [:]
        var page: [String: Any] = [:]
        var entries: [DownloadCatalogItem] = []
        var warnings: [String] = []
        var authenticationRestrictedSections = Set<UniversalCatalogSection>()
        var hardError: [String: Any]?

        for line in lines {
            guard let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  let record = object["record"] as? String else { continue }
            switch record {
            case "profile": profile = object
            case "page": page = object
            case "media":
                if let entry = mediaEntry(object, username: username) { entries.append(entry) }
            case "warning":
                if object["code"] as? String == "section_requires_authentication",
                   let sectionName = object["section"] as? String,
                   let section = authenticationRestrictedSection(sectionName) {
                    authenticationRestrictedSections.insert(section)
                } else if let message = object["message"] as? String {
                    warnings.append(message)
                }
            case "error":
                hardError = object
            default: break
            }
        }

        let issueCode = nonEmpty(hardError?["code"] as? String)
        let sessionSupplied = bool(profile["session_supplied"] ?? hardError?["session_supplied"])
        let sessionValidated = optionalBool(profile["session_validated"] ?? hardError?["session_validated"])

        if profile.isEmpty, let hardError {
            let message = nonEmpty(hardError["message"] as? String)
                ?? "Instagram no ha devuelto información utilizable."
            if isNonConclusivePublicLookup(code: issueCode) {
                return InstagramCatalogParseResult(
                    analysis: publicLookupUnavailableAnalysis(
                        input: input,
                        username: username,
                        message: message
                    ),
                    issueCode: issueCode,
                    sessionSupplied: sessionSupplied,
                    sessionValidated: sessionValidated
                )
            }
            throw UniversalDownloaderError.analysisFailed(message)
        }

        let isPrivate = bool(profile["is_private"])
        let requiresAuthentication = bool(profile["requires_authentication"])
        let displayName = nonEmpty(profile["full_name"] as? String) ?? username
        let profilePicture = url(profile["profile_picture_url"])
        let sections = Array(Set(entries.compactMap(\.catalogSection))).sorted { $0.rawValue < $1.rawValue }
        let knownTotal = int(page["known_total"]) ?? int(profile["media_count"])
        let warningText = warnings.isEmpty ? nil : warnings.joined(separator: "\n")

        let analysis = DownloadAnalysis(
            canonicalID: input.canonicalID,
            kind: .profile,
            title: displayName,
            uploader: username,
            channelID: int(profile["userid"]).map(String.init),
            thumbnailURL: profilePicture,
            description: warningText ?? nonEmpty(profile["biography"] as? String),
            availability: requiresAuthentication ? "needs_auth" : (isPrivate ? "private_accessible" : "public"),
            playlistTitle: username,
            playlistCount: knownTotal ?? entries.count,
            playlistEntries: entries,
            sourceURL: input.canonicalURL,
            serviceName: "Instagram",
            extractor: "instaloader-zeuve",
            platform: .instagram,
            mediaKind: .gallery,
            engineKind: .instagramCatalog,
            profileUsername: username,
            isPrivateProfile: isPrivate,
            requiresAuthentication: requiresAuthentication,
            paginationCursor: nonEmpty(page["next_cursor"] as? String),
            hasMoreEntries: bool(page["has_more"]),
            availableSections: sections,
            authenticationRestrictedSections: authenticationRestrictedSections.isEmpty
                ? nil
                : authenticationRestrictedSections.sorted { $0.rawValue < $1.rawValue }
        )
        return InstagramCatalogParseResult(
            analysis: analysis,
            issueCode: issueCode,
            sessionSupplied: sessionSupplied,
            sessionValidated: sessionValidated
        )
    }

    public func parseDirectResult(
        data: Data,
        input: ValidatedDownloadURL
    ) throws -> InstagramDirectParseResult {
        let lines = String(decoding: data, as: UTF8.self).split(whereSeparator: \.isNewline)
        var post: [String: Any] = [:]
        var page: [String: Any] = [:]
        var entries: [DownloadCatalogItem] = []
        var hardError: [String: Any]?

        for line in lines {
            guard let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  let record = object["record"] as? String else { continue }
            switch record {
            case "post": post = object
            case "page": page = object
            case "media":
                let username = nonEmpty(string(object["username"])) ?? nonEmpty(string(post["username"])) ?? "instagram"
                if let entry = mediaEntry(object, username: username) { entries.append(entry) }
            case "error": hardError = object
            default: break
            }
        }

        let issueCode = nonEmpty(hardError?["code"] as? String)
        let sessionSupplied = bool(post["session_supplied"] ?? hardError?["session_supplied"])
        if entries.isEmpty {
            let message = nonEmpty(hardError?["message"] as? String)
                ?? "El motor específico de Instagram no ha devuelto contenido multimedia."
            throw UniversalDownloaderError.analysisFailed(message)
        }

        let username = nonEmpty(string(post["username"])) ?? entries.first?.uploader
        let shortcode = nonEmpty(string(post["shortcode"]))
            ?? InstagramCatalogCommandBuilder.shortcode(from: input.canonicalURL)
            ?? input.canonicalID
        let mediaKind = entries.count == 1 ? (entries[0].mediaKind ?? .unknown) : .gallery
        let analysis = DownloadAnalysis(
            canonicalID: input.canonicalID,
            kind: .gallery,
            title: username.map { "Instagram · @\($0) · \(shortcode)" } ?? "Instagram · \(shortcode)",
            uploader: username,
            thumbnailURL: entries.first?.thumbnailURL,
            playlistTitle: shortcode,
            playlistCount: int(page["known_total"]) ?? entries.count,
            playlistEntries: entries,
            sourceURL: input.canonicalURL,
            serviceName: "Instagram",
            extractor: "instaloader-zeuve",
            platform: .instagram,
            mediaKind: mediaKind,
            engineKind: .instagramCatalog,
            profileUsername: username,
            requiresAuthentication: false,
            availableSections: Array(Set(entries.compactMap(\.catalogSection))).sorted { $0.rawValue < $1.rawValue }
        )
        return InstagramDirectParseResult(
            analysis: analysis,
            issueCode: issueCode,
            sessionSupplied: sessionSupplied
        )
    }

    private func publicLookupUnavailableAnalysis(
        input: ValidatedDownloadURL,
        username: String,
        message: String
    ) -> DownloadAnalysis {
        DownloadAnalysis(
            canonicalID: input.canonicalID,
            kind: .profile,
            title: "@\(username)",
            uploader: username,
            description: message,
            availability: "unavailable",
            playlistTitle: username,
            playlistCount: 0,
            playlistEntries: [],
            sourceURL: input.canonicalURL,
            serviceName: "Instagram",
            extractor: "instaloader-zeuve",
            platform: .instagram,
            mediaKind: .gallery,
            engineKind: .instagramCatalog,
            profileUsername: username,
            isPrivateProfile: false,
            requiresAuthentication: false
        )
    }

    private func isNonConclusivePublicLookup(code: String?) -> Bool {
        switch code {
        case "profile_unavailable", // Compatibility with the 0.10.1 helper.
             "profile_lookup_ambiguous",
             "public_lookup_blocked",
             "authentication_required", // Legacy 0.10.2 helper output.
             "session_not_validated",
             "session_load_failed",
             "request_blocked",
             "profile_lookup_failed":
            return true
        default:
            return false
        }
    }

    private func authenticationRestrictedSection(_ raw: String) -> UniversalCatalogSection? {
        switch raw {
        case "stories": return .stories
        case "highlights": return .highlights
        default: return nil
        }
    }

    private func mediaEntry(_ object: [String: Any], username: String) -> DownloadCatalogItem? {
        guard let mediaURL = url(object["media_url"]),
              let rawKind = object["kind"] as? String else { return nil }
        let kind = UniversalMediaKind(rawValue: rawKind) ?? .unknown
        let id = string(object["id"]) ?? "media-\(stableIdentifier(mediaURL.absoluteString))"
        let index = int(object["index"])
        let section = sectionFor(record: object, kind: kind)
        let date = parseDate(object["date"])
        let dateText = date.map(Self.filenameDate)
        let title = [username, dateText, id, index.map { String(format: "%02d", $0) }]
            .compactMap { $0 }
            .joined(separator: " - ")
        let extensionName = normalizedExtension(object["extension"] as? String, url: mediaURL)
        let highlightTitle = nonEmpty(object["highlight_title"] as? String)
        var folders = ["Instagram", username]
        switch section {
        case .photos: folders.append("Publicaciones")
        case .videos: folders.append("Publicaciones")
        case .reels: folders.append("Reels")
        case .stories: folders.append("Stories")
        case .highlights:
            folders.append("Destacadas")
            if let highlightTitle { folders.append(highlightTitle) }
        case .profile: folders.append("Perfil")
        case .all: folders.append("Contenido")
        }
        let resolved = ResolvedMediaReference(
            mediaURL: mediaURL,
            kind: extensionName == "m3u8" ? .hls : (extensionName == "mpd" ? .dash : .directFile),
            protocolName: mediaURL.scheme,
            extensionName: extensionName,
            expiresAt: parseDate(object["expires_at"]) ?? expirationDate(in: mediaURL),
            resolvedAt: Date(),
            httpHeaders: ["Referer": "https://www.instagram.com/"]
        )
        var safeMetadata: [String: String] = [
            "username": username,
            "id": id,
            "kind": kind.rawValue,
            "source_page": string(object["source_page"]) ?? "https://www.instagram.com/\(username)/",
        ]
        for key in ["shortcode", "caption", "alt_text", "date", "highlight_title"] {
            if let value = nonEmpty(string(object[key])), value.count <= 8_000 { safeMetadata[key] = value }
        }
        return DownloadCatalogItem(
            canonicalID: "instagram:\(id)",
            playlistIndex: index,
            title: title.isEmpty ? "Instagram - \(id)" : title,
            duration: double(object["duration"]),
            uploader: username,
            availability: "public",
            isAvailable: true,
            sourceURL: mediaURL,
            serviceName: "Instagram",
            extractor: "instaloader-zeuve",
            resolvedMedia: resolved,
            platform: .instagram,
            mediaKind: kind,
            thumbnailURL: url(object["thumbnail_url"]) ?? (kind.mediaClass == .image ? mediaURL : nil),
            engineKind: .genericPage,
            catalogSection: section,
            folderComponents: folders,
            expectedExtension: extensionName,
            safeMetadata: safeMetadata
        )
    }

    private func sectionFor(record: [String: Any], kind: UniversalMediaKind) -> UniversalCatalogSection {
        switch record["section"] as? String {
        case "posts": return kind.mediaClass == .image ? .photos : .videos
        case "reels": return .reels
        case "stories": return .stories
        case "highlights": return .highlights
        case "profile": return .profile
        default:
            switch kind {
            case .photo: return .photos
            case .video, .audio, .webpageMedia: return .videos
            case .reel: return .reels
            case .storyPhoto, .storyVideo: return .stories
            case .highlightPhoto, .highlightVideo: return .highlights
            case .profilePicture: return .profile
            case .gallery, .unknown: return .all
            }
        }
    }

    private func string(_ value: Any?) -> String? {
        if let value = value as? String { return value }
        if let value = value as? NSNumber { return value.stringValue }
        return nil
    }
    private func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    private func int(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }
    private func double(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value) }
        return nil
    }
    private func bool(_ value: Any?) -> Bool {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        if let value = value as? String { return ["true", "1", "yes"].contains(value.lowercased()) }
        return false
    }
    private func optionalBool(_ value: Any?) -> Bool? {
        if value == nil || value is NSNull { return nil }
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        if let value = value as? String {
            let normalized = value.lowercased()
            if ["true", "1", "yes"].contains(normalized) { return true }
            if ["false", "0", "no"].contains(normalized) { return false }
        }
        return nil
    }
    private func url(_ value: Any?) -> URL? { nonEmpty(string(value)).flatMap(URL.init(string:)) }

    private func parseDate(_ value: Any?) -> Date? {
        if let value = value as? NSNumber { return Date(timeIntervalSince1970: value.doubleValue) }
        guard let raw = nonEmpty(string(value)) else { return nil }
        if let seconds = TimeInterval(raw) { return Date(timeIntervalSince1970: seconds) }
        return ISO8601DateFormatter().date(from: raw)
    }

    private func normalizedExtension(_ value: String?, url: URL) -> String? {
        let raw = (nonEmpty(value) ?? url.pathExtension).lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return raw.range(of: "^[a-z0-9]{1,8}$", options: .regularExpression) == nil ? nil : raw
    }

    private static func filenameDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func stableIdentifier(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 { hash ^= UInt64(byte); hash &*= 1_099_511_628_211 }
        return String(hash, radix: 16)
    }

    private func expirationDate(in url: URL) -> Date? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        for item in components.queryItems ?? [] where ["expire", "expires", "exp"].contains(item.name.lowercased()) {
            if let raw = item.value, let seconds = TimeInterval(raw) { return Date(timeIntervalSince1970: seconds) }
        }
        return nil
    }
}
