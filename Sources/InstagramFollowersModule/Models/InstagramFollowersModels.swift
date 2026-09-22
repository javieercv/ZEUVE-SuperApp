import Foundation

public let instagramFollowersModuleIdentifier = "com.zeuve.instagram-followers"

public enum InstagramFollowersInputType: String, Codable, Sendable, CaseIterable {
    case archive = "ZIP de Instagram"
    case jsonFiles = "Archivos JSON"
}

public enum InstagramFollowersCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case notFollowingBack
    case followersNotFollowed
    case mutual

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .notFollowingBack: return "No te siguen de vuelta"
        case .followersNotFollowed: return "Te siguen y tú no les sigues"
        case .mutual: return "Seguimiento mutuo"
        }
    }

    public var exportValue: String {
        switch self {
        case .notFollowingBack: return "no_te_siguen_de_vuelta"
        case .followersNotFollowed: return "te_siguen_y_no_sigues"
        case .mutual: return "seguimiento_mutuo"
        }
    }
}

public struct InstagramAccount: Codable, Sendable, Hashable, Identifiable, Comparable {
    public let username: String
    public let normalizedKey: String

    public var id: String { normalizedKey }
    public var profileURL: URL { URL(string: "https://www.instagram.com/\(username)/")! }

    public init(username: String, normalizedKey: String) {
        self.username = username
        self.normalizedKey = normalizedKey
    }

    public static func < (lhs: InstagramAccount, rhs: InstagramAccount) -> Bool {
        let comparison = lhs.username.localizedCaseInsensitiveCompare(rhs.username)
        if comparison == .orderedSame { return lhs.username < rhs.username }
        return comparison == .orderedAscending
    }
}

public struct InstagramFollowersFileDescriptor: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let name: String
    public let path: String
    public let size: Int64
    public let sequence: Int?

    public var id: String { path }

    public init(name: String, path: String, size: Int64, sequence: Int? = nil) {
        self.name = name
        self.path = path
        self.size = size
        self.sequence = sequence
    }
}

public struct InstagramFollowersInputCatalog: Codable, Sendable, Equatable {
    public let inputType: InstagramFollowersInputType
    public let following: InstagramFollowersFileDescriptor
    public let followers: [InstagramFollowersFileDescriptor]
    public let warnings: [String]
    public let archiveEntryCount: Int?
    public let archiveCompressedSize: Int64?
    public let archiveDeclaredSize: Int64?

    public init(
        inputType: InstagramFollowersInputType,
        following: InstagramFollowersFileDescriptor,
        followers: [InstagramFollowersFileDescriptor],
        warnings: [String] = [],
        archiveEntryCount: Int? = nil,
        archiveCompressedSize: Int64? = nil,
        archiveDeclaredSize: Int64? = nil
    ) {
        self.inputType = inputType
        self.following = following
        self.followers = followers
        self.warnings = warnings
        self.archiveEntryCount = archiveEntryCount
        self.archiveCompressedSize = archiveCompressedSize
        self.archiveDeclaredSize = archiveDeclaredSize
    }
}

public enum InstagramFollowersPreparedInput: Sendable, Equatable {
    case archive(url: URL, catalog: InstagramFollowersInputCatalog)
    case jsonFiles(following: URL, followers: [URL], catalog: InstagramFollowersInputCatalog)

    public var catalog: InstagramFollowersInputCatalog {
        switch self {
        case .archive(_, let catalog), .jsonFiles(_, _, let catalog): return catalog
        }
    }

    public var securityScopedURLs: [URL] {
        switch self {
        case .archive(let url, _): return [url]
        case .jsonFiles(let following, let followers, _): return [following] + followers
        }
    }
}

public struct InstagramFollowersComparisonResult: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let startedAt: Date
    public let finishedAt: Date
    public let inputType: InstagramFollowersInputType
    public let followerFileCount: Int
    public let followingCount: Int
    public let followerCount: Int
    public let notFollowingBack: [InstagramAccount]
    public let followersNotFollowed: [InstagramAccount]
    public let mutual: [InstagramAccount]
    public let warnings: [String]

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        finishedAt: Date,
        inputType: InstagramFollowersInputType,
        followerFileCount: Int,
        followingCount: Int,
        followerCount: Int,
        notFollowingBack: [InstagramAccount],
        followersNotFollowed: [InstagramAccount],
        mutual: [InstagramAccount],
        warnings: [String]
    ) {
        self.id = id
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.inputType = inputType
        self.followerFileCount = followerFileCount
        self.followingCount = followingCount
        self.followerCount = followerCount
        self.notFollowingBack = notFollowingBack
        self.followersNotFollowed = followersNotFollowed
        self.mutual = mutual
        self.warnings = warnings
    }

    public func accounts(in category: InstagramFollowersCategory) -> [InstagramAccount] {
        switch category {
        case .notFollowingBack: return notFollowingBack
        case .followersNotFollowed: return followersNotFollowed
        case .mutual: return mutual
        }
    }
}

public enum InstagramFollowersError: LocalizedError, Sendable, Equatable {
    case invalidManifest
    case inputNotProvided(String)
    case inputMissing(String)
    case inputUnreadable(String)
    case unsupportedInput(String)
    case malformedJSON(String)
    case incompatibleJSON(String)
    case archiveMalformed
    case archiveUnsafe(String)
    case archiveEncrypted
    case archiveLimit(String)
    case archiveConflict(String)
    case followingNotFound
    case multipleFollowingFiles
    case followersNotFound
    case destinationExists(String)
    case exportFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidManifest: return "No se ha podido cargar el manifiesto del Comparador de seguidores de Instagram."
        case .inputNotProvided(let value): return "No se ha proporcionado \(value)."
        case .inputMissing(let value): return "No se encuentra el archivo «\(value)»."
        case .inputUnreadable(let value): return "No se puede leer el archivo «\(value)»."
        case .unsupportedInput(let value): return "El archivo no es compatible: \(value)."
        case .malformedJSON(let value): return "«\(value)» no contiene un JSON válido."
        case .incompatibleJSON(let value): return "«\(value)» es un JSON válido, pero no tiene una estructura de seguidores compatible."
        case .archiveMalformed: return "El ZIP no se puede inspeccionar o está dañado."
        case .archiveUnsafe(let value): return "El ZIP contiene una ruta o entrada no segura: \(value)."
        case .archiveEncrypted: return "Los ZIP cifrados o protegidos con contraseña no son compatibles."
        case .archiveLimit(let value): return "El ZIP se ha rechazado por seguridad: \(value)."
        case .archiveConflict(let value): return "El ZIP contiene archivos en conflicto: \(value)."
        case .followingNotFound: return "No se encuentra connections/followers_and_following/following.json dentro del ZIP."
        case .multipleFollowingFiles: return "El ZIP contiene más de un following.json compatible."
        case .followersNotFound: return "No se encuentra ningún followers_<número>.json compatible."
        case .destinationExists(let value): return "Ya existe un archivo en «\(value)»."
        case .exportFailed(let value): return "No se ha podido exportar el resultado: \(value)."
        }
    }
}
