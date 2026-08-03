import Foundation
import ZEUVECore

public struct YouTubeTemporaryWorkspace: Sendable, Equatable {
    public let operationID: UUID
    public let root: URL
    public let download: URL
    public let temporary: URL
    public let metadata: URL
    private let marker: URL

    public init(operationID: UUID, baseDirectory: URL? = nil, fileManager: FileManager = .default) throws {
        let base = try baseDirectory ?? AppPaths.applicationSupport(fileManager: fileManager)
            .appendingPathComponent("Temporary/YouTube", isDirectory: true)
        let root = base.appendingPathComponent(operationID.uuidString, isDirectory: true)
        self.operationID = operationID
        self.root = root
        self.download = root.appendingPathComponent("download", isDirectory: true)
        self.temporary = root.appendingPathComponent("temporary", isDirectory: true)
        self.metadata = root.appendingPathComponent("metadata", isDirectory: true)
        self.marker = root.appendingPathComponent("operation.json")
        for directory in [root, download, temporary, metadata] {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let data = try JSONEncoder().encode(Marker(operationID: operationID, createdAt: Date()))
        try data.write(to: marker, options: .atomic)
    }

    public func verify(fileManager: FileManager = .default) throws {
        let data = try Data(contentsOf: marker)
        let decoded = try JSONDecoder().decode(Marker.self, from: data)
        guard decoded.operationID == operationID,
              root.lastPathComponent == operationID.uuidString,
              download.standardizedFileURL.path.hasPrefix(root.standardizedFileURL.path + "/") else {
            throw YouTubeDownloaderError.invalidTemporaryWorkspace
        }
    }

    public func clean(fileManager: FileManager = .default) throws {
        try verify(fileManager: fileManager)
        guard fileManager.fileExists(atPath: root.path) else { return }
        try removeOwnedTree(at: root, fileManager: fileManager)
    }

    private func removeOwnedTree(at url: URL, fileManager: FileManager) throws {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        if values.isDirectory == true && values.isSymbolicLink != true {
            for child in try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: []
            ) {
                try removeOwnedTree(at: child, fileManager: fileManager)
            }
        }
        try fileManager.removeItem(at: url)
    }

    public static func abandoned(baseDirectory: URL, olderThan date: Date, fileManager: FileManager = .default) -> [URL] {
        guard let children = try? fileManager.contentsOfDirectory(at: baseDirectory, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else { return [] }
        return children.filter { child in
            guard UUID(uuidString: child.lastPathComponent) != nil,
                  let values = try? child.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modified = values.contentModificationDate,
                  modified < date,
                  fileManager.fileExists(atPath: child.appendingPathComponent("operation.json").path) else { return false }
            return true
        }
    }

    private struct Marker: Codable { let operationID: UUID; let createdAt: Date }
}
