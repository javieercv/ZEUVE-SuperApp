import Foundation

public enum CleanerFileInspection {
    public static func fingerprint(at url: URL, fileManager: FileManager = .default) -> CleanerFileFingerprint? {
        let path = url.standardizedFileURL.path
        guard let attrs = try? fileManager.attributesOfItem(atPath: path) else { return nil }
        let type = attrs[.type] as? FileAttributeType
        let isLink = type == .typeSymbolicLink
        let isDirectory = type == .typeDirectory
        let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        let allocated = (attrs[.systemSize] as? NSNumber)?.int64Value
        let inode = (attrs[.systemFileNumber] as? NSNumber)?.uint64Value
        let modification = attrs[.modificationDate] as? Date
        if isLink { return .init(isDirectory: false, isSymbolicLink: true, logicalSize: size, allocatedSize: allocated, modificationDate: modification, inode: inode) }
        if isDirectory {
            let totals = recursiveSize(at: url, fileManager: fileManager)
            return .init(isDirectory: true, isSymbolicLink: false, logicalSize: totals.logical, allocatedSize: totals.allocated, modificationDate: modification, inode: inode)
        }
        return .init(isDirectory: false, isSymbolicLink: false, logicalSize: size, allocatedSize: allocated, modificationDate: modification, inode: inode)
    }

    public static func recursiveSize(at root: URL, fileManager: FileManager = .default) -> (logical: Int64, allocated: Int64?) {
        if let attrs = try? fileManager.attributesOfItem(atPath: root.path), attrs[.type] as? FileAttributeType == .typeSymbolicLink {
            return ((attrs[.size] as? NSNumber)?.int64Value ?? 0, (attrs[.systemSize] as? NSNumber)?.int64Value)
        }
        var logical: Int64 = 0; var allocated: Int64 = 0; var hasAllocated = false
        guard let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: [.isSymbolicLinkKey, .isRegularFileKey], options: [], errorHandler: { _, _ in true }) else {
            if let attrs = try? fileManager.attributesOfItem(atPath: root.path) { return ((attrs[.size] as? NSNumber)?.int64Value ?? 0, (attrs[.systemSize] as? NSNumber)?.int64Value) }
            return (0, nil)
        }
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey])
            if values?.isSymbolicLink == true { enumerator.skipDescendants(); continue }
            guard values?.isRegularFile == true, let attrs = try? fileManager.attributesOfItem(atPath: url.path) else { continue }
            logical += (attrs[.size] as? NSNumber)?.int64Value ?? 0
            if let value = (attrs[.systemSize] as? NSNumber)?.int64Value { allocated += value; hasAllocated = true }
        }
        return (logical, hasAllocated ? allocated : nil)
    }
}
