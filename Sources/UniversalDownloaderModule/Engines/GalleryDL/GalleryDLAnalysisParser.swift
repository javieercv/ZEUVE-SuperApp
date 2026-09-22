import Foundation

public struct GalleryDLAnalysisParser: Sendable {
    public init() {}

    public func parse(
        data: Data,
        input: ValidatedDownloadURL,
        pageTitle: String? = nil
    ) throws -> DownloadAnalysis {
        let root = try JSONSerialization.jsonObject(with: data)
        var directoryMetadata: [String: Any] = [:]
        var records: [(url: URL, metadata: [String: Any])] = []
        collect(root, directoryMetadata: &directoryMetadata, records: &records)

        var entries: [DownloadCatalogItem] = []
        var seen = Set<String>()
        for (offset, record) in records.enumerated() {
            let key = UniversalURLNormalizer.duplicateKey(for: record.url)
            guard seen.insert(key).inserted else { continue }
            let metadata = directoryMetadata.merging(record.metadata) { _, new in new }
            let extensionName = normalizedExtension(metadata["extension"] as? String, url: record.url)
            let kind = mediaKind(for: extensionName, metadata: metadata, url: record.url)
            let identifier = string(metadata, keys: ["id", "post_id", "shortcode", "tweet_id", "pin_id"])
                ?? "media-\(Self.stableIdentifier(key))"
            let index = int(metadata, keys: ["num", "index", "position"]) ?? offset + 1
            let username = string(metadata, keys: ["username", "user", "account", "author", "uploader"])
            let title = displayTitle(metadata: metadata, username: username, identifier: identifier, index: index, kind: kind)
            let thumbnail = url(metadata, keys: ["thumbnail", "thumbnail_url", "display_url", "preview"])
                ?? (kind.mediaClass == .image ? record.url : nil)
            let section = catalogSection(for: kind)
            let folderComponents = folders(input: input, username: username, metadata: metadata, section: section)
            let safeMetadata = sanitizedMetadata(metadata, sourceURL: input.canonicalURL)
            let resolved = ResolvedMediaReference(
                mediaURL: record.url,
                kind: resolvedKind(for: record.url, extensionName: extensionName),
                protocolName: record.url.scheme,
                extensionName: extensionName,
                expiresAt: Self.expirationDate(in: record.url),
                resolvedAt: Date(),
                httpHeaders: [:]
            )
            entries.append(DownloadCatalogItem(
                canonicalID: "\(input.platform.rawValue):\(identifier):\(index)",
                playlistIndex: index,
                title: title,
                duration: double(metadata, keys: ["duration"]),
                uploader: username,
                availability: "public",
                isAvailable: true,
                // Conservamos la pagina publica estable para que gallery-dl
                // pueda volver a resolver URLs firmadas y probar sus fallbacks.
                sourceURL: input.canonicalURL,
                serviceName: input.platform.spanishName,
                extractor: "gallery-dl",
                downloadSource: input.kind == .webpage ? .pageDiscovered : .directContent,
                pageOrigin: input.kind == .webpage ? .init(pageURL: input.canonicalURL) : nil,
                resolvedMedia: resolved,
                platform: input.platform,
                mediaKind: kind,
                thumbnailURL: thumbnail,
                engineKind: .galleryDL,
                catalogSection: section,
                folderComponents: folderComponents,
                expectedExtension: extensionName,
                safeMetadata: safeMetadata
            ))
        }

        guard !entries.isEmpty else {
            throw UniversalDownloaderError.analysisFailed("gallery-dl no devolvió archivos multimedia descargables.")
        }
        let title = pageTitle
            ?? string(directoryMetadata, keys: ["title", "album", "gallery", "collection", "category"])
            ?? input.profileUsername
            ?? input.host
        return DownloadAnalysis(
            canonicalID: input.canonicalID,
            kind: entries.count == 1 ? .gallery : .playlist,
            title: title,
            uploader: string(directoryMetadata, keys: ["username", "user", "account", "author"]),
            thumbnailURL: entries.first?.thumbnailURL,
            description: string(directoryMetadata, keys: ["description", "caption", "text"]),
            playlistTitle: title,
            playlistCount: entries.count,
            playlistEntries: entries,
            sourceURL: input.canonicalURL,
            serviceName: input.platform.spanishName,
            extractor: "gallery-dl",
            platform: input.platform,
            mediaKind: entries.count == 1 ? entries[0].mediaKind : .gallery,
            engineKind: .galleryDL,
            profileUsername: input.profileUsername,
            availableSections: Array(Set(entries.compactMap(\.catalogSection))).sorted { $0.rawValue < $1.rawValue }
        )
    }

    private func collect(
        _ object: Any,
        directoryMetadata: inout [String: Any],
        records: inout [(url: URL, metadata: [String: Any])]
    ) {
        if let array = object as? [Any] {
            if let type = array.first as? Int {
                switch type {
                case 1:
                    // Contrato heredado usado por las primeras pruebas de integración.
                    if array.count > 1, let metadata = array[1] as? [String: Any] {
                        directoryMetadata.merge(metadata) { _, new in new }
                    }
                    return
                case 2:
                    // gallery-dl 1.32.9: Message.Directory = 2. El formato
                    // heredado utilizaba 2 para una URL; se conservan ambos.
                    if array.count > 1, let metadata = array[1] as? [String: Any] {
                        directoryMetadata.merge(metadata) { _, new in new }
                        return
                    }
                    if array.count > 1, let raw = array[1] as? String, let mediaURL = URL(string: raw) {
                        let metadata = array.count > 2 ? (array[2] as? [String: Any] ?? [:]) : [:]
                        records.append((mediaURL, metadata))
                    }
                    return
                case 3:
                    // gallery-dl 1.32.9: Message.Url = 3.
                    if array.count > 1, let raw = array[1] as? String, let mediaURL = URL(string: raw) {
                        let metadata = array.count > 2 ? (array[2] as? [String: Any] ?? [:]) : [:]
                        records.append((mediaURL, metadata))
                    }
                    return
                case 6:
                    // Message.Queue apunta a otra página, no a un archivo final.
                    return
                default:
                    break
                }
            }
            for value in array { collect(value, directoryMetadata: &directoryMetadata, records: &records) }
            return
        }
        if let dictionary = object as? [String: Any] {
            if let raw = string(dictionary, keys: ["url", "media_url", "download_url"]), let mediaURL = URL(string: raw) {
                records.append((mediaURL, dictionary))
            } else {
                for value in dictionary.values { collect(value, directoryMetadata: &directoryMetadata, records: &records) }
            }
        }
    }

    private func displayTitle(metadata: [String: Any], username: String?, identifier: String, index: Int, kind: UniversalMediaKind) -> String {
        if let value = string(metadata, keys: ["title", "filename", "caption", "description"]), !value.isEmpty {
            return String(value.prefix(160))
        }
        let dateText = date(metadata, keys: ["date", "created", "timestamp"]).map {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: $0)
        }
        return [username, dateText, identifier, String(format: "%02d", index), kind.spanishName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " - ")
    }

    private func folders(input: ValidatedDownloadURL, username: String?, metadata: [String: Any], section: UniversalCatalogSection) -> [String] {
        var values = [input.platform.spanishName]
        if let username, !username.isEmpty { values.append(username) }
        if let album = string(metadata, keys: ["album", "gallery", "collection", "highlight_title"]), !album.isEmpty {
            values.append(album)
        } else {
            values.append(section.spanishName)
        }
        return values
    }

    private func sanitizedMetadata(_ metadata: [String: Any], sourceURL: URL) -> [String: String] {
        var result: [String: String] = [:]
        let allowed = ["id", "shortcode", "title", "caption", "description", "text", "alt", "alt_text", "username", "user", "author", "date", "timestamp", "width", "height", "duration"]
        for key in allowed {
            if let value = metadata[key] {
                let text = String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty, text.count <= 8_000 { result[key] = text }
            }
        }
        result["source_page"] = UniversalURLNormalizer.provenanceURL(sourceURL).absoluteString
        return result
    }

    private func mediaKind(for extensionName: String?, metadata: [String: Any], url: URL) -> UniversalMediaKind {
        let category = (["subcategory", "category", "type", "typename"].compactMap { metadata[$0] as? String }.joined(separator: " ") + " " + url.path).lowercased()
        let isVideo = ["mp4", "webm", "mov", "m4v", "mkv", "avi", "m3u8", "mpd"].contains(extensionName ?? "") || category.contains("video")
        let isAudio = ["mp3", "m4a", "aac", "flac", "wav", "opus", "ogg"].contains(extensionName ?? "") || category.contains("audio")
        if category.contains("highlight") { return isVideo ? .highlightVideo : .highlightPhoto }
        if category.contains("story") { return isVideo ? .storyVideo : .storyPhoto }
        if category.contains("reel") { return .reel }
        if category.contains("profile") || category.contains("avatar") { return .profilePicture }
        if isAudio { return .audio }
        if isVideo { return .video }
        return .photo
    }

    private func catalogSection(for kind: UniversalMediaKind) -> UniversalCatalogSection {
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

    private func resolvedKind(for url: URL, extensionName: String?) -> ResolvedMediaKind {
        let ext = extensionName ?? url.pathExtension.lowercased()
        if ext == "m3u8" { return .hls }
        if ext == "mpd" { return .dash }
        if ["mp4", "webm", "mov", "m4v", "mkv", "avi", "jpg", "jpeg", "png", "webp", "gif", "avif", "heic", "mp3", "m4a", "aac", "flac", "wav", "opus", "ogg"].contains(ext) { return .directFile }
        return .unknown
    }

    private func normalizedExtension(_ value: String?, url: URL) -> String? {
        let raw = (value?.isEmpty == false ? value! : url.pathExtension).lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard raw.range(of: "^[a-z0-9]{1,8}$", options: .regularExpression) != nil else { return nil }
        return raw
    }

    private func string(_ metadata: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = metadata[key] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return value }
            if let value = metadata[key] as? NSNumber { return value.stringValue }
        }
        return nil
    }

    private func int(_ metadata: [String: Any], keys: [String]) -> Int? {
        for key in keys {
            if let value = metadata[key] as? Int { return value }
            if let value = metadata[key] as? NSNumber { return value.intValue }
            if let value = metadata[key] as? String, let number = Int(value) { return number }
        }
        return nil
    }

    private func double(_ metadata: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let value = metadata[key] as? Double { return value }
            if let value = metadata[key] as? NSNumber { return value.doubleValue }
            if let value = metadata[key] as? String, let number = Double(value) { return number }
        }
        return nil
    }

    private func url(_ metadata: [String: Any], keys: [String]) -> URL? {
        string(metadata, keys: keys).flatMap(URL.init(string:))
    }

    private func date(_ metadata: [String: Any], keys: [String]) -> Date? {
        for key in keys {
            if let value = metadata[key] as? Date { return value }
            if let value = metadata[key] as? NSNumber { return Date(timeIntervalSince1970: value.doubleValue) }
            if let value = metadata[key] as? String {
                if let timestamp = Double(value) { return Date(timeIntervalSince1970: timestamp) }
                let formatter = ISO8601DateFormatter()
                if let parsed = formatter.date(from: value) { return parsed }
            }
        }
        return nil
    }

    private static func stableIdentifier(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 { hash ^= UInt64(byte); hash &*= 1_099_511_628_211 }
        return String(hash, radix: 16)
    }

    private static func expirationDate(in url: URL) -> Date? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let names = ["expire", "expires", "exp"]
        for item in components.queryItems ?? [] where names.contains(item.name.lowercased()) {
            if let raw = item.value, let seconds = TimeInterval(raw) { return Date(timeIntervalSince1970: seconds) }
        }
        return nil
    }
}
