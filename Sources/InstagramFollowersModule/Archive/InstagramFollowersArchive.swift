import Foundation
import CLibArchive

public struct InstagramFollowersArchiveLimits: Sendable, Equatable {
    public var compressedWarningBytes: Int64
    public var compressedMaximumBytes: Int64
    public var entryWarningCount: Int
    public var entryMaximumCount: Int
    public var totalDeclaredWarningBytes: Int64
    public var totalDeclaredMaximumBytes: Int64
    public var compressionRatioWarning: Double
    public var compressionRatioMaximum: Double
    public var relevantEntryMaximumBytes: Int64
    public var relevantTotalMaximumBytes: Int64
    public var maximumFolderDepth: Int

    public init(
        compressedWarningBytes: Int64 = 2 * 1_024 * 1_024 * 1_024,
        compressedMaximumBytes: Int64 = 20 * 1_024 * 1_024 * 1_024,
        entryWarningCount: Int = 20_000,
        entryMaximumCount: Int = 100_000,
        totalDeclaredWarningBytes: Int64 = 20 * 1_024 * 1_024 * 1_024,
        totalDeclaredMaximumBytes: Int64 = 200 * 1_024 * 1_024 * 1_024,
        compressionRatioWarning: Double = 250,
        compressionRatioMaximum: Double = 1_000,
        relevantEntryMaximumBytes: Int64 = 512 * 1_024 * 1_024,
        relevantTotalMaximumBytes: Int64 = 2 * 1_024 * 1_024 * 1_024,
        maximumFolderDepth: Int = 64
    ) {
        self.compressedWarningBytes = compressedWarningBytes
        self.compressedMaximumBytes = compressedMaximumBytes
        self.entryWarningCount = entryWarningCount
        self.entryMaximumCount = entryMaximumCount
        self.totalDeclaredWarningBytes = totalDeclaredWarningBytes
        self.totalDeclaredMaximumBytes = totalDeclaredMaximumBytes
        self.compressionRatioWarning = compressionRatioWarning
        self.compressionRatioMaximum = compressionRatioMaximum
        self.relevantEntryMaximumBytes = relevantEntryMaximumBytes
        self.relevantTotalMaximumBytes = relevantTotalMaximumBytes
        self.maximumFolderDepth = min(max(maximumFolderDepth, 1), 512)
    }
}

public enum InstagramFollowersSafeArchivePath {
    public static func normalize(_ rawPath: String) throws -> String {
        let cleaned = rawPath.replacingOccurrences(of: "\\", with: "/")
            .precomposedStringWithCanonicalMapping
        guard !cleaned.hasPrefix("/"), !cleaned.hasPrefix("~") else {
            throw InstagramFollowersError.archiveUnsafe(rawPath)
        }
        var result: [Substring] = []
        for component in cleaned.split(separator: "/", omittingEmptySubsequences: true) {
            if component == "." { continue }
            guard component != "..", !component.contains("\0") else {
                throw InstagramFollowersError.archiveUnsafe(rawPath)
            }
            result.append(component)
        }
        let normalized = result.joined(separator: "/")
        guard !normalized.contains(":/") else { throw InstagramFollowersError.archiveUnsafe(rawPath) }
        return normalized
    }

    public static func shouldIgnore(_ path: String) -> Bool {
        let components = path.split(separator: "/")
        let name = components.last.map(String.init) ?? path
        return components.contains("__MACOSX") || name == ".DS_Store" || name.hasPrefix("._")
    }
}

private struct ArchiveRelevantMatch {
    enum Kind { case following, followers(Int) }
    let prefix: String
    let kind: Kind
}

public final class InstagramFollowersArchiveReader: @unchecked Sendable {
    private let url: URL
    private let limits: InstagramFollowersArchiveLimits

    public init(url: URL, limits: InstagramFollowersArchiveLimits = InstagramFollowersArchiveLimits()) {
        self.url = url.standardizedFileURL
        self.limits = limits
    }

    public func catalog() throws -> InstagramFollowersInputCatalog {
        let values: URLResourceValues
        do {
            values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        } catch {
            throw InstagramFollowersError.inputUnreadable(url.lastPathComponent)
        }
        guard values.isRegularFile == true else { throw InstagramFollowersError.inputUnreadable(url.lastPathComponent) }
        let archiveSize = Int64(values.fileSize ?? 0)
        guard archiveSize <= limits.compressedMaximumBytes else {
            throw InstagramFollowersError.archiveLimit("el tamaño comprimido supera el máximo permitido")
        }

        var warnings: [String] = []
        if archiveSize > limits.compressedWarningBytes { warnings.append("El ZIP es muy grande y su inspección puede tardar.") }
        var followingMatches: [(path: String, size: Int64, prefix: String)] = []
        var followerMatches: [(path: String, size: Int64, prefix: String, sequence: Int)] = []
        var totalDeclared: Int64 = 0
        var entryCount = 0
        var seen = Set<String>()
        var seenCaseFolded: [String: String] = [:]

        try withArchive { archive in
            var entry: OpaquePointer?
            while true {
                try Task.checkCancellation()
                let status = archive_read_next_header(archive, &entry)
                if status == ARCHIVE_EOF { break }
                guard status == ARCHIVE_OK else { throw archiveError(archive) }
                guard let entry, let cPath = archive_entry_pathname(entry) else {
                    archive_read_data_skip(archive)
                    continue
                }
                let path = try InstagramFollowersSafeArchivePath.normalize(String(cString: cPath))
                guard path.split(separator: "/").count <= limits.maximumFolderDepth else {
                    throw InstagramFollowersError.archiveLimit("la profundidad de carpetas supera el máximo permitido")
                }

                entryCount += 1
                guard entryCount <= limits.entryMaximumCount else { throw InstagramFollowersError.archiveLimit("contiene demasiadas entradas") }

                let fileType = archive_entry_filetype(entry)
                let isDirectory = fileType == mode_t(0o040000)
                let isSymbolicLink = fileType == mode_t(0o120000) || archive_entry_symlink(entry) != nil
                guard !isSymbolicLink else { throw InstagramFollowersError.archiveUnsafe("enlace simbólico \(path)") }
                guard archive_entry_is_encrypted(entry) <= 0 else { throw InstagramFollowersError.archiveEncrypted }

                let size = max(archive_entry_size(entry), 0)
                let addition = totalDeclared.addingReportingOverflow(size)
                guard !addition.overflow else { throw InstagramFollowersError.archiveLimit("declara un tamaño no válido") }
                totalDeclared = addition.partialValue
                guard totalDeclared <= limits.totalDeclaredMaximumBytes else {
                    throw InstagramFollowersError.archiveLimit("el tamaño total descomprimido es excesivo")
                }

                if path.isEmpty {
                    archive_read_data_skip(archive)
                    continue
                }
                guard seen.insert(path).inserted else { throw InstagramFollowersError.archiveConflict("entrada duplicada: \(path)") }
                let folded = path.lowercased(with: Locale(identifier: "en_US_POSIX"))
                if let prior = seenCaseFolded[folded], prior != path {
                    throw InstagramFollowersError.archiveConflict("rutas que solo se diferencian por mayúsculas: \(prior) y \(path)")
                }
                seenCaseFolded[folded] = path

                if InstagramFollowersSafeArchivePath.shouldIgnore(path) {
                    archive_read_data_skip(archive)
                    continue
                }

                if !isDirectory, let match = relevantMatch(for: path) {
                    guard size <= limits.relevantEntryMaximumBytes else {
                        throw InstagramFollowersError.archiveLimit("«\(path)» supera el tamaño individual permitido")
                    }
                    switch match.kind {
                    case .following:
                        followingMatches.append((path, size, match.prefix))
                    case .followers(let sequence):
                        followerMatches.append((path, size, match.prefix, sequence))
                    }
                }
                archive_read_data_skip(archive)
            }
        }

        guard followingMatches.count <= 1 else { throw InstagramFollowersError.multipleFollowingFiles }
        guard let following = followingMatches.first else { throw InstagramFollowersError.followingNotFound }
        let matchingFollowers = followerMatches.filter { $0.prefix == following.prefix }
        guard !matchingFollowers.isEmpty else { throw InstagramFollowersError.followersNotFound }
        let foreignRelevant = followerMatches.filter { $0.prefix != following.prefix }
        guard foreignRelevant.isEmpty else {
            throw InstagramFollowersError.archiveConflict("hay archivos de seguidores en más de una exportación dentro del mismo ZIP")
        }

        let relevantTotal = matchingFollowers.reduce(following.size) { partial, next in
            let addition = partial.addingReportingOverflow(next.size)
            return addition.overflow ? Int64.max : addition.partialValue
        }
        guard relevantTotal <= limits.relevantTotalMaximumBytes else {
            throw InstagramFollowersError.archiveLimit("los JSON relevantes superan el tamaño conjunto permitido")
        }
        if entryCount > limits.entryWarningCount { warnings.append("El ZIP contiene muchas entradas.") }
        if totalDeclared > limits.totalDeclaredWarningBytes { warnings.append("El tamaño descomprimido declarado es muy elevado.") }
        if archiveSize > 0 {
            let ratio = Double(totalDeclared) / Double(archiveSize)
            guard ratio <= limits.compressionRatioMaximum else { throw InstagramFollowersError.archiveLimit("la relación de compresión es sospechosa") }
            if ratio > limits.compressionRatioWarning { warnings.append("La relación de compresión del ZIP es inusualmente alta.") }
        }

        let orderedFollowers = matchingFollowers.sorted {
            if $0.sequence == $1.sequence { return $0.path < $1.path }
            return $0.sequence < $1.sequence
        }
        return InstagramFollowersInputCatalog(
            inputType: .archive,
            following: .init(name: URL(fileURLWithPath: following.path).lastPathComponent, path: following.path, size: following.size),
            followers: orderedFollowers.map {
                .init(name: URL(fileURLWithPath: $0.path).lastPathComponent, path: $0.path, size: $0.size, sequence: $0.sequence)
            },
            warnings: warnings,
            archiveEntryCount: entryCount,
            archiveCompressedSize: archiveSize,
            archiveDeclaredSize: totalDeclared
        )
    }

    public func readRelevantFiles(catalog: InstagramFollowersInputCatalog) throws -> [String: Data] {
        let wanted = Set([catalog.following.path] + catalog.followers.map(\.path))
        var result: [String: Data] = [:]
        var totalRead: Int64 = 0
        try withArchive { archive in
            var entry: OpaquePointer?
            while true {
                try Task.checkCancellation()
                let status = archive_read_next_header(archive, &entry)
                if status == ARCHIVE_EOF { break }
                guard status == ARCHIVE_OK else { throw archiveError(archive) }
                guard let entry, let cPath = archive_entry_pathname(entry) else {
                    archive_read_data_skip(archive)
                    continue
                }
                let path = try InstagramFollowersSafeArchivePath.normalize(String(cString: cPath))
                guard wanted.contains(path) else {
                    archive_read_data_skip(archive)
                    continue
                }
                guard archive_entry_is_encrypted(entry) <= 0 else { throw InstagramFollowersError.archiveEncrypted }
                let declared = max(archive_entry_size(entry), 0)
                guard declared <= limits.relevantEntryMaximumBytes else {
                    throw InstagramFollowersError.archiveLimit("«\(path)» supera el tamaño individual permitido")
                }
                var data = Data()
                data.reserveCapacity(Int(min(declared, 4 * 1_024 * 1_024)))
                var buffer = [UInt8](repeating: 0, count: 64 * 1_024)
                while true {
                    try Task.checkCancellation()
                    let count = archive_read_data(archive, &buffer, buffer.count)
                    if count == 0 { break }
                    if count < 0 { throw archiveError(archive) }
                    let nextTotal = Int64(data.count) + Int64(count)
                    guard nextTotal <= limits.relevantEntryMaximumBytes else {
                        throw InstagramFollowersError.archiveLimit("«\(path)» supera el tamaño individual permitido")
                    }
                    data.append(buffer, count: count)
                }
                totalRead += Int64(data.count)
                guard totalRead <= limits.relevantTotalMaximumBytes else {
                    throw InstagramFollowersError.archiveLimit("los JSON relevantes superan el tamaño conjunto permitido")
                }
                result[path] = data
                if result.count == wanted.count { break }
            }
        }
        let missing = wanted.subtracting(result.keys)
        guard missing.isEmpty else { throw InstagramFollowersError.inputMissing(missing.sorted().joined(separator: ", ")) }
        return result
    }

    private func relevantMatch(for path: String) -> ArchiveRelevantMatch? {
        let lower = path.lowercased(with: Locale(identifier: "en_US_POSIX"))
        let followingSuffix = "connections/followers_and_following/following.json"
        if lower == followingSuffix || lower.hasSuffix("/" + followingSuffix) {
            let prefixLength = lower.count - followingSuffix.count
            return ArchiveRelevantMatch(prefix: String(lower.prefix(prefixLength)), kind: .following)
        }
        let pattern = #"^(.*?)(connections/followers_and_following/followers_([0-9]+)\.json)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
              let prefixRange = Range(match.range(at: 1), in: lower),
              let sequenceRange = Range(match.range(at: 3), in: lower),
              let sequence = Int(lower[sequenceRange]) else { return nil }
        return ArchiveRelevantMatch(prefix: String(lower[prefixRange]), kind: .followers(sequence))
    }

    private func withArchive<T>(_ body: (OpaquePointer) throws -> T) throws -> T {
        guard let archive = archive_read_new() else { throw InstagramFollowersError.archiveMalformed }
        defer { archive_read_free(archive) }
        archive_read_support_filter_all(archive)
        archive_read_support_format_zip(archive)
        let status = url.path.withCString { archive_read_open_filename(archive, $0, 64 * 1_024) }
        guard status == ARCHIVE_OK else { throw archiveError(archive) }
        return try body(archive)
    }

    private func archiveError(_ archive: OpaquePointer) -> InstagramFollowersError {
        let detail = archive_error_string(archive).map { String(cString: $0) } ?? "ZIP no válido"
        if detail.localizedCaseInsensitiveContains("encrypted") || detail.localizedCaseInsensitiveContains("passphrase") || detail.localizedCaseInsensitiveContains("password") {
            return .archiveEncrypted
        }
        return .archiveMalformed
    }
}
