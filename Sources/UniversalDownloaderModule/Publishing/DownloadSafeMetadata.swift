import Foundation

public struct DownloadSafeInfoDocument: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let canonicalID: String
    public let contentType: String
    public let title: String
    public let playlistTitle: String?
    public let playlistIndex: Int?
    public let downloadMode: String
    public let formatSummary: String
    public let platform: String?
    public let mediaKind: String?
    public let metadata: [String: String]
    public let generatedAt: Date

    public init(
        item: UniversalDownloadItem,
        settings: UniversalDownloadSettings,
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
        platform = item.platform.rawValue
        mediaKind = item.mediaKind.rawValue
        metadata = Self.sanitizedMetadata(item.safeMetadata)
        self.generatedAt = generatedAt
    }
    private static func sanitizedMetadata(_ metadata: [String: String]) -> [String: String] {
        let forbidden = ["cookie", "session", "token", "authorization", "password", "secret", "proxy", "header"]
        var result: [String: String] = [:]
        for (key, value) in metadata {
            let normalizedKey = key.lowercased()
            guard !forbidden.contains(where: normalizedKey.contains) else { continue }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            result[key] = String(trimmed.prefix(8_000))
        }
        return result
    }

}

public struct DownloadSafeCatalogItemDocument: Codable, Sendable, Equatable {
    public let canonicalID: String
    public let index: Int?
    public let title: String
    public let status: DownloadItemResultStatus

    public init(canonicalID: String, index: Int?, title: String, status: DownloadItemResultStatus) {
        self.canonicalID = canonicalID
        self.index = index
        self.title = title
        self.status = status
    }
}

public struct DownloadSafeCatalogDocument: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let title: String
    public let generatedAt: Date
    public let entries: [DownloadSafeCatalogItemDocument]

    public init(title: String, generatedAt: Date = Date(), entries: [DownloadSafeCatalogItemDocument]) {
        schemaVersion = 1
        self.title = title
        self.generatedAt = generatedAt
        self.entries = entries
    }
}

public struct DownloadSafeMetadataWriter {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    @discardableResult
    public func writeInfo(
        for item: UniversalDownloadItem,
        settings: UniversalDownloadSettings,
        formatSummary: String,
        to directory: URL
    ) throws -> URL {
        let base = try DownloadFilenamePolicy().sanitize("\(item.title) [\(item.canonicalID)]", maximumUTF8Bytes: 170)
        let destination = directory.appendingPathComponent("\(base).zeuve-info.json", isDirectory: false)
        let document = DownloadSafeInfoDocument(item: item, settings: settings, formatSummary: formatSummary)
        try encoded(document).write(to: destination, options: .atomic)
        return destination
    }

    @discardableResult
    public func writeDescription(for item: UniversalDownloadItem, to directory: URL) throws -> URL? {
        let candidates = ["description", "caption", "alt_text"]
        guard let description = candidates.compactMap({ item.safeMetadata[$0] }).first(where: {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) else { return nil }
        let base = try DownloadFilenamePolicy().sanitize(item.outputFilenameBase ?? item.title, maximumUTF8Bytes: 170)
        let destination = directory.appendingPathComponent("\(base).description.txt", isDirectory: false)
        let normalized = description.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
        try Data(normalized.utf8).write(to: destination, options: .atomic)
        return destination
    }

    @discardableResult
    public func writePlaylist(
        title: String,
        items: [UniversalDownloadItem],
        resultsByCanonicalID: [String: DownloadItemResultStatus],
        to directory: URL
    ) throws -> URL {
        let safeTitle = try DownloadFilenamePolicy().sanitize(title, maximumUTF8Bytes: 170)
        let destination = directory.appendingPathComponent("\(safeTitle).zeuve-playlist.json", isDirectory: false)
        let entries = items.map {
            DownloadSafeCatalogItemDocument(
                canonicalID: $0.canonicalID,
                index: $0.playlistIndex,
                title: $0.title,
                status: resultsByCanonicalID[$0.canonicalID] ?? .cancelled
            )
        }
        try encoded(DownloadSafeCatalogDocument(title: title, entries: entries)).write(to: destination, options: .atomic)
        return destination
    }

    private func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(value)
    }
}
