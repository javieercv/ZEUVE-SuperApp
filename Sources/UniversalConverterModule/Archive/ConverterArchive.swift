import Foundation
import CLibArchive
import ZEUVECore

public struct ConverterArchiveLimits: Codable, Sendable, Equatable {
    public var compressedWarningBytes: Int64
    public var compressedMaximumBytes: Int64
    public var entryWarningCount: Int
    public var entryMaximumCount: Int
    public var totalDeclaredWarningBytes: Int64
    public var totalDeclaredMaximumBytes: Int64
    public var compressionRatioWarning: Double
    public var compressionRatioMaximum: Double
    public var individualEntryMaximumBytes: Int64
    public var maximumFolderDepth: Int

    public init(
        compressedWarningBytes: Int64 = 4 * 1_024 * 1_024 * 1_024,
        compressedMaximumBytes: Int64 = 100 * 1_024 * 1_024 * 1_024,
        entryWarningCount: Int = 20_000,
        entryMaximumCount: Int = 100_000,
        totalDeclaredWarningBytes: Int64 = 50 * 1_024 * 1_024 * 1_024,
        totalDeclaredMaximumBytes: Int64 = 500 * 1_024 * 1_024 * 1_024,
        compressionRatioWarning: Double = 250,
        compressionRatioMaximum: Double = 1_000,
        individualEntryMaximumBytes: Int64 = 100 * 1_024 * 1_024 * 1_024,
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
        self.individualEntryMaximumBytes = individualEntryMaximumBytes
        self.maximumFolderDepth = min(max(maximumFolderDepth, 1), 512)
    }

    private enum CodingKeys: String, CodingKey {
        case compressedWarningBytes, compressedMaximumBytes, entryWarningCount, entryMaximumCount
        case totalDeclaredWarningBytes, totalDeclaredMaximumBytes, compressionRatioWarning, compressionRatioMaximum
        case individualEntryMaximumBytes, maximumFolderDepth
    }

    public init(from decoder: Decoder) throws {
        let defaults = ConverterArchiveLimits()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            compressedWarningBytes: try container.decodeIfPresent(Int64.self, forKey: .compressedWarningBytes) ?? defaults.compressedWarningBytes,
            compressedMaximumBytes: try container.decodeIfPresent(Int64.self, forKey: .compressedMaximumBytes) ?? defaults.compressedMaximumBytes,
            entryWarningCount: try container.decodeIfPresent(Int.self, forKey: .entryWarningCount) ?? defaults.entryWarningCount,
            entryMaximumCount: try container.decodeIfPresent(Int.self, forKey: .entryMaximumCount) ?? defaults.entryMaximumCount,
            totalDeclaredWarningBytes: try container.decodeIfPresent(Int64.self, forKey: .totalDeclaredWarningBytes) ?? defaults.totalDeclaredWarningBytes,
            totalDeclaredMaximumBytes: try container.decodeIfPresent(Int64.self, forKey: .totalDeclaredMaximumBytes) ?? defaults.totalDeclaredMaximumBytes,
            compressionRatioWarning: try container.decodeIfPresent(Double.self, forKey: .compressionRatioWarning) ?? defaults.compressionRatioWarning,
            compressionRatioMaximum: try container.decodeIfPresent(Double.self, forKey: .compressionRatioMaximum) ?? defaults.compressionRatioMaximum,
            individualEntryMaximumBytes: try container.decodeIfPresent(Int64.self, forKey: .individualEntryMaximumBytes) ?? defaults.individualEntryMaximumBytes,
            maximumFolderDepth: try container.decodeIfPresent(Int.self, forKey: .maximumFolderDepth) ?? defaults.maximumFolderDepth
        )
    }
}

public struct ConverterArchiveEntry: Sendable, Equatable, Hashable {
    public let path: String
    public let size: Int64
    public let isDirectory: Bool

    public init(path: String, size: Int64, isDirectory: Bool) {
        self.path = path
        self.size = size
        self.isDirectory = isDirectory
    }
}

public struct ConverterArchiveCatalog: Sendable, Equatable {
    public let entries: [ConverterArchiveEntry]
    public let archiveSize: Int64
    public let totalDeclaredSize: Int64
    public let warnings: [String]

    public init(entries: [ConverterArchiveEntry], archiveSize: Int64, totalDeclaredSize: Int64, warnings: [String]) {
        self.entries = entries
        self.archiveSize = archiveSize
        self.totalDeclaredSize = totalDeclaredSize
        self.warnings = warnings
    }
}

public enum ConverterSafePath {
    public static func normalize(_ rawPath: String) throws -> String {
        let cleaned = rawPath.replacingOccurrences(of: "\\", with: "/")
            .precomposedStringWithCanonicalMapping
        guard !cleaned.hasPrefix("/"), !cleaned.hasPrefix("~") else {
            throw UniversalConverterError.unsafePath(rawPath)
        }
        var result: [Substring] = []
        for component in cleaned.split(separator: "/", omittingEmptySubsequences: true) {
            if component == "." { continue }
            guard component != "..", !component.contains("\0") else {
                throw UniversalConverterError.unsafePath(rawPath)
            }
            result.append(component)
        }
        let normalized = result.joined(separator: "/")
        guard !normalized.contains(":/") else { throw UniversalConverterError.unsafePath(rawPath) }
        return normalized
    }

    public static func shouldIgnore(_ path: String) -> Bool {
        let components = path.split(separator: "/")
        let name = components.last.map(String.init) ?? path
        return components.contains("__MACOSX") || name == ".DS_Store" || name.hasPrefix("._")
    }

    public static func isInside(_ child: URL, root: URL) -> Bool {
        let normalizedRoot = root.resolvingSymlinksInPath().standardizedFileURL
        let normalizedChild = child.resolvingSymlinksInPath().standardizedFileURL
        let prefix = normalizedRoot.path.hasSuffix("/") ? normalizedRoot.path : normalizedRoot.path + "/"
        return normalizedChild.path == normalizedRoot.path || normalizedChild.path.hasPrefix(prefix)
    }
}

public final class ConverterArchiveReader: @unchecked Sendable {
    private let url: URL
    private let limits: ConverterArchiveLimits
    private let fileManager: FileManager
    private let password: String?

    public init(
        url: URL,
        limits: ConverterArchiveLimits = ConverterArchiveLimits(),
        fileManager: FileManager = .default,
        password: String? = nil
    ) {
        self.url = url.standardizedFileURL
        self.limits = limits
        self.fileManager = fileManager
        let cleaned = password?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.password = cleaned?.isEmpty == false ? cleaned : nil
    }

    public func catalog() throws -> ConverterArchiveCatalog {
        let fingerprint = try FileFingerprint.read(from: url, fileManager: fileManager)
        let archiveSize = fingerprint.size
        guard archiveSize <= limits.compressedMaximumBytes else {
            throw UniversalConverterError.archiveLimit("el tamaño comprimido supera el máximo estructural")
        }
        var warnings: [String] = []
        if archiveSize > limits.compressedWarningBytes {
            warnings.append("El ZIP es muy grande y su inspección puede tardar.")
        }
        var entries: [ConverterArchiveEntry] = []
        var total: Int64 = 0
        var seen = Set<String>()
        try withArchive { archive in
            var entry: OpaquePointer?
            while true {
                if Task.isCancelled { throw CancellationError() }
                let status = archive_read_next_header(archive, &entry)
                if status == ARCHIVE_EOF { break }
                guard status == ARCHIVE_OK else { throw archiveError(archive) }
                guard let entry, let cPath = archive_entry_pathname(entry) else {
                    archive_read_data_skip(archive)
                    continue
                }
                let path = try ConverterSafePath.normalize(String(cString: cPath))
                guard path.split(separator: "/").count <= limits.maximumFolderDepth else {
                    throw UniversalConverterError.archiveLimit("la profundidad de carpetas supera el máximo configurado")
                }
                if path.isEmpty || ConverterSafePath.shouldIgnore(path) {
                    archive_read_data_skip(archive)
                    continue
                }
                guard seen.insert(path).inserted else {
                    throw UniversalConverterError.archiveLimit("contiene una entrada duplicada: \(path)")
                }
                let fileType = archive_entry_filetype(entry)
                let isDirectory = fileType == mode_t(0o040000)
                let isSymbolicLink = fileType == mode_t(0o120000) || archive_entry_symlink(entry) != nil
                guard !isSymbolicLink else {
                    throw UniversalConverterError.archiveLimit("contiene un enlace simbólico: \(path)")
                }
                let encrypted = archive_entry_is_encrypted(entry) > 0
                if encrypted {
                    guard password != nil else { throw UniversalConverterError.archivePasswordRequired }
                    var probe: UInt8 = 0
                    let count = archive_read_data(archive, &probe, 1)
                    if count < 0 { throw archiveError(archive) }
                }
                let size = max(archive_entry_size(entry), 0)
                guard size <= limits.individualEntryMaximumBytes else {
                    throw UniversalConverterError.archiveLimit("«\(path)» supera el tamaño individual permitido")
                }
                let addition = total.addingReportingOverflow(size)
                guard !addition.overflow else { throw UniversalConverterError.archiveLimit("declara un tamaño no válido") }
                total = addition.partialValue
                guard total <= limits.totalDeclaredMaximumBytes else {
                    throw UniversalConverterError.archiveLimit("el tamaño total descomprimido es excesivo")
                }
                entries.append(.init(path: path, size: size, isDirectory: isDirectory))
                guard entries.count <= limits.entryMaximumCount else {
                    throw UniversalConverterError.archiveLimit("contiene demasiadas entradas")
                }
                archive_read_data_skip(archive)
            }
        }
        if entries.count > limits.entryWarningCount {
            warnings.append("El ZIP contiene muchas entradas.")
        }
        if total > limits.totalDeclaredWarningBytes {
            warnings.append("El tamaño total descomprimido declarado es muy elevado.")
        }
        if archiveSize > 0 {
            let ratio = Double(total) / Double(archiveSize)
            guard ratio <= limits.compressionRatioMaximum else {
                throw UniversalConverterError.archiveLimit("la relación de compresión es sospechosa")
            }
            if ratio > limits.compressionRatioWarning {
                warnings.append("La relación de compresión es inusualmente alta.")
            }
        }
        return ConverterArchiveCatalog(entries: entries, archiveSize: archiveSize, totalDeclaredSize: total, warnings: warnings)
    }

    public func readPrefix(path rawPath: String, maximumBytes: Int = 64 * 1_024) throws -> Data {
        let wanted = try ConverterSafePath.normalize(rawPath)
        guard maximumBytes > 0 else { return Data() }
        var result: Data?
        try withArchive { archive in
            var entry: OpaquePointer?
            while true {
                if Task.isCancelled { throw CancellationError() }
                let status = archive_read_next_header(archive, &entry)
                if status == ARCHIVE_EOF { break }
                guard status == ARCHIVE_OK else { throw archiveError(archive) }
                guard let entry, let cPath = archive_entry_pathname(entry) else {
                    archive_read_data_skip(archive)
                    continue
                }
                let path = try ConverterSafePath.normalize(String(cString: cPath))
                guard path.split(separator: "/").count <= limits.maximumFolderDepth else {
                    throw UniversalConverterError.archiveLimit("la profundidad de carpetas supera el máximo configurado")
                }
                guard path == wanted else {
                    archive_read_data_skip(archive)
                    continue
                }
                if archive_entry_is_encrypted(entry) > 0, password == nil {
                    throw UniversalConverterError.archivePasswordRequired
                }
                var data = Data()
                data.reserveCapacity(min(maximumBytes, Int(max(archive_entry_size(entry), 0))))
                var buffer = [UInt8](repeating: 0, count: min(64 * 1_024, maximumBytes))
                while data.count < maximumBytes {
                    let request = min(buffer.count, maximumBytes - data.count)
                    let count = archive_read_data(archive, &buffer, request)
                    if count == 0 { break }
                    if count < 0 { throw archiveError(archive) }
                    data.append(buffer, count: count)
                }
                result = data
                break
            }
        }
        guard let result else { throw UniversalConverterError.sourceMissing(wanted) }
        return result
    }

    public func extract(path rawPath: String, to destination: URL) throws {
        let wanted = try ConverterSafePath.normalize(rawPath)
        guard ConverterSafePath.isInside(destination, root: destination.deletingLastPathComponent()) else {
            throw UniversalConverterError.unsafePath(destination.path)
        }
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        let staging = destination.deletingLastPathComponent()
            .appendingPathComponent(".zeuve-extract-\(UUID().uuidString)", isDirectory: false)
        var found = false
        do {
            guard fileManager.createFile(atPath: staging.path, contents: nil) else {
                throw UniversalConverterError.processFailed("no se ha podido crear el archivo temporal de extracción")
            }
            let output = try FileHandle(forWritingTo: staging)
            defer { try? output.close() }
            try withArchive { archive in
                var entry: OpaquePointer?
                while true {
                    if Task.isCancelled { throw CancellationError() }
                    let status = archive_read_next_header(archive, &entry)
                    if status == ARCHIVE_EOF { break }
                    guard status == ARCHIVE_OK else { throw archiveError(archive) }
                    guard let entry, let cPath = archive_entry_pathname(entry) else {
                        archive_read_data_skip(archive)
                        continue
                    }
                    let path = try ConverterSafePath.normalize(String(cString: cPath))
                    guard path == wanted else {
                        archive_read_data_skip(archive)
                        continue
                    }
                    found = true
                    if archive_entry_is_encrypted(entry) > 0, password == nil {
                        throw UniversalConverterError.archivePasswordRequired
                    }
                    let declared = max(archive_entry_size(entry), 0)
                    guard declared <= limits.individualEntryMaximumBytes else {
                        throw UniversalConverterError.archiveLimit("«\(path)» supera el tamaño individual permitido")
                    }
                    var total: Int64 = 0
                    var buffer = [UInt8](repeating: 0, count: 64 * 1_024)
                    while true {
                        if Task.isCancelled { throw CancellationError() }
                        let count = archive_read_data(archive, &buffer, buffer.count)
                        if count == 0 { break }
                        if count < 0 { throw archiveError(archive) }
                        total += Int64(count)
                        guard total <= limits.individualEntryMaximumBytes else {
                            throw UniversalConverterError.archiveLimit("«\(path)» supera el tamaño individual permitido")
                        }
                        try output.write(contentsOf: Data(buffer[0..<count]))
                    }
                    break
                }
            }
            guard found else { throw UniversalConverterError.sourceMissing(wanted) }
            try output.synchronize()
            if fileManager.fileExists(atPath: destination.path) { try fileManager.removeItem(at: destination) }
            try fileManager.moveItem(at: staging, to: destination)
        } catch {
            try? fileManager.removeItem(at: staging)
            throw error
        }
    }

    private func withArchive<T>(_ body: (OpaquePointer) throws -> T) throws -> T {
        guard let archive = archive_read_new() else {
            throw UniversalConverterError.archiveDamaged("no se ha podido inicializar libarchive")
        }
        defer { archive_read_free(archive) }
        archive_read_support_filter_all(archive)
        archive_read_support_format_zip(archive)
        if let password {
            let passphraseStatus = password.withCString { archive_read_add_passphrase(archive, $0) }
            guard passphraseStatus == ARCHIVE_OK else {
                throw UniversalConverterError.archivePasswordIncorrect
            }
        }
        let status = url.path.withCString { archive_read_open_filename(archive, $0, 64 * 1_024) }
        guard status == ARCHIVE_OK else { throw archiveError(archive) }
        return try body(archive)
    }

    private func archiveError(_ archive: OpaquePointer) -> UniversalConverterError {
        let detail = archive_error_string(archive).map { String(cString: $0) } ?? "ZIP no válido"
        if detail.localizedCaseInsensitiveContains("encrypted") || detail.localizedCaseInsensitiveContains("passphrase") || detail.localizedCaseInsensitiveContains("password") {
            return password == nil ? .archivePasswordRequired : .archivePasswordIncorrect
        }
        return .archiveDamaged(detail)
    }
}

public struct ConverterZIPWriter: Sendable {
    public init() {}

    public func createZIP(from root: URL, at destination: URL, fileManager: FileManager = .default) throws {
        guard ConverterSafePath.isInside(destination, root: destination.deletingLastPathComponent()) else {
            throw UniversalConverterError.unsafePath(destination.path)
        }
        let normalizedRoot = root.resolvingSymlinksInPath().standardizedFileURL
        let files = try regularFilesRecursively(in: normalizedRoot, fileManager: fileManager)
        let staging = destination.deletingLastPathComponent()
            .appendingPathComponent(".zeuve-zip-\(UUID().uuidString).zip")
        try? fileManager.removeItem(at: staging)
        guard let archive = archive_write_new() else {
            throw UniversalConverterError.processFailed("no se ha podido inicializar la creación del ZIP")
        }
        defer { archive_write_free(archive) }
        guard archive_write_set_format_zip(archive) == ARCHIVE_OK,
              archive_write_add_filter_none(archive) == ARCHIVE_OK else {
            throw writerError(archive)
        }
        let openStatus = staging.path.withCString { archive_write_open_filename(archive, $0) }
        guard openStatus == ARCHIVE_OK else { throw writerError(archive) }
        do {
            for file in files {
                if Task.isCancelled { throw CancellationError() }
                let relative = try archiveRelativePath(for: file, root: normalizedRoot)
                let safeRelative = try ConverterSafePath.normalize(relative)
                let values = try file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                guard let entry = archive_entry_new() else {
                    throw UniversalConverterError.processFailed("no se ha podido crear una entrada del ZIP")
                }
                defer { archive_entry_free(entry) }
                safeRelative.withCString { archive_entry_set_pathname(entry, $0) }
                archive_entry_set_size(entry, Int64(values.fileSize ?? 0))
                archive_entry_set_filetype(entry, UInt32(0o100000))
                archive_entry_set_perm(entry, mode_t(0o644))
                if let date = values.contentModificationDate {
                    let seconds = floor(date.timeIntervalSince1970)
                    let nanoseconds = (date.timeIntervalSince1970 - seconds) * 1_000_000_000
                    archive_entry_set_mtime(entry, time_t(seconds), Int(nanoseconds))
                }
                guard archive_write_header(archive, entry) == ARCHIVE_OK else { throw writerError(archive) }
                let handle = try FileHandle(forReadingFrom: file)
                defer { try? handle.close() }
                while true {
                    if Task.isCancelled { throw CancellationError() }
                    let data = try handle.read(upToCount: 64 * 1_024) ?? Data()
                    if data.isEmpty { break }
                    let written = data.withUnsafeBytes { buffer in
                        archive_write_data(archive, buffer.baseAddress, data.count)
                    }
                    guard written == data.count else { throw writerError(archive) }
                }
            }
            guard archive_write_close(archive) == ARCHIVE_OK else { throw writerError(archive) }
            if fileManager.fileExists(atPath: destination.path) { try fileManager.removeItem(at: destination) }
            try fileManager.moveItem(at: staging, to: destination)
        } catch {
            _ = archive_write_close(archive)
            try? fileManager.removeItem(at: staging)
            throw error
        }
    }

    private func archiveRelativePath(for file: URL, root: URL) throws -> String {
        let normalizedRoot = root.resolvingSymlinksInPath().standardizedFileURL
        let normalizedFile = file.resolvingSymlinksInPath().standardizedFileURL
        let rootPath = normalizedRoot.path.hasSuffix("/") ? normalizedRoot.path : normalizedRoot.path + "/"
        guard normalizedFile.path.hasPrefix(rootPath) else {
            throw UniversalConverterError.unsafePath(file.path)
        }
        let relative = String(normalizedFile.path.dropFirst(rootPath.count))
        guard !relative.isEmpty else {
            throw UniversalConverterError.unsafePath(file.path)
        }
        return relative
    }

    private func regularFilesRecursively(in root: URL, fileManager: FileManager) throws -> [URL] {
        var files: [URL] = []
        func visit(_ directory: URL) throws {
            if Task.isCancelled { throw CancellationError() }
            for child in try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .isHiddenKey],
                options: [.skipsHiddenFiles]
            ) {
                let values = try child.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .isHiddenKey])
                if values.isSymbolicLink == true { continue }
                if values.isDirectory == true { try visit(child) }
                else if values.isRegularFile == true { files.append(child) }
            }
        }
        try visit(root)
        return files.sorted { $0.path < $1.path }
    }

    private func writerError(_ archive: OpaquePointer) -> UniversalConverterError {
        let detail = archive_error_string(archive).map { String(cString: $0) } ?? "error desconocido"
        return .processFailed("no se ha podido crear el ZIP: \(detail)")
    }
}
