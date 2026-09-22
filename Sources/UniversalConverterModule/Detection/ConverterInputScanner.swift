import Foundation
import ZEUVECore

public struct ConverterScanResult: Sendable, Equatable {
    public let items: [ConverterInputItem]
    public let warnings: [String]
    public let rejected: [String]

    public init(items: [ConverterInputItem], warnings: [String], rejected: [String]) {
        self.items = items
        self.warnings = warnings
        self.rejected = rejected
    }
}

private struct ConverterScanCacheKey: Hashable, Sendable {
    let path: String
    let size: Int64
    let modificationTimeNanoseconds: Int64
    let recursive: Bool
    let archivePasswordToken: Int
}

public actor ConverterInputScanner {
    private let detector: ConverterFormatDetector
    private let fileManager: FileManager
    private let archiveLimits: ConverterArchiveLimits
    private var cache: [ConverterScanCacheKey: ConverterScanResult] = [:]

    public init(
        detector: ConverterFormatDetector = ConverterFormatDetector(),
        fileManager: FileManager = .default,
        archiveLimits: ConverterArchiveLimits = ConverterArchiveLimits()
    ) {
        self.detector = detector
        self.fileManager = fileManager
        self.archiveLimits = archiveLimits
    }

    public func scan(urls: [URL], recursive: Bool = true, archivePassword: String? = nil) throws -> ConverterScanResult {
        var items: [ConverterInputItem] = []
        var warnings: [String] = []
        var rejected: [String] = []
        var seen = Set<String>()

        for url in urls {
            try Task.checkCancellation()
            let normalized = url.standardizedFileURL
            guard normalized.isFileURL else {
                rejected.append("\(url.lastPathComponent): la entrada no es un archivo local.")
                continue
            }
            guard fileManager.fileExists(atPath: normalized.path) else {
                rejected.append("\(url.lastPathComponent): ya no existe.")
                continue
            }
            let values = try normalized.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .isHiddenKey])
            if values.isSymbolicLink == true {
                rejected.append("\(url.lastPathComponent): los enlaces simbólicos no se procesan.")
                continue
            }
            let fingerprint = try FileFingerprint.read(from: normalized, fileManager: fileManager)
            let key = ConverterScanCacheKey(
                path: normalized.path,
                size: fingerprint.size,
                modificationTimeNanoseconds: fingerprint.modificationTimeNanoseconds,
                recursive: recursive,
                archivePasswordToken: archivePassword?.hashValue ?? 0
            )
            if let cached = cache[key] {
                append(cached, items: &items, warnings: &warnings, rejected: &rejected, seen: &seen)
                continue
            }

            let result: ConverterScanResult
            if values.isDirectory == true {
                result = try scanDirectory(normalized, recursive: recursive)
            } else if values.isRegularFile == true {
                result = try scanFile(normalized, fingerprint: fingerprint, archivePassword: archivePassword)
            } else {
                result = ConverterScanResult(items: [], warnings: [], rejected: ["\(url.lastPathComponent): no es un archivo regular."])
            }
            cache[key] = result
            append(result, items: &items, warnings: &warnings, rejected: &rejected, seen: &seen)
        }

        return ConverterScanResult(
            items: items.sorted { lhs, rhs in
                lhs.relativePath.localizedStandardCompare(rhs.relativePath) == .orderedAscending
            },
            warnings: unique(warnings),
            rejected: unique(rejected)
        )
    }

    public func clearCache() {
        cache.removeAll(keepingCapacity: false)
    }

    public func invalidate(url: URL) {
        cache = cache.filter { $0.key.path != url.standardizedFileURL.path }
    }

    private func scanFile(_ url: URL, fingerprint: FileFingerprint, archivePassword: String?) throws -> ConverterScanResult {
        let detection = try detector.detectDetailed(url: url)
        if detection.detectedFormat == .zip {
            return try scanArchive(url, fingerprint: fingerprint, archivePassword: archivePassword)
        }
        guard detection.detectedFormat != .unknown else {
            return ConverterScanResult(items: [], warnings: detection.warning.map { [$0] } ?? [], rejected: ["\(url.lastPathComponent): formato no reconocido."])
        }
        if let reason = Self.unsupportedReason(for: detection.detectedFormat) {
            return ConverterScanResult(items: [], warnings: detection.warning.map { [$0] } ?? [], rejected: ["\(url.lastPathComponent): \(reason)"])
        }
        let item = ConverterInputItem(
            kind: .file,
            sourceURL: url,
            relativePath: url.lastPathComponent,
            displayName: url.lastPathComponent,
            size: fingerprint.size,
            format: detection.detectedFormat,
            detection: detection,
            fingerprint: fingerprint,
            sourceRootName: url.deletingPathExtension().lastPathComponent
        )
        return ConverterScanResult(items: [item], warnings: detection.warning.map { ["\(url.lastPathComponent): \($0)"] } ?? [], rejected: [])
    }

    private func scanDirectory(_ directory: URL, recursive: Bool) throws -> ConverterScanResult {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .isHiddenKey, .fileSizeKey]
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return ConverterScanResult(items: [], warnings: [], rejected: ["No se ha podido leer \(directory.lastPathComponent)."])
        }
        var items: [ConverterInputItem] = []
        var warnings: [String] = []
        var rejected: [String] = []
        let rootPrefix = directory.path.hasSuffix("/") ? directory.path : directory.path + "/"
        while let child = enumerator.nextObject() as? URL {
            try Task.checkCancellation()
            let values = try child.resourceValues(forKeys: Set(keys))
            if values.isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }
            if values.isDirectory == true {
                if !recursive, child.deletingLastPathComponent() != directory { enumerator.skipDescendants() }
                continue
            }
            guard values.isRegularFile == true else { continue }
            let relative = child.path.hasPrefix(rootPrefix) ? String(child.path.dropFirst(rootPrefix.count)) : child.lastPathComponent
            let fingerprint = try FileFingerprint.read(from: child, fileManager: fileManager)
            let detection = try detector.detectDetailed(url: child)
            let format = detection.detectedFormat
            if format == .unknown || format == .zip {
                rejected.append("\(relative): formato no reconocido o ZIP anidado no procesado.")
                continue
            }
            if let reason = Self.unsupportedReason(for: format) {
                rejected.append("\(relative): \(reason)")
                continue
            }
            if let warning = detection.warning { warnings.append("\(relative): \(warning)") }
            items.append(ConverterInputItem(
                kind: .file,
                sourceURL: child,
                relativePath: relative,
                displayName: child.lastPathComponent,
                size: fingerprint.size,
                format: format,
                detection: detection,
                fingerprint: fingerprint,
                sourceRootName: directory.lastPathComponent
            ))
        }
        return ConverterScanResult(items: items, warnings: warnings, rejected: rejected)
    }

    private func scanArchive(_ url: URL, fingerprint: FileFingerprint, archivePassword: String?) throws -> ConverterScanResult {
        let reader = ConverterArchiveReader(url: url, limits: archiveLimits, fileManager: fileManager, password: archivePassword)
        let catalog = try reader.catalog()
        var items: [ConverterInputItem] = []
        var warnings = catalog.warnings
        var rejected: [String] = []
        let rootName = url.deletingPathExtension().lastPathComponent
        for entry in catalog.entries where !entry.isDirectory {
            try Task.checkCancellation()
            let sample = try reader.readPrefix(path: entry.path)
            let detection: ConverterFormatDetection
            let extensionFormat = ConverterFormat.from(pathExtension: URL(fileURLWithPath: entry.path).pathExtension)
            if Self.isZIPContainerFamily(extensionFormat), sample.starts(with: [0x50, 0x4B]) {
                detection = try inspectNestedContainer(reader: reader, entryPath: entry.path)
            } else {
                detection = detector.detectDetailed(sample: sample, filename: entry.path)
            }
            let format = detection.detectedFormat
            if format == .unknown || format == .zip {
                rejected.append("\(entry.path): formato no reconocido o ZIP anidado no procesado.")
                continue
            }
            if let reason = Self.unsupportedReason(for: format) {
                rejected.append("\(entry.path): \(reason)")
                continue
            }
            if let warning = detection.warning { warnings.append("\(entry.path): \(warning)") }
            items.append(ConverterInputItem(
                kind: .archiveEntry,
                sourceURL: url,
                archiveEntryPath: entry.path,
                relativePath: entry.path,
                displayName: URL(fileURLWithPath: entry.path).lastPathComponent,
                size: entry.size,
                format: format,
                detection: detection,
                fingerprint: fingerprint,
                sourceRootName: rootName
            ))
        }
        return ConverterScanResult(items: items, warnings: warnings, rejected: rejected)
    }

    private func inspectNestedContainer(reader: ConverterArchiveReader, entryPath: String) throws -> ConverterFormatDetection {
        let temporaryRoot = fileManager.temporaryDirectory
            .appendingPathComponent("ZEUVE-Converter-NestedInspection-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }
        let filename = URL(fileURLWithPath: entryPath).lastPathComponent
        let destination = temporaryRoot.appendingPathComponent(filename)
        try reader.extract(path: entryPath, to: destination)
        try Task.checkCancellation()
        return try detector.detectDetailed(url: destination)
    }

    private static func isZIPContainerFamily(_ format: ConverterFormat) -> Bool {
        format == .epub
    }

    private static func unsupportedReason(for format: ConverterFormat) -> String? {
        switch format {
        case .epub, .mobi, .azw3, .fb2:
            return "formato de libro electrónico no compatible (\(format.displayName))."
        case .eps:
            return "el formato EPS se reconoce, pero ya no es compatible con el Conversor."
        default:
            return nil
        }
    }

    private func append(
        _ result: ConverterScanResult,
        items: inout [ConverterInputItem],
        warnings: inout [String],
        rejected: inout [String],
        seen: inout Set<String>
    ) {
        for item in result.items {
            let key = item.sourceURL.path + "\u{0}" + (item.archiveEntryPath ?? "")
            if seen.insert(key).inserted { items.append(item) }
        }
        warnings.append(contentsOf: result.warnings)
        rejected.append(contentsOf: result.rejected)
    }

    private func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
