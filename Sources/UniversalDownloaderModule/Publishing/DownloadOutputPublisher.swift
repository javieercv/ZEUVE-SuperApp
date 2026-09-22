import Foundation

public struct DownloadOutputPublisher {
    private let fileManager: FileManager
    public init(fileManager: FileManager = .default) { self.fileManager = fileManager }

    public func candidateFiles(in workspace: DownloadWorkspace) throws -> [URL] {
        try workspace.verify(fileManager: fileManager)
        let root = workspace.download.resolvingSymlinksInPath().standardizedFileURL
        let prefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        let files = try fileManager.contentsOfDirectory(
            at: workspace.download,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        return try files.filter { url in
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            let resolved = url.resolvingSymlinksInPath().standardizedFileURL
            return values.isRegularFile == true
                && values.isSymbolicLink != true
                && resolved.path.hasPrefix(prefix)
                && (values.fileSize ?? 0) > 0
                && url.pathExtension.lowercased() != "part"
                && !url.lastPathComponent.hasSuffix(".ytdl")
        }
    }

    public func publish(files: [URL], to outputFolder: URL, policy: DownloadConflictPolicy) throws -> [URL] {
        let destinationRoot = try DownloadPathValidator.validateOutputFolder(outputFolder, fileManager: fileManager)
        var published: [URL] = []
        for source in files {
            let sourceValues = try source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard sourceValues.isRegularFile == true,
                  sourceValues.isSymbolicLink != true,
                  let sourceSize = sourceValues.fileSize,
                  sourceSize > 0,
                  source.pathExtension.lowercased() != "part" else { continue }

            let safeName = try DownloadFilenamePolicy().sanitize(source.lastPathComponent, maximumUTF8Bytes: 220)
            var destination = destinationRoot.appendingPathComponent(safeName)
            if fileManager.fileExists(atPath: destination.path) {
                switch policy {
                case .renameAutomatically:
                    destination = try DownloadFilenamePolicy().automaticRename(for: destination, fileManager: fileManager)
                case .skip:
                    continue
                case .replaceConfirmed:
                    break
                }
            }

            let staging = destinationRoot.appendingPathComponent(".zeuve-publish-\(UUID().uuidString)")
            let canMoveAtomically = sameVolume(source, destinationRoot)
            do {
                if canMoveAtomically {
                    try fileManager.moveItem(at: source, to: staging)
                } else {
                    try fileManager.copyItem(at: source, to: staging)
                }

                let stagingSize = try staging.resourceValues(forKeys: [.fileSizeKey]).fileSize
                guard stagingSize == sourceSize, (stagingSize ?? 0) > 0 else {
                    throw UniversalDownloaderError.noPublishedFiles
                }

                if fileManager.fileExists(atPath: destination.path) {
                    guard policy == .replaceConfirmed else { throw UniversalDownloaderError.overwriteNotConfirmed }
                    _ = try fileManager.replaceItemAt(destination, withItemAt: staging, backupItemName: nil, options: [])
                } else {
                    try fileManager.moveItem(at: staging, to: destination)
                }
                published.append(destination)
            } catch {
                if fileManager.fileExists(atPath: staging.path) {
                    if canMoveAtomically, !fileManager.fileExists(atPath: source.path) {
                        try? fileManager.moveItem(at: staging, to: source)
                    } else {
                        try? fileManager.removeItem(at: staging)
                    }
                }
                throw error
            }
        }
        return published
    }

    /// Un movimiento dentro del mismo volumen es un renombrado atómico y evita
    /// leer y escribir de nuevo todo el vídeo. Si el sistema no expone el volumen,
    /// se utiliza la copia segura tradicional.
    public func sameVolume(_ source: URL, _ destinationFolder: URL) -> Bool {
        do {
            let sourceValues = try source.resourceValues(forKeys: [.volumeIdentifierKey, .volumeURLKey])
            let destinationValues = try destinationFolder.resourceValues(forKeys: [.volumeIdentifierKey, .volumeURLKey])
            if let lhs = sourceValues.volumeIdentifier as? AnyHashable,
               let rhs = destinationValues.volumeIdentifier as? AnyHashable {
                return lhs == rhs
            }
            if let lhs = sourceValues.volume, let rhs = destinationValues.volume {
                return lhs.standardizedFileURL == rhs.standardizedFileURL
            }
        } catch {
            return false
        }
        return false
    }
}
