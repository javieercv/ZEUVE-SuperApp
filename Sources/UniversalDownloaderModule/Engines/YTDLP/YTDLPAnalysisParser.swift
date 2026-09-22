import Foundation

public struct YTDLPAnalysisParser: Sendable {
    public init() {}

    public func parse(data: Data, fallbackURL: URL? = nil) throws -> DownloadAnalysis {
        let raw = try JSONDecoder().decode(RawInfo.self, from: data)
        return convert(raw, fallbackURL: fallbackURL)
    }

    public func parsePlaylistEntry(data: Data, fallbackURL: URL? = nil) throws -> DownloadCatalogItem {
        let raw = try JSONDecoder().decode(RawInfo.self, from: data)
        guard let id = stableID(raw, fallbackURL: fallbackURL) else {
            throw UniversalDownloaderError.analysisFailed("Falta el identificador del elemento.")
        }
        guard let sourceURL = sourceURL(raw, fallbackURL: fallbackURL) else {
            throw UniversalDownloaderError.analysisFailed("Falta la URL descargable del elemento.")
        }
        return DownloadCatalogItem(
            canonicalID: id,
            playlistIndex: raw.playlistIndex,
            title: raw.title ?? "Elemento sin título",
            duration: raw.duration,
            uploader: raw.uploader ?? raw.channel,
            availability: raw.availability,
            isAvailable: isAvailable(raw.availability),
            sourceURL: sourceURL,
            serviceName: serviceName(raw, sourceURL: sourceURL),
            extractor: raw.extractorKey ?? raw.extractor,
            resolvedMedia: resolvedMediaReference(raw, fallbackURL: fallbackURL)
        )
    }

    private func convert(_ raw: RawInfo, fallbackURL: URL?) -> DownloadAnalysis {
        let entries = (raw.entries ?? []).compactMap { entry -> DownloadCatalogItem? in
            guard let id = stableID(entry, fallbackURL: fallbackURL),
                  let url = sourceURL(entry, fallbackURL: fallbackURL) else { return nil }
            return DownloadCatalogItem(
                canonicalID: id,
                playlistIndex: entry.playlistIndex,
                title: entry.title ?? "Elemento sin título",
                duration: entry.duration,
                uploader: entry.uploader ?? entry.channel,
                availability: entry.availability,
                isAvailable: isAvailable(entry.availability),
                sourceURL: url,
                serviceName: serviceName(entry, sourceURL: url),
                extractor: entry.extractorKey ?? entry.extractor,
                resolvedMedia: resolvedMediaReference(entry, fallbackURL: fallbackURL)
            )
        }
        let kind: DownloadContentKind = raw.type == "playlist" || raw.type == "multi_video" || !entries.isEmpty ? .playlist : .video
        let formats = (raw.formats ?? []).compactMap(convertFormat)
        var subtitles: [YTDLPSubtitleTrack] = []
        subtitles += convertSubtitles(raw.subtitles, kind: .manual)
        subtitles += convertSubtitles(raw.automaticCaptions, kind: .automatic)
        let resolvedURL = sourceURL(raw, fallbackURL: fallbackURL)
        let id = stableID(raw, fallbackURL: fallbackURL) ?? UniversalURLNormalizer.stableIdentifier(for: resolvedURL?.absoluteString ?? UUID().uuidString)
        return DownloadAnalysis(
            canonicalID: id,
            kind: kind,
            title: raw.title ?? raw.playlistTitle ?? "Contenido sin título",
            uploader: raw.uploader ?? raw.channel,
            channelID: raw.channelID,
            duration: raw.duration,
            publicationDate: publicationDate(raw),
            thumbnailURL: raw.thumbnail.flatMap(URL.init(string:)),
            description: raw.description,
            formats: formats,
            subtitles: subtitles.sorted { $0.languageCode < $1.languageCode },
            chaptersCount: raw.chapters?.count ?? 0,
            liveStatus: liveStatus(raw.liveStatus, isLive: raw.isLive, wasLive: raw.wasLive),
            ageLimit: raw.ageLimit,
            availability: raw.availability,
            playlistTitle: raw.playlistTitle ?? (kind == .playlist ? raw.title : nil),
            playlistCount: raw.playlistCount ?? raw.entries?.count,
            playlistEntries: entries,
            sourceURL: resolvedURL,
            serviceName: serviceName(raw, sourceURL: resolvedURL),
            extractor: raw.extractorKey ?? raw.extractor,
            resolvedMedia: resolvedMediaReference(raw, fallbackURL: fallbackURL)
        )
    }

    private func resolvedMediaReference(_ raw: RawInfo, fallbackURL: URL?) -> ResolvedMediaReference? {
        let requested = raw.requestedFormats ?? []
        let formats = raw.formats ?? []

        if let commonManifest = commonManifestURL(in: requested.isEmpty ? formats : requested, fallbackURL: fallbackURL) {
            let format = (requested.isEmpty ? formats : requested).first { candidateURL($0.manifestURL, fallbackURL: fallbackURL) == commonManifest }
            return makeResolvedReference(
                url: commonManifest,
                protocolName: format?.protocolName ?? raw.protocolName,
                extensionName: format?.extensionName ?? raw.extensionName,
                headers: mergedHeaders(raw.httpHeaders, format?.httpHeaders),
                explicitExpiration: raw.urlExpiration
            )
        }

        if let manifest = candidateURL(raw.manifestURL, fallbackURL: fallbackURL) {
            return makeResolvedReference(
                url: manifest,
                protocolName: raw.protocolName,
                extensionName: raw.extensionName,
                headers: raw.httpHeaders ?? [:],
                explicitExpiration: raw.urlExpiration
            )
        }

        if let url = candidateURL(raw.url, fallbackURL: fallbackURL),
           looksLikeResolvedMediaURL(url, protocolName: raw.protocolName, extensionName: raw.extensionName, hasFormats: raw.formats != nil) {
            return makeResolvedReference(
                url: url,
                protocolName: raw.protocolName,
                extensionName: raw.extensionName,
                headers: raw.httpHeaders ?? [:],
                explicitExpiration: raw.urlExpiration
            )
        }

        let rankedFormats = (requested.isEmpty ? formats : requested).sorted { lhs, rhs in
            let lhsProgressive = (lhs.videoCodec != nil && lhs.videoCodec != "none") && (lhs.audioCodec != nil && lhs.audioCodec != "none")
            let rhsProgressive = (rhs.videoCodec != nil && rhs.videoCodec != "none") && (rhs.audioCodec != nil && rhs.audioCodec != "none")
            if lhsProgressive != rhsProgressive { return lhsProgressive }
            return (lhs.height ?? 0, lhs.totalBitrate ?? 0) > (rhs.height ?? 0, rhs.totalBitrate ?? 0)
        }
        for format in rankedFormats {
            guard let url = candidateURL(format.url, fallbackURL: fallbackURL) else { continue }
            return makeResolvedReference(
                url: url,
                protocolName: format.protocolName,
                extensionName: format.extensionName,
                headers: mergedHeaders(raw.httpHeaders, format.httpHeaders),
                explicitExpiration: raw.urlExpiration
            )
        }
        return nil
    }

    private func commonManifestURL(in formats: [RawFormat], fallbackURL: URL?) -> URL? {
        let values = formats.compactMap { candidateURL($0.manifestURL, fallbackURL: fallbackURL) }
        guard let first = values.first, values.allSatisfy({ $0 == first }) else { return nil }
        return first
    }

    private func candidateURL(_ value: String?, fallbackURL: URL?) -> URL? {
        guard let value, !value.isEmpty else { return nil }
        if let url = URL(string: value), url.scheme != nil { return url }
        guard let fallbackURL else { return nil }
        return URL(string: value, relativeTo: fallbackURL)?.absoluteURL
    }

    private func looksLikeResolvedMediaURL(_ url: URL, protocolName: String?, extensionName: String?, hasFormats: Bool) -> Bool {
        let protocolValue = protocolName?.lowercased() ?? ""
        if ["m3u8", "m3u8_native", "http_dash_segments", "dash", "ism", "f4m"].contains(protocolValue) { return true }
        let ext = (extensionName ?? url.pathExtension).lowercased()
        if ["mp4", "webm", "mov", "m4v", "mkv", "avi", "mpeg", "mpg", "m3u8", "mpd", "ts", "m4a", "aac", "mp3", "opus"].contains(ext) { return true }
        return hasFormats && ["http", "https"].contains(protocolValue)
    }

    private func makeResolvedReference(
        url: URL,
        protocolName: String?,
        extensionName: String?,
        headers: [String: String],
        explicitExpiration: Double?
    ) -> ResolvedMediaReference {
        let kind = resolvedKind(url: url, protocolName: protocolName)
        return ResolvedMediaReference(
            mediaURL: url,
            kind: kind,
            protocolName: protocolName,
            extensionName: extensionName,
            expiresAt: expirationDate(url: url, explicit: explicitExpiration),
            httpHeaders: sanitizedInMemoryHeaders(headers)
        )
    }

    private func resolvedKind(url: URL, protocolName: String?) -> ResolvedMediaKind {
        let value = protocolName?.lowercased() ?? ""
        let path = url.path.lowercased()
        if value.contains("m3u8") || path.hasSuffix(".m3u8") { return .hls }
        if value.contains("dash") || value.contains("http_dash_segments") || path.hasSuffix(".mpd") { return .dash }
        if ["http", "https"].contains(value) || !url.pathExtension.isEmpty { return .directFile }
        return .unknown
    }

    private func expirationDate(url: URL, explicit: Double?) -> Date? {
        if let explicit, explicit > 0 { return Date(timeIntervalSince1970: explicit) }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        for name in ["expire", "expires", "exp", "e"] {
            guard let value = components.queryItems?.first(where: { $0.name.lowercased() == name })?.value,
                  let seconds = Double(value), seconds > 1_000_000_000 else { continue }
            return Date(timeIntervalSince1970: seconds)
        }
        return nil
    }

    private func mergedHeaders(_ first: [String: String]?, _ second: [String: String]?) -> [String: String] {
        var result = first ?? [:]
        for (name, value) in second ?? [:] { result[name] = value }
        return result
    }

    private func sanitizedInMemoryHeaders(_ headers: [String: String]) -> [String: String] {
        var result: [String: String] = [:]
        for (name, value) in headers.prefix(32) {
            guard name.range(of: "^[A-Za-z0-9-]{1,64}$", options: .regularExpression) != nil,
                  value.utf8.count <= 8_192,
                  !value.contains("\r"), !value.contains("\n") else { continue }
            if name.caseInsensitiveCompare("Cookie") == .orderedSame || name.caseInsensitiveCompare("Proxy-Authorization") == .orderedSame { continue }
            result[name] = value
        }
        return result
    }

    private func sourceURL(_ raw: RawInfo, fallbackURL: URL?) -> URL? {
        for value in [raw.webpageURL, raw.originalURL, raw.url] {
            guard let value, !value.isEmpty else { continue }
            if let url = URL(string: value), url.scheme != nil { return url }
            if let fallbackURL,
               value.hasPrefix("/") || value.hasPrefix("./") || value.hasPrefix("../"),
               let relativeURL = URL(string: value, relativeTo: fallbackURL)?.absoluteURL {
                return relativeURL
            }
        }
        if let id = raw.id, !id.isEmpty,
           (fallbackURL == nil || Self.isYouTube(raw: raw, fallbackURL: fallbackURL)) {
            return URL(string: "https://www.youtube.com/watch?v=\(id)")
        }
        return fallbackURL
    }

    private static func isYouTube(raw: RawInfo, fallbackURL: URL?) -> Bool {
        let namespace = [raw.extractorKey, raw.extractor, raw.ieKey]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
        if namespace.contains("youtube") { return true }
        let host = fallbackURL?.host?.lowercased() ?? ""
        return host == "youtu.be" || host == "youtube.com" || host.hasSuffix(".youtube.com")
    }

    private func stableID(_ raw: RawInfo, fallbackURL: URL?) -> String? {
        if let id = raw.id, !id.isEmpty {
            if let namespace = raw.extractorKey ?? raw.extractor ?? raw.ieKey, !namespace.isEmpty {
                return "\(namespace.lowercased()):\(id)"
            }
            return id
        }
        if let url = sourceURL(raw, fallbackURL: fallbackURL) {
            return UniversalURLNormalizer.stableIdentifier(for: UniversalURLNormalizer.duplicateKey(for: url))
        }
        return nil
    }

    private func serviceName(_ raw: RawInfo, sourceURL: URL?) -> String? {
        raw.extractorKey ?? raw.extractor ?? sourceURL?.host
    }

    private func isAvailable(_ availability: String?) -> Bool {
        availability != "private" && availability != "needs_auth" && availability != "unavailable"
    }

    private func convertFormat(_ raw: RawFormat) -> YTDLPFormat? {
        guard let id = raw.formatID else { return nil }
        let rangeText = [raw.dynamicRange, raw.formatNote].compactMap { $0 }.joined(separator: " ").lowercased()
        let range: YTDLPDynamicRange
        if rangeText.contains("hdr") || rangeText.contains("hlg") || rangeText.contains("pq") { range = .hdr }
        else if !rangeText.isEmpty { range = .sdr }
        else { range = .unknown }
        return YTDLPFormat(
            formatID: id,
            extensionName: raw.extensionName,
            protocolName: raw.protocolName,
            width: raw.width,
            height: raw.height,
            fps: raw.fps,
            videoCodec: raw.videoCodec,
            audioCodec: raw.audioCodec,
            videoBitrateKbps: raw.videoBitrate,
            audioBitrateKbps: raw.audioBitrate,
            totalBitrateKbps: raw.totalBitrate,
            fileSize: raw.fileSize,
            approximateFileSize: raw.approximateFileSize,
            language: raw.language,
            dynamicRange: range,
            formatNote: raw.formatNote
        )
    }

    private func convertSubtitles(_ source: [String: [RawSubtitle]]?, kind: YTDLPSubtitleKind) -> [YTDLPSubtitleTrack] {
        guard let source else { return [] }
        return source.map { language, tracks in
            YTDLPSubtitleTrack(
                languageCode: language,
                name: tracks.compactMap(\.name).first,
                kind: kind,
                extensions: Array(Set(tracks.compactMap(\.extensionName))).sorted()
            )
        }
    }

    private func liveStatus(_ raw: String?, isLive: Bool?, wasLive: Bool?) -> DownloadLiveStatus {
        switch raw {
        case "is_upcoming": return .upcoming
        case "is_live": return .live
        case "was_live": return .wasLive
        case "post_live": return .postLive
        case "not_live": return .notLive
        default:
            if isLive == true { return .live }
            if wasLive == true { return .wasLive }
            return raw == nil ? .notLive : .unknown
        }
    }

    private func publicationDate(_ raw: RawInfo) -> Date? {
        if let timestamp = raw.timestamp { return Date(timeIntervalSince1970: timestamp) }
        guard let value = raw.uploadDate, value.count == 8 else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: value)
    }
}

private struct RawInfo: Decodable {
    let id: String?
    let type: String?
    let title: String?
    let uploader: String?
    let channel: String?
    let channelID: String?
    let duration: Double?
    let timestamp: Double?
    let uploadDate: String?
    let thumbnail: String?
    let description: String?
    let formats: [RawFormat]?
    let subtitles: [String: [RawSubtitle]]?
    let automaticCaptions: [String: [RawSubtitle]]?
    let chapters: [RawChapter]?
    let liveStatus: String?
    let isLive: Bool?
    let wasLive: Bool?
    let ageLimit: Int?
    let availability: String?
    let playlistID: String?
    let playlistTitle: String?
    let playlistCount: Int?
    let playlistIndex: Int?
    let entries: [RawInfo]?
    let webpageURL: String?
    let originalURL: String?
    let url: String?
    let manifestURL: String?
    let protocolName: String?
    let extensionName: String?
    let httpHeaders: [String: String]?
    let urlExpiration: Double?
    let requestedFormats: [RawFormat]?
    let extractor: String?
    let extractorKey: String?
    let ieKey: String?

    enum CodingKeys: String, CodingKey {
        case id, title, uploader, channel, duration, timestamp, thumbnail, description, formats, subtitles, chapters, entries, availability, url, extractor
        case type = "_type"
        case channelID = "channel_id"
        case uploadDate = "upload_date"
        case automaticCaptions = "automatic_captions"
        case liveStatus = "live_status"
        case isLive = "is_live"
        case wasLive = "was_live"
        case ageLimit = "age_limit"
        case playlistID = "playlist_id"
        case playlistTitle = "playlist_title"
        case playlistCount = "playlist_count"
        case playlistIndex = "playlist_index"
        case webpageURL = "webpage_url"
        case originalURL = "original_url"
        case manifestURL = "manifest_url"
        case protocolName = "protocol"
        case extensionName = "ext"
        case httpHeaders = "http_headers"
        case urlExpiration = "url_expiration"
        case requestedFormats = "requested_formats"
        case extractorKey = "extractor_key"
        case ieKey = "ie_key"
    }
}

private struct RawFormat: Decodable {
    let formatID: String?
    let extensionName: String?
    let protocolName: String?
    let url: String?
    let manifestURL: String?
    let httpHeaders: [String: String]?
    let width: Int?
    let height: Int?
    let fps: Double?
    let videoCodec: String?
    let audioCodec: String?
    let videoBitrate: Double?
    let audioBitrate: Double?
    let totalBitrate: Double?
    let fileSize: Int64?
    let approximateFileSize: Int64?
    let language: String?
    let dynamicRange: String?
    let formatNote: String?

    enum CodingKeys: String, CodingKey {
        case width, height, fps, language, url
        case formatID = "format_id"
        case extensionName = "ext"
        case protocolName = "protocol"
        case manifestURL = "manifest_url"
        case httpHeaders = "http_headers"
        case videoCodec = "vcodec"
        case audioCodec = "acodec"
        case videoBitrate = "vbr"
        case audioBitrate = "abr"
        case totalBitrate = "tbr"
        case fileSize = "filesize"
        case approximateFileSize = "filesize_approx"
        case dynamicRange = "dynamic_range"
        case formatNote = "format_note"
    }
}

private struct RawSubtitle: Decodable {
    let extensionName: String?
    let name: String?
    enum CodingKeys: String, CodingKey { case extensionName = "ext"; case name }
}
private struct RawChapter: Decodable { let title: String? }
