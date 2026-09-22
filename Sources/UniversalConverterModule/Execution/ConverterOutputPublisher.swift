import Foundation

public struct ConverterOutputPublisher: Sendable {
    private let filenamePolicy: ConverterFilenamePolicy

    public init(filenamePolicy: ConverterFilenamePolicy = ConverterFilenamePolicy()) {
        self.filenamePolicy = filenamePolicy
    }

    public func publish(
        source: URL,
        relativePath: String,
        to outputRoot: URL,
        policy: ConverterConflictPolicy,
        protectedOriginals: [URL] = [],
        protectedCanonicalPaths: Set<String>? = nil,
        fileManager: FileManager = .default
    ) throws -> URL? {
        let root = outputRoot.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw UniversalConverterError.outputFolderMissing
        }
        guard fileManager.isWritableFile(atPath: root.path) else {
            throw UniversalConverterError.permissionDenied(root.path)
        }

        let safe = try ConverterSafePath.normalize(relativePath)
        var destination = root.appendingPathComponent(safe).standardizedFileURL
        guard ConverterSafePath.isInside(destination, root: root) else { throw UniversalConverterError.unsafePath(relativePath) }
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)

        let protected = protectedCanonicalPaths ?? Self.protectedCanonicalPaths(for: protectedOriginals)
        if protected.contains(canonicalPath(destination)) {
            destination = try automaticRename(destination, fileManager: fileManager, protectedPaths: protected)
        } else if fileManager.fileExists(atPath: destination.path) {
            switch policy {
            case .skip: return nil
            case .replaceConfirmed: break
            case .renameAutomatically:
                destination = try automaticRename(destination, fileManager: fileManager, protectedPaths: protected)
            }
        }

        guard !protected.contains(canonicalPath(destination)) else {
            throw UniversalConverterError.outputConflict("La salida coincide con un archivo original protegido.")
        }

        let sourceValues = try source.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey])
        guard sourceValues.isSymbolicLink != true,
              sourceValues.isRegularFile == true || sourceValues.isDirectory == true else {
            throw UniversalConverterError.invalidResult("El resultado no es un archivo o carpeta publicable.")
        }
        if sourceValues.isRegularFile == true, (sourceValues.fileSize ?? 0) <= 0 {
            throw UniversalConverterError.invalidResult("El resultado está vacío.")
        }

        let parent = destination.deletingLastPathComponent()
        let staging = parent.appendingPathComponent(".zeuve-publish-\(UUID().uuidString)")
        try fileManager.copyItem(at: source, to: staging)
        do {
            if fileManager.fileExists(atPath: destination.path) {
                guard policy == .replaceConfirmed else { throw UniversalConverterError.overwriteNotConfirmed }
                let backupName = ".zeuve-backup-\(UUID().uuidString)"
                _ = try fileManager.replaceItemAt(destination, withItemAt: staging, backupItemName: backupName, options: [])
                let backup = parent.appendingPathComponent(backupName)
                try? fileManager.removeItem(at: backup)
            } else {
                try fileManager.moveItem(at: staging, to: destination)
            }
            return destination
        } catch {
            try? fileManager.removeItem(at: staging)
            throw error
        }
    }

    private func automaticRename(_ url: URL, fileManager: FileManager, protectedPaths: Set<String>) throws -> URL {
        let directory = url.deletingLastPathComponent()
        let ext = url.pathExtension
        var base = url.deletingPathExtension().lastPathComponent
        if !base.localizedCaseInsensitiveContains("converted") {
            base += " - converted"
        }
        for number in 1...100_000 {
            let numberedBase = number == 1 ? base : "\(base) \(number)"
            let name = ext.isEmpty ? numberedBase : "\(numberedBase).\(ext)"
            let candidate = directory.appendingPathComponent(try filenamePolicy.sanitize(name))
            if !fileManager.fileExists(atPath: candidate.path), !protectedPaths.contains(canonicalPath(candidate)) {
                return candidate
            }
        }
        throw UniversalConverterError.outputConflict(url.lastPathComponent)
    }

    public static func protectedCanonicalPaths(for urls: [URL]) -> Set<String> {
        Set(urls.map { canonicalPath($0) })
    }

    private static func canonicalPath(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private func canonicalPath(_ url: URL) -> String { Self.canonicalPath(url) }
}
