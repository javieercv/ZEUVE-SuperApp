import Foundation
import ZEUVECore

public struct ConverterWorkspace: Sendable, Equatable {
    public let operationID: UUID
    public let root: URL
    public let inputs: URL
    public let generated: URL
    public let profiles: URL
    public let metadata: URL
    private let marker: URL

    public init(operationID: UUID, baseDirectory: URL? = nil, fileManager: FileManager = .default) throws {
        let base = try baseDirectory ?? AppPaths.applicationSupport(fileManager: fileManager)
            .appendingPathComponent("Temporary/UniversalConverter", isDirectory: true)
        let root = base.appendingPathComponent(operationID.uuidString, isDirectory: true)
        self.operationID = operationID
        self.root = root
        inputs = root.appendingPathComponent("inputs", isDirectory: true)
        generated = root.appendingPathComponent("generated", isDirectory: true)
        profiles = root.appendingPathComponent("profiles", isDirectory: true)
        metadata = root.appendingPathComponent("metadata", isDirectory: true)
        marker = root.appendingPathComponent("operation.json")
        for directory in [root, inputs, generated, profiles, metadata] {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let data = try JSONEncoder().encode(Marker(operationID: operationID, createdAt: Date()))
        try data.write(to: marker, options: .atomic)
    }


    @discardableResult
    public static func cleanupAbandoned(
        olderThan maximumAge: TimeInterval,
        baseDirectory: URL? = nil,
        now: Date = Date(),
        fileManager: FileManager = .default
    ) throws -> Int {
        let base = try baseDirectory ?? AppPaths.applicationSupport(fileManager: fileManager)
            .appendingPathComponent("Temporary/UniversalConverter", isDirectory: true)
        guard fileManager.fileExists(atPath: base.path) else { return 0 }
        var removed = 0
        let children = try fileManager.contentsOfDirectory(
            at: base,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        for child in children {
            try Task.checkCancellation()
            let values = try child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true, values.isSymbolicLink != true, UUID(uuidString: child.lastPathComponent) != nil else { continue }
            let marker = child.appendingPathComponent("operation.json")
            guard let data = try? Data(contentsOf: marker), let decoded = try? JSONDecoder().decode(Marker.self, from: data), decoded.operationID.uuidString == child.lastPathComponent else { continue }
            guard now.timeIntervalSince(decoded.createdAt) >= maximumAge else { continue }
            let workspace = try ConverterWorkspace(existingRoot: child, marker: decoded, fileManager: fileManager)
            try workspace.clean(fileManager: fileManager)
            removed += 1
        }
        return removed
    }

    private init(existingRoot root: URL, marker decoded: Marker, fileManager: FileManager) throws {
        operationID = decoded.operationID
        self.root = root.standardizedFileURL
        inputs = self.root.appendingPathComponent("inputs", isDirectory: true)
        generated = self.root.appendingPathComponent("generated", isDirectory: true)
        profiles = self.root.appendingPathComponent("profiles", isDirectory: true)
        metadata = self.root.appendingPathComponent("metadata", isDirectory: true)
        marker = self.root.appendingPathComponent("operation.json")
        try verify(fileManager: fileManager)
    }

    public func verify(fileManager: FileManager = .default) throws {
        let decoded = try JSONDecoder().decode(Marker.self, from: Data(contentsOf: marker))
        let rootPath = root.standardizedFileURL.path + "/"
        guard decoded.operationID == operationID,
              root.lastPathComponent == operationID.uuidString,
              inputs.standardizedFileURL.path.hasPrefix(rootPath),
              generated.standardizedFileURL.path.hasPrefix(rootPath) else {
            throw UniversalConverterError.unsafePath(root.path)
        }
    }

    public func clean(fileManager: FileManager = .default) throws {
        try verify(fileManager: fileManager)
        if fileManager.fileExists(atPath: root.path) { try removeOwnedTree(root, fileManager: fileManager) }
    }

    public func inputURL(for item: ConverterInputItem, archivePassword: String? = nil, fileManager: FileManager = .default) throws -> URL {
        if item.kind == .file { return item.sourceURL }
        guard let entry = item.archiveEntryPath else { throw UniversalConverterError.sourceMissing(item.displayName) }
        let safe = try ConverterSafePath.normalize(entry)
        let destination = inputs.appendingPathComponent(item.id.uuidString, isDirectory: true).appendingPathComponent(safe)
        guard ConverterSafePath.isInside(destination, root: inputs) else { throw UniversalConverterError.unsafePath(safe) }
        if !fileManager.fileExists(atPath: destination.path) {
            try ConverterArchiveReader(url: item.sourceURL, fileManager: fileManager, password: archivePassword).extract(path: safe, to: destination)
        }
        return destination
    }


    public func visibleFrameRecordURL(itemID: UUID) -> URL {
        metadata.appendingPathComponent("visible-frame-\(itemID.uuidString).json")
    }

    @discardableResult
    public static func recoverAbandonedVisibleFrameOutputs(
        baseDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> [URL] {
        let base = try baseDirectory ?? AppPaths.applicationSupport(fileManager: fileManager)
            .appendingPathComponent("Temporary/UniversalConverter", isDirectory: true)
        guard fileManager.fileExists(atPath: base.path) else { return [] }
        let coordinator = VisibleFrameOutputCoordinator()
        var recovered: [URL] = []
        let children = try fileManager.contentsOfDirectory(
            at: base,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )
        for child in children {
            let values = try child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true,
                  values.isSymbolicLink != true,
                  UUID(uuidString: child.lastPathComponent) != nil else { continue }
            let markerURL = child.appendingPathComponent("operation.json")
            guard let markerData = try? Data(contentsOf: markerURL),
                  let marker = try? JSONDecoder().decode(Marker.self, from: markerData),
                  marker.operationID.uuidString == child.lastPathComponent else { continue }
            let metadata = child.appendingPathComponent("metadata", isDirectory: true)
            guard let records = try? fileManager.contentsOfDirectory(
                at: metadata,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            var recoveredAny = false
            for record in records where record.lastPathComponent.hasPrefix("visible-frame-") && record.pathExtension == "json" {
                let recordValues = try record.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                guard recordValues.isRegularFile == true, recordValues.isSymbolicLink != true else { continue }
                if let output = try? coordinator.recover(recordURL: record, fileManager: fileManager) {
                    recovered.append(output)
                    recoveredAny = true
                }
            }
            if recoveredAny,
               let workspace = try? ConverterWorkspace(existingRoot: child, marker: marker, fileManager: fileManager) {
                try? workspace.clean(fileManager: fileManager)
            }
        }
        return recovered
    }

    public func generatedURL(relativePath: String, fileManager: FileManager = .default) throws -> URL {
        let safe = try ConverterSafePath.normalize(relativePath)
        let result = generated.appendingPathComponent(safe)
        guard ConverterSafePath.isInside(result, root: generated) else { throw UniversalConverterError.unsafePath(relativePath) }
        try fileManager.createDirectory(at: result.deletingLastPathComponent(), withIntermediateDirectories: true)
        return result
    }

    private func removeOwnedTree(_ url: URL, fileManager: FileManager) throws {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        if values.isDirectory == true && values.isSymbolicLink != true {
            for child in try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]) {
                try removeOwnedTree(child, fileManager: fileManager)
            }
        }
        try fileManager.removeItem(at: url)
    }

    private struct Marker: Codable { let operationID: UUID; let createdAt: Date }
}
