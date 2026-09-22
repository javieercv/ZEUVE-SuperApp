import Foundation

public let universalDownloaderModuleIdentifier = "com.zeuve.universal-downloader"
public let legacyYouTubeDownloaderModuleIdentifier = "com.zeuve.youtube-downloader"

public enum DownloadContentKind: String, Codable, Sendable, CaseIterable {
    case video
    case playlist
    case webpage
    case profile
    case gallery

    public var spanishName: String {
        switch self {
        case .video: return "Vídeo"
        case .playlist: return "Colección"
        case .webpage: return "Página web"
        case .profile: return "Perfil"
        case .gallery: return "Galería"
        }
    }
}

public struct ValidatedDownloadURL: Codable, Sendable, Equatable, Identifiable {
    public let original: URL
    public let canonicalURL: URL
    public let canonicalID: String
    public let kind: DownloadContentKind
    public let playlistID: String?
    public let host: String
    public let allowInsecureLocalNetwork: Bool
    public let platform: UniversalDownloadPlatform
    public let profileUsername: String?
    public let isAdultContent: Bool

    public var id: String { "\(kind.rawValue):\(canonicalID)" }

    public init(
        original: URL,
        canonicalURL: URL,
        canonicalID: String,
        kind: DownloadContentKind,
        playlistID: String? = nil,
        host: String? = nil,
        allowInsecureLocalNetwork: Bool = false,
        platform: UniversalDownloadPlatform = .automatic,
        profileUsername: String? = nil,
        isAdultContent: Bool = false
    ) {
        self.original = original
        self.canonicalURL = canonicalURL
        self.canonicalID = canonicalID
        self.kind = kind
        self.playlistID = playlistID
        self.host = host ?? canonicalURL.host ?? "desconocido"
        self.allowInsecureLocalNetwork = allowInsecureLocalNetwork
        self.platform = platform == .automatic ? UniversalDownloadPlatform.detect(from: canonicalURL) : platform
        self.profileUsername = profileUsername
        self.isAdultContent = isAdultContent
    }

    private enum CodingKeys: String, CodingKey {
        case original, canonicalURL, canonicalID, kind, playlistID, host, allowInsecureLocalNetwork
        case platform, profileUsername, isAdultContent
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        original = try container.decode(URL.self, forKey: .original)
        canonicalURL = try container.decode(URL.self, forKey: .canonicalURL)
        canonicalID = try container.decode(String.self, forKey: .canonicalID)
        kind = try container.decode(DownloadContentKind.self, forKey: .kind)
        playlistID = try container.decodeIfPresent(String.self, forKey: .playlistID)
        host = try container.decodeIfPresent(String.self, forKey: .host) ?? canonicalURL.host ?? "desconocido"
        allowInsecureLocalNetwork = try container.decodeIfPresent(Bool.self, forKey: .allowInsecureLocalNetwork) ?? false
        platform = try container.decodeIfPresent(UniversalDownloadPlatform.self, forKey: .platform) ?? UniversalDownloadPlatform.detect(from: canonicalURL)
        profileUsername = try container.decodeIfPresent(String.self, forKey: .profileUsername)
        isAdultContent = try container.decodeIfPresent(Bool.self, forKey: .isAdultContent) ?? false
    }
}

public enum DownloadSource: String, Codable, Sendable, Equatable {
    case directContent
    case pageDiscovered

    public var spanishName: String {
        switch self {
        case .directContent: return "Enlace directo"
        case .pageDiscovered: return "Encontrado en una página"
        }
    }
}

public struct DownloadPageOrigin: Codable, Sendable, Equatable {
    public let pageURL: URL
    public let domain: String
    public let pageIdentifier: String?

    public init(pageURL: URL, domain: String? = nil, pageIdentifier: String? = nil) {
        self.pageURL = pageURL
        self.domain = domain ?? pageURL.host ?? "desconocido"
        self.pageIdentifier = pageIdentifier
    }
}

public enum DownloadLiveStatus: String, Codable, Sendable, Equatable {
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
        case .wasLive, .postLive: return "La emisión ha finalizado y puede tratarse como un vídeo normal si el servicio permite acceder a ella."
        case .unknown: return "No se ha podido determinar el estado de la emisión."
        }
    }
}
