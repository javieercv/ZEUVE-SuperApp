import Foundation
import AppKit
import ZEUVECore
import ZEUVEStorage
import ZEUVEOperations
import CleanerModule

@MainActor
final class CleanerViewModel: ObservableObject {
    @Published var preferences: CleanerPreferences
    @Published var analysis: CleanerAnalysisResult?
    @Published var plan = CleanerRemovalPlan(candidates: [])
    @Published var uninstallAnalysis: CleanerUninstallAnalysis?
    @Published var isBusy = false
    @Published var errorMessage: String?
    @Published var resultMessage: String?
    @Published var executionSummary: CleanerExecutionSummary?
    @Published var lastHistoryID: UUID?
    @Published var spaceRoot: URL
    @Published var spaceTree: CleanerStorageNode?
    @Published var spaceMinimumMB: Int = 0
    @Published var conservedPaths: [String] = []

    private let coordinator: OperationCoordinator
    private let repository: CleanerRepository?
    private let settingsStore: CleanerSettingsStore
    private let analysisService: CleanerAnalysisService
    private let executionService: CleanerExecutionService
    private let undoService: CleanerUndoService?
    private let uninstallAnalyzer: CleanerUninstallAnalyzer
    private let identityProvider: SystemCleanerAppIdentityProvider
    private let storageScanner = CleanerStorageScanner()
    private var spaceScanTask: Task<CleanerStorageNode?, Never>?

    init(coordinator: OperationCoordinator, storage: StorageContainer?) {
        self.coordinator = coordinator
        let repo = storage.flatMap { try? CleanerRepository(database: $0.database) }
        self.repository = repo
        self.settingsStore = CleanerSettingsStore(settings: storage?.settings)
        self.preferences = CleanerSettingsStore(settings: storage?.settings).load()
        self.identityProvider = SystemCleanerAppIdentityProvider()
        self.analysisService = CleanerAnalysisService(coordinator: coordinator, repository: repo)
        self.executionService = CleanerExecutionService(coordinator: coordinator, cleanerRepository: repo, history: storage?.history)
        if let repo, let history = storage?.history {
            self.undoService = CleanerUndoService(coordinator: coordinator, repository: repo, history: history)
        } else {
            self.undoService = nil
        }
        self.uninstallAnalyzer = CleanerUninstallAnalyzer()
        self.spaceRoot = FileManager.default.homeDirectoryForCurrentUser
        self.conservedPaths = ((try? repo?.keptPaths()) ?? []).sorted()
    }

    var selectedCount: Int { plan.selectedCandidates.count }
    var selectedBytes: Int64 { plan.selectedLogicalBytes }
    var canUndoLast: Bool { lastHistoryID != nil && undoService != nil }

    func analyze(preservingResult: Bool = false) async {
        guard !isBusy else { return }
        isBusy = true; errorMessage = nil; uninstallAnalysis = nil
        if !preservingResult { resultMessage = nil; executionSummary = nil }
        defer { isBusy = false }
        do {
            let output = try await analysisService.analyze(preferences: preferences)
            analysis = output
            plan = CleanerPlanner.plan(candidates: output.candidates, selectSafeItems: !preservingResult && preferences.safeSelectionEnabled)
        } catch is CancellationError {
            resultMessage = "Análisis cancelado."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancel() { Task { await cancelAndWait() } }
    func cancelAndWait() async {
        spaceScanTask?.cancel()
        if let current = await coordinator.current(), current.moduleID == cleanerModuleIdentifier {
            try? await coordinator.requestCancellation(id: current.id)
        }
    }

    func setSelected(_ selected: Bool, candidateID: UUID) {
        if uninstallAnalysis != nil {
            guard let candidate = plan.candidates.first(where: { $0.id == candidateID }) else { return }
            if selected && !canSelect(candidate) {
                resultMessage = "Selecciona primero la aplicación; sus elementos asociados solo pueden retirarse con ella."
                return
            }
            plan = CleanerPlanner.settingUninstallSelection(selected, candidateID: candidateID, in: plan)
        } else {
            plan = CleanerPlanner.settingSelection(selected, candidateID: candidateID, in: plan)
        }
    }

    func selectSafeItems() {
        if uninstallAnalysis != nil {
            let applicationSelected = plan.candidates.contains { $0.category == .application && $0.selected }
            plan = CleanerPlanner.selectingSafeUninstallItems(in: plan)
            if !applicationSelected { resultMessage = "Selecciona primero la aplicación para incluir sus elementos regenerables." }
        } else {
            plan = CleanerPlanner.plan(candidates: plan.candidates, selectSafeItems: true)
        }
    }

    func canSelect(_ candidate: CleanerCandidate) -> Bool {
        guard CleanerPlanner.canSelect(candidate) else { return false }
        if uninstallAnalysis != nil && candidate.category != .application {
            return plan.candidates.contains { $0.category == .application && $0.selected }
        }
        return true
    }

    func deselectAll() {
        plan = CleanerRemovalPlan(candidates: plan.candidates.map { CleanerPlanner.copy($0, selected: false) })
    }

    func conserve(_ candidate: CleanerCandidate, value: Bool = true) {
        do {
            try repository?.keep(path: candidate.url.path, value: value)
            if value { setSelected(false, candidateID: candidate.id) }
            conservedPaths = ((try? repository?.keptPaths()) ?? []).sorted()
            resultMessage = value ? "Elemento marcado como Conservado." : "Se ha revocado la decisión de conservar."
        } catch { errorMessage = error.localizedDescription }
    }

    func analyzeUninstall(_ application: CleanerAppInventoryItem, preservingResult: Bool = false) {
        if !preservingResult { resultMessage = nil; executionSummary = nil }
        let historical = (try? repository?.loadInventory()) ?? []
        let kept = (try? repository?.keptPaths()) ?? []
        let output = uninstallAnalyzer.analyze(application: application, historicalApps: historical, keptPaths: kept, safeSelection: preferences.safeSelectionEnabled)
        uninstallAnalysis = output
        plan = output.plan
    }

    func analyzeDroppedApplication(_ url: URL) {
        guard let identity = identityProvider.identity(for: url) else {
            errorMessage = "El elemento soltado no es un bundle .app válido."
            return
        }
        let size = CleanerFileInspection.recursiveSize(at: url).logical
        analyzeUninstall(CleanerAppInventoryItem(identity: identity, logicalSize: size))
    }

    func closeApplicationAndReanalyze() {
        guard let uninstallAnalysis, let bundleID = uninstallAnalysis.application.identity.bundleID else { return }
        let apps = NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier == bundleID }
        apps.forEach { _ = $0.terminate() }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            self.analyzeUninstall(uninstallAnalysis.application)
        }
    }

    func executeCurrentPlan(kind: String? = nil) async {
        guard !isBusy, !plan.selectedCandidates.isEmpty else { return }
        let applicationURL = uninstallAnalysis.map { URL(fileURLWithPath: $0.application.identity.path) }
        let shouldRefresh = uninstallAnalysis == nil
        isBusy = true; errorMessage = nil; resultMessage = nil
        do {
            let output = try await executionService.execute(plan: plan, mode: preferences.deletionMode, kind: kind ?? (shouldRefresh ? "cleaning" : "uninstall"))
            let summary = output.summary
            if preferences.deletionMode == .trash && summary.removedCount > 0 && undoService != nil { lastHistoryID = output.historyID }
            executionSummary = summary
            resultMessage = "\(summary.removedCount) eliminados · \(summary.skippedCount) omitidos · \(summary.failedCount) fallidos."
            plan = CleanerRemovalPlan(candidates: [])
            analysis = nil
            uninstallAnalysis = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isBusy = false
        guard errorMessage == nil else { return }
        if let applicationURL, FileManager.default.fileExists(atPath: applicationURL.path),
           let identity = identityProvider.identity(for: applicationURL) {
            let item = CleanerAppInventoryItem(identity: identity, logicalSize: CleanerFileInspection.recursiveSize(at: applicationURL).logical)
            analyzeUninstall(item, preservingResult: true)
            deselectAll()
        } else {
            await analyze(preservingResult: true)
        }
    }

    func undoLast() async {
        guard let historyID = lastHistoryID, let undoService else { return }
        isBusy = true; defer { isBusy = false }
        do {
            let summary = try await undoService.undo(historyID: historyID)
            resultMessage = "\(summary.restoredCount) elementos restaurados; \(summary.skippedCount + summary.failedCount) no se pudieron restaurar."
            executionSummary = nil
            if summary.restoredCount > 0 { lastHistoryID = nil }
        } catch { errorMessage = error.localizedDescription }
    }

    func persistPreferences() {
        preferences.oldInstallerDays = max(1, preferences.oldInstallerDays)
        do { try settingsStore.save(preferences) } catch { errorMessage = error.localizedDescription }
    }

    func restorePreferences() {
        preferences = .default
        do { try settingsStore.restoreDefaults() } catch { errorMessage = error.localizedDescription }
    }

    func restorePersistentDefaultsForGlobalReset() -> [String] {
        preferences = .default
        do { try settingsStore.restoreDefaults(); return [] }
        catch { return ["Limpiador: \(error.localizedDescription)"] }
    }

    func addAdditionalLocation(_ url: URL) {
        do {
            let bookmark = try SystemFolderBookmarkCodec().makeBookmark(for: url)
            guard !preferences.additionalFolderBookmarks.contains(bookmark) else { return }
            preferences.additionalFolderBookmarks.append(bookmark)
            persistPreferences()
        } catch { errorMessage = error.localizedDescription }
    }

    func removeAdditionalLocation(at index: Int) {
        guard preferences.additionalFolderBookmarks.indices.contains(index) else { return }
        preferences.additionalFolderBookmarks.remove(at: index); persistPreferences()
    }

    func additionalLocationNames() -> [String] {
        let codec = SystemFolderBookmarkCodec()
        return preferences.additionalFolderBookmarks.map { data in
            (try? codec.resolveBookmark(data).url.path) ?? "Ubicación no disponible"
        }
    }

    func revokeConservedPath(_ path: String) {
        do { try repository?.keep(path: path, value: false); conservedPaths = ((try? repository?.keptPaths()) ?? []).sorted() }
        catch { errorMessage = error.localizedDescription }
    }

    func locateApplication(for candidate: CleanerCandidate, at url: URL) async {
        guard let identity = identityProvider.identity(for: url) else { errorMessage = "La ruta seleccionada no contiene una aplicación válida."; return }
        if let expected = candidate.associatedBundleID, identity.bundleID != expected {
            errorMessage = "La aplicación seleccionada no coincide con el Bundle ID esperado (\(expected))."; return
        }
        do {
            let item = CleanerAppInventoryItem(identity: identity, logicalSize: CleanerFileInspection.recursiveSize(at: url).logical)
            try repository?.upsertInventory([item])
            resultMessage = "Ubicación de la aplicación actualizada."
            await analyze()
        } catch { errorMessage = error.localizedDescription }
    }

    func clearInventoryHistory() {
        do { try repository?.clearInventoryHistory(); resultMessage = "Inventario histórico del Limpiador borrado." }
        catch { errorMessage = error.localizedDescription }
    }

    func scanSpace(root: URL? = nil) async {
        guard !isBusy else { return }
        let target = root ?? spaceRoot
        isBusy = true; errorMessage = nil
        do {
            let operationID = try await coordinator.begin(moduleID: cleanerModuleIdentifier, name: "Analizando espacio")
            do {
                try? await coordinator.update(id: operationID, progress: .init(completed: 0, total: nil, phase: "Calculando tamaños", currentItem: target.lastPathComponent))
                let minimum = Int64(max(0, spaceMinimumMB)) * 1_024 * 1_024
                let scanner = storageScanner
                let task = Task.detached { scanner.scan(root: target, maximumDepth: 3) }
                spaceScanTask = task
                let node = await task.value
                spaceScanTask = nil
                if await coordinator.shouldCancel(id: operationID) {
                    resultMessage = "Análisis de espacio cancelado."
                } else if minimum > 0, let node {
                    spaceTree = Self.filter(node: node, minimum: minimum)
                } else {
                    spaceTree = node
                }
                spaceRoot = target
                try? await coordinator.finish(id: operationID)
            } catch {
                try? await coordinator.finish(id: operationID)
                throw error
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        spaceScanTask = nil
        isBusy = false
    }

    private static func filter(node: CleanerStorageNode, minimum: Int64) -> CleanerStorageNode? {
        let children = node.children.compactMap { filter(node: $0, minimum: minimum) }
        guard node.logicalSize >= minimum || !children.isEmpty else { return nil }
        return CleanerStorageNode(url: node.url, logicalSize: node.logicalSize, allocatedSize: node.allocatedSize, isDirectory: node.isDirectory, children: children)
    }
}
