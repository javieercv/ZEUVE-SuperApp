import Foundation
import ZEUVECore

public enum MultimediaBatchFolderOrder: String, Codable, CaseIterable, Sendable, Identifiable {
    case nameAscending, nameDescending, pathAscending, modificationNewestFirst
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .nameAscending: return "Nombre A–Z"
        case .nameDescending: return "Nombre Z–A"
        case .pathAscending: return "Ruta A–Z"
        case .modificationNewestFirst: return "Más recientes primero"
        }
    }
}

public enum MultimediaBatchIncompatiblePolicy: String, Codable, CaseIterable, Sendable, Identifiable {
    case keepAsIncompatible, skip
    public var id: String { rawValue }
    public var displayName: String { self == .keepAsIncompatible ? "Conservar como incompatible" : "Omitir" }
}

public struct MultimediaBatchFolderOptions: Codable, Sendable, Equatable {
    public var includeSubfolders: Bool
    public var maximumDepth: Int
    public var includeHidden: Bool
    public var allowedExtensions: Set<String>
    public var order: MultimediaBatchFolderOrder
    public var incompatiblePolicy: MultimediaBatchIncompatiblePolicy

    public init(
        includeSubfolders: Bool = true,
        maximumDepth: Int = 8,
        includeHidden: Bool = false,
        allowedExtensions: Set<String> = MultimediaBatchFolderOptions.defaultExtensions,
        order: MultimediaBatchFolderOrder = .nameAscending,
        incompatiblePolicy: MultimediaBatchIncompatiblePolicy = .keepAsIncompatible
    ) {
        self.includeSubfolders = includeSubfolders
        self.maximumDepth = maximumDepth
        self.includeHidden = includeHidden
        self.allowedExtensions = allowedExtensions
        self.order = order
        self.incompatiblePolicy = incompatiblePolicy
        normalize()
    }

    public mutating func normalize() {
        maximumDepth = min(max(maximumDepth, 0), 32)
        allowedExtensions = Set(allowedExtensions.map { $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ". ")) }.filter { !$0.isEmpty && $0.count <= 16 })
        if allowedExtensions.isEmpty { allowedExtensions = Self.defaultExtensions }
        if !includeSubfolders { maximumDepth = 0 }
    }

    public static let defaultExtensions: Set<String> = [
        "mkv", "mp4", "mov", "m4v", "webm", "avi", "ts", "mts", "m2ts",
        "mp3", "m4a", "aac", "flac", "wav", "aiff", "aif", "alac", "ogg", "opus", "wma"
    ]
}

public struct MultimediaBatchDiscoveredFile: Sendable, Equatable, Identifiable {
    public let url: URL
    public let fingerprint: FileFingerprint
    public var id: String { url.standardizedFileURL.path }

    public init(url: URL, fingerprint: FileFingerprint) {
        self.url = url
        self.fingerprint = fingerprint
    }
}

public struct MultimediaBatchFolderEnumeration: Sendable, Equatable {
    public let files: [MultimediaBatchDiscoveredFile]
    public let ignoredSymlinks: Int
    public let ignoredHidden: Int
    public let ignoredByFilter: Int
    public let unreadable: Int
}

public struct MultimediaBatchFolderEnumerator: Sendable {
    public init() {}

    public func enumerate(folder: URL, options inputOptions: MultimediaBatchFolderOptions) throws -> MultimediaBatchFolderEnumeration {
        var options = inputOptions
        options.normalize()
        let root = folder.standardizedFileURL
        let rootValues = try root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard rootValues.isDirectory == true, rootValues.isSymbolicLink != true else { throw MultimediaInspectorError.invalidInput }

        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .isHiddenKey, .contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: Array(keys), options: [.skipsPackageDescendants], errorHandler: { _, _ in true }) else {
            throw MultimediaInspectorError.invalidInput
        }
        var files: [(MultimediaBatchDiscoveredFile, Date?)] = []
        var canonical = Set<String>()
        var ignoredSymlinks = 0, ignoredHidden = 0, ignoredByFilter = 0, unreadable = 0
        let rootComponents = root.pathComponents.count

        for case let url as URL in enumerator {
            try Task.checkCancellation()
            let standardized = url.standardizedFileURL
            let depth = max(0, standardized.pathComponents.count - rootComponents - 1)
            if depth > options.maximumDepth {
                if (try? standardized.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true { enumerator.skipDescendants() }
                continue
            }
            guard let values = try? standardized.resourceValues(forKeys: keys) else { unreadable += 1; continue }
            if values.isSymbolicLink == true {
                ignoredSymlinks += 1
                if values.isDirectory == true { enumerator.skipDescendants() }
                continue
            }
            if !options.includeHidden, (values.isHidden == true || standardized.lastPathComponent.hasPrefix(".")) {
                ignoredHidden += 1
                if values.isDirectory == true { enumerator.skipDescendants() }
                continue
            }
            if values.isDirectory == true {
                if !options.includeSubfolders { enumerator.skipDescendants() }
                continue
            }
            guard values.isRegularFile == true else { continue }
            let ext = standardized.pathExtension.lowercased()
            guard options.allowedExtensions.contains(ext) else { ignoredByFilter += 1; continue }
            let key = standardized.resolvingSymlinksInPath().path
            guard canonical.insert(key).inserted else { continue }
            guard let fp = try? FileFingerprint.read(from: standardized) else { unreadable += 1; continue }
            files.append((.init(url: standardized, fingerprint: fp), values.contentModificationDate))
        }

        files.sort { lhs, rhs in
            switch options.order {
            case .nameAscending:
                return lhs.0.url.lastPathComponent.localizedStandardCompare(rhs.0.url.lastPathComponent) == .orderedAscending
            case .nameDescending:
                return lhs.0.url.lastPathComponent.localizedStandardCompare(rhs.0.url.lastPathComponent) == .orderedDescending
            case .pathAscending:
                return lhs.0.url.path.localizedStandardCompare(rhs.0.url.path) == .orderedAscending
            case .modificationNewestFirst:
                return (lhs.1 ?? .distantPast) > (rhs.1 ?? .distantPast)
            }
        }
        return .init(files: files.map(\.0), ignoredSymlinks: ignoredSymlinks, ignoredHidden: ignoredHidden, ignoredByFilter: ignoredByFilter, unreadable: unreadable)
    }
}
