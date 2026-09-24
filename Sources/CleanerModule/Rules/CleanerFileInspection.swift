import Foundation

public enum CleanerFileInspection {
    public static func fingerprint(at url: URL, fileManager: FileManager = .default, shouldCancel: (() -> Bool)? = nil) -> CleanerFileFingerprint? {
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
            let totals = recursiveSize(at: url, fileManager: fileManager, shouldCancel: shouldCancel)
            if shouldCancel?() == true { return nil }
            return .init(isDirectory: true, isSymbolicLink: false, logicalSize: totals.logical, allocatedSize: totals.allocated, modificationDate: modification, inode: inode)
        }
        return .init(isDirectory: false, isSymbolicLink: false, logicalSize: size, allocatedSize: allocated, modificationDate: modification, inode: inode)
    }

    public static func recursiveSize(at root: URL, fileManager: FileManager = .default, shouldCancel: (() -> Bool)? = nil) -> (logical: Int64, allocated: Int64?) {
        if let attrs = try? fileManager.attributesOfItem(atPath: root.path), attrs[.type] as? FileAttributeType == .typeSymbolicLink {
            return ((attrs[.size] as? NSNumber)?.int64Value ?? 0, (attrs[.systemSize] as? NSNumber)?.int64Value)
        }
        var logical: Int64 = 0; var allocated: Int64 = 0; var hasAllocated = false
        guard let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: [.isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey], options: [], errorHandler: { _, _ in true }) else {
            if let attrs = try? fileManager.attributesOfItem(atPath: root.path) { return ((attrs[.size] as? NSNumber)?.int64Value ?? 0, (attrs[.systemSize] as? NSNumber)?.int64Value) }
            return (0, nil)
        }
        for case let url as URL in enumerator {
            if shouldCancel?() == true { break }
            let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
            if values?.isSymbolicLink == true { enumerator.skipDescendants(); continue }
            guard values?.isRegularFile == true else { continue }
            let fallback = values?.fileSize == nil ? try? fileManager.attributesOfItem(atPath: url.path) : nil
            logical += values?.fileSize.map(Int64.init) ?? (fallback?[.size] as? NSNumber)?.int64Value ?? 0
            if let value = values?.totalFileAllocatedSize ?? values?.fileAllocatedSize { allocated += Int64(value); hasAllocated = true }
            else if let value = (fallback?[.systemSize] as? NSNumber)?.int64Value { allocated += value; hasAllocated = true }
        }
        return (logical, hasAllocated ? allocated : nil)
    }
}
