import Foundation
import CLibArchive

public struct ChatArchiveEntry: Sendable, Equatable, Hashable {
    public let path: String
    public let size: Int64
    public let isDirectory: Bool
    public let isSymbolicLink: Bool
    public let isEncrypted: Bool
    public init(path: String, size: Int64, isDirectory: Bool, isSymbolicLink: Bool, isEncrypted: Bool) {
        self.path = path; self.size = size; self.isDirectory = isDirectory
        self.isSymbolicLink = isSymbolicLink; self.isEncrypted = isEncrypted
    }
}

public struct ChatArchiveCatalog: Sendable, Equatable {
    public let entries: [ChatArchiveEntry]
    public let totalDeclaredSize: Int64
    public let archiveSize: Int64
    public let warnings: [ChatImportWarning]
}

public enum SafeArchivePath {
    public static func normalize(_ path: String) throws -> String {
        let cleaned = path.replacingOccurrences(of: "\\", with: "/")
            .precomposedStringWithCanonicalMapping
        guard !cleaned.hasPrefix("/"), !cleaned.hasPrefix("~") else {
            throw ChatAnalyzerError.archiveUnsafe(path)
        }
        let components = cleaned.split(separator: "/", omittingEmptySubsequences: true)
        guard !components.isEmpty else { return "" }
        var result: [Substring] = []
        for component in components {
            if component == "." { continue }
            guard component != "..", !component.contains("\0") else {
                throw ChatAnalyzerError.archiveUnsafe(path)
            }
            result.append(component)
        }
        let normalized = result.joined(separator: "/")
        guard !normalized.contains(":/") else { throw ChatAnalyzerError.archiveUnsafe(path) }
        return normalized
    }

    public static func shouldIgnore(_ path: String) -> Bool {
        let components = path.split(separator: "/")
        let name = components.last.map(String.init) ?? path
        return components.contains("__MACOSX") || name == ".DS_Store" || name.hasPrefix("._")
    }
}

/// Seguro para concurrencia porque sus únicas propiedades son inmutables y cada lectura crea su propio manejador de libarchive.
public final class ChatArchiveReader: @unchecked Sendable {
    private let url: URL
    private let limits: ChatArchiveLimits

    public init(url: URL, limits: ChatArchiveLimits) {
        self.url = url.standardizedFileURL
        self.limits = limits
    }

    public func catalog() throws -> ChatArchiveCatalog {
        let archiveSize = try FileFingerprintSnapshot.read(url).size
        if archiveSize > limits.compressedMaximumBytes {
            throw ChatAnalyzerError.archiveLimit("tamaño comprimido superior al máximo permitido")
        }
        var warnings: [ChatImportWarning] = []
        if archiveSize > limits.compressedWarningBytes {
            warnings.append(.init(code: "archive-large", message: "El ZIP es muy grande y el análisis puede tardar."))
        }

        var entries: [ChatArchiveEntry] = []
        var total: Int64 = 0
        var seen = Set<String>()
        try withArchive { archive in
            var entry: OpaquePointer?
            while true {
                let status = archive_read_next_header(archive, &entry)
                if status == ARCHIVE_EOF { break }
                guard status == ARCHIVE_OK else { throw archiveError(archive) }
                guard let entry, let cPath = archive_entry_pathname(entry) else {
                    archive_read_data_skip(archive); continue
                }
                let rawPath = String(cString: cPath)
                let path = try SafeArchivePath.normalize(rawPath)
                if SafeArchivePath.shouldIgnore(path) { archive_read_data_skip(archive); continue }
                if !seen.insert(path).inserted {
                    warnings.append(.init(code: "duplicate-entry", message: "El ZIP contiene una entrada duplicada: \(path)."))
                }
                let fileType = archive_entry_filetype(entry)
                let isDirectory = fileType == mode_t(0o040000)
                let isSymbolicLink = fileType == mode_t(0o120000) || archive_entry_symlink(entry) != nil
                let encrypted = archive_entry_is_encrypted(entry) > 0
                if isSymbolicLink { throw ChatAnalyzerError.archiveUnsafe("enlace simbólico \(path)") }
                if encrypted { throw ChatAnalyzerError.archiveEncrypted }
                let size = max(archive_entry_size(entry), 0)
                let addition = total.addingReportingOverflow(size)
                total = addition.overflow ? Int64.max : addition.partialValue
                entries.append(.init(path: path, size: size, isDirectory: isDirectory, isSymbolicLink: isSymbolicLink, isEncrypted: encrypted))
                if entries.count > limits.entryMaximumCount {
                    throw ChatAnalyzerError.archiveLimit("demasiadas entradas")
                }
                if total > limits.totalDeclaredMaximumBytes {
                    throw ChatAnalyzerError.archiveLimit("tamaño total descomprimido excesivo")
                }
                archive_read_data_skip(archive)
            }
        }
        if entries.count > limits.entryWarningCount {
            warnings.append(.init(code: "many-entries", message: "El ZIP contiene muchas entradas."))
        }
        if total > limits.totalDeclaredWarningBytes {
            warnings.append(.init(code: "declared-size", message: "El tamaño descomprimido declarado es muy elevado."))
        }
        if archiveSize > 0 {
            let ratio = Double(total) / Double(archiveSize)
            if ratio > limits.compressionRatioMaximum { throw ChatAnalyzerError.archiveLimit("relación de compresión sospechosa") }
            if ratio > limits.compressionRatioWarning {
                warnings.append(.init(code: "compression-ratio", message: "La relación de compresión del ZIP es inusualmente alta."))
            }
        }
        return ChatArchiveCatalog(entries: entries, totalDeclaredSize: total, archiveSize: archiveSize, warnings: warnings)
    }

    public func read(paths: Set<String>, maximumBytesPerEntry: Int64? = nil) throws -> [String: Data] {
        guard !paths.isEmpty else { return [:] }
        let wanted = Set(try paths.map(SafeArchivePath.normalize))
        var result: [String: Data] = [:]
        try withArchive { archive in
            var entry: OpaquePointer?
            while true {
                let status = archive_read_next_header(archive, &entry)
                if status == ARCHIVE_EOF { break }
                guard status == ARCHIVE_OK else { throw archiveError(archive) }
                guard let entry, let cPath = archive_entry_pathname(entry) else { archive_read_data_skip(archive); continue }
                let path = try SafeArchivePath.normalize(String(cString: cPath))
                guard wanted.contains(path) else { archive_read_data_skip(archive); continue }
                if archive_entry_is_encrypted(entry) > 0 { throw ChatAnalyzerError.archiveEncrypted }
                let declared = max(archive_entry_size(entry), 0)
                let limit = maximumBytesPerEntry ?? limits.individualRelevantMaximumBytes
                if declared > limit { throw ChatAnalyzerError.archiveLimit("«\(path)» supera el tamaño individual permitido") }
                var data = Data()
                data.reserveCapacity(Int(min(declared, 4 * 1_024 * 1_024)))
                var buffer = [UInt8](repeating: 0, count: 64 * 1_024)
                while true {
                    let count = archive_read_data(archive, &buffer, buffer.count)
                    if count == 0 { break }
                    if count < 0 { throw archiveError(archive) }
                    if Int64(data.count) + Int64(count) > limit {
                        throw ChatAnalyzerError.archiveLimit("«\(path)» supera el tamaño individual permitido")
                    }
                    data.append(buffer, count: count)
                }
                result[path] = data
                if result.count == wanted.count { break }
            }
        }
        return result
    }

    /// Lee únicamente el comienzo de cada entrada solicitada. El límite indica cuánto se devuelve,
    /// no el tamaño máximo permitido para la entrada completa.
    public func readPrefixes(paths: Set<String>, maximumBytesPerEntry: Int64) throws -> [String: Data] {
        guard !paths.isEmpty, maximumBytesPerEntry > 0 else { return [:] }
        let wanted = Set(try paths.map(SafeArchivePath.normalize))
        var result: [String: Data] = [:]
        try withArchive { archive in
            var entry: OpaquePointer?
            while true {
                let status = archive_read_next_header(archive, &entry)
                if status == ARCHIVE_EOF { break }
                guard status == ARCHIVE_OK else { throw archiveError(archive) }
                guard let entry, let cPath = archive_entry_pathname(entry) else { archive_read_data_skip(archive); continue }
                let path = try SafeArchivePath.normalize(String(cString: cPath))
                guard wanted.contains(path) else { archive_read_data_skip(archive); continue }
                if archive_entry_is_encrypted(entry) > 0 { throw ChatAnalyzerError.archiveEncrypted }
                let declared = max(archive_entry_size(entry), 0)
                var data = Data()
                data.reserveCapacity(Int(min(declared, maximumBytesPerEntry)))
                var buffer = [UInt8](repeating: 0, count: 64 * 1_024)
                while Int64(data.count) < maximumBytesPerEntry {
                    let remaining = maximumBytesPerEntry - Int64(data.count)
                    let request = Int(min(Int64(buffer.count), remaining))
                    let count = archive_read_data(archive, &buffer, request)
                    if count == 0 { break }
                    if count < 0 { throw archiveError(archive) }
                    data.append(buffer, count: count)
                }
                if Int64(data.count) >= maximumBytesPerEntry { archive_read_data_skip(archive) }
                result[path] = data
                if result.count == wanted.count { break }
            }
        }
        return result
    }

    /// Entrega una entrada por bloques sin acumularla completa en memoria.
    public func stream(
        path rawPath: String,
        maximumBytesPerEntry: Int64? = nil,
        chunkSize: Int = 64 * 1_024,
        _ consume: (Data) throws -> Void
    ) throws {
        let wanted = try SafeArchivePath.normalize(rawPath)
        var found = false
        try withArchive { archive in
            var entry: OpaquePointer?
            while true {
                let status = archive_read_next_header(archive, &entry)
                if status == ARCHIVE_EOF { break }
                guard status == ARCHIVE_OK else { throw archiveError(archive) }
                guard let entry, let cPath = archive_entry_pathname(entry) else { archive_read_data_skip(archive); continue }
                let path = try SafeArchivePath.normalize(String(cString: cPath))
                guard path == wanted else { archive_read_data_skip(archive); continue }
                found = true
                if archive_entry_is_encrypted(entry) > 0 { throw ChatAnalyzerError.archiveEncrypted }
                let declared = max(archive_entry_size(entry), 0)
                if let maximumBytesPerEntry, declared > maximumBytesPerEntry {
                    throw ChatAnalyzerError.archiveLimit("«\(path)» supera el tamaño individual permitido")
                }
                var total: Int64 = 0
                var buffer = [UInt8](repeating: 0, count: max(1, chunkSize))
                while true {
                    let count = archive_read_data(archive, &buffer, buffer.count)
                    if count == 0 { break }
                    if count < 0 { throw archiveError(archive) }
                    let addition = total.addingReportingOverflow(Int64(count))
                    if addition.overflow { throw ChatAnalyzerError.archiveLimit("«\(path)» tiene un tamaño no válido") }
                    total = addition.partialValue
                    if let maximumBytesPerEntry, total > maximumBytesPerEntry {
                        throw ChatAnalyzerError.archiveLimit("«\(path)» supera el tamaño individual permitido")
                    }
                    try consume(Data(buffer[0..<count]))
                }
                break
            }
        }
        if !found { throw ChatAnalyzerError.unreadableFile(URL(fileURLWithPath: wanted).lastPathComponent) }
    }

    private func withArchive<T>(_ body: (OpaquePointer) throws -> T) throws -> T {
        guard let archive = archive_read_new() else { throw ChatAnalyzerError.archiveDamaged }
        defer { archive_read_free(archive) }
        archive_read_support_filter_all(archive)
        archive_read_support_format_zip(archive)
        let openStatus = url.path.withCString { archive_read_open_filename(archive, $0, 64 * 1_024) }
        guard openStatus == ARCHIVE_OK else { throw archiveError(archive) }
        return try body(archive)
    }

    private func archiveError(_ archive: OpaquePointer) -> ChatAnalyzerError {
        let detail = archive_error_string(archive).map { String(cString: $0) } ?? "ZIP no válido"
        if detail.localizedCaseInsensitiveContains("encrypted") || detail.localizedCaseInsensitiveContains("passphrase") {
            return .archiveEncrypted
        }
        return .archiveUnsafe(detail)
    }
}
