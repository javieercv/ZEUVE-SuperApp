import Foundation
import ZEUVECore
import ZEUVEStorage
import ZEUVEOperations

public struct CleanerExecutionOutput: Sendable {
    public let summary: CleanerExecutionSummary
    public let historyID: UUID
    public let undoAvailable: Bool
    public let historyWarning: String?
}

public final class CleanerExecutionService: @unchecked Sendable {
    let coordinator: OperationCoordinator
    let cleanerRepository: CleanerRepository?
    let history: HistoryRepository?
    let mutator: any CleanerFileMutating
    let fileManager: FileManager

    public init(
        coordinator: OperationCoordinator,
        cleanerRepository: CleanerRepository?,
        history: HistoryRepository?,
        mutator: any CleanerFileMutating = SystemCleanerFileMutator(),
        fileManager: FileManager = .default
    ) {
        self.coordinator = coordinator
        self.cleanerRepository = cleanerRepository
        self.history = history
        self.mutator = mutator
        self.fileManager = fileManager
    }

    public func execute(plan: CleanerRemovalPlan, mode: CleanerDeletionMode, kind: String = "cleaning") async throws -> CleanerExecutionOutput {
        let operationID = try await coordinator.begin(
            moduleID: cleanerModuleIdentifier,
            name: kind == "uninstall" ? "Desinstalando aplicación" : "Limpiando elementos"
        )
        var results: [CleanerItemExecutionResult] = []
        var deletedBytes: Int64 = 0
        var recordedUndoItems = 0
        var blockedBundleIDs = Set<String>()
        var blockedAppNames = Set<String>()
        if kind == "uninstall" {
            for application in plan.candidates where application.category == .application && !application.selected {
                if let bundleID = application.associatedBundleID { blockedBundleIDs.insert(bundleID) }
                if let name = application.associatedAppName { blockedAppNames.insert(name) }
            }
        }

        do {
            let selected = plan.selectedCandidates
            for (index, candidate) in selected.enumerated() {
                if await coordinator.shouldCancel(id: operationID) { break }
                try? await coordinator.update(
                    id: operationID,
                    progress: .init(
                        completed: index,
                        total: selected.count,
                        phase: "Revalidando y ejecutando",
                        currentItem: candidate.url.lastPathComponent
                    )
                )

                if kind == "uninstall",
                   candidate.category != .application,
                   ((candidate.associatedBundleID.map(blockedBundleIDs.contains) ?? false)
                    || (candidate.associatedAppName.map(blockedAppNames.contains) ?? false)) {
                    results.append(.init(
                        sourcePath: candidate.url.path,
                        status: .unavailable,
                        message: "Omitido por seguridad porque la aplicación no pudo retirarse."
                    ))
                    continue
                }

                let kept: Bool
                do { kept = try cleanerRepository?.isKept(path: candidate.url.path) ?? false }
                catch {
                    results.append(.init(sourcePath: candidate.url.path, status: .failed, message: "No se pudo revalidar la decisión «Conservar»."))
                    if kind == "uninstall", candidate.category == .application {
                        if let bundleID = candidate.associatedBundleID { blockedBundleIDs.insert(bundleID) }
                        if let name = candidate.associatedAppName { blockedAppNames.insert(name) }
                    }
                    continue
                }

                let failure: CleanerItemExecutionResult?
                if kept || candidate.status == .keptByUser {
                    failure = .init(sourcePath: candidate.url.path, status: .unavailable, message: "Omitido por la decisión «Conservar».")
                } else if !fileManager.fileExists(atPath: candidate.url.path) {
                    failure = .init(sourcePath: candidate.url.path, status: .unavailable, message: "El elemento ya no existe.")
                } else if candidate.requiresAdministrator || candidate.applicationRunning || candidate.isShared {
                    failure = .init(sourcePath: candidate.url.path, status: .permissionDenied, message: "Bloqueado por una guarda de seguridad.")
                } else if let current = CleanerFileInspection.fingerprint(at: candidate.url, fileManager: fileManager),
                          let expected = candidate.fingerprint,
                          current == expected {
                    failure = nil
                } else {
                    failure = .init(sourcePath: candidate.url.path, status: .skippedChanged, message: "Omitido por seguridad: cambió desde el análisis.")
                }

                if let failure {
                    results.append(failure)
                    if kind == "uninstall", candidate.category == .application, let bundleID = candidate.associatedBundleID {
                        blockedBundleIDs.insert(bundleID)
                    }
                    if kind == "uninstall", candidate.category == .application, let name = candidate.associatedAppName {
                        blockedAppNames.insert(name)
                    }
                    continue
                }

                guard let current = CleanerFileInspection.fingerprint(at: candidate.url, fileManager: fileManager) else {
                    results.append(.init(sourcePath: candidate.url.path, status: .skippedChanged, message: "Omitido por seguridad: no se pudo revalidar."))
                    if kind == "uninstall", candidate.category == .application, let bundleID = candidate.associatedBundleID {
                        blockedBundleIDs.insert(bundleID)
                    }
                    if kind == "uninstall", candidate.category == .application, let name = candidate.associatedAppName {
                        blockedAppNames.insert(name)
                    }
                    continue
                }

                do {
                    if mode == .trash {
                        let trashURL = try mutator.moveToTrash(candidate.url)
                        let undoFingerprint = CleanerFileInspection.fingerprint(at: trashURL, fileManager: fileManager) ?? current
                        if let cleanerRepository {
                            do {
                                try cleanerRepository.addUndoItem(.init(historyID: operationID, originalURL: candidate.url, trashURL: trashURL, fingerprint: undoFingerprint))
                                recordedUndoItems += 1
                                results.append(.init(sourcePath: candidate.url.path, trashPath: trashURL.path, status: .removed))
                            } catch {
                                let stillInTrash = CleanerFileInspection.fingerprint(at: trashURL, fileManager: fileManager) == undoFingerprint
                                if stillInTrash && !fileManager.fileExists(atPath: candidate.url.path),
                                   (try? mutator.restore(trashURL, to: candidate.url)) != nil {
                                    results.append(.init(sourcePath: candidate.url.path, status: .failed, message: "No se pudo registrar Deshacer; el elemento volvió a su ubicación original."))
                                    if kind == "uninstall", candidate.category == .application {
                                        if let bundleID = candidate.associatedBundleID { blockedBundleIDs.insert(bundleID) }
                                        if let name = candidate.associatedAppName { blockedAppNames.insert(name) }
                                    }
                                    continue
                                }
                                results.append(.init(sourcePath: candidate.url.path, trashPath: trashURL.path, status: .removed, message: "Se movió a Papelera, pero no se pudo registrar Deshacer. Restáuralo manualmente desde Finder si lo necesitas."))
                            }
                        } else {
                            results.append(.init(sourcePath: candidate.url.path, trashPath: trashURL.path, status: .removed, message: "Se movió a Papelera sin registro de Deshacer disponible."))
                        }
                    } else {
                        try mutator.removePermanently(candidate.url)
                        results.append(.init(sourcePath: candidate.url.path, status: .removed))
                    }
                    deletedBytes += candidate.logicalSize ?? 0
                } catch {
                    let status: CleanerItemExecutionStatus = (error as NSError).code == NSFileWriteNoPermissionError ? .permissionDenied : .failed
                    results.append(.init(sourcePath: candidate.url.path, status: status, message: error.localizedDescription))
                    if kind == "uninstall", candidate.category == .application, let bundleID = candidate.associatedBundleID {
                        blockedBundleIDs.insert(bundleID)
                    }
                    if kind == "uninstall", candidate.category == .application, let name = candidate.associatedAppName {
                        blockedAppNames.insert(name)
                    }
                }
            }

            let summary = CleanerExecutionSummary(results: results, deletedLogicalBytes: deletedBytes, deletionMode: mode)
            let undoAvailable = mode == .trash && recordedUndoItems > 0
            var historyWarning: String?
            do { try saveHistory(id: operationID, kind: kind, summary: summary, undo: undoAvailable) }
            catch { historyWarning = "La operación terminó, pero no se pudo guardar en el historial global." }
            try await coordinator.finish(id: operationID)
            return .init(summary: summary, historyID: operationID, undoAvailable: undoAvailable, historyWarning: historyWarning)
        } catch {
            try? await coordinator.finish(id: operationID)
            throw error
        }
    }

    private func saveHistory(id: UUID, kind: String, summary: CleanerExecutionSummary, undo: Bool) throws {
        guard let history else { return }
        let payload = CleanerHistoryPayload(
            kind: kind,
            removed: summary.removedCount,
            skipped: summary.skippedCount,
            failed: summary.failedCount,
            logicalBytes: summary.deletedLogicalBytes,
            undoAvailable: undo
        )
        try history.add(.init(
            id: id,
            moduleID: cleanerModuleIdentifier,
            kind: kind,
            baseFolder: nil,
            status: .completed,
            undoAvailable: undo,
            payload: try JSONEncoder().encode(payload)
        ))
    }
}
