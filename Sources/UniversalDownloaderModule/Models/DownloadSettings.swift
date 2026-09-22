import Foundation

public enum DownloadMode: String, Codable, Sendable, CaseIterable {
    case automatic
    case original
    case video
    case audio
}

public enum MaximumResolution: Int, Codable, Sendable, CaseIterable, Identifiable {
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

public enum AudioOutputFormat: String, Codable, Sendable, CaseIterable, Identifiable {
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

public enum MP3Bitrate: Int, Codable, Sendable, CaseIterable, Identifiable {
    case kbps128 = 128
    case kbps192 = 192
    case kbps256 = 256
    case kbps320 = 320

    public var id: Int { rawValue }
    public var spanishName: String { "\(rawValue) kbps" }
    public var ytDLPValue: String { "\(rawValue)K" }
}

public enum ContainerPreference: String, Codable, Sendable, CaseIterable, Identifiable {
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

public enum HDRPreference: String, Codable, Sendable, CaseIterable, Identifiable {
    case automatic
    case preferSDR
    case preferHDR
    public var id: String { rawValue }
}

public enum DownloadFilenamePreset: String, Codable, Sendable, CaseIterable, Identifiable {
    case title
    case titleAndID
    case dateAndTitle
    case channelAndTitle
    case playlistIndexAndTitle
    case playlistAndIndexAndTitle

    public var id: String { rawValue }
}

public enum DownloadConflictPolicy: String, Codable, Sendable, CaseIterable, Identifiable {
    case renameAutomatically
    case skip
    case replaceConfirmed
    public var id: String { rawValue }
}

public struct DownloadSubtitleSelection: Codable, Sendable, Equatable {
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

public struct DownloadMetadataOptions: Codable, Sendable, Equatable {
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

public struct DownloadPageSourceOptions: Codable, Sendable, Equatable {
    public var embedSourceMetadata: Bool
    public var includeDownloadDate: Bool
    public var applyMacOSWhereFrom: Bool

    public init(
        embedSourceMetadata: Bool = false,
        includeDownloadDate: Bool = false,
        applyMacOSWhereFrom: Bool = false
    ) {
        self.embedSourceMetadata = embedSourceMetadata
        self.includeDownloadDate = includeDownloadDate
        self.applyMacOSWhereFrom = applyMacOSWhereFrom
    }
}

public struct DownloadNetworkOptions: Codable, Sendable, Equatable {
    public var retryCount: Int
    public var fragmentRetryCount: Int
    public var speedLimit: String?
    public var connectionTimeoutSeconds: Int
    public var concurrentFragments: Int
    public var adaptivePageFragments: Bool
    public var allowInsecureLocalNetwork: Bool

    public init(
        retryCount: Int = 5,
        fragmentRetryCount: Int = 5,
        speedLimit: String? = nil,
        connectionTimeoutSeconds: Int = 20,
        concurrentFragments: Int = 4,
        adaptivePageFragments: Bool = true,
        allowInsecureLocalNetwork: Bool = false
    ) {
        self.retryCount = retryCount
        self.fragmentRetryCount = fragmentRetryCount
        self.speedLimit = speedLimit
        self.connectionTimeoutSeconds = connectionTimeoutSeconds
        self.concurrentFragments = concurrentFragments
        self.adaptivePageFragments = adaptivePageFragments
        self.allowInsecureLocalNetwork = allowInsecureLocalNetwork
    }

    private enum CodingKeys: String, CodingKey {
        case retryCount, fragmentRetryCount, speedLimit, connectionTimeoutSeconds, concurrentFragments, adaptivePageFragments, allowInsecureLocalNetwork
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        retryCount = try values.decodeIfPresent(Int.self, forKey: .retryCount) ?? 5
        fragmentRetryCount = try values.decodeIfPresent(Int.self, forKey: .fragmentRetryCount) ?? 5
        speedLimit = try values.decodeIfPresent(String.self, forKey: .speedLimit)
        connectionTimeoutSeconds = try values.decodeIfPresent(Int.self, forKey: .connectionTimeoutSeconds) ?? 20
        concurrentFragments = try values.decodeIfPresent(Int.self, forKey: .concurrentFragments) ?? 4
        adaptivePageFragments = try values.decodeIfPresent(Bool.self, forKey: .adaptivePageFragments) ?? true
        allowInsecureLocalNetwork = try values.decodeIfPresent(Bool.self, forKey: .allowInsecureLocalNetwork) ?? false
    }
}

public struct DownloadProxyCredentials: Sendable, Equatable {
    public var username: String
    public var password: String
    public init(username: String = "", password: String = "") { self.username = username; self.password = password }
}

public enum DownloadBrowserCookieSource: String, Codable, Sendable, CaseIterable, Identifiable {
    case safari
    case chrome
    case firefox
    case brave
    case edge
    case arc
    case chromium
    case opera
    case vivaldi

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .safari: return "Safari"
        case .chrome: return "Chrome"
        case .firefox: return "Firefox"
        case .brave: return "Brave"
        case .edge: return "Edge"
        case .arc: return "Arc"
        case .chromium: return "Chromium"
        case .opera: return "Opera"
        case .vivaldi: return "Vivaldi"
        }
    }
}

public struct UniversalDownloadSettings: Codable, Sendable, Equatable {
    public var mode: DownloadMode
    public var maximumResolution: MaximumResolution
    public var container: ContainerPreference
    public var audioOutput: AudioOutputFormat
    public var mp3Bitrate: MP3Bitrate
    public var exactVideoFormatID: String?
    public var exactAudioFormatID: String?
    public var hdrPreference: HDRPreference
    public var subtitles: DownloadSubtitleSelection
    public var metadata: DownloadMetadataOptions
    public var pageSource: DownloadPageSourceOptions
    public var filenamePreset: DownloadFilenamePreset
    public var numberPlaylistItems: Bool
    public var createPlaylistFolder: Bool
    public var conflictPolicy: DownloadConflictPolicy
    public var network: DownloadNetworkOptions

    public init(
        mode: DownloadMode = .automatic,
        maximumResolution: MaximumResolution = .best,
        container: ContainerPreference = .mp4,
        audioOutput: AudioOutputFormat = .mp3,
        mp3Bitrate: MP3Bitrate = .kbps320,
        exactVideoFormatID: String? = nil,
        exactAudioFormatID: String? = nil,
        hdrPreference: HDRPreference = .automatic,
        subtitles: DownloadSubtitleSelection = .init(),
        metadata: DownloadMetadataOptions = .init(),
        pageSource: DownloadPageSourceOptions = .init(),
        filenamePreset: DownloadFilenamePreset = .title,
        numberPlaylistItems: Bool = true,
        createPlaylistFolder: Bool = true,
        conflictPolicy: DownloadConflictPolicy = .renameAutomatically,
        network: DownloadNetworkOptions = .init()
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
        self.pageSource = pageSource
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
        case pageSource
        case filenamePreset
        case numberPlaylistItems
        case createPlaylistFolder
        case conflictPolicy
        case network
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        mode = try values.decodeIfPresent(DownloadMode.self, forKey: .mode) ?? .automatic
        maximumResolution = try values.decodeIfPresent(MaximumResolution.self, forKey: .maximumResolution) ?? .best
        container = try values.decodeIfPresent(ContainerPreference.self, forKey: .container) ?? .mp4
        audioOutput = try values.decodeIfPresent(AudioOutputFormat.self, forKey: .audioOutput) ?? .mp3
        mp3Bitrate = try values.decodeIfPresent(MP3Bitrate.self, forKey: .mp3Bitrate) ?? .kbps320
        exactVideoFormatID = try values.decodeIfPresent(String.self, forKey: .exactVideoFormatID)
        exactAudioFormatID = try values.decodeIfPresent(String.self, forKey: .exactAudioFormatID)
        hdrPreference = try values.decodeIfPresent(HDRPreference.self, forKey: .hdrPreference) ?? .automatic
        subtitles = try values.decodeIfPresent(DownloadSubtitleSelection.self, forKey: .subtitles) ?? .init()
        metadata = try values.decodeIfPresent(DownloadMetadataOptions.self, forKey: .metadata) ?? .init()
        pageSource = try values.decodeIfPresent(DownloadPageSourceOptions.self, forKey: .pageSource) ?? .init()
        filenamePreset = try values.decodeIfPresent(DownloadFilenamePreset.self, forKey: .filenamePreset) ?? .title
        numberPlaylistItems = try values.decodeIfPresent(Bool.self, forKey: .numberPlaylistItems) ?? true
        createPlaylistFolder = try values.decodeIfPresent(Bool.self, forKey: .createPlaylistFolder) ?? true
        conflictPolicy = try values.decodeIfPresent(DownloadConflictPolicy.self, forKey: .conflictPolicy) ?? .renameAutomatically
        network = try values.decodeIfPresent(DownloadNetworkOptions.self, forKey: .network) ?? .init()
    }
}
