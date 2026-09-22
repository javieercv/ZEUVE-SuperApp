import Foundation

public enum UniversalDownloadPlatform: String, Codable, Sendable, CaseIterable, Identifiable {
    case automatic
    case instagram
    case youtube
    case tiktok
    case pinterest
    case x
    case facebook
    case reddit
    case twitch
    case vimeo
    case dailymotion
    case soundcloud
    case tumblr
    case threads
    case snapchat
    case erome
    case webpage

    public var id: String { rawValue }

    public var spanishName: String {
        switch self {
        case .automatic: return "Automático"
        case .instagram: return "Instagram"
        case .youtube: return "YouTube"
        case .tiktok: return "TikTok"
        case .pinterest: return "Pinterest"
        case .x: return "X / Twitter"
        case .facebook: return "Facebook"
        case .reddit: return "Reddit"
        case .twitch: return "Twitch"
        case .vimeo: return "Vimeo"
        case .dailymotion: return "Dailymotion"
        case .soundcloud: return "SoundCloud"
        case .tumblr: return "Tumblr"
        case .threads: return "Threads"
        case .snapchat: return "Snapchat"
        case .erome: return "EroMe"
        case .webpage: return "Página web"
        }
    }

    public var supportsUsernameInput: Bool { self == .instagram }
    public var requiresConcreteURL: Bool {
        switch self {
        case .automatic, .instagram, .webpage: return false
        default: return true
        }
    }
    public var isAdultPlatform: Bool { self == .erome }

    public static func detect(from url: URL) -> UniversalDownloadPlatform {
        let host = (url.host ?? "").lowercased()
        func matches(_ domains: [String]) -> Bool {
            domains.contains { host == $0 || host.hasSuffix(".\($0)") }
        }
        if matches(["instagram.com"]) { return .instagram }
        if matches(["youtube.com", "youtu.be", "youtube-nocookie.com"]) { return .youtube }
        if matches(["tiktok.com"]) { return .tiktok }
        if matches(["pinterest.com", "pin.it"]) { return .pinterest }
        if matches(["x.com", "twitter.com", "t.co"]) { return .x }
        if matches(["facebook.com", "fb.watch"]) { return .facebook }
        if matches(["reddit.com", "redd.it"]) { return .reddit }
        if matches(["twitch.tv"]) { return .twitch }
        if matches(["vimeo.com"]) { return .vimeo }
        if matches(["dailymotion.com", "dai.ly"]) { return .dailymotion }
        if matches(["soundcloud.com"]) { return .soundcloud }
        if matches(["tumblr.com"]) { return .tumblr }
        if matches(["threads.net", "threads.com"]) { return .threads }
        if matches(["snapchat.com"]) { return .snapchat }
        if matches(["erome.com"]) { return .erome }
        return .webpage
    }
}

public enum UniversalMediaClass: String, Codable, Sendable, Equatable {
    case image
    case video
    case audio
    case collection
    case unknown
}

public enum UniversalMediaKind: String, Codable, Sendable, CaseIterable, Equatable, Identifiable {
    case photo
    case video
    case audio
    case reel
    case storyPhoto
    case storyVideo
    case highlightPhoto
    case highlightVideo
    case profilePicture
    case gallery
    case webpageMedia
    case unknown

    public var id: String { rawValue }

    public var mediaClass: UniversalMediaClass {
        switch self {
        case .photo, .storyPhoto, .highlightPhoto, .profilePicture: return .image
        case .video, .reel, .storyVideo, .highlightVideo, .webpageMedia: return .video
        case .audio: return .audio
        case .gallery: return .collection
        case .unknown: return .unknown
        }
    }

    public var spanishName: String {
        switch self {
        case .photo: return "Foto"
        case .video: return "Vídeo"
        case .audio: return "Audio"
        case .reel: return "Reel"
        case .storyPhoto: return "Story · foto"
        case .storyVideo: return "Story · vídeo"
        case .highlightPhoto: return "Destacada · foto"
        case .highlightVideo: return "Destacada · vídeo"
        case .profilePicture: return "Foto de perfil"
        case .gallery: return "Galería"
        case .webpageMedia: return "Multimedia de página"
        case .unknown: return "Multimedia"
        }
    }

    public var systemImage: String {
        switch mediaClass {
        case .image: return "photo"
        case .video: return self == .reel ? "play.square.stack" : "play.rectangle"
        case .audio: return "waveform"
        case .collection: return "rectangle.stack"
        case .unknown: return "doc"
        }
    }
}

public enum UniversalEngineKind: String, Codable, Sendable, CaseIterable, Equatable, Identifiable {
    case ytDLP = "yt-dlp"
    case galleryDL = "gallery-dl"
    case instagramCatalog = "instaloader-zeuve"
    case genericPage = "generic-page"
    case browser = "playwright-browser"

    public var id: String { rawValue }
    public var spanishName: String {
        switch self {
        case .ytDLP: return "yt-dlp"
        case .galleryDL: return "gallery-dl"
        case .instagramCatalog: return "Catálogo de Instagram"
        case .genericPage: return "Extractor web"
        case .browser: return "Navegador adicional"
        }
    }
}

public enum UniversalCatalogSection: String, Codable, Sendable, CaseIterable, Hashable, Identifiable {
    case all
    case photos
    case videos
    case reels
    case stories
    case highlights
    case profile

    public var id: String { rawValue }
    public var spanishName: String {
        switch self {
        case .all: return "Todo"
        case .photos: return "Fotos"
        case .videos: return "Vídeos"
        case .reels: return "Reels"
        case .stories: return "Stories"
        case .highlights: return "Destacadas"
        case .profile: return "Foto de perfil"
        }
    }
}

public enum UniversalCatalogLayout: String, Codable, Sendable, CaseIterable, Identifiable {
    case grid
    case list
    public var id: String { rawValue }
    public var spanishName: String { self == .grid ? "Cuadrícula" : "Lista" }
}

public struct UniversalDownloaderPreferences: Codable, Sendable, Equatable {
    public var defaultPlatform: UniversalDownloadPlatform
    public var allowAdultContent: Bool
    public var adultDomainsAddedByUser: [String]
    public var catalogLayout: UniversalCatalogLayout
    public var enabledSections: Set<UniversalCatalogSection>
    public var initialCatalogBatchSize: Int
    public var catalogPageSize: Int
    public var thumbnailSize: Int
    public var selectNewItemsByDefault: Bool
    public var keepLocalProfilePictureHistory: Bool
    public var useOptionalBrowserFallback: Bool
    public var createPlatformFolders: Bool
    public var createSubfolderForMultiItemPosts: Bool
    public var rememberInstagramSessionByDefault: Bool

    public init(
        defaultPlatform: UniversalDownloadPlatform = .automatic,
        allowAdultContent: Bool = false,
        adultDomainsAddedByUser: [String] = [],
        catalogLayout: UniversalCatalogLayout = .grid,
        enabledSections: Set<UniversalCatalogSection> = Set(UniversalCatalogSection.allCases),
        initialCatalogBatchSize: Int = 24,
        catalogPageSize: Int = 24,
        thumbnailSize: Int = 160,
        selectNewItemsByDefault: Bool = false,
        keepLocalProfilePictureHistory: Bool = false,
        useOptionalBrowserFallback: Bool = false,
        createPlatformFolders: Bool = true,
        createSubfolderForMultiItemPosts: Bool = true,
        rememberInstagramSessionByDefault: Bool = false
    ) {
        self.defaultPlatform = defaultPlatform
        self.allowAdultContent = allowAdultContent
        self.adultDomainsAddedByUser = adultDomainsAddedByUser
        self.catalogLayout = catalogLayout
        self.enabledSections = enabledSections
        self.initialCatalogBatchSize = max(6, min(initialCatalogBatchSize, 200))
        self.catalogPageSize = max(6, min(catalogPageSize, 200))
        self.thumbnailSize = max(80, min(thumbnailSize, 320))
        self.selectNewItemsByDefault = selectNewItemsByDefault
        self.keepLocalProfilePictureHistory = keepLocalProfilePictureHistory
        self.useOptionalBrowserFallback = useOptionalBrowserFallback
        self.createPlatformFolders = createPlatformFolders
        self.createSubfolderForMultiItemPosts = createSubfolderForMultiItemPosts
        self.rememberInstagramSessionByDefault = rememberInstagramSessionByDefault
    }

    private enum CodingKeys: String, CodingKey {
        case defaultPlatform, allowAdultContent, adultDomainsAddedByUser, catalogLayout, enabledSections
        case initialCatalogBatchSize, catalogPageSize, thumbnailSize, selectNewItemsByDefault
        case keepLocalProfilePictureHistory, useOptionalBrowserFallback, createPlatformFolders
        case createSubfolderForMultiItemPosts, rememberInstagramSessionByDefault
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            defaultPlatform: try values.decodeIfPresent(UniversalDownloadPlatform.self, forKey: .defaultPlatform) ?? .automatic,
            allowAdultContent: try values.decodeIfPresent(Bool.self, forKey: .allowAdultContent) ?? false,
            adultDomainsAddedByUser: try values.decodeIfPresent([String].self, forKey: .adultDomainsAddedByUser) ?? [],
            catalogLayout: try values.decodeIfPresent(UniversalCatalogLayout.self, forKey: .catalogLayout) ?? .grid,
            enabledSections: try values.decodeIfPresent(Set<UniversalCatalogSection>.self, forKey: .enabledSections) ?? Set(UniversalCatalogSection.allCases),
            initialCatalogBatchSize: try values.decodeIfPresent(Int.self, forKey: .initialCatalogBatchSize) ?? 24,
            catalogPageSize: try values.decodeIfPresent(Int.self, forKey: .catalogPageSize) ?? 24,
            thumbnailSize: try values.decodeIfPresent(Int.self, forKey: .thumbnailSize) ?? 160,
            selectNewItemsByDefault: try values.decodeIfPresent(Bool.self, forKey: .selectNewItemsByDefault) ?? false,
            keepLocalProfilePictureHistory: try values.decodeIfPresent(Bool.self, forKey: .keepLocalProfilePictureHistory) ?? false,
            useOptionalBrowserFallback: try values.decodeIfPresent(Bool.self, forKey: .useOptionalBrowserFallback) ?? false,
            createPlatformFolders: try values.decodeIfPresent(Bool.self, forKey: .createPlatformFolders) ?? true,
            createSubfolderForMultiItemPosts: try values.decodeIfPresent(Bool.self, forKey: .createSubfolderForMultiItemPosts) ?? true,
            rememberInstagramSessionByDefault: try values.decodeIfPresent(Bool.self, forKey: .rememberInstagramSessionByDefault) ?? false
        )
    }
}

public struct UniversalEngineStrategy: Sendable, Equatable {
    public let primary: UniversalEngineKind
    public let fallbacks: [UniversalEngineKind]

    public init(primary: UniversalEngineKind, fallbacks: [UniversalEngineKind] = []) {
        self.primary = primary
        self.fallbacks = fallbacks
    }

    public var ordered: [UniversalEngineKind] { [primary] + fallbacks }
}

public enum UniversalEngineRouter {
    public static func strategy(for input: ValidatedDownloadURL, browserFallbackEnabled _: Bool) -> UniversalEngineStrategy {
        if input.platform == .instagram, input.kind == .profile {
            return .init(primary: .instagramCatalog, fallbacks: [.galleryDL])
        }
        switch input.platform {
        case .instagram:
            return .init(primary: .instagramCatalog, fallbacks: [.galleryDL, .ytDLP, .genericPage])
        case .pinterest, .x, .facebook, .reddit, .tumblr, .threads, .erome:
            return .init(primary: .galleryDL, fallbacks: [.ytDLP, .genericPage])
        case .tiktok:
            return .init(primary: .galleryDL, fallbacks: [.ytDLP, .genericPage])
        case .youtube, .twitch, .vimeo, .dailymotion, .soundcloud, .snapchat:
            return .init(primary: .ytDLP, fallbacks: [.galleryDL, .genericPage])
        case .webpage, .automatic:
            return .init(primary: .ytDLP, fallbacks: [.genericPage, .galleryDL])
        }
    }
}
