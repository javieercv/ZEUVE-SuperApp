import Foundation

public let youtubeDownloaderModuleIdentifier = "com.zeuve.youtube-downloader"

public enum YouTubeContentKind: String, Codable, Sendable, CaseIterable {
    case video
    case playlist

    public var spanishName: String { self == .video ? "Vídeo" : "Lista de reproducción" }
}

public struct ValidatedYouTubeURL: Codable, Sendable, Equatable, Identifiable {
    public let original: URL
    public let canonicalURL: URL
    public let canonicalID: String
    public let kind: YouTubeContentKind
    public let playlistID: String?

    public var id: String { "\(kind.rawValue):\(canonicalID)" }

    public init(original: URL, canonicalURL: URL, canonicalID: String, kind: YouTubeContentKind, playlistID: String? = nil) {
        self.original = original
        self.canonicalURL = canonicalURL
        self.canonicalID = canonicalID
        self.kind = kind
        self.playlistID = playlistID
    }
}

public enum YouTubeLiveStatus: String, Codable, Sendable, Equatable {
    case notLive
    case upcoming
    case live
    case wasLive
    case postLive
    case unknown

    public var canDownloadInVersion020: Bool {
        switch self {
        case .upcoming, .live: return false
        default: return true
        }
    }

    public var spanishDescription: String {
        switch self {
        case .notLive: return "No es una emisión en directo."
        case .upcoming: return "La emisión todavía no ha comenzado y no puede descargarse en esta versión."
        case .live: return "La emisión está en directo y no puede descargarse en esta versión."
        case .wasLive, .postLive: return "La emisión ha finalizado y puede tratarse como un vídeo normal si YouTube permite acceder a ella."
        case .unknown: return "No se ha podido determinar el estado de la emisión."
        }
    }
}

public enum YouTubeDynamicRange: String, Codable, Sendable, Equatable {
    case sdr
    case hdr
    case unknown
}

public struct YouTubeFormat: Codable, Sendable, Equatable, Identifiable {
    public let formatID: String
    public let extensionName: String?
    public let protocolName: String?
    public let width: Int?
    public let height: Int?
    public let fps: Double?
    public let videoCodec: String?
    public let audioCodec: String?
    public let videoBitrateKbps: Double?
    public let audioBitrateKbps: Double?
    public let totalBitrateKbps: Double?
    public let fileSize: Int64?
    public let approximateFileSize: Int64?
    public let language: String?
    public let dynamicRange: YouTubeDynamicRange
    public let formatNote: String?

    public var id: String { formatID }
    public var hasVideo: Bool { videoCodec.map { $0 != "none" } ?? false }
    public var hasAudio: Bool { audioCodec.map { $0 != "none" } ?? false }
    public var isProgressive: Bool { hasVideo && hasAudio }
    public var bestKnownSize: Int64? { fileSize ?? approximateFileSize }

    public init(
        formatID: String,
        extensionName: String? = nil,
        protocolName: String? = nil,
        width: Int? = nil,
        height: Int? = nil,
        fps: Double? = nil,
        videoCodec: String? = nil,
        audioCodec: String? = nil,
        videoBitrateKbps: Double? = nil,
        audioBitrateKbps: Double? = nil,
        totalBitrateKbps: Double? = nil,
        fileSize: Int64? = nil,
        approximateFileSize: Int64? = nil,
        language: String? = nil,
        dynamicRange: YouTubeDynamicRange = .unknown,
        formatNote: String? = nil
    ) {
        self.formatID = formatID
        self.extensionName = extensionName
        self.protocolName = protocolName
        self.width = width
        self.height = height
        self.fps = fps
        self.videoCodec = videoCodec
        self.audioCodec = audioCodec
        self.videoBitrateKbps = videoBitrateKbps
        self.audioBitrateKbps = audioBitrateKbps
        self.totalBitrateKbps = totalBitrateKbps
        self.fileSize = fileSize
        self.approximateFileSize = approximateFileSize
        self.language = language
        self.dynamicRange = dynamicRange
        self.formatNote = formatNote
    }
}

public enum YouTubeSubtitleKind: String, Codable, Sendable, Equatable {
    case manual
    case automatic
}

public struct YouTubeSubtitleTrack: Codable, Sendable, Equatable, Identifiable {
    public let languageCode: String
    public let name: String?
    public let kind: YouTubeSubtitleKind
    public let extensions: [String]

    public var id: String { "\(kind.rawValue):\(languageCode)" }

    public init(languageCode: String, name: String? = nil, kind: YouTubeSubtitleKind, extensions: [String]) {
        self.languageCode = languageCode
        self.name = name
        self.kind = kind
        self.extensions = extensions
    }
}

public struct YouTubePlaylistEntry: Codable, Sendable, Equatable, Identifiable {
    public let videoID: String
    public let playlistIndex: Int?
    public let title: String
    public let duration: Double?
    public let uploader: String?
    public let availability: String?
    public let isAvailable: Bool

    public var id: String { videoID }
    public var canonicalURL: URL { URL(string: "https://www.youtube.com/watch?v=\(videoID)")! }

    public init(
        videoID: String,
        playlistIndex: Int? = nil,
        title: String,
        duration: Double? = nil,
        uploader: String? = nil,
        availability: String? = nil,
        isAvailable: Bool = true
    ) {
        self.videoID = videoID
        self.playlistIndex = playlistIndex
        self.title = title
        self.duration = duration
        self.uploader = uploader
        self.availability = availability
        self.isAvailable = isAvailable
    }
}

public struct YouTubeMediaAnalysis: Codable, Sendable, Equatable, Identifiable {
    public let canonicalID: String
    public let kind: YouTubeContentKind
    public let title: String
    public let uploader: String?
    public let channelID: String?
    public let duration: Double?
    public let publicationDate: Date?
    public let thumbnailURL: URL?
    public let description: String?
    public let formats: [YouTubeFormat]
    public let subtitles: [YouTubeSubtitleTrack]
    public let chaptersCount: Int
    public let liveStatus: YouTubeLiveStatus
    public let ageLimit: Int?
    public let availability: String?
    public let playlistTitle: String?
    public let playlistCount: Int?
    public let playlistEntries: [YouTubePlaylistEntry]

    public var id: String { "\(kind.rawValue):\(canonicalID)" }
    public var isDownloadable: Bool { liveStatus.canDownloadInVersion020 && availability != "private" && availability != "needs_auth" }

    public init(
        canonicalID: String,
        kind: YouTubeContentKind,
        title: String,
        uploader: String? = nil,
        channelID: String? = nil,
        duration: Double? = nil,
        publicationDate: Date? = nil,
        thumbnailURL: URL? = nil,
        description: String? = nil,
        formats: [YouTubeFormat] = [],
        subtitles: [YouTubeSubtitleTrack] = [],
        chaptersCount: Int = 0,
        liveStatus: YouTubeLiveStatus = .notLive,
        ageLimit: Int? = nil,
        availability: String? = nil,
        playlistTitle: String? = nil,
        playlistCount: Int? = nil,
        playlistEntries: [YouTubePlaylistEntry] = []
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
    }
}


public struct YouTubeAnalysisFailure: Sendable, Equatable, Identifiable {
    public let canonicalID: String
    public let kind: YouTubeContentKind
    public let userMessage: String
    public let technicalReference: String

    public var id: String { "\(kind.rawValue):\(canonicalID):\(technicalReference)" }

    public init(canonicalID: String, kind: YouTubeContentKind, userMessage: String, technicalReference: String) {
        self.canonicalID = canonicalID
        self.kind = kind
        self.userMessage = userMessage
        self.technicalReference = technicalReference
    }
}

public enum YouTubeDownloadMode: String, Codable, Sendable, CaseIterable {
    case video
    case audio
}

public enum YouTubeMaximumResolution: Int, Codable, Sendable, CaseIterable, Identifiable {
    case best = 0
    case p2160 = 2160
    case p1440 = 1440
    case p1080 = 1080
    case p720 = 720
    case p480 = 480
    case p360 = 360

    public var id: Int { rawValue }
    public var spanishName: String { self == .best ? "Mejor disponible" : "\(rawValue)p" }
}

public enum YouTubeAudioOutput: String, Codable, Sendable, CaseIterable, Identifiable {
    case mp3
    case m4a
    case flac
    case wav
    case opus
    case original

    public var id: String { rawValue }
    public var requiresTranscoding: Bool { self != .original }
    public var spanishName: String {
        switch self {
        case .mp3: return "MP3"
        case .m4a: return "M4A"
        case .flac: return "FLAC"
        case .wav: return "WAV"
        case .opus: return "Opus"
        case .original: return "Flujo original"
        }
    }
}

public enum YouTubeMP3Bitrate: Int, Codable, Sendable, CaseIterable, Identifiable {
    case kbps128 = 128
    case kbps192 = 192
    case kbps256 = 256
    case kbps320 = 320

    public var id: Int { rawValue }
    public var spanishName: String { "\(rawValue) kbps" }
    public var ytDLPValue: String { "\(rawValue)K" }
}

public enum YouTubeContainerPreference: String, Codable, Sendable, CaseIterable, Identifiable {
    case automatic
    case mp4
    case mkv
    case webm

    public var id: String { rawValue }
    public var spanishName: String {
        switch self {
        case .automatic: return "Automático"
        case .mp4: return "MP4"
        case .mkv: return "MKV"
        case .webm: return "WebM"
        }
    }
}

public enum YouTubeHDRPreference: String, Codable, Sendable, CaseIterable, Identifiable {
    case automatic
    case preferSDR
    case preferHDR
    public var id: String { rawValue }
}

public enum YouTubeFilenamePreset: String, Codable, Sendable, CaseIterable, Identifiable {
    case title
    case titleAndID
    case dateAndTitle
    case channelAndTitle
    case playlistIndexAndTitle
    case playlistAndIndexAndTitle

    public var id: String { rawValue }
}

public enum YouTubeConflictPolicy: String, Codable, Sendable, CaseIterable, Identifiable {
    case renameAutomatically
    case skip
    case replaceConfirmed
    public var id: String { rawValue }
}

public struct YouTubeSubtitleSelection: Codable, Sendable, Equatable {
    public var languages: [String]
    public var includeAutomatic: Bool
    public var embed: Bool
    public var convertToSRT: Bool

    public init(languages: [String] = [], includeAutomatic: Bool = false, embed: Bool = false, convertToSRT: Bool = false) {
        self.languages = languages
        self.includeAutomatic = includeAutomatic
        self.embed = embed
        self.convertToSRT = convertToSRT
    }
}

public struct YouTubeMetadataOptions: Codable, Sendable, Equatable {
    public var embedMetadata: Bool
    public var embedThumbnail: Bool
    public var saveThumbnail: Bool
    public var preservePublicationDate: Bool
    public var addChapters: Bool
    public var saveDescription: Bool
    public var saveInfoJSON: Bool
    public var savePlaylistMetadata: Bool

    public init(
        embedMetadata: Bool = true,
        embedThumbnail: Bool = false,
        saveThumbnail: Bool = false,
        preservePublicationDate: Bool = false,
        addChapters: Bool = true,
        saveDescription: Bool = false,
        saveInfoJSON: Bool = false,
        savePlaylistMetadata: Bool = false
    ) {
        self.embedMetadata = embedMetadata
        self.embedThumbnail = embedThumbnail
        self.saveThumbnail = saveThumbnail
        self.preservePublicationDate = preservePublicationDate
        self.addChapters = addChapters
        self.saveDescription = saveDescription
        self.saveInfoJSON = saveInfoJSON
        self.savePlaylistMetadata = savePlaylistMetadata
    }
}

public struct YouTubeNetworkOptions: Codable, Sendable, Equatable {
    public var retryCount: Int
    public var fragmentRetryCount: Int
    public var speedLimit: String?
    public var connectionTimeoutSeconds: Int
    public var concurrentFragments: Int

    public init(retryCount: Int = 5, fragmentRetryCount: Int = 5, speedLimit: String? = nil, connectionTimeoutSeconds: Int = 20, concurrentFragments: Int = 4) {
        self.retryCount = retryCount
        self.fragmentRetryCount = fragmentRetryCount
        self.speedLimit = speedLimit
        self.connectionTimeoutSeconds = connectionTimeoutSeconds
        self.concurrentFragments = concurrentFragments
    }
}

public struct YouTubeProxyCredentials: Sendable, Equatable {
    public var username: String
    public var password: String
    public init(username: String = "", password: String = "") { self.username = username; self.password = password }
}

public struct YouTubeDownloadSettings: Codable, Sendable, Equatable {
    public var mode: YouTubeDownloadMode
    public var maximumResolution: YouTubeMaximumResolution
    public var container: YouTubeContainerPreference
    public var audioOutput: YouTubeAudioOutput
    public var mp3Bitrate: YouTubeMP3Bitrate
    public var exactVideoFormatID: String?
    public var exactAudioFormatID: String?
    public var hdrPreference: YouTubeHDRPreference
    public var subtitles: YouTubeSubtitleSelection
    public var metadata: YouTubeMetadataOptions
    public var filenamePreset: YouTubeFilenamePreset
    public var numberPlaylistItems: Bool
    public var createPlaylistFolder: Bool
    public var conflictPolicy: YouTubeConflictPolicy
    public var network: YouTubeNetworkOptions

    public init(
        mode: YouTubeDownloadMode = .video,
        maximumResolution: YouTubeMaximumResolution = .best,
        container: YouTubeContainerPreference = .mp4,
        audioOutput: YouTubeAudioOutput = .mp3,
        mp3Bitrate: YouTubeMP3Bitrate = .kbps320,
        exactVideoFormatID: String? = nil,
        exactAudioFormatID: String? = nil,
        hdrPreference: YouTubeHDRPreference = .automatic,
        subtitles: YouTubeSubtitleSelection = .init(),
        metadata: YouTubeMetadataOptions = .init(),
        filenamePreset: YouTubeFilenamePreset = .title,
        numberPlaylistItems: Bool = true,
        createPlaylistFolder: Bool = true,
        conflictPolicy: YouTubeConflictPolicy = .renameAutomatically,
        network: YouTubeNetworkOptions = .init()
    ) {
        self.mode = mode
        self.maximumResolution = maximumResolution
        self.container = container
        self.audioOutput = audioOutput
        self.mp3Bitrate = mp3Bitrate
        self.exactVideoFormatID = exactVideoFormatID
        self.exactAudioFormatID = exactAudioFormatID
        self.hdrPreference = hdrPreference
        self.subtitles = subtitles
        self.metadata = metadata
        self.filenamePreset = filenamePreset
        self.numberPlaylistItems = numberPlaylistItems
        self.createPlaylistFolder = createPlaylistFolder
        self.conflictPolicy = conflictPolicy
        self.network = network
    }

    private enum CodingKeys: String, CodingKey {
        case mode
        case maximumResolution
        case container
        case audioOutput
        case mp3Bitrate
        case exactVideoFormatID
        case exactAudioFormatID
        case hdrPreference
        case subtitles
        case metadata
        case filenamePreset
        case numberPlaylistItems
        case createPlaylistFolder
        case conflictPolicy
        case network
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        mode = try values.decodeIfPresent(YouTubeDownloadMode.self, forKey: .mode) ?? .video
        maximumResolution = try values.decodeIfPresent(YouTubeMaximumResolution.self, forKey: .maximumResolution) ?? .best
        container = try values.decodeIfPresent(YouTubeContainerPreference.self, forKey: .container) ?? .mp4
        audioOutput = try values.decodeIfPresent(YouTubeAudioOutput.self, forKey: .audioOutput) ?? .mp3
        mp3Bitrate = try values.decodeIfPresent(YouTubeMP3Bitrate.self, forKey: .mp3Bitrate) ?? .kbps320
        exactVideoFormatID = try values.decodeIfPresent(String.self, forKey: .exactVideoFormatID)
        exactAudioFormatID = try values.decodeIfPresent(String.self, forKey: .exactAudioFormatID)
        hdrPreference = try values.decodeIfPresent(YouTubeHDRPreference.self, forKey: .hdrPreference) ?? .automatic
        subtitles = try values.decodeIfPresent(YouTubeSubtitleSelection.self, forKey: .subtitles) ?? .init()
        metadata = try values.decodeIfPresent(YouTubeMetadataOptions.self, forKey: .metadata) ?? .init()
        filenamePreset = try values.decodeIfPresent(YouTubeFilenamePreset.self, forKey: .filenamePreset) ?? .title
        numberPlaylistItems = try values.decodeIfPresent(Bool.self, forKey: .numberPlaylistItems) ?? true
        createPlaylistFolder = try values.decodeIfPresent(Bool.self, forKey: .createPlaylistFolder) ?? true
        conflictPolicy = try values.decodeIfPresent(YouTubeConflictPolicy.self, forKey: .conflictPolicy) ?? .renameAutomatically
        network = try values.decodeIfPresent(YouTubeNetworkOptions.self, forKey: .network) ?? .init()
    }
}

public struct YouTubeDownloadItem: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let canonicalID: String
    public let kind: YouTubeContentKind
    public let sourceURL: URL
    public let title: String
    public let playlistTitle: String?
    public let playlistIndex: Int?
    public let estimatedBytes: Int64?

    public init(
        id: UUID = UUID(),
        canonicalID: String,
        kind: YouTubeContentKind = .video,
        sourceURL: URL,
        title: String,
        playlistTitle: String? = nil,
        playlistIndex: Int? = nil,
        estimatedBytes: Int64? = nil
    ) {
        self.id = id
        self.canonicalID = canonicalID
        self.kind = kind
        self.sourceURL = sourceURL
        self.title = title
        self.playlistTitle = playlistTitle
        self.playlistIndex = playlistIndex
        self.estimatedBytes = estimatedBytes
    }
}

public struct YouTubeDownloadPlan: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let createdAt: Date
    public let items: [YouTubeDownloadItem]
    public let settings: YouTubeDownloadSettings
    public let outputFolder: URL
    public let cookiesFile: URL?
    public let proxyHost: String?

    public init(id: UUID = UUID(), createdAt: Date = Date(), items: [YouTubeDownloadItem], settings: YouTubeDownloadSettings, outputFolder: URL, cookiesFile: URL? = nil, proxyHost: String? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.items = items
        self.settings = settings
        self.outputFolder = outputFolder.standardizedFileURL
        self.cookiesFile = cookiesFile?.standardizedFileURL
        self.proxyHost = proxyHost
    }
}

public enum YouTubeProgressPhase: String, Codable, Sendable, Equatable {
    case preparing
    case analyzing
    case downloading
    case merging
    case converting
    case publishing
    case cleaning
}

public struct YouTubeDownloadProgress: Codable, Sendable, Equatable {
    public let phase: YouTubeProgressPhase
    public let currentItem: String?
    public let itemIndex: Int
    public let itemTotal: Int
    public let fraction: Double?
    public let downloadedBytes: Int64?
    public let totalBytes: Int64?
    public let speedBytesPerSecond: Double?
    public let estimatedSecondsRemaining: Double?
    public let completedItems: Int
    public let failedItems: Int
    public let skippedItems: Int

    public init(phase: YouTubeProgressPhase, currentItem: String? = nil, itemIndex: Int = 0, itemTotal: Int = 0, fraction: Double? = nil, downloadedBytes: Int64? = nil, totalBytes: Int64? = nil, speedBytesPerSecond: Double? = nil, estimatedSecondsRemaining: Double? = nil, completedItems: Int = 0, failedItems: Int = 0, skippedItems: Int = 0) {
        self.phase = phase
        self.currentItem = currentItem
        self.itemIndex = itemIndex
        self.itemTotal = itemTotal
        self.fraction = fraction
        self.downloadedBytes = downloadedBytes
        self.totalBytes = totalBytes
        self.speedBytesPerSecond = speedBytesPerSecond
        self.estimatedSecondsRemaining = estimatedSecondsRemaining
        self.completedItems = completedItems
        self.failedItems = failedItems
        self.skippedItems = skippedItems
    }
}

public enum YouTubeItemResultStatus: String, Codable, Sendable, Equatable {
    case completed
    case skipped
    case failed
    case cancelled
}

public struct YouTubeItemResult: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let canonicalID: String
    public let title: String
    public let status: YouTubeItemResultStatus
    public let outputFiles: [URL]
    public let errorReference: String?
    public let userMessage: String?

    public init(id: UUID = UUID(), canonicalID: String, title: String, status: YouTubeItemResultStatus, outputFiles: [URL] = [], errorReference: String? = nil, userMessage: String? = nil) {
        self.id = id
        self.canonicalID = canonicalID
        self.title = title
        self.status = status
        self.outputFiles = outputFiles
        self.errorReference = errorReference
        self.userMessage = userMessage
    }
}

public struct YouTubeOperationResult: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let startedAt: Date
    public let finishedAt: Date
    public let outputFolder: URL
    public let mode: YouTubeDownloadMode
    public let formatSummary: String
    public let items: [YouTubeItemResult]
    public let auxiliaryFiles: [URL]
    public let warnings: [String]
    public let wasCancelled: Bool

    public var completedCount: Int { items.filter { $0.status == .completed }.count }
    public var skippedCount: Int { items.filter { $0.status == .skipped }.count }
    public var failedCount: Int { items.filter { $0.status == .failed }.count }

    public init(id: UUID, startedAt: Date, finishedAt: Date = Date(), outputFolder: URL, mode: YouTubeDownloadMode, formatSummary: String, items: [YouTubeItemResult], auxiliaryFiles: [URL] = [], warnings: [String] = [], wasCancelled: Bool) {
        self.id = id
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.outputFolder = outputFolder
        self.mode = mode
        self.formatSummary = formatSummary
        self.items = items
        self.auxiliaryFiles = auxiliaryFiles
        self.warnings = warnings
        self.wasCancelled = wasCancelled
    }
}

public struct YouTubePreset: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public var schemaVersion: Int
    public var name: String
    public var settings: YouTubeDownloadSettings
    public var isFavorite: Bool
    public var modifiedAt: Date

    public init(id: UUID = UUID(), schemaVersion: Int = 2, name: String, settings: YouTubeDownloadSettings, isFavorite: Bool = false, modifiedAt: Date = Date()) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.name = name
        self.settings = settings
        self.isFavorite = isFavorite
        self.modifiedAt = modifiedAt
    }
}
