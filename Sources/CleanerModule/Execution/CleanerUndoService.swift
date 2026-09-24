import Foundation
import ZEUVECore
import ZEUVEStorage
import ZEUVEOperations

public final class CleanerUndoService: @unchecked Sendable {
    let coordinator: OperationCoordinator
    let repository: CleanerRepository
    let history: HistoryRepository
    let mutator: any CleanerFileMutating
    let fileManager: FileManager

    public init(coordinator: OperationCoordinator, repository: CleanerRepository, history: HistoryRepository, mutator: any CleanerFileMutating = SystemCleanerFileMutator(), fileManager: FileManager = .default) {
        self.coordinator = coordinator
        self.repository = repository
        self.history = history
        self.mutator = mutator
        self.fileManager = fileManager
    }

    public func hasPendingItems(historyID: UUID) throws -> Bool {
        try !repository.undoItems(historyID: historyID).isEmpty
    }

    public func undo(historyID: UUID) async throws -> CleanerExecutionSummary {
        let operationID = try await coordinator.begin(moduleID: cleanerModuleIdentifier, name: "Restaurando desde la Papelera")
        var results: [CleanerItemExecutionResult] = []
        do {
            let items = try repository.undoItems(historyID: historyID)
            for item in items {
                if await coordinator.shouldCancel(id: operationID) { break }
                if fileManager.fileExists(atPath: item.originalURL.path) {
                    results.append(.init(sourcePath: item.originalURL.path, trashPath: item.trashURL.path, status: .restoreConflict, message: "La ubicación original ya está ocupada."))
                    continue
                }
                guard let current = CleanerFileInspection.fingerprint(at: item.trashURL, fileManager: fileManager), current == item.fingerprint else {
                    results.append(.init(sourcePath: item.originalURL.path, trashPath: item.trashURL.path, status: .unavailable, message: "El elemento de la Papelera ya no está disponible o cambió."))
                    continue
                }
                do {
                    try mutator.restore(item.trashURL, to: item.originalURL)
                } catch {
                    results.append(.init(sourcePath: item.originalURL.path, trashPath: item.trashURL.path, status: .failed, message: error.localizedDescription))
                    continue
                }
                do {
                    try repository.removeUndoItem(id: item.id)
                    results.append(.init(sourcePath: item.originalURL.path, status: .restored))
                } catch {
                    results.append(.init(sourcePath: item.originalURL.path, status: .restored, message: "Restaurado, pero no se pudo actualizar el registro de Deshacer."))
                }
            }

            let remaining = try repository.undoItems(historyID: historyID)
            let restoredCount = results.filter { $0.status == .restored }.count
            let status: OperationStatus = remaining.isEmpty ? .undone : (restoredCount > 0 ? .partiallyUndone : .undoUnavailable)
            try? history.updateUndoState(id: historyID, status: status, undoAvailable: !remaining.isEmpty)
            try await coordinator.finish(id: operationID)
            return .init(results: results, deletedLogicalBytes: 0, deletionMode: .trash)
        } catch {
            try? await coordinator.finish(id: operationID)
            throw error
        }
    }
}
