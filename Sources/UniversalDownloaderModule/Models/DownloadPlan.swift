import Foundation

public struct UniversalDownloadItem: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let canonicalID: String
    public let kind: DownloadContentKind
    public let sourceURL: URL
    public let title: String
    public let playlistTitle: String?
    public let playlistIndex: Int?
    public let estimatedBytes: Int64?
    public let sourceKind: DownloadSource?
    public let pageOrigin: DownloadPageOrigin?
    public let resolvedMedia: ResolvedMediaReference?
    public let platform: UniversalDownloadPlatform
    public let mediaKind: UniversalMediaKind
    public let engineKind: UniversalEngineKind
    public let requiresAuthentication: Bool
    public let folderComponents: [String]
    public let expectedExtension: String?
    public let safeMetadata: [String: String]
    public var outputFilenameBase: String?

    public var downloadSource: DownloadSource { sourceKind ?? .directContent }
    public var isPageDiscovered: Bool { downloadSource == .pageDiscovered }

    public init(
        id: UUID = UUID(),
        canonicalID: String,
        kind: DownloadContentKind = .video,
        sourceURL: URL,
        title: String,
        playlistTitle: String? = nil,
        playlistIndex: Int? = nil,
        estimatedBytes: Int64? = nil,
        downloadSource: DownloadSource = .directContent,
        pageOrigin: DownloadPageOrigin? = nil,
        resolvedMedia: ResolvedMediaReference? = nil,
        platform: UniversalDownloadPlatform = .automatic,
        mediaKind: UniversalMediaKind = .video,
        engineKind: UniversalEngineKind = .ytDLP,
        requiresAuthentication: Bool = false,
        folderComponents: [String] = [],
        expectedExtension: String? = nil,
        safeMetadata: [String: String] = [:],
        outputFilenameBase: String? = nil
    ) {
        self.id = id
        self.canonicalID = canonicalID
        self.kind = kind
        self.sourceURL = sourceURL
        self.title = title
        self.playlistTitle = playlistTitle
        self.playlistIndex = playlistIndex
        self.estimatedBytes = estimatedBytes
        self.sourceKind = downloadSource
        self.pageOrigin = pageOrigin
        self.resolvedMedia = resolvedMedia
        self.platform = platform
        self.mediaKind = mediaKind
        self.engineKind = engineKind
        self.requiresAuthentication = requiresAuthentication
        self.folderComponents = folderComponents
        self.expectedExtension = expectedExtension
        self.safeMetadata = safeMetadata
        self.outputFilenameBase = outputFilenameBase
    }
}

public struct UniversalDownloadPlan: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let createdAt: Date
    public let items: [UniversalDownloadItem]
    public let settings: UniversalDownloadSettings
    public let itemSettings: [UUID: UniversalDownloadSettings]
    public let outputFolder: URL
    public let cookiesFile: URL?
    public let cookieHeaderFile: URL?
    public let browserCookies: DownloadBrowserCookieSource?
    public let proxyHost: String?

    public init(id: UUID = UUID(), createdAt: Date = Date(), items: [UniversalDownloadItem], settings: UniversalDownloadSettings, itemSettings: [UUID: UniversalDownloadSettings] = [:], outputFolder: URL, cookiesFile: URL? = nil, cookieHeaderFile: URL? = nil, browserCookies: DownloadBrowserCookieSource? = nil, proxyHost: String? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.items = items
        self.settings = settings
        self.itemSettings = itemSettings
        self.outputFolder = outputFolder.standardizedFileURL
        self.cookiesFile = cookiesFile?.standardizedFileURL
        self.cookieHeaderFile = cookieHeaderFile?.standardizedFileURL
        self.browserCookies = browserCookies
        self.proxyHost = proxyHost
    }

    public func settings(for item: UniversalDownloadItem) -> UniversalDownloadSettings {
        itemSettings[item.id] ?? settings
    }
}
