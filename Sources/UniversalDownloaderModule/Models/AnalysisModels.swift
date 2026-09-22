import Foundation

public struct DownloadCatalogItem: Codable, Sendable, Equatable, Identifiable {
    // El nombre codificado `videoID` se conserva para compatibilidad con datos históricos.
    private let videoID: String
    public var canonicalID: String { videoID }
    public let playlistIndex: Int?
    public let title: String
    public let duration: Double?
    public let uploader: String?
    public let availability: String?
    public let isAvailable: Bool
    public let sourceURL: URL
    public let serviceName: String?
    public let extractor: String?
    public let sourceKind: DownloadSource?
    public let pageOrigin: DownloadPageOrigin?
    public let resolvedMedia: ResolvedMediaReference?
    public let platform: UniversalDownloadPlatform?
    public let mediaKind: UniversalMediaKind?
    public let thumbnailURL: URL?
    public let engineKind: UniversalEngineKind?
    public let catalogSection: UniversalCatalogSection?
    public let folderComponents: [String]
    public let expectedExtension: String?
    public let safeMetadata: [String: String]

    public var downloadSource: DownloadSource { sourceKind ?? .directContent }
    public var id: String { "\(canonicalID):\(sourceURL.absoluteString)" }
    public var canonicalURL: URL { sourceURL }

    public init(
        canonicalID: String,
        playlistIndex: Int? = nil,
        title: String,
        duration: Double? = nil,
        uploader: String? = nil,
        availability: String? = nil,
        isAvailable: Bool = true,
        sourceURL: URL,
        serviceName: String? = nil,
        extractor: String? = nil,
        downloadSource: DownloadSource = .directContent,
        pageOrigin: DownloadPageOrigin? = nil,
        resolvedMedia: ResolvedMediaReference? = nil,
        platform: UniversalDownloadPlatform? = nil,
        mediaKind: UniversalMediaKind? = nil,
        thumbnailURL: URL? = nil,
        engineKind: UniversalEngineKind? = nil,
        catalogSection: UniversalCatalogSection? = nil,
        folderComponents: [String] = [],
        expectedExtension: String? = nil,
        safeMetadata: [String: String] = [:]
    ) {
        self.videoID = canonicalID
        self.playlistIndex = playlistIndex
        self.title = title
        self.duration = duration
        self.uploader = uploader
        self.availability = availability
        self.isAvailable = isAvailable
        self.sourceURL = sourceURL
        self.serviceName = serviceName
        self.extractor = extractor
        self.sourceKind = downloadSource
        self.pageOrigin = pageOrigin
        self.resolvedMedia = resolvedMedia
        self.platform = platform
        self.mediaKind = mediaKind
        self.thumbnailURL = thumbnailURL
        self.engineKind = engineKind
        self.catalogSection = catalogSection
        self.folderComponents = folderComponents
        self.expectedExtension = expectedExtension
        self.safeMetadata = safeMetadata
    }
}

public struct DownloadAnalysis: Codable, Sendable, Equatable, Identifiable {
    public let canonicalID: String
    public let kind: DownloadContentKind
    public let title: String
    public let uploader: String?
    public let channelID: String?
    public let duration: Double?
    public let publicationDate: Date?
    public let thumbnailURL: URL?
    public let description: String?
    public let formats: [YTDLPFormat]
    public let subtitles: [YTDLPSubtitleTrack]
    public let chaptersCount: Int
    public let liveStatus: DownloadLiveStatus
    public let ageLimit: Int?
    public let availability: String?
    public let playlistTitle: String?
    public let playlistCount: Int?
    public let playlistEntries: [DownloadCatalogItem]
    public let sourceURL: URL?
    public let serviceName: String?
    public let extractor: String?
    public let duplicateCount: Int
    public let sourceKind: DownloadSource?
    public let pageOrigin: DownloadPageOrigin?
    public let resolvedMedia: ResolvedMediaReference?
    public let platform: UniversalDownloadPlatform?
    public let mediaKind: UniversalMediaKind?
    public let engineKind: UniversalEngineKind?
    public let profileUsername: String?
    public let isPrivateProfile: Bool
    public let requiresAuthentication: Bool
    public let paginationCursor: String?
    public let hasMoreEntries: Bool
    public let availableSections: [UniversalCatalogSection]
    public let authenticationRestrictedSections: [UniversalCatalogSection]?

    public var downloadSource: DownloadSource { sourceKind ?? .directContent }
    public var id: String { "\(kind.rawValue):\(canonicalID):\(sourceURL?.absoluteString ?? "")" }
    public var isDownloadable: Bool { liveStatus.canDownloadInVersion020 && availability != "private" && availability != "needs_auth" && availability != "unavailable" }

    public init(
        canonicalID: String,
        kind: DownloadContentKind,
        title: String,
        uploader: String? = nil,
        channelID: String? = nil,
        duration: Double? = nil,
        publicationDate: Date? = nil,
        thumbnailURL: URL? = nil,
        description: String? = nil,
        formats: [YTDLPFormat] = [],
        subtitles: [YTDLPSubtitleTrack] = [],
        chaptersCount: Int = 0,
        liveStatus: DownloadLiveStatus = .notLive,
        ageLimit: Int? = nil,
        availability: String? = nil,
        playlistTitle: String? = nil,
        playlistCount: Int? = nil,
        playlistEntries: [DownloadCatalogItem] = [],
        sourceURL: URL? = nil,
        serviceName: String? = nil,
        extractor: String? = nil,
        duplicateCount: Int = 0,
        downloadSource: DownloadSource = .directContent,
        pageOrigin: DownloadPageOrigin? = nil,
        resolvedMedia: ResolvedMediaReference? = nil,
        platform: UniversalDownloadPlatform? = nil,
        mediaKind: UniversalMediaKind? = nil,
        engineKind: UniversalEngineKind? = nil,
        profileUsername: String? = nil,
        isPrivateProfile: Bool = false,
        requiresAuthentication: Bool = false,
        paginationCursor: String? = nil,
        hasMoreEntries: Bool = false,
        availableSections: [UniversalCatalogSection] = [],
        authenticationRestrictedSections: [UniversalCatalogSection]? = nil
    ) {
        self.canonicalID = canonicalID
        self.kind = kind
        self.title = title
        self.uploader = uploader
        self.channelID = channelID
        self.duration = duration
        self.publicationDate = publicationDate
        self.thumbnailURL = thumbnailURL
        self.description = description
        self.formats = formats
        self.subtitles = subtitles
        self.chaptersCount = chaptersCount
        self.liveStatus = liveStatus
        self.ageLimit = ageLimit
        self.availability = availability
        self.playlistTitle = playlistTitle
        self.playlistCount = playlistCount
        self.playlistEntries = playlistEntries
        self.sourceURL = sourceURL
        self.serviceName = serviceName
        self.extractor = extractor
        self.duplicateCount = duplicateCount
        self.sourceKind = downloadSource
        self.pageOrigin = pageOrigin
        self.resolvedMedia = resolvedMedia
        self.platform = platform
        self.mediaKind = mediaKind
        self.engineKind = engineKind
        self.profileUsername = profileUsername
        self.isPrivateProfile = isPrivateProfile
        self.requiresAuthentication = requiresAuthentication
        self.paginationCursor = paginationCursor
        self.hasMoreEntries = hasMoreEntries
        self.availableSections = availableSections
        self.authenticationRestrictedSections = authenticationRestrictedSections
    }
}


public struct DownloadAnalysisFailure: Sendable, Equatable, Identifiable {
    public let canonicalID: String
    public let kind: DownloadContentKind
    public let userMessage: String
    public let technicalReference: String

    public var id: String { "\(kind.rawValue):\(canonicalID):\(technicalReference)" }

    public init(canonicalID: String, kind: DownloadContentKind, userMessage: String, technicalReference: String) {
        self.canonicalID = canonicalID
        self.kind = kind
        self.userMessage = userMessage
        self.technicalReference = technicalReference
    }
}
