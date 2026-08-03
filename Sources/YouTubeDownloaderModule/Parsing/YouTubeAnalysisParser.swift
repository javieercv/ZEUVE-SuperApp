import Foundation

public struct YouTubeAnalysisParser: Sendable {
    public init() {}

    public func parse(data: Data) throws -> YouTubeMediaAnalysis {
        let raw = try JSONDecoder().decode(RawInfo.self, from: data)
        return convert(raw)
    }

    public func parsePlaylistEntry(data: Data) throws -> YouTubePlaylistEntry {
        let raw = try JSONDecoder().decode(RawInfo.self, from: data)
        guard let id = raw.id, !id.isEmpty else { throw YouTubeDownloaderError.analysisFailed("Falta el identificador del elemento.") }
        return YouTubePlaylistEntry(
            videoID: id,
            playlistIndex: raw.playlistIndex,
            title: raw.title ?? "Elemento sin título",
            duration: raw.duration,
            uploader: raw.uploader ?? raw.channel,
            availability: raw.availability,
            isAvailable: raw.availability != "private" && raw.availability != "needs_auth" && raw.availability != "unavailable"
        )
    }

    private func convert(_ raw: RawInfo) -> YouTubeMediaAnalysis {
        let entries = (raw.entries ?? []).compactMap { entry -> YouTubePlaylistEntry? in
            guard let id = entry.id else { return nil }
            return YouTubePlaylistEntry(
                videoID: id,
                playlistIndex: entry.playlistIndex,
                title: entry.title ?? "Elemento sin título",
                duration: entry.duration,
                uploader: entry.uploader ?? entry.channel,
                availability: entry.availability,
                isAvailable: entry.availability != "private" && entry.availability != "needs_auth" && entry.availability != "unavailable"
            )
        }
        let kind: YouTubeContentKind = raw.type == "playlist" || !entries.isEmpty ? .playlist : .video
        let formats = (raw.formats ?? []).compactMap(convertFormat)
        var subtitles: [YouTubeSubtitleTrack] = []
        subtitles += convertSubtitles(raw.subtitles, kind: .manual)
        subtitles += convertSubtitles(raw.automaticCaptions, kind: .automatic)
        return YouTubeMediaAnalysis(
            canonicalID: raw.id ?? raw.playlistID ?? "desconocido",
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
            playlistEntries: entries
        )
    }

    private func convertFormat(_ raw: RawFormat) -> YouTubeFormat? {
        guard let id = raw.formatID else { return nil }
        let rangeText = [raw.dynamicRange, raw.formatNote].compactMap { $0 }.joined(separator: " ").lowercased()
        let range: YouTubeDynamicRange
        if rangeText.contains("hdr") || rangeText.contains("hlg") || rangeText.contains("pq") { range = .hdr }
        else if !rangeText.isEmpty { range = .sdr }
        else { range = .unknown }
        return YouTubeFormat(
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

    private func convertSubtitles(_ source: [String: [RawSubtitle]]?, kind: YouTubeSubtitleKind) -> [YouTubeSubtitleTrack] {
        guard let source else { return [] }
        return source.map { language, tracks in
            YouTubeSubtitleTrack(
                languageCode: language,
                name: tracks.compactMap(\.name).first,
                kind: kind,
                extensions: Array(Set(tracks.compactMap(\.extensionName))).sorted()
            )
        }
    }

    private func liveStatus(_ raw: String?, isLive: Bool?, wasLive: Bool?) -> YouTubeLiveStatus {
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

    enum CodingKeys: String, CodingKey {
        case id, title, uploader, channel, duration, timestamp, thumbnail, description, formats, subtitles, chapters, entries, availability
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
    }
}

private struct RawFormat: Decodable {
    let formatID: String?
    let extensionName: String?
    let protocolName: String?
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
        case width, height, fps, language
        case formatID = "format_id"
        case extensionName = "ext"
        case protocolName = "protocol"
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
