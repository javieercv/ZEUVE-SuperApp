import Foundation
import ZEUVECore
import ZEUVEStorage
import ZEUVEOperations

public struct CleanerUndoOutput: Sendable {
    public let summary: CleanerExecutionSummary
    public let historyWarning: String?
}

public final class CleanerUndoService: @unchecked Sendable {
    let coordinator: OperationCoordinator
    let repository: CleanerRepository
    let history: HistoryRepository
    let mutator: any CleanerFileMutating
    let fileManager: FileManager
    private let trashRoots: [URL]?

    public init(coordinator: OperationCoordinator, repository: CleanerRepository, history: HistoryRepository, mutator: any CleanerFileMutating = SystemCleanerFileMutator(), fileManager: FileManager = .default, trashRoots: [URL]? = nil) {
        self.coordinator = coordinator
        self.repository = repository
        self.history = history
        self.mutator = mutator
        self.fileManager = fileManager
        self.trashRoots = trashRoots
    }

    public func hasPendingItems(historyID: UUID) throws -> Bool {
        try !repository.undoItems(historyID: historyID).isEmpty
    }

    /// Reconstruye disponibilidad desde las filas persistidas, sin eliminarlas
    /// cuando un objeto deja de ser recuperable. La ejecución vuelve a verificarlo.
    public func latestRecoverableHistoryID() async throws -> UUID? {
        let operationID = try await coordinator.begin(moduleID: cleanerModuleIdentifier, name: "Comprobando Deshacer")
        do {
            let task = Task.detached { [self] () async throws -> UUID? in
                for id in try repository.pendingUndoHistoryIDs() {
                    for item in try repository.undoItems(historyID: id) {
                        try Task.checkCancellation()
                        guard !(await coordinator.shouldCancel(id: operationID)) else { throw CancellationError() }
                        if canRestore(item, shouldCancel: { Task.isCancelled }) { return id }
                    }
                }
                return Optional<UUID>.none
            }
            let result = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
            try Task.checkCancellation()
            try await coordinator.finish(id: operationID)
            return result
        } catch {
            try? await coordinator.finish(id: operationID)
            throw error
        }
    }

    private func isTrashLocation(_ item: CleanerUndoItem) -> Bool {
        let roots: [URL]
        if let trashRoots { roots = trashRoots }
        else {
            #if os(macOS)
            guard let root = try? fileManager.url(for: .trashDirectory, in: .userDomainMask, appropriateFor: item.trashURL, create: false) else { return false }
            roots = [root]
            #else
            roots = [fileManager.temporaryDirectory.appendingPathComponent("ZEUVE-Test-Trash", isDirectory: true)]
            #endif
        }
        // Resolver solo el padre permite restaurar el enlace mismo, nunca su destino.
        let parent = item.trashURL.deletingLastPathComponent().standardizedFileURL.resolvingSymlinksInPath().path
        return roots.contains { root in
            let path = root.standardizedFileURL.resolvingSymlinksInPath().path
            return parent == path || parent.hasPrefix(path + "/")
        }
    }

    private func originalIsOccupied(_ item: CleanerUndoItem) -> Bool {
        (try? fileManager.attributesOfItem(atPath: item.originalURL.path)) != nil
    }

    private func canRestore(_ item: CleanerUndoItem, shouldCancel: (() -> Bool)? = nil) -> Bool {
        guard isTrashLocation(item), !originalIsOccupied(item),
              fileManager.isWritableFile(atPath: item.originalURL.deletingLastPathComponent().path),
              let current = CleanerFileInspection.fingerprint(at: item.trashURL, fileManager: fileManager, shouldCancel: shouldCancel) else { return false }
        return current == item.fingerprint
    }

    public func undo(historyID: UUID) async throws -> CleanerUndoOutput {
        let operationID = try await coordinator.begin(moduleID: cleanerModuleIdentifier, name: "Restaurando desde la Papelera")
        var results: [CleanerItemExecutionResult] = []
        do {
            let items = try repository.undoItems(historyID: historyID)
            for item in items {
                if await coordinator.shouldCancel(id: operationID) { break }
                if originalIsOccupied(item) {
                    results.append(.init(sourcePath: item.originalURL.path, trashPath: item.trashURL.path, status: .restoreConflict, message: "La ubicación original ya está ocupada."))
                    continue
                }
                guard canRestore(item) else {
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
            var historyWarning: String?
            do { try history.updateUndoState(id: historyID, status: status, undoAvailable: !remaining.isEmpty) }
            catch { historyWarning = "Los archivos se restauraron, pero no se pudo actualizar el historial global." }
            try await coordinator.finish(id: operationID)
            return .init(
                summary: .init(results: results, deletedLogicalBytes: 0, deletionMode: .trash),
                historyWarning: historyWarning
            )
        } catch {
            try? await coordinator.finish(id: operationID)
            throw error
        }
    }
}
