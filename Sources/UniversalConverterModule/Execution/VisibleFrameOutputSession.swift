import Foundation

public struct VisibleFrameOutputSession: Codable, Sendable, Equatable {
    public let operationID: UUID
    public let workingURL: URL
    public let finalURL: URL
    public let recordURL: URL
    public let conflictPolicy: ConverterConflictPolicy

    public init(
        operationID: UUID,
        workingURL: URL,
        finalURL: URL,
        recordURL: URL,
        conflictPolicy: ConverterConflictPolicy
    ) {
        self.operationID = operationID
        self.workingURL = workingURL.standardizedFileURL
        self.finalURL = finalURL.standardizedFileURL
        self.recordURL = recordURL.standardizedFileURL
        self.conflictPolicy = conflictPolicy
    }
}

/// Gestiona la carpeta visible utilizada durante vídeo → fotogramas.
/// Los resultados se escriben en el mismo volumen de salida para evitar una copia completa final.
public struct VisibleFrameOutputCoordinator: Sendable {
    private let filenamePolicy: ConverterFilenamePolicy
    private static let activeMarkerName = ".zeuve-frame-operation.json"
    private static let incompleteMarkerName = ".zeuve-frame-incomplete.json"

    public init(filenamePolicy: ConverterFilenamePolicy = ConverterFilenamePolicy()) {
        self.filenamePolicy = filenamePolicy
    }

    public func prepare(
        operationID: UUID,
        relativePath: String,
        outputRoot: URL,
        policy: ConverterConflictPolicy,
        protectedCanonicalPaths: Set<String>,
        recordURL: URL,
        fileManager: FileManager = .default
    ) throws -> VisibleFrameOutputSession? {
        let root = outputRoot.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw UniversalConverterError.outputFolderMissing
        }
        guard fileManager.isWritableFile(atPath: root.path) else {
            throw UniversalConverterError.permissionDenied(root.path)
        }

        let safe = try ConverterSafePath.normalize(relativePath)
        var finalURL = root.appendingPathComponent(safe).standardizedFileURL
        guard ConverterSafePath.isInside(finalURL, root: root) else {
            throw UniversalConverterError.unsafePath(relativePath)
        }
        try fileManager.createDirectory(at: finalURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        if protectedCanonicalPaths.contains(canonicalPath(finalURL)) {
            finalURL = try automaticRename(finalURL, fileManager: fileManager, protectedPaths: protectedCanonicalPaths)
        } else if fileManager.fileExists(atPath: finalURL.path) {
            switch policy {
            case .skip:
                return nil
            case .replaceConfirmed:
                break
            case .renameAutomatically:
                finalURL = try automaticRename(finalURL, fileManager: fileManager, protectedPaths: protectedCanonicalPaths)
            }
        }

        let parent = finalURL.deletingLastPathComponent()
        let processingName = try filenamePolicy.sanitize("\(finalURL.lastPathComponent) - Procesando", maximumUTF8Bytes: 220)
        let workingURL = try uniqueDirectory(
            parent.appendingPathComponent(processingName, isDirectory: true),
            fileManager: fileManager
        )
        try fileManager.createDirectory(at: workingURL, withIntermediateDirectories: false)

        let session = VisibleFrameOutputSession(
            operationID: operationID,
            workingURL: workingURL,
            finalURL: finalURL,
            recordURL: recordURL,
            conflictPolicy: policy
        )
        do {
            let data = try JSONEncoder().encode(session)
            try fileManager.createDirectory(at: recordURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: recordURL, options: .atomic)
            try data.write(to: workingURL.appendingPathComponent(Self.activeMarkerName), options: .atomic)
            return session
        } catch {
            try? fileManager.removeItem(at: workingURL)
            throw error
        }
    }

    public func complete(
        _ session: VisibleFrameOutputSession,
        protectedCanonicalPaths: Set<String>,
        fileManager: FileManager = .default
    ) throws -> URL {
        guard fileManager.fileExists(atPath: session.workingURL.path) else {
            throw UniversalConverterError.invalidResult("La carpeta de fotogramas en curso ya no existe.")
        }
        try? fileManager.removeItem(at: session.workingURL.appendingPathComponent(Self.activeMarkerName))

        var destination = session.finalURL
        if protectedCanonicalPaths.contains(canonicalPath(destination)) {
            destination = try automaticRename(destination, fileManager: fileManager, protectedPaths: protectedCanonicalPaths)
        }

        if fileManager.fileExists(atPath: destination.path) {
            switch session.conflictPolicy {
            case .replaceConfirmed:
                try replaceDirectory(at: destination, with: session.workingURL, fileManager: fileManager)
            case .renameAutomatically:
                destination = try automaticRename(destination, fileManager: fileManager, protectedPaths: protectedCanonicalPaths)
                try fileManager.moveItem(at: session.workingURL, to: destination)
            case .skip:
                throw UniversalConverterError.outputConflict("El resultado apareció mientras se extraían los fotogramas.")
            }
        } else {
            try fileManager.moveItem(at: session.workingURL, to: destination)
        }
        try? fileManager.removeItem(at: session.recordURL)
        return destination
    }

    @discardableResult
    public func preserveIncomplete(
        _ session: VisibleFrameOutputSession,
        fileManager: FileManager = .default
    ) throws -> URL? {
        guard fileManager.fileExists(atPath: session.workingURL.path) else {
            try? fileManager.removeItem(at: session.recordURL)
            return nil
        }
        try? fileManager.removeItem(at: session.workingURL.appendingPathComponent(Self.activeMarkerName))

        let parent = session.finalURL.deletingLastPathComponent()
        let incompleteName = try filenamePolicy.sanitize("\(session.finalURL.lastPathComponent) - Incompleto", maximumUTF8Bytes: 220)
        let incompleteURL = try uniqueDirectory(
            parent.appendingPathComponent(incompleteName, isDirectory: true),
            fileManager: fileManager
        )
        try fileManager.moveItem(at: session.workingURL, to: incompleteURL)
        let timingCSV = incompleteURL.appendingPathComponent("tiempos.csv")
        if fileManager.fileExists(atPath: timingCSV.path) {
            let partialCSV = incompleteURL.appendingPathComponent("tiempos_parcial.csv")
            if fileManager.fileExists(atPath: partialCSV.path) { try? fileManager.removeItem(at: partialCSV) }
            try? fileManager.moveItem(at: timingCSV, to: partialCSV)
        }
        let marker = IncompleteMarker(operationID: session.operationID, preservedAt: Date(), intendedFinalURL: session.finalURL)
        if let data = try? JSONEncoder().encode(marker) {
            try? data.write(to: incompleteURL.appendingPathComponent(Self.incompleteMarkerName), options: .atomic)
        }
        try? fileManager.removeItem(at: session.recordURL)
        return incompleteURL
    }

    @discardableResult
    public func recover(recordURL: URL, fileManager: FileManager = .default) throws -> URL? {
        let data = try Data(contentsOf: recordURL)
        let session = try JSONDecoder().decode(VisibleFrameOutputSession.self, from: data)
        return try preserveIncomplete(session, fileManager: fileManager)
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
            let candidate = directory.appendingPathComponent(try filenamePolicy.sanitize(name), isDirectory: ext.isEmpty)
            if !fileManager.fileExists(atPath: candidate.path), !protectedPaths.contains(canonicalPath(candidate)) {
                return candidate
            }
        }
        throw UniversalConverterError.outputConflict(url.lastPathComponent)
    }

    private func uniqueDirectory(_ preferred: URL, fileManager: FileManager) throws -> URL {
        if !fileManager.fileExists(atPath: preferred.path) { return preferred }
        let parent = preferred.deletingLastPathComponent()
        let base = preferred.lastPathComponent
        for number in 2...100_000 {
            let candidate = parent.appendingPathComponent(
                try filenamePolicy.sanitize("\(base) \(number)", maximumUTF8Bytes: 220),
                isDirectory: true
            )
            if !fileManager.fileExists(atPath: candidate.path) { return candidate }
        }
        throw UniversalConverterError.outputConflict(preferred.lastPathComponent)
    }

    private func replaceDirectory(at destination: URL, with replacement: URL, fileManager: FileManager) throws {
        let parent = destination.deletingLastPathComponent()
        let backup = parent.appendingPathComponent(".zeuve-backup-\(UUID().uuidString)", isDirectory: true)
        try fileManager.moveItem(at: destination, to: backup)
        do {
            try fileManager.moveItem(at: replacement, to: destination)
            try? fileManager.removeItem(at: backup)
        } catch {
            if fileManager.fileExists(atPath: destination.path) { try? fileManager.removeItem(at: destination) }
            try? fileManager.moveItem(at: backup, to: destination)
            throw error
        }
    }

    private func canonicalPath(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private struct IncompleteMarker: Codable {
        let operationID: UUID
        let preservedAt: Date
        let intendedFinalURL: URL
    }
}
