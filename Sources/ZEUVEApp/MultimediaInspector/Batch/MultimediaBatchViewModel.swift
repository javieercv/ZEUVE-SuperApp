import Foundation
import AppKit
import SwiftUI
import ZEUVECore
import ZEUVEOperations
import ZEUVEEngines
import MultimediaInspectorModule

@MainActor
final class MultimediaBatchViewModel: ObservableObject {
    @Published private(set) var items: [MultimediaBatchItem] = []
    @Published var configuration: MultimediaBatchConfiguration
    @Published var selectedPresetID: UUID?
    @Published private(set) var presets: [MultimediaInspectorBatchPreset]
    @Published private(set) var savedRuleSets: [MultimediaBatchRuleSet]
    @Published private(set) var favorites: [MultimediaInspectorFavorite]
    @Published private(set) var outputDirectory: URL?
    @Published private(set) var isRunning = false
    @Published private(set) var currentIndex: Int?
    @Published private(set) var currentFraction: Double?
    @Published private(set) var runSummary: MultimediaBatchRunSummary?
    @Published var errorMessage: String?
    @Published var warningMessage: String?
    @Published var folderOptions: MultimediaBatchFolderOptions
    @Published var structuralRuleSet = MultimediaBatchRuleSet(name: "Reglas del lote", rules: [])
    @Published private(set) var preflightItems: [MultimediaBatchPreflightItem] = []
    @Published private(set) var isPreflighting = false
    @Published private(set) var isExecutingStructural = false
    @Published private(set) var structuralCompleted = 0
    @Published private(set) var structuralFailed = 0
    @Published private(set) var structuralOutputDirectory: URL?

    private let processor: MultimediaBatchProcessor?
    private let history: MultimediaInspectorHistoryService
    private let presetStore: MultimediaInspectorBatchPresetStore
    private let ruleSetStore: MultimediaInspectorRuleSetStore
    private let favoritesStore: MultimediaInspectorFavoritesStore
    private let locator: MultimediaEngineLocator?
    private let structuralEditService: MultimediaEditService?
    private let preflightService: MultimediaBatchPreflightService
    private let folderEnumerator = MultimediaBatchFolderEnumerator()
    private let inspectionService = MediaInspectionService()
    private var preferences: MultimediaInspectorPreferences
    private var runTask: Task<Void, Never>?
    private var folderTask: Task<Void, Never>?
    private var structuralTask: Task<Void, Never>?
    private var runStartedAt: Date?

    init(
        processor: MultimediaBatchProcessor?,
        history: MultimediaInspectorHistoryService,
        presetStore: MultimediaInspectorBatchPresetStore,
        ruleSetStore: MultimediaInspectorRuleSetStore,
        favoritesStore: MultimediaInspectorFavoritesStore,
        preferences: MultimediaInspectorPreferences,
        coordinator: OperationCoordinator,
        engineRegistry: EngineRegistry?,
        engineDiagnostics: EngineDiagnosticService?
    ) {
        self.processor = processor
        self.history = history
        self.presetStore = presetStore
        self.ruleSetStore = ruleSetStore
        self.favoritesStore = favoritesStore
        self.preferences = preferences
        self.folderOptions = preferences.batchFolderOptions
        self.preflightService = MultimediaBatchPreflightService(coordinator: coordinator)
        if let engineRegistry {
            self.locator = MultimediaEngineLocator(registry: engineRegistry, diagnostics: engineDiagnostics)
            self.structuralEditService = MultimediaEditService(coordinator: coordinator, engineRegistry: engineRegistry, diagnostics: engineDiagnostics, history: history, preferences: preferences)
        } else {
            self.locator = nil
            self.structuralEditService = nil
        }
        let loadedPresets = presetStore.load()
        let defaultPreset = loadedPresets.first(where: { $0.id == preferences.defaultBatchPresetID }) ?? loadedPresets.first
        presets = loadedPresets
        savedRuleSets = ruleSetStore.load()
        favorites = favoritesStore.load()
        selectedPresetID = defaultPreset?.id
        configuration = defaultPreset?.configuration ?? preferences.batchConfigurationDefaults
    }

    var needsOutputFolder: Bool { configuration.exportSpectrogram || configuration.reportFormat != nil }
    var canStart: Bool { !items.isEmpty && !isRunning && (!needsOutputFolder || outputDirectory != nil) }
    var canRetryFailures: Bool { !isRunning && items.contains(where: { $0.status == .failed }) }
    var completedCount: Int { items.filter { $0.status.isTerminal }.count }
    var overallProgress: Double { items.isEmpty ? 0 : Double(completedCount) / Double(items.count) }

    func updatePreferences(_ value: MultimediaInspectorPreferences) {
        preferences = value
        folderOptions = value.batchFolderOptions
        if selectedPresetID == nil {
            configuration = value.batchConfigurationDefaults
        }
    }

    func refreshPresets(defaultPresetID: UUID?) {
        presets = presetStore.load()
        let target = defaultPresetID.flatMap { id in presets.first(where: { $0.id == id }) } ?? presets.first
        if selectedPresetID == nil || !presets.contains(where: { $0.id == selectedPresetID }) {
            selectedPresetID = target?.id
            if let target { configuration = target.configuration }
        }
    }

    func prepare(urls: [URL], resetConfiguration: Bool = true) {
        guard !isRunning else { return }
        if resetConfiguration {
            let defaultPreset = preferences.defaultBatchPresetID.flatMap { id in presets.first(where: { $0.id == id }) } ?? presets.first
            selectedPresetID = defaultPreset?.id
            configuration = defaultPreset?.configuration ?? preferences.batchConfigurationDefaults
        }
        var seen = Set<String>()
        var values: [MultimediaBatchItem] = []
        var rejected: [String] = []
        for rawURL in urls {
            let standardized = rawURL.standardizedFileURL
            do {
                let resources = try standardized.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                guard resources.isRegularFile == true, resources.isSymbolicLink != true else {
                    rejected.append(rawURL.lastPathComponent)
                    continue
                }
                let url = standardized.resolvingSymlinksInPath()
                let key = url.path
                guard seen.insert(key).inserted else { continue }
                values.append(.init(url: url, fingerprint: try FileFingerprint.read(from: url)))
            } catch {
                rejected.append(rawURL.lastPathComponent)
            }
        }
        items = values
        currentIndex = nil
        currentFraction = nil
        runSummary = nil
        warningMessage = rejected.isEmpty ? nil : "Se omitieron \(rejected.count) elementos que no eran archivos regulares o no podían leerse."
        errorMessage = nil
    }

    func append(urls: [URL]) {
        guard !isRunning else { return }
        let existing = Set(items.map { $0.url.standardizedFileURL.resolvingSymlinksInPath().path })
        let additions = urls.filter { !existing.contains($0.standardizedFileURL.resolvingSymlinksInPath().path) }
        let previous = items
        prepare(urls: previous.map(\.url) + additions, resetConfiguration: false)
    }

    func remove(_ item: MultimediaBatchItem) {
        guard !isRunning else { return }
        items.removeAll { $0.id == item.id }
        runSummary = nil
    }

    func clear() {
        guard !isRunning else { return }
        items = []
        currentIndex = nil
        currentFraction = nil
        runSummary = nil
        warningMessage = nil
        errorMessage = nil
        preflightItems = []
        structuralCompleted = 0
        structuralFailed = 0
    }

    func chooseInputFolder() {
        guard !isRunning, !isPreflighting, !isExecutingStructural else { return }
        let panel = NSOpenPanel(); panel.title = "Añadir carpeta al lote"; panel.prompt = "Añadir carpeta"
        panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.allowsMultipleSelection = false; panel.resolvesAliases = false
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        enumerateAndAppend(folder: folder)
    }

    func enumerateAndAppend(folder: URL) {
        folderTask?.cancel()
        let options = folderOptions
        folderTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await Task.detached { try self.folderEnumerator.enumerate(folder: folder, options: options) }.value
                guard !Task.isCancelled else { return }
                self.append(urls: result.files.map(\.url))
                let ignored = result.ignoredSymlinks + result.ignoredHidden + result.ignoredByFilter + result.unreadable
                if ignored > 0 { self.warningMessage = "Carpeta añadida: \(result.files.count) archivos; \(ignored) elementos omitidos por filtros o seguridad." }
            } catch is CancellationError { } catch { self.errorMessage = error.localizedDescription }
        }
    }

    func addStructuralRule(kind: MediaTrackKind, field: MultimediaBatchRuleField, match: MultimediaBatchRuleMatch, value: String, action: MultimediaBatchRuleAction, name: String) {
        guard !isPreflighting, !isExecutingStructural else { return }
        let condition = MultimediaBatchRuleCondition(kind: kind, field: field, match: match, value: value)
        structuralRuleSet.rules.append(.init(name: name.isEmpty ? "Regla \(structuralRuleSet.rules.count + 1)" : name, conditions: [condition], action: action))
        structuralRuleSet.modifiedAt = Date(); preflightItems = []
    }

    func removeStructuralRule(_ id: UUID) { structuralRuleSet.rules.removeAll { $0.id == id }; structuralRuleSet.modifiedAt = Date(); preflightItems = [] }

    func prepareStructuralPreflight() {
        guard !items.isEmpty, !structuralRuleSet.rules.isEmpty, let locator else {
            errorMessage = structuralRuleSet.rules.isEmpty ? "Añade al menos una regla estructural." : "FFprobe no está disponible."; return
        }
        structuralTask?.cancel(); isPreflighting = true; preflightItems = []; errorMessage = nil
        let files = items.map { MultimediaBatchDiscoveredFile(url: $0.url, fingerprint: $0.fingerprint) }
        let rules = structuralRuleSet; let prefs = preferences
        structuralTask = Task { [weak self] in
            guard let self else { return }; defer { self.isPreflighting = false }
            do {
                let ffprobe = try await locator.ffprobe()
                let prepared = await self.preflightService.prepare(files: files, ruleSet: rules, ffprobe: ffprobe, preferences: prefs)
                if self.folderOptions.incompatiblePolicy == .skip {
                    let omitted = prepared.filter { $0.classification == .incompatible }.count
                    self.preflightItems = prepared.filter { $0.classification != .incompatible }
                    if omitted > 0 { self.warningMessage = "Preflight: se omitieron \(omitted) archivos incompatibles según la política configurada." }
                } else {
                    self.preflightItems = prepared
                }
            } catch is CancellationError { } catch { self.errorMessage = error.localizedDescription }
        }
    }

    func chooseStructuralOutputFolder() {
        guard !isExecutingStructural else { return }
        let panel = NSOpenPanel(); panel.title = "Carpeta para ediciones por lotes"; panel.prompt = "Usar carpeta"
        panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.allowsMultipleSelection = false; panel.canCreateDirectories = true
        if panel.runModal() == .OK { structuralOutputDirectory = panel.url }
    }

    var structuralApplicableCount: Int { preflightItems.filter { $0.plan != nil && ($0.classification == .applicable || $0.classification == .applicableWithWarnings) }.count }
    var canExecuteStructural: Bool { structuralApplicableCount > 0 && structuralOutputDirectory != nil && !isExecutingStructural && !isRunning }

    func executeStructuralBatch() {
        guard canExecuteStructural, let outputFolder = structuralOutputDirectory, let editService = structuralEditService, let locator else { return }
        structuralTask?.cancel(); isExecutingStructural = true; structuralCompleted = 0; structuralFailed = 0; errorMessage = nil
        let applicable = preflightItems.filter { $0.plan != nil && ($0.classification == .applicable || $0.classification == .applicableWithWarnings) }
        structuralTask = Task { [weak self] in
            guard let self else { return }; defer { self.isExecutingStructural = false }
            do {
                let ffprobe = try await locator.ffprobe()
                for item in applicable {
                    if Task.isCancelled { break }
                    guard let plan = item.plan else { continue }
                    do {
                        let inspection = try await self.inspectionService.inspect(url: item.url, ffprobe: ffprobe, fingerprint: item.fingerprint, useCache: false)
                        let base = item.url.deletingPathExtension().lastPathComponent + "_editado." + plan.targetContainer.fileExtension
                        _ = try await editService.execute(plan: plan, originalInspection: inspection, proposedOutput: outputFolder.appendingPathComponent(base))
                        self.structuralCompleted += 1
                    } catch MultimediaInspectorError.cancelled { return } catch is CancellationError { return } catch { self.structuralFailed += 1 }
                }
                if self.structuralFailed > 0 { self.warningMessage = "Edición por lotes finalizada: \(self.structuralCompleted) correctos y \(self.structuralFailed) fallidos. Los originales permanecen intactos." }
            } catch { self.errorMessage = error.localizedDescription }
        }
    }

    func cancelStructural() { structuralTask?.cancel(); Task { await structuralEditService?.cancel() } }

    var favoritePresets: [MultimediaInspectorBatchPreset] {
        presets.filter { isFavoritePreset($0.id) }
    }

    var favoriteRuleSets: [MultimediaBatchRuleSet] {
        savedRuleSets.filter { isFavoriteRuleSet($0.id) }
    }

    func isFavoritePreset(_ id: UUID) -> Bool {
        favorites.contains { $0.kind == .batchPreset && $0.referencedID == id }
    }

    func isFavoriteRuleSet(_ id: UUID) -> Bool {
        favorites.contains { $0.kind == .structuralRuleSet && $0.referencedID == id }
    }

    func toggleFavoritePreset(_ preset: MultimediaInspectorBatchPreset) {
        do {
            favorites = try favoritesStore.setFavorite(kind: .batchPreset, referencedID: preset.id, displayName: preset.name, favorite: !isFavoritePreset(preset.id))
        } catch {
            errorMessage = "No se ha podido actualizar el favorito: \(error.localizedDescription)"
        }
    }

    func toggleFavoriteRuleSet(_ ruleSet: MultimediaBatchRuleSet) {
        do {
            favorites = try favoritesStore.setFavorite(kind: .structuralRuleSet, referencedID: ruleSet.id, displayName: ruleSet.name, favorite: !isFavoriteRuleSet(ruleSet.id))
        } catch {
            errorMessage = "No se ha podido actualizar el favorito: \(error.localizedDescription)"
        }
    }

    func saveCurrentRuleSet(named rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { errorMessage = "Escribe un nombre para el conjunto de reglas."; return }
        guard !structuralRuleSet.rules.isEmpty else { errorMessage = "Añade al menos una regla antes de guardar el conjunto."; return }
        let value = MultimediaBatchRuleSet(schemaVersion: MultimediaInspectorRuleSetStore.currentSchemaVersion, name: name, rules: structuralRuleSet.rules)
        savedRuleSets.append(value)
        structuralRuleSet = value
        persistRuleSets()
    }

    func updateCurrentRuleSet() {
        guard let index = savedRuleSets.firstIndex(where: { $0.id == structuralRuleSet.id }) else { return }
        structuralRuleSet.modifiedAt = Date()
        savedRuleSets[index] = structuralRuleSet
        persistRuleSets()
    }

    func applyRuleSet(_ ruleSet: MultimediaBatchRuleSet) {
        guard !isPreflighting, !isExecutingStructural else { return }
        structuralRuleSet = ruleSet
        preflightItems = []
    }

    func deleteRuleSet(_ ruleSet: MultimediaBatchRuleSet) {
        savedRuleSets.removeAll { $0.id == ruleSet.id }
        do {
            try ruleSetStore.save(savedRuleSets)
            if isFavoriteRuleSet(ruleSet.id) {
                favorites = try favoritesStore.setFavorite(kind: .structuralRuleSet, referencedID: ruleSet.id, displayName: ruleSet.name, favorite: false)
            }
            if structuralRuleSet.id == ruleSet.id { structuralRuleSet = .init(name: "Reglas del lote", rules: []) }
        } catch {
            errorMessage = "No se ha podido eliminar el conjunto de reglas: \(error.localizedDescription)"
        }
    }

    private func persistRuleSets() {
        do { try ruleSetStore.save(savedRuleSets) }
        catch { errorMessage = "No se han podido guardar las reglas del Inspector: \(error.localizedDescription)" }
    }

    func applyPreset(_ preset: MultimediaInspectorBatchPreset) {
        guard !isRunning else { return }
        selectedPresetID = preset.id
        configuration = preset.configuration
        configuration.normalize()
    }

    func createPreset(named rawName: String, configuration: MultimediaBatchConfiguration? = nil) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { errorMessage = "Escribe un nombre para el preset."; return }
        var value = configuration ?? self.configuration
        value.normalize()
        let preset = MultimediaInspectorBatchPreset(
            schemaVersion: MultimediaInspectorBatchPresetStore.currentSchemaVersion,
            name: name,
            configuration: value
        )
        presets.append(preset)
        selectedPresetID = preset.id
        persistPresets()
    }

    func renamePreset(_ preset: MultimediaInspectorBatchPreset, to rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index].name = name
        presets[index].modifiedAt = Date()
        persistPresets()
        if isFavoritePreset(preset.id) {
            do { favorites = try favoritesStore.setFavorite(kind: .batchPreset, referencedID: preset.id, displayName: name, favorite: true) }
            catch { errorMessage = "El preset se guardó, pero no se pudo actualizar el favorito: \(error.localizedDescription)" }
        }
    }

    func updatePreset(_ preset: MultimediaInspectorBatchPreset, configuration: MultimediaBatchConfiguration) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        var normalized = configuration
        normalized.normalize()
        presets[index].configuration = normalized
        presets[index].modifiedAt = Date()
        if selectedPresetID == preset.id { self.configuration = normalized }
        persistPresets()
    }

    func duplicatePreset(_ preset: MultimediaInspectorBatchPreset) {
        let copy = MultimediaInspectorBatchPreset(
            schemaVersion: MultimediaInspectorBatchPresetStore.currentSchemaVersion,
            name: preset.name + " (copia)",
            configuration: preset.configuration
        )
        presets.append(copy)
        selectedPresetID = copy.id
        persistPresets()
    }

    func deletePreset(_ preset: MultimediaInspectorBatchPreset) {
        guard presets.count > 1 else {
            errorMessage = "Debe existir al menos un preset de lote."
            return
        }
        presets.removeAll { $0.id == preset.id }
        if isFavoritePreset(preset.id) {
            do { favorites = try favoritesStore.setFavorite(kind: .batchPreset, referencedID: preset.id, displayName: preset.name, favorite: false) }
            catch { errorMessage = "No se ha podido limpiar el favorito asociado: \(error.localizedDescription)" }
        }
        if selectedPresetID == preset.id {
            selectedPresetID = presets.first?.id
            if let first = presets.first { configuration = first.configuration }
        }
        persistPresets()
    }

    func restoreDefaultPresets() {
        do {
            presets = try presetStore.restoreDefaults()
            let preferred = preferences.defaultBatchPresetID.flatMap { id in presets.first(where: { $0.id == id }) } ?? presets.first
            selectedPresetID = preferred?.id
            if let preferred { configuration = preferred.configuration }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persistPresets() {
        do { try presetStore.save(presets) }
        catch { errorMessage = "No se han podido guardar los presets del Inspector: \(error.localizedDescription)" }
    }

    func chooseOutputFolder() {
        guard !isRunning else { return }
        let panel = NSOpenPanel()
        panel.title = "Seleccionar carpeta de resultados"
        panel.prompt = "Usar carpeta"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK { outputDirectory = panel.url }
    }

    func clearOutputFolder() {
        guard !isRunning else { return }
        outputDirectory = nil
    }

    func start() {
        guard canStart, let processor else {
            if self.processor == nil { errorMessage = "FFmpeg/FFprobe no están disponibles para el lote." }
            else if needsOutputFolder { errorMessage = "Selecciona una carpeta para los resultados." }
            return
        }
        var normalized = configuration
        normalized.normalize()
        configuration = normalized
        if let outputDirectory, needsOutputFolder {
            do {
                let estimate = MultimediaBatchOutputPolicy().estimatedOutputBytes(fileCount: items.count, configuration: normalized)
                try MultimediaDiskSpaceChecker().require(estimatedBytes: estimate, at: outputDirectory)
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        }

        runTask?.cancel()
        runSummary = nil
        errorMessage = nil
        isRunning = true
        runStartedAt = Date()
        let protectedOriginals = items.map(\.url)
        runTask = Task { [weak self] in
            guard let self else { return }
            await processor.resetCancellation()
            for index in items.indices {
                if Task.isCancelled { break }
                currentIndex = index
                currentFraction = nil
                items[index].status = .queued
                items[index].phase = nil
                items[index].warning = nil
                items[index].error = nil
                items[index].generatedOutputs = []
                do {
                    let item = items[index]
                    let outcome = try await processor.process(
                        item: item,
                        configuration: normalized,
                        outputDirectory: outputDirectory,
                        protectedOriginals: protectedOriginals
                    ) { [weak self] status, phase, fraction in
                        Task { @MainActor [weak self] in
                            guard let self, self.items.indices.contains(index) else { return }
                            self.items[index].status = status
                            self.items[index].phase = phase
                            self.currentFraction = fraction
                        }
                    }
                    switch outcome {
                    case .completed(let result):
                        items[index].summary = result.summary
                        items[index].generatedOutputs = result.generatedOutputs
                        items[index].warning = result.warning
                        items[index].phase = result.warning == nil ? "Completado" : "Completado con aviso"
                        items[index].status = result.warning == nil ? .completed : .completedWithWarning
                    case .skipped(let summary, let reason):
                        items[index].summary = summary
                        items[index].warning = reason
                        items[index].phase = reason
                        items[index].status = .skipped
                    }
                } catch MultimediaInspectorError.cancelled {
                    items[index].status = .cancelled
                    items[index].phase = "Cancelado"
                    break
                } catch is CancellationError {
                    items[index].status = .cancelled
                    items[index].phase = "Cancelado"
                    break
                } catch {
                    items[index].status = .failed
                    items[index].error = error.localizedDescription
                    items[index].phase = "Falló: \(error.localizedDescription)"
                }
                currentFraction = nil
            }
            if Task.isCancelled || items.contains(where: { !$0.status.isTerminal }) {
                for index in items.indices where !items[index].status.isTerminal {
                    items[index].status = .cancelled
                    items[index].phase = "Cancelado"
                }
            }
            finalizeRun()
        }
    }

    func cancel() {
        guard isRunning else { return }
        runTask?.cancel()
        Task { [weak self] in await self?.processor?.cancel() }
    }

    func cancelAndWait() async {
        cancel()
        _ = await runTask?.result
    }

    func retryFailures() {
        guard canRetryFailures else { return }
        let failedURLs = items.filter { $0.status == .failed }.map(\.url)
        prepare(urls: failedURLs, resetConfiguration: false)
        start()
    }

    func openResultsFolder() {
        guard let outputDirectory else { return }
        NSWorkspace.shared.open(outputDirectory)
    }

    private func finalizeRun() {
        let started = runStartedAt ?? Date()
        let finished = Date()
        let summary = MultimediaBatchRunSummary(
            total: items.count,
            completed: items.filter { $0.status == .completed }.count,
            warnings: items.filter { $0.status == .completedWithWarning }.count,
            skipped: items.filter { $0.status == .skipped }.count,
            failed: items.filter { $0.status == .failed }.count,
            cancelled: items.filter { $0.status == .cancelled }.count,
            reportsGenerated: items.flatMap(\.generatedOutputs).filter { ["txt", "md", "json"].contains($0.pathExtension.lowercased()) }.count,
            spectrogramsGenerated: items.flatMap(\.generatedOutputs).filter { $0.pathExtension.lowercased() == "png" }.count,
            durationSeconds: finished.timeIntervalSince(started)
        )
        runSummary = summary
        currentIndex = nil
        currentFraction = nil
        isRunning = false
        runTask = nil
        let warning = ZEUVEHistoryPersistence.attempt {
            try history.saveBatch(id: UUID(), summary: summary, startedAt: started, finishedAt: finished)
        }?.warning
        if let warning { warningMessage = [warningMessage, warning].compactMap { $0 }.joined(separator: " ") }
    }
}
