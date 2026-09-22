import Foundation
import AppKit
import SwiftUI
import UniformTypeIdentifiers
import ZEUVECore
import ZEUVEStorage
import ZEUVEOperations
import OrganizerModule

@MainActor
enum OrganizerUIState: Equatable {
    case idle
    case planning
    case ready
    case executing
    case cancelling
    case undoing

    var isBusy: Bool {
        switch self {
        case .planning, .executing, .cancelling, .undoing: return true
        case .idle, .ready: return false
        }
    }
}

struct OrganizerCompletion: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let folder: URL?
    let moved: Int?
    let foldersCreated: Int?
    let renamed: Int?
    let undoRecordID: UUID?

    init(
        title: String,
        message: String,
        folder: URL?,
        moved: Int? = nil,
        foldersCreated: Int? = nil,
        renamed: Int? = nil,
        undoRecordID: UUID? = nil
    ) {
        self.title = title
        self.message = message
        self.folder = folder
        self.moved = moved
        self.foldersCreated = foldersCreated
        self.renamed = renamed
        self.undoRecordID = undoRecordID
    }
}

@MainActor
final class OrganizerViewModel: ObservableObject {
    @Published var folderURL: URL?
    @Published var options = OrganizerOptions()
    @Published var defaultOptions = OrganizerOptions()
    @Published var plan: OrganizerPlan?
    @Published var selectedIDs = Set<UUID>()
    @Published var progress: OperationProgress?
    @Published var state: OrganizerUIState = .idle
    @Published var errorMessage: String?
    @Published var warningMessage: String?
    @Published var completion: OrganizerCompletion?
    @Published var historyEntries: [OrganizerHistoryEntry] = []
    @Published var recentFolders: [URL] = []

    let unavailableMessage: String?

    private let coordinator: OperationCoordinator?
    private let settings: SettingsRepository?
    private let history: OrganizerHistoryService?
    private let logger: LocalLogger?
    private var currentOperationID: UUID?
    private var operationTask: Task<Void, Never>?
    private var planningWorker: Task<OrganizerPlan, Error>?
    private var executionWorker: Task<OrganizerExecutionResult, Error>?
    private var undoWorker: Task<OrganizerUndoResult, Error>?

    init(
        coordinator: OperationCoordinator,
        settings: SettingsRepository,
        history: OrganizerHistoryService,
        logger: LocalLogger? = nil
    ) {
        self.coordinator = coordinator
        self.settings = settings
        self.history = history
        self.logger = logger
        self.unavailableMessage = nil
        let savedDefaults = (try? settings.value(forKey: OrganizerStorageKeys.defaultOptions, as: OrganizerOptions.self))
            ?? (try? settings.value(forKey: OrganizerStorageKeys.Legacy.options, as: OrganizerOptions.self))
        if let savedDefaults {
            defaultOptions = savedDefaults
            options = savedDefaults
        }
        if let recent = try? settings.value(forKey: OrganizerStorageKeys.lastFolder, as: String.self) {
            folderURL = URL(fileURLWithPath: recent, isDirectory: true)
        }
        let recentPaths = (try? settings.value(forKey: OrganizerStorageKeys.recentFolders, as: [String].self)) ?? []
        recentFolders = recentPaths.map { URL(fileURLWithPath: $0, isDirectory: true) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    private init(unavailableMessage: String) {
        self.coordinator = nil
        self.settings = nil
        self.history = nil
        self.logger = nil
        self.unavailableMessage = unavailableMessage
    }

    static func unavailable(message: String) -> OrganizerViewModel {
        OrganizerViewModel(unavailableMessage: message)
    }


    var selectedCount: Int { selectedIDs.count }
    var canPlan: Bool { folderURL != nil && !state.isBusy && unavailableMessage == nil }
    var canExecute: Bool { plan != nil && !selectedIDs.isEmpty && !state.isBusy && unavailableMessage == nil }

    func persistDefaultOptions() {
        guard let settings else { return }
        do {
            try settings.set(defaultOptions, forKey: OrganizerStorageKeys.defaultOptions)
        } catch {
            errorMessage = "No se han podido guardar los valores predeterminados del Organizador: \(error.localizedDescription)"
        }
    }

    func restoreDefaultOptions() {
        defaultOptions = OrganizerOptions()
        persistDefaultOptions()
    }

    func applyDefaultOptionsToCurrentOperation() {
        guard !state.isBusy else { return }
        options = defaultOptions
        clearPlan()
    }

    func clearRecentFolders() {
        recentFolders = []
        guard let settings else { return }
        do {
            try settings.set([String](), forKey: OrganizerStorageKeys.recentFolders)
            try settings.removeValue(forKey: OrganizerStorageKeys.lastFolder)
        } catch {
            errorMessage = "Se ha vaciado la lista durante esta sesión, pero no se ha podido guardar el cambio: \(error.localizedDescription)"
        }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Selecciona la carpeta que quieres organizar"
        panel.prompt = "Seleccionar"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            setFolder(url)
        }
    }

    func setFolder(_ url: URL) {
        folderURL = url.standardizedFileURL
        options = defaultOptions
        plan = nil
        selectedIDs.removeAll()
        state = .idle
        let normalized = url.standardizedFileURL
        recentFolders.removeAll { $0.standardizedFileURL.path == normalized.path }
        recentFolders.insert(normalized, at: 0)
        recentFolders = Array(recentFolders.prefix(5))
        if let settings {
            do {
                try settings.set(normalized.path, forKey: OrganizerStorageKeys.lastFolder)
                try settings.set(recentFolders.map(\.path), forKey: OrganizerStorageKeys.recentFolders)
            } catch {
                errorMessage = "La carpeta se ha seleccionado, pero no se ha podido guardar en recientes: \(error.localizedDescription)"
            }
        }
    }

    func clearPlan() {
        plan = nil
        selectedIDs.removeAll()
        progress = nil
        state = .idle
    }

    func selectAll() {
        selectedIDs = Set(plan?.operations.map(\.id) ?? [])
    }

    func selectNone() {
        selectedIDs.removeAll()
    }

    func toggle(_ operation: OrganizerMoveOperation) {
        setSelected([operation.id], selected: !selectedIDs.contains(operation.id))
    }

    func setSelected(_ ids: Set<UUID>, selected: Bool) {
        if selected {
            selectedIDs.formUnion(ids)
        } else {
            selectedIDs.subtract(ids)
        }
    }

    func analyze() {
        guard let folderURL, let coordinator else { return }
        operationTask?.cancel()
        operationTask = Task { [weak self] in
            guard let self else { return }
            do {
                state = .planning
                progress = OperationProgress(completed: 0, total: nil, phase: "Preparando análisis")
                _ = try? await logger?.write(
                    .info,
                    category: "organizador",
                    message: "Inicio del análisis",
                    metadata: [:]
                )
                let operationID = try await coordinator.begin(
                    moduleID: organizerModuleIdentifier,
                    name: "Analizando carpeta"
                )
                currentOperationID = operationID
                let pair = AsyncStream<OperationProgress>.makeStream()
                let optionsSnapshot = options
                let worker = Task.detached(priority: .userInitiated) {
                    defer { pair.continuation.finish() }
                    return try OrganizerPlanner().buildPlan(
                        folder: folderURL,
                        options: optionsSnapshot,
                        progress: { pair.continuation.yield($0) }
                    )
                }
                planningWorker = worker
                let progressTask = Task { [weak self] in
                    for await update in pair.stream {
                        guard let self else { return }
                        progress = update
                        try? await coordinator.update(id: operationID, progress: update)
                    }
                }
                let newPlan = try await worker.value
                progressTask.cancel()
                try await coordinator.finish(id: operationID)
                currentOperationID = nil
                planningWorker = nil
                plan = newPlan
                selectedIDs = Set(newPlan.operations.map(\.id))
                progress = nil
                state = .ready
                _ = try? await logger?.write(
                    .info,
                    category: "organizador",
                    message: "Análisis completado",
                    metadata: ["operaciones": "\(newPlan.operations.count)", "omitidos": "\(newPlan.ignored.count)"]
                )
            } catch is CancellationError {
                await finishCancelledOperation(coordinator)
            } catch {
                await finishFailedOperation(coordinator, error: error)
            }
        }
    }

    func execute() {
        guard let plan, !selectedIDs.isEmpty, let coordinator, let history else { return }
        warningMessage = nil
        let selected = selectedIDs
        operationTask?.cancel()
        operationTask = Task { [weak self] in
            guard let self else { return }
            do {
                state = .executing
                progress = OperationProgress(completed: 0, total: selected.count, phase: "Preparando organización")
                let operationID = try await coordinator.begin(
                    moduleID: organizerModuleIdentifier,
                    name: "Organizando archivos"
                )
                currentOperationID = operationID
                let pair = AsyncStream<OperationProgress>.makeStream()
                let worker = Task.detached(priority: .userInitiated) {
                    defer { pair.continuation.finish() }
                    return try OrganizerExecutor().execute(
                        plan: plan,
                        selectedIDs: selected,
                        progress: { pair.continuation.yield($0) }
                    )
                }
                executionWorker = worker
                let progressTask = Task { [weak self] in
                    for await update in pair.stream {
                        guard let self else { return }
                        progress = update
                        try? await coordinator.update(id: operationID, progress: update)
                    }
                }
                let result = try await worker.value
                progressTask.cancel()
                try await coordinator.finish(id: operationID)
                currentOperationID = nil
                executionWorker = nil
                let savedRecordID: UUID?
                do {
                    let record = try await Task.detached { try history.save(result) }.value
                    savedRecordID = record.id
                } catch {
                    savedRecordID = nil
                    let failure = ZEUVEHistoryPersistence.attempt { throw error }
                    warningMessage = failure?.warning
                    _ = try? await logger?.write(
                        .warning,
                        category: "organizador",
                        message: "No se ha podido guardar el historial",
                        metadata: failure?.logMetadata ?? [:]
                    )
                }
                self.plan = nil
                selectedIDs.removeAll()
                progress = nil
                state = .idle
                if savedRecordID != nil { await loadHistory() }
                _ = try? await logger?.write(
                    .info,
                    category: "organizador",
                    message: "Organización completada",
                    metadata: ["movidos": "\(result.moved)", "omitidos": "\(result.skipped)", "renombrados": "\(result.renamed)"]
                )
                completion = OrganizerCompletion(
                    title: "Organización completada",
                    message: "Se han organizado \(result.moved) archivos. Se omitieron \(result.skipped).",
                    folder: result.baseFolder,
                    moved: result.moved,
                    foldersCreated: result.createdDirectories.count,
                    renamed: result.renamed,
                    undoRecordID: savedRecordID
                )
            } catch is CancellationError {
                await finishCancelledOperation(coordinator)
            } catch {
                await finishFailedOperation(coordinator, error: error)
            }
        }
    }

    func cancel() {
        state = .cancelling
        planningWorker?.cancel()
        executionWorker?.cancel()
        undoWorker?.cancel()
        operationTask?.cancel()
        if let coordinator, let currentOperationID {
            Task { try? await coordinator.requestCancellation(id: currentOperationID) }
        }
    }

    func exportPlan() {
        guard let plan else { return }
        let panel = NSSavePanel()
        panel.title = "Exportar planificación"
        panel.nameFieldStringValue = "plan-organizacion.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try OrganizerCSVExporter().export(plan: plan, to: url, selectedIDs: selectedIDs)
                completion = OrganizerCompletion(
                    title: "Plan exportado",
                    message: "La planificación se ha guardado correctamente.",
                    folder: url.deletingLastPathComponent()
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func loadHistory() async {
        guard let history else { return }
        do {
            historyEntries = try await Task.detached { try history.entries() }.value
        } catch {
            errorMessage = "No se ha podido cargar el historial: \(error.localizedDescription)"
        }
    }

    func undo(_ entry: OrganizerHistoryEntry) {
        guard entry.record.undoAvailable, let coordinator, let history else { return }
        operationTask?.cancel()
        operationTask = Task { [weak self] in
            guard let self else { return }
            do {
                state = .undoing
                progress = OperationProgress(completed: 0, total: nil, phase: "Deshaciendo organización")
                let operationID = try await coordinator.begin(
                    moduleID: organizerModuleIdentifier,
                    name: "Deshaciendo organización"
                )
                currentOperationID = operationID
                let worker = Task.detached(priority: .userInitiated) {
                    try history.undo(recordID: entry.id)
                }
                undoWorker = worker
                let result = try await worker.value
                try await coordinator.finish(id: operationID)
                currentOperationID = nil
                undoWorker = nil
                state = .idle
                progress = nil
                _ = try? await logger?.write(
                    result.status == .undone ? .info : .warning,
                    category: "organizador",
                    message: result.status == .undone ? "Organización deshecha" : "Deshacer incompleto",
                    metadata: ["restaurados": "\(result.restored)", "omitidos": "\(result.skipped)"]
                )
                completion = OrganizerCompletion(
                    title: result.status == .undone ? "Organización deshecha" : "Deshacer incompleto",
                    message: "Se han restaurado \(result.restored) archivos y se han omitido \(result.skipped).",
                    folder: entry.payload.execution.baseFolder
                )
                await loadHistory()
            } catch is CancellationError {
                await finishCancelledOperation(coordinator)
            } catch {
                await finishFailedOperation(coordinator, error: error)
            }
        }
    }

    func undoCompletion(recordID: UUID) {
        guard let entry = historyEntries.first(where: { $0.id == recordID }) else {
            errorMessage = "La operación todavía no está disponible en el historial."
            return
        }
        completion = nil
        undo(entry)
    }

    func openFolder(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    private func finishCancelledOperation(_ coordinator: OperationCoordinator) async {
        if let currentOperationID { try? await coordinator.finish(id: currentOperationID) }
        self.currentOperationID = nil
        planningWorker = nil
        executionWorker = nil
        undoWorker = nil
        progress = nil
        state = plan == nil ? .idle : .ready
        errorMessage = "La operación se ha cancelado. No se ha sobrescrito ningún archivo."
        _ = try? await logger?.write(.warning, category: "organizador", message: "Operación cancelada")
    }

    private func finishFailedOperation(_ coordinator: OperationCoordinator, error: Error) async {
        if let currentOperationID { try? await coordinator.finish(id: currentOperationID) }
        self.currentOperationID = nil
        planningWorker = nil
        executionWorker = nil
        undoWorker = nil
        progress = nil
        state = plan == nil ? .idle : .ready
        errorMessage = error.localizedDescription
        _ = try? await logger?.write(.error, category: "organizador", message: "La operación ha fallado", metadata: ["error": error.localizedDescription])
    }
}
