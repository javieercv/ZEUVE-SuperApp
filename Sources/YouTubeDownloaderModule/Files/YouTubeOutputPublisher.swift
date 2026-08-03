import Foundation

public struct YouTubeOutputPublisher {
    private let fileManager: FileManager
    public init(fileManager: FileManager = .default) { self.fileManager = fileManager }

    public func candidateFiles(in workspace: YouTubeTemporaryWorkspace) throws -> [URL] {
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

    public func publish(files: [URL], to outputFolder: URL, policy: YouTubeConflictPolicy) throws -> [URL] {
        let destinationRoot = try YouTubePathValidator.validateOutputFolder(outputFolder, fileManager: fileManager)
        var published: [URL] = []
        for source in files {
            let sourceValues = try source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard sourceValues.isRegularFile == true,
                  sourceValues.isSymbolicLink != true,
                  (sourceValues.fileSize ?? 0) > 0,
                  !source.pathExtension.lowercased().elementsEqual("part") else { continue }
            let safeName = try YouTubeFilenamePolicy().sanitize(source.lastPathComponent, maximumUTF8Bytes: 220)
            var destination = destinationRoot.appendingPathComponent(safeName)
            if fileManager.fileExists(atPath: destination.path) {
                switch policy {
                case .renameAutomatically: destination = try YouTubeFilenamePolicy().automaticRename(for: destination, fileManager: fileManager)
                case .skip: continue
                case .replaceConfirmed: break
                }
            }
            let staging = destinationRoot.appendingPathComponent(".zeuve-publish-\(UUID().uuidString)")
            try fileManager.copyItem(at: source, to: staging)
            do {
                let sourceSize = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize
                let stagingSize = try staging.resourceValues(forKeys: [.fileSizeKey]).fileSize
                guard sourceSize == stagingSize, (stagingSize ?? 0) > 0 else { throw YouTubeDownloaderError.noPublishedFiles }
                if fileManager.fileExists(atPath: destination.path) {
                    guard policy == .replaceConfirmed else { throw YouTubeDownloaderError.overwriteNotConfirmed }
                    _ = try fileManager.replaceItemAt(destination, withItemAt: staging, backupItemName: nil, options: [])
                } else {
                    try fileManager.moveItem(at: staging, to: destination)
                }
                published.append(destination)
            } catch {
                try? fileManager.removeItem(at: staging)
                throw error
            }
        }
        return published
    }
}
