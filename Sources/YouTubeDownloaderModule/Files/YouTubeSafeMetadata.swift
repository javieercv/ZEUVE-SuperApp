import Foundation

public struct YouTubeSafeInfoDocument: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let canonicalID: String
    public let contentType: String
    public let title: String
    public let playlistTitle: String?
    public let playlistIndex: Int?
    public let downloadMode: String
    public let formatSummary: String
    public let generatedAt: Date

    public init(
        item: YouTubeDownloadItem,
        settings: YouTubeDownloadSettings,
        formatSummary: String,
        generatedAt: Date = Date()
    ) {
        schemaVersion = 1
        canonicalID = item.canonicalID
        contentType = item.kind.rawValue
        title = item.title
        playlistTitle = item.playlistTitle
        playlistIndex = item.playlistIndex
        downloadMode = settings.mode.rawValue
        self.formatSummary = formatSummary
        self.generatedAt = generatedAt
    }
}

public struct YouTubeSafePlaylistEntryDocument: Codable, Sendable, Equatable {
    public let canonicalID: String
    public let index: Int?
    public let title: String
    public let status: YouTubeItemResultStatus

    public init(canonicalID: String, index: Int?, title: String, status: YouTubeItemResultStatus) {
        self.canonicalID = canonicalID
        self.index = index
        self.title = title
        self.status = status
    }
}

public struct YouTubeSafePlaylistDocument: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let title: String
    public let generatedAt: Date
    public let entries: [YouTubeSafePlaylistEntryDocument]

    public init(title: String, generatedAt: Date = Date(), entries: [YouTubeSafePlaylistEntryDocument]) {
        schemaVersion = 1
        self.title = title
        self.generatedAt = generatedAt
        self.entries = entries
    }
}

public struct YouTubeSafeMetadataWriter {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    @discardableResult
    public func writeInfo(
        for item: YouTubeDownloadItem,
        settings: YouTubeDownloadSettings,
        formatSummary: String,
        to directory: URL
    ) throws -> URL {
        let base = try YouTubeFilenamePolicy().sanitize("\(item.title) [\(item.canonicalID)]", maximumUTF8Bytes: 170)
        let destination = directory.appendingPathComponent("\(base).zeuve-info.json", isDirectory: false)
        let document = YouTubeSafeInfoDocument(item: item, settings: settings, formatSummary: formatSummary)
        try encoded(document).write(to: destination, options: .atomic)
        return destination
    }

    @discardableResult
    public func writePlaylist(
        title: String,
        items: [YouTubeDownloadItem],
        resultsByCanonicalID: [String: YouTubeItemResultStatus],
        to directory: URL
    ) throws -> URL {
        let safeTitle = try YouTubeFilenamePolicy().sanitize(title, maximumUTF8Bytes: 170)
        let destination = directory.appendingPathComponent("\(safeTitle).zeuve-playlist.json", isDirectory: false)
        let entries = items.map {
            YouTubeSafePlaylistEntryDocument(
                canonicalID: $0.canonicalID,
                index: $0.playlistIndex,
                title: $0.title,
                status: resultsByCanonicalID[$0.canonicalID] ?? .cancelled
            )
        }
        try encoded(YouTubeSafePlaylistDocument(title: title, entries: entries)).write(to: destination, options: .atomic)
        return destination
    }

    private func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(value)
    }
}
