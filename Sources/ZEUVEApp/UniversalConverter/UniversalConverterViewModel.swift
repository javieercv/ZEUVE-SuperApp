import Foundation
import AppKit
import SwiftUI
import UniformTypeIdentifiers
import ZEUVECore
import ZEUVEStorage
import ZEUVEOperations
import ZEUVEEngines
import UniversalConverterModule

@MainActor
enum UniversalConverterScreenState: Equatable {
    case idle
    case scanning
    case preview
    case running
    case result
}

@MainActor
final class UniversalConverterViewModel: ObservableObject {
    @Published var state: UniversalConverterScreenState = .idle
    @Published var inputs: [ConverterInputItem] = []
    @Published var scanWarnings: [String] = []
    @Published var rejectedInputs: [String] = []
    @Published var options: ConverterOperationOptions
    @Published var defaultSettings: UniversalConverterSettings
    @Published var outputFolder: URL?
    @Published var plan: ConversionPlan?
    @Published var result: UniversalConverterResult?
    @Published var progress: ConverterProgressSnapshot?
    @Published var errorMessage: String?
    @Published var isDropTargeted = false
    @Published var engineSummary = "Sin comprobar"
    @Published var engineAvailability = ConverterEngineAvailability()
    @Published var diagnosticsReport: UniversalConverterDiagnosticsReport?
    @Published var archivePassword = ""
    @Published var presets: [UniversalConverterPreset]
    @Published var selectedPresetID: UUID?
    @Published var favorites: [UniversalConverterFavorite]
    @Published var selectedFavoriteID: UUID?
    @Published var isArchivePasswordVisible = false

    private let settingsRepository: SettingsRepository?
    private let bookmarkStore: ConverterOutputBookmarkStore?
    private var outputFolderAccess: ConverterSecurityScopedResourceAccess?
    private var planner = ConversionPlanner(compatibility: .init(availability: ConverterEngineAvailability()))
    private let diagnosticService: UniversalConverterDiagnosticService?
    private let execution: UniversalConverterExecutionService
    private var inputScanner: ConverterInputScanner
    private var inputScannerLimits: ConverterArchiveLimits
    private var scanTask: Task<Void, Never>?
    private var planTask: Task<Void, Never>?
    private var executionTask: Task<Void, Never>?
    private var archivePasswordTask: Task<Void, Never>?
    private var sourceURLs: [URL] = []
    private var planRevision: UInt64 = 0
    private static let settingsKey = "universalConverter.defaults.v4"
    private static let legacySettingsV3Key = "universalConverter.defaults.v3"
    private static let legacySettingsV2Key = "universalConverter.defaults.v2"
    private static let legacySettingsV1Key = "universalConverter.defaults.v1"
    private static let presetsKey = "universalConverter.presets.v4"
    private static let legacyPresetsV3Key = "universalConverter.presets.v3"
    private static let legacyPresetsV2Key = "universalConverter.presets.v2"
    private static let legacyPresetsV1Key = "universalConverter.presets.v1"
    private static let favoritesKey = "universalConverter.favorites.v1"

    init(
        coordinator: OperationCoordinator,
        storage: StorageContainer?,
        logger: LocalLogger?,
        engineRegistry: EngineRegistry? = nil,
        engineDiagnostics: EngineDiagnosticService? = nil
    ) {
        settingsRepository = storage?.settings
        bookmarkStore = storage.map { ConverterOutputBookmarkStore(settings: $0.settings) }
        var loaded = UniversalConverterSettings()
        var migratedSettings = false
        if let storage {
            if let stored = try? storage.settings.value(forKey: Self.settingsKey, as: UniversalConverterSettings.self) {
                loaded = stored
            } else if let legacy = try? storage.settings.value(forKey: Self.legacySettingsV3Key, as: UniversalConverterSettings.self) {
                loaded = legacy
                loaded.preferRemuxWhenPossible = false
                migratedSettings = true
            } else if let legacy = try? storage.settings.value(forKey: Self.legacySettingsV2Key, as: UniversalConverterSettings.self) {
                loaded = legacy
                loaded.preferRemuxWhenPossible = false
                migratedSettings = true
            } else if let legacy = try? storage.settings.value(forKey: Self.legacySettingsV1Key, as: UniversalConverterSettings.self) {
                loaded = legacy
                loaded.preferRemuxWhenPossible = false
                migratedSettings = true
            }
        }
        loaded.normalize()
        if migratedSettings { try? storage?.settings.set(loaded, forKey: Self.settingsKey) }
        defaultSettings = loaded
        options = ConverterOperationOptions(settings: loaded)
        inputScannerLimits = loaded.archiveLimits
        inputScanner = ConverterInputScanner(archiveLimits: loaded.archiveLimits)

        var migratedPresets = false
        let storedPresets: [UniversalConverterPreset]? = storage.flatMap { container in
            if let current = try? container.settings.value(forKey: Self.presetsKey, as: [UniversalConverterPreset].self) {
                return current
            }
            let legacy = (try? container.settings.value(forKey: Self.legacyPresetsV3Key, as: [UniversalConverterPreset].self))
                ?? (try? container.settings.value(forKey: Self.legacyPresetsV2Key, as: [UniversalConverterPreset].self))
                ?? (try? container.settings.value(forKey: Self.legacyPresetsV1Key, as: [UniversalConverterPreset].self))
            if legacy != nil { migratedPresets = true }
            return legacy
        } ?? nil
        let normalizedPresets = storedPresets?.map { preset -> UniversalConverterPreset in
            guard migratedPresets, preset.isBuiltIn, preset.name == "Vídeo MP4 compatible" else { return preset }
            var updated = preset
            updated.options.preferRemuxWhenPossible = false
            return updated
        }
        let resolvedPresets = normalizedPresets?.isEmpty == false ? normalizedPresets! : UniversalConverterPreset.defaults
        presets = resolvedPresets
        if migratedPresets { try? storage?.settings.set(resolvedPresets, forKey: Self.presetsKey) }
        favorites = storage.flatMap { try? $0.settings.value(forKey: Self.favoritesKey, as: [UniversalConverterFavorite].self) } ?? []
        selectedPresetID = nil
        selectedFavoriteID = nil
        let sharedLocator: UniversalConverterEngineLocator?
        do {
            let localRegistry: EngineRegistry
            if let engineRegistry {
                localRegistry = engineRegistry
            } else {
                localRegistry = try EngineRegistry.bundled()
            }
            sharedLocator = UniversalConverterEngineLocator(
                registry: localRegistry,
                diagnosticsService: engineDiagnostics
            )
        } catch {
            sharedLocator = nil
        }
        diagnosticService = sharedLocator.map { UniversalConverterDiagnosticService(locator: $0) }
        execution = UniversalConverterExecutionService(
            coordinator: coordinator,
            history: storage.map { UniversalConverterHistoryService(repository: $0.history) },
            logger: logger,
            engineLocator: sharedLocator
        )
    }

    var availableOperations: [ConversionOperation] {
        guard !inputs.isEmpty else { return [.convert] }
        if inputs.allSatisfy({ $0.format == .pdf }) {
            var values: [ConversionOperation] = []
            if engineAvailability.pdfKit { values += [.pdfToImages, .pdfToText] }
            return values.isEmpty ? [.convert] : values
        }
        let categories = Set(inputs.map(\.category))
        var values: [ConversionOperation] = [.convert]
        if categories == [.video], engineAvailability.ffmpeg { values += [.extractFrames, .extractAudio, .videoToAnimation] }
        if categories == [.audio], engineAvailability.ffmpeg { values += [.audioToVideo] }
        if categories == [.image] {
            if engineAvailability.pdfKit { values += [.imagesToPDF] }
            if engineAvailability.ffmpeg { values += [.imagesToVideo] }
        }
        if categories == [.animation], engineAvailability.ffmpeg { values += [.animationToVideo] }
        return values
    }

    var availableTargetFormats: [ConverterFormat] {
        switch options.operation {
        case .extractFrames:
            return engineAvailability.webPEncoder ? ConverterFrameFormat.allCases.map(\.converterFormat) : [.png, .jpeg, .tiff]
        case .extractAudio: return engineAvailability.ffmpeg ? [.m4a, .mp3, .flac, .wav, .opus, .ogg] : []
        case .audioToVideo: return engineAvailability.ffmpeg ? [.mp4, .mov, .mkv] : []
        case .pdfToImages: return engineAvailability.pdfKit ? [.png, .jpeg] : []
        case .pdfToText: return engineAvailability.pdfKit ? [.txt] : []
        case .imagesToPDF: return engineAvailability.pdfKit ? [.pdf] : []
        case .imagesToVideo, .animationToVideo: return engineAvailability.ffmpeg ? [.mp4, .mov, .mkv] : []
        case .videoToAnimation:
            guard engineAvailability.ffmpeg else { return [] }
            return engineAvailability.webPEncoder ? [.gif, .webp, .apng] : [.gif, .apng]
        case .convert:
            let formats = inputs.map(\.format)
            guard !formats.isEmpty else { return [] }
            return ConverterCompatibilityRegistry(availability: engineAvailability).outputFormats(for: formats)
        }
    }

    var canPrepare: Bool { !inputs.isEmpty && outputFolder != nil && options.targetFormat != nil && state != .running }
    var canExecute: Bool { plan != nil && state == .preview }
    var isBusy: Bool { state == .scanning || state == .running }

    func start() {
        refreshEngineSummary()
        restoreRememberedOutputFolder()
        let maximumAge = TimeInterval(defaultSettings.cleanupTemporaryMaximumAgeDays * 86_400)
        Task.detached(priority: .utility) {
            _ = try? ConverterWorkspace.recoverAbandonedVisibleFrameOutputs()
            _ = try? ConverterWorkspace.cleanupAbandoned(olderThan: maximumAge)
        }
    }

    func chooseInputs() {
        chooseMultipleInputs()
    }

    func chooseSingleInput() {
        let panel = NSOpenPanel()
        panel.title = "Seleccionar un archivo"
        panel.prompt = "Seleccionar"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = false
        if panel.runModal() == .OK { addURLs(panel.urls) }
    }

    func chooseMultipleInputs() {
        let panel = NSOpenPanel()
        panel.title = "Seleccionar varios archivos"
        panel.prompt = "Añadir"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.resolvesAliases = false
        if panel.runModal() == .OK { addURLs(panel.urls) }
    }

    func chooseZIPInput() {
        let panel = NSOpenPanel()
        panel.title = "Seleccionar un ZIP"
        panel.prompt = "Seleccionar ZIP"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = false
        panel.allowedContentTypes = [.zip]
        if panel.runModal() == .OK { addURLs(panel.urls) }
    }

    func chooseFolderInput() {
        let panel = NSOpenPanel()
        panel.title = "Seleccionar una carpeta"
        panel.prompt = "Seleccionar carpeta"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = false
        if panel.runModal() == .OK { addURLs(panel.urls) }
    }

    func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.title = "Seleccionar carpeta de salida"
        panel.prompt = "Seleccionar"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { setOutputFolder(url, persistBookmark: defaultSettings.rememberOutputFolder) }
    }

    func chooseAudioVideoImage() {
        let panel = NSOpenPanel()
        panel.title = "Seleccionar imagen"
        panel.prompt = "Seleccionar"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        if panel.runModal() == .OK {
            options.audioVideoImageURL = panel.url
            options.audioVideoBackground = .image
            schedulePlan()
        }
    }

    func addURLs(_ urls: [URL]) {
        let existing = Set(sourceURLs.map { $0.standardizedFileURL.path })
        let additions = urls.filter { !existing.contains($0.standardizedFileURL.path) }
        guard !additions.isEmpty else { return }
        archivePassword = ""
        isArchivePasswordVisible = false
        sourceURLs.append(contentsOf: additions)
        rescan()
    }

    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            accepted = true
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, _ in
                let url: URL?
                if let data = item as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
                else if let value = item as? URL { url = value }
                else if let value = item as? NSURL { url = value as URL }
                else { url = nil }
                guard let url else { return }
                Task { @MainActor in self?.addURLs([url]) }
            }
        }
        return accepted
    }

    func removeInput(_ item: ConverterInputItem) {
        inputs.removeAll { $0.id == item.id }
        if !inputs.contains(where: { $0.sourceURL == item.sourceURL }) {
            sourceURLs.removeAll { $0.standardizedFileURL == item.sourceURL.standardizedFileURL }
        }
        if inputs.isEmpty { state = .idle; plan = nil } else { synchronizeOperation(); schedulePlan() }
    }

    func clearInputs() {
        scanTask?.cancel(); planTask?.cancel(); archivePasswordTask?.cancel()
        Task { await inputScanner.clearCache() }
        sourceURLs.removeAll(); inputs.removeAll(); scanWarnings.removeAll(); rejectedInputs.removeAll()
        archivePassword = ""
        plan = nil; result = nil; progress = nil; state = .idle
    }

    func operationChanged() {
        selectedPresetID = nil
        synchronizeOperation()
        schedulePlan()
    }

    func optionsChanged(markQualityAsCustom: Bool = true) {
        if markQualityAsCustom { options.quality = .custom }
        options.normalize()
        selectedPresetID = nil
        selectedFavoriteID = nil
        schedulePlan()
    }

    func qualityChanged() {
        selectedPresetID = nil
        selectedFavoriteID = nil
        options.normalize()
        schedulePlan()
    }

    func archivePasswordChanged() {
        archivePasswordTask?.cancel()
        guard sourceURLs.contains(where: { $0.pathExtension.lowercased() == "zip" }) else { return }
        archivePasswordTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            self?.rescan()
        }
    }

    func applyPreset(_ id: UUID?) {
        selectedPresetID = id
        guard let id, let preset = presets.first(where: { $0.id == id }) else { return }
        options = preset.options
        options.audioVideoImageURL = nil
        let requestedOperation = options.operation
        let requestedTarget = options.targetFormat
        synchronizeOperation()
        if options.operation != requestedOperation || options.targetFormat != requestedTarget {
            selectedPresetID = nil
        }
        schedulePlan(delayNanoseconds: 0)
    }

    func createPreset(name: String? = nil) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let base = trimmed.isEmpty ? "Nueva conversión" : trimmed
        presets.append(.init(name: uniquePresetName(base), options: options))
        persistPresets()
    }

    func duplicatePreset(_ id: UUID) {
        guard let preset = presets.first(where: { $0.id == id }) else { return }
        presets.append(.init(name: uniquePresetName("Copia de \(preset.name)"), options: preset.options))
        persistPresets()
    }

    func deletePreset(_ id: UUID) {
        presets.removeAll { $0.id == id }
        if selectedPresetID == id { selectedPresetID = nil }
        persistPresets()
    }

    func renamePreset(_ id: UUID, to value: String) {
        guard let index = presets.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        presets[index].name = trimmed.isEmpty ? "Conversión sin nombre" : trimmed
        presets[index].isBuiltIn = false
        persistPresets()
    }

    func restoreDefaultPresets() {
        presets = UniversalConverterPreset.defaults
        selectedPresetID = nil
        persistPresets()
    }

    func persistPresets() {
        do { try settingsRepository?.set(presets, forKey: Self.presetsKey) }
        catch { errorMessage = "No se han podido guardar los preajustes: \(error.localizedDescription)" }
    }

    func prepareNow() { schedulePlan(delayNanoseconds: 0) }

    func executePlan() {
        guard let plan else { return }
        executionTask?.cancel()
        state = .running; result = nil; errorMessage = nil
        executionTask = Task { [weak self] in
            guard let self else { return }
            do {
                let password = self.archivePassword.trimmingCharacters(in: .whitespacesAndNewlines)
                let result = try await execution.execute(plan, archivePassword: password.isEmpty ? nil : password) { snapshot in
                    Task { @MainActor [weak self] in self?.progress = snapshot }
                }
                guard !Task.isCancelled else { return }
                self.archivePassword = ""
                self.isArchivePasswordVisible = false
                self.result = result
                self.state = .result
            } catch {
                guard !Task.isCancelled else { return }
                self.archivePassword = ""
                self.isArchivePasswordVisible = false
                self.errorMessage = error.localizedDescription
                self.state = self.inputs.isEmpty ? .idle : .preview
            }
        }
    }

    func cancel() {
        archivePassword = ""
        isArchivePasswordVisible = false
        executionTask?.cancel()
        Task { await execution.cancel() }
    }

    func cancelAndWait() async {
        executionTask?.cancel()
        await execution.cancel()
        _ = await executionTask?.result
    }

    func newConversion() {
        clearInputs()
        options = ConverterOperationOptions(settings: defaultSettings)
    }

    func closeResultKeepingInputs() {
        result = nil; progress = nil
        state = inputs.isEmpty ? .idle : .preview
        schedulePlan(delayNanoseconds: 0)
    }

    func persistDefaultSettings() {
        defaultSettings.normalize()
        if defaultSettings.archiveLimits != inputScannerLimits {
            inputScannerLimits = defaultSettings.archiveLimits
            inputScanner = ConverterInputScanner(archiveLimits: defaultSettings.archiveLimits)
            if !sourceURLs.isEmpty { rescan() }
        }
        do { try settingsRepository?.set(defaultSettings, forKey: Self.settingsKey) }
        catch { errorMessage = "No se han podido guardar los ajustes: \(error.localizedDescription)" }
    }

    func applyDefaultsToCurrentOperation() {
        options = ConverterOperationOptions(settings: defaultSettings)
        synchronizeOperation(); schedulePlan()
    }

    func restoreDefaults() {
        defaultSettings = UniversalConverterSettings()
        persistDefaultSettings()
    }

    func refreshEngineSummary(forceRefresh: Bool = false) {
        Task { [weak self] in
            guard let self else { return }
            guard let diagnosticService = self.diagnosticService else {
                self.engineSummary = "Los motores del Conversor no están preparados."
                self.engineAvailability = ConverterEngineAvailability()
                self.planner = ConversionPlanner(compatibility: .init(availability: self.engineAvailability))
                return
            }
            let report = await diagnosticService.snapshot(forceRefresh: forceRefresh)
            self.diagnosticsReport = report
            self.engineAvailability = report.availability
            self.planner = ConversionPlanner(compatibility: .init(availability: report.availability))
            let available = [
                report.availability.ffmpeg ? "FFmpeg" : nil,
                report.availability.pandoc ? "Pandoc" : nil,
                report.availability.calibre ? "Calibre" : nil,
                report.availability.ghostscript ? "Ghostscript" : nil,
            ].compactMap { $0 }
            self.engineSummary = available.isEmpty ? "No hay motores externos disponibles" : available.joined(separator: " · ")
            self.synchronizeOperation()
            self.schedulePlan(delayNanoseconds: 0)
        }
    }

    private func rescan() {
        scanTask?.cancel(); planTask?.cancel(); plan = nil; result = nil
        guard !sourceURLs.isEmpty else { state = .idle; return }
        state = .scanning; errorMessage = nil
        let urls = sourceURLs
        scanTask = Task { [weak self] in
            guard let self else { return }
            do {
                let password = self.archivePassword.trimmingCharacters(in: .whitespacesAndNewlines)
                let result = try await self.inputScanner.scan(urls: urls, archivePassword: password.isEmpty ? nil : password)
                try Task.checkCancellation()
                self.inputs = result.items
                self.scanWarnings = result.warnings
                self.rejectedInputs = result.rejected
                if self.inputs.isEmpty {
                    self.state = .idle
                    self.errorMessage = result.rejected.first ?? "No se ha encontrado ningún archivo compatible."
                } else {
                    self.synchronizeOperation()
                    self.state = .preview
                    self.schedulePlan(delayNanoseconds: 0)
                }
            } catch is CancellationError { }
            catch {
                self.state = .idle
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func uniquePresetName(_ proposed: String) -> String {
        let existing = Set(presets.map { $0.name.lowercased() })
        if !existing.contains(proposed.lowercased()) { return proposed }
        var number = 2
        while existing.contains("\(proposed) \(number)".lowercased()) { number += 1 }
        return "\(proposed) \(number)"
    }

    private func synchronizeOperation() {
        if !availableOperations.contains(options.operation) { options.operation = .convert }
        options.normalize()
        if !availableTargetFormats.contains(options.targetFormat ?? .unknown) {
            options.targetFormat = availableTargetFormats.first
        }
        options.normalize()
    }

    private func schedulePlan(delayNanoseconds: UInt64 = 180_000_000) {
        planTask?.cancel(); plan = nil
        guard canPrepare, let outputFolder else { return }
        planRevision &+= 1
        let revision = planRevision
        let currentInputs = inputs
        var currentOptions = options
        currentOptions.normalize()
        planTask = Task { [weak self] in
            guard let self else { return }
            if delayNanoseconds > 0 { try? await Task.sleep(nanoseconds: delayNanoseconds) }
            guard !Task.isCancelled else { return }
            do {
                let planned = try await planner.plan(inputs: currentInputs, outputFolder: outputFolder, options: currentOptions, revision: revision)
                guard !Task.isCancelled, revision == self.planRevision else { return }
                self.plan = planned
                if self.state != .running && self.state != .result { self.state = .preview }
            } catch is CancellationError { }
            catch {
                guard revision == self.planRevision else { return }
                self.errorMessage = error.localizedDescription
            }
        }
    }
}

@MainActor
extension UniversalConverterViewModel {
    func createFavorite(name: String? = nil, saveOutputFolder: Bool = false) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let base = trimmed.isEmpty ? "Conversión favorita" : trimmed
        let favorite = UniversalConverterFavorite(
            name: uniqueFavoriteName(base),
            sourceCategories: Array(Set(inputs.map(\.category))),
            sourceFormats: Array(Set(inputs.map(\.format))),
            targetFormat: options.targetFormat,
            engine: plan.flatMap { Set($0.items.map(\.executionKind)).count == 1 ? $0.items.first?.executionKind : nil },
            presetID: selectedPresetID,
            presetName: selectedPresetID.flatMap { id in presets.first(where: { $0.id == id })?.name },
            options: options,
            outputFolder: saveOutputFolder ? outputFolder : nil
        )
        favorites.append(favorite)
        selectedFavoriteID = favorite.id
        persistFavorites()
    }

    func applyFavorite(_ id: UUID?) {
        selectedFavoriteID = id
        guard let id, let favorite = favorites.first(where: { $0.id == id }) else { return }
        options = favorite.options
        selectedPresetID = favorite.presetID
        if let folder = favorite.outputFolder, (try? ConverterOutputBookmarkStore.validate(folder)) != nil {
            setOutputFolder(folder, persistBookmark: defaultSettings.rememberOutputFolder)
        }
        synchronizeOperation()
        schedulePlan(delayNanoseconds: 0)
    }

    func renameFavorite(_ id: UUID, to value: String) {
        guard let index = favorites.firstIndex(where: { $0.id == id }) else { return }
        favorites[index].rename(value)
        persistFavorites()
    }

    func duplicateFavorite(_ id: UUID) {
        guard let value = favorites.first(where: { $0.id == id }) else { return }
        var copy = value
        copy.id = UUID()
        copy.rename(uniqueFavoriteName("Copia de \(value.name)"))
        copy.createdAt = Date()
        copy.updatedAt = copy.createdAt
        copy.isPinned = false
        favorites.append(copy)
        persistFavorites()
    }

    func deleteFavorite(_ id: UUID) {
        favorites.removeAll { $0.id == id }
        if selectedFavoriteID == id { selectedFavoriteID = nil }
        persistFavorites()
    }

    func togglePinnedFavorite(_ id: UUID) {
        guard let index = favorites.firstIndex(where: { $0.id == id }) else { return }
        favorites[index].isPinned.toggle()
        favorites[index].updatedAt = Date()
        persistFavorites()
    }

    func persistFavorites() {
        do { try settingsRepository?.set(favorites, forKey: Self.favoritesKey) }
        catch { errorMessage = "No se han podido guardar las favoritas: \(error.localizedDescription)" }
    }

    func exportPresets() { exportData(defaultName: "Preajustes ZEUVE.json") { try ConverterRecipeFileService.encodePresets(presets) } }
    func exportFavorites() { exportData(defaultName: "Favoritas ZEUVE.json") { try ConverterRecipeFileService.encodeFavorites(favorites) } }
    func exportSettings() { exportData(defaultName: "Ajustes Conversor ZEUVE.json") { try ConverterRecipeFileService.encodeSettings(defaultSettings) } }

    func importPresets() {
        importData { data in
            let imported = try ConverterRecipeFileService.decodePresets(data)
            for preset in imported {
                var copy = preset
                copy.id = UUID()
                copy.name = uniquePresetName(copy.name)
                copy.isBuiltIn = false
                presets.append(copy)
            }
            persistPresets()
        }
    }

    func importFavorites() {
        importData { data in
            let imported = try ConverterRecipeFileService.decodeFavorites(data)
            for favorite in imported {
                var copy = favorite
                copy.id = UUID()
                copy.rename(uniqueFavoriteName(copy.name))
                favorites.append(copy)
            }
            persistFavorites()
        }
    }

    func importSettings() {
        importData { data in
            defaultSettings = try ConverterRecipeFileService.decodeSettings(data)
            persistDefaultSettings()
        }
    }

    private func exportData(defaultName: String, producer: () throws -> Data) {
        let panel = NSSavePanel()
        panel.title = "Exportar"
        panel.nameFieldStringValue = defaultName
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try producer().write(to: url, options: .atomic) }
        catch { errorMessage = "No se ha podido exportar: \(error.localizedDescription)" }
    }

    private func importData(consumer: (Data) throws -> Void) {
        let panel = NSOpenPanel()
        panel.title = "Importar"
        panel.prompt = "Importar"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try consumer(Data(contentsOf: url)) }
        catch { errorMessage = "No se ha podido importar: \(error.localizedDescription)" }
    }

    private func uniqueFavoriteName(_ proposed: String) -> String {
        let existing = Set(favorites.map { $0.name.lowercased() })
        if !existing.contains(proposed.lowercased()) { return proposed }
        var number = 2
        while existing.contains("\(proposed) \(number)".lowercased()) { number += 1 }
        return "\(proposed) \(number)"
    }

    private func setOutputFolder(_ url: URL, persistBookmark: Bool) {
        do {
            let valid = try ConverterOutputBookmarkStore.validate(url)
            outputFolderAccess?.stop()
            outputFolderAccess = ConverterSecurityScopedResourceAccess(valid)
            outputFolder = valid
            if persistBookmark { try bookmarkStore?.save(valid) }
            else if !defaultSettings.rememberOutputFolder { try? bookmarkStore?.clear() }
            schedulePlan()
        } catch {
            outputFolder = nil
            errorMessage = error.localizedDescription
        }
    }

    private func restoreRememberedOutputFolder() {
        guard defaultSettings.rememberOutputFolder else { return }
        do {
            guard let url = try bookmarkStore?.resolve() else { return }
            setOutputFolder(url, persistBookmark: false)
        } catch {
            outputFolder = nil
            errorMessage = "La carpeta recordada ya no es válida. Selecciónala de nuevo."
        }
    }
}
