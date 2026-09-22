import Foundation
#if SWIFT_PACKAGE
import ZEUVECore
import ZEUVEStorage
#endif

public struct OrganizerHistoryEntry: Sendable, Equatable, Identifiable {
    public let record: OperationHistoryRecord
    public let payload: OrganizerHistoryPayload
    public var id: UUID { record.id }
}

public final class OrganizerHistoryService: @unchecked Sendable {
    private let repository: HistoryRepository
    private let fileManager: FileManager

    public init(repository: HistoryRepository, fileManager: FileManager = .default) {
        self.repository = repository
        self.fileManager = fileManager
    }

    @discardableResult
    public func save(_ execution: OrganizerExecutionResult) throws -> OperationHistoryRecord {
        let payload = OrganizerHistoryPayload(execution: execution)
        let record = OperationHistoryRecord(
            id: execution.operationID,
            moduleID: organizerModuleIdentifier,
            kind: "organize",
            baseFolder: execution.baseFolder.path,
            createdAt: execution.finishedAt,
            status: .completed,
            undoAvailable: !execution.operations.isEmpty,
            payload: try JSONEncoder().encode(payload)
        )
        try repository.add(record)
        return record
    }

    public func entries(limit: Int = 100) throws -> [OrganizerHistoryEntry] {
        try repository.records(moduleID: organizerModuleIdentifier, limit: limit).compactMap { record in
            guard let payload = try? JSONDecoder().decode(OrganizerHistoryPayload.self, from: record.payload) else { return nil }
            return OrganizerHistoryEntry(record: record, payload: payload)
        }
    }

    public func undo(recordID: UUID) throws -> OrganizerUndoResult {
        guard let record = try repository.record(id: recordID) else { throw OrganizerError.noHistoryRecord }
        guard record.undoAvailable else { throw OrganizerError.undoUnavailable }
        let payload = try JSONDecoder().decode(OrganizerHistoryPayload.self, from: record.payload)
        let result = undo(payload.execution)
        let updatedPayload = OrganizerHistoryPayload(execution: payload.execution, undoDetails: result.details)
        try repository.updateUndoState(
            id: recordID,
            status: result.status,
            undoAvailable: false,
            payload: try JSONEncoder().encode(updatedPayload)
        )
        return result
    }

    public func undoLatest(baseFolder: URL) throws -> OrganizerUndoResult {
        guard let record = try repository.latestUndoable(
            moduleID: organizerModuleIdentifier,
            baseFolder: baseFolder.standardizedFileURL.path
        ) else { throw OrganizerError.noHistoryRecord }
        return try undo(recordID: record.id)
    }

    private func undo(_ execution: OrganizerExecutionResult) -> OrganizerUndoResult {
        var restored = 0
        var skipped = 0
        var details: [String] = []

        for item in execution.operations.reversed() {
            if !fileManager.fileExists(atPath: item.destination.path) {
                skipped += 1
                details.append("No encontrado en destino: \(item.destination.lastPathComponent)")
                continue
            }
            if fileManager.fileExists(atPath: item.source.path) {
                skipped += 1
                details.append("Ya existe un archivo en la ubicación original: \(item.source.lastPathComponent)")
                continue
            }
            if !item.destinationFingerprint.matches(item.destination, fileManager: fileManager) {
                skipped += 1
                details.append("El archivo fue modificado después de organizarlo: \(item.destination.lastPathComponent)")
                continue
            }
            do {
                try fileManager.createDirectory(
                    at: item.source.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try fileManager.moveItem(at: item.destination, to: item.source)
                restored += 1
            } catch {
                skipped += 1
                details.append("No se pudo restaurar \(item.destination.lastPathComponent): \(error.localizedDescription)")
            }
        }

        removeEmptyDirectories(execution.createdDirectories)
        let status: OperationStatus = skipped == 0
            ? .undone
            : (restored > 0 ? .partiallyUndone : .undoUnavailable)
        return OrganizerUndoResult(restored: restored, skipped: skipped, status: status, details: details)
    }

    private func removeEmptyDirectories(_ directories: [URL]) {
        for directory in directories.sorted(by: { $0.pathComponents.count > $1.pathComponents.count }) {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: directory.path), contents.isEmpty else { continue }
            try? fileManager.removeItem(at: directory)
        }
    }
}
