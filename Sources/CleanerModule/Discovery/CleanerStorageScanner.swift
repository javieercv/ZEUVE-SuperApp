import Foundation

public final class CleanerStorageScanner: @unchecked Sendable {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func scan(root: URL, maximumDepth: Int = 4) -> CleanerStorageNode? {
        node(root, depth: 0, maxDepth: max(0, maximumDepth))
    }

    private func node(_ url: URL, depth: Int, maxDepth: Int) -> CleanerStorageNode? {
        guard !Task.isCancelled,
              let attrs = try? fileManager.attributesOfItem(atPath: url.path) else { return nil }
        let type = attrs[.type] as? FileAttributeType
        if type == .typeSymbolicLink {
            let fingerprint = CleanerFileInspection.fingerprint(at: url, fileManager: fileManager)
            return .init(url: url, logicalSize: fingerprint?.logicalSize ?? 0, allocatedSize: fingerprint?.allocatedSize, isDirectory: false)
        }

        let isDirectory = type == .typeDirectory
        if isDirectory,
           depth < maxDepth,
           let children = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            let nodes = children.compactMap { child -> CleanerStorageNode? in
                guard !Task.isCancelled else { return nil }
                return node(child, depth: depth + 1, maxDepth: maxDepth)
            }.sorted { $0.logicalSize > $1.logicalSize }
            guard !Task.isCancelled else { return nil }
            let allocated = nodes.compactMap(\.allocatedSize)
            return .init(
                url: url,
                logicalSize: nodes.reduce(0) { $0 + $1.logicalSize },
                allocatedSize: allocated.isEmpty ? nil : allocated.reduce(0, +),
                isDirectory: true,
                children: nodes
            )
        }

        let fingerprint = CleanerFileInspection.fingerprint(at: url, fileManager: fileManager)
        return .init(url: url, logicalSize: fingerprint?.logicalSize ?? 0, allocatedSize: fingerprint?.allocatedSize, isDirectory: isDirectory)
    }
}
