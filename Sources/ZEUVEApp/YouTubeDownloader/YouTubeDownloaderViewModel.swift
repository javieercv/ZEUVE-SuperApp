import Foundation
import AppKit
import UniformTypeIdentifiers
import SwiftUI
import ZEUVECore
import ZEUVEStorage
import ZEUVEOperations
import ZEUVEEngines
import YouTubeDownloaderModule

@MainActor
enum YouTubeDownloaderUIState: Equatable {
    case idle
    case analysing
    case ready
    case downloading
    case cancelling

    var isBusy: Bool {
        switch self {
        case .analysing, .downloading, .cancelling: return true
        case .idle, .ready: return false
        }
    }
}

@MainActor
final class YouTubeDownloaderViewModel: ObservableObject {
    @Published var inputText = ""
    @Published var acceptedURLs: [ValidatedYouTubeURL] = []
    @Published var duplicates: [String] = []
    @Published var rejected: [String: String] = [:]
    @Published var analyses: [YouTubeMediaAnalysis] = []
    @Published var analysisFailures: [YouTubeAnalysisFailure] = []
    @Published var selectedItemIDs = Set<String>()
    @Published var settings = YouTubeDownloadSettings()
    @Published var defaultSettings = YouTubeDownloadSettings()
    @Published var outputFolder: URL?
    @Published var cookiesFile: URL?
    @Published var proxyEnabled = false
    @Published var proxyAddress = ""
    @Published var proxyUsername = ""
    @Published var proxyPassword = ""
    @Published var advancedMode = false
    @Published var defaultAdvancedMode = false
    @Published var state: YouTubeDownloaderUIState = .idle
    @Published var progress: YouTubeDownloadProgress?
    @Published var errorMessage: String?
    @Published var completion: YouTubeOperationResult?
    @Published var diagnostics: [EngineDiagnostic] = []
    @Published var presets: [YouTubePreset] = []
    @Published var selectedPresetID: UUID?

    let unavailableMessage: String?

    private let coordinator: OperationCoordinator
    private let settingsRepository: SettingsRepository?
    private let locator: YouTubeEngineLocator?
    private let analysisService: YouTubeAnalysisService?
    private let downloadService: YouTubeDownloadService?
    private let bookmarkStore: SecurityScopedFolderBookmarkStore?
    private let presetService: YouTubePresetService?
    private var currentOperationID: UUID?
    private var worker: Task<Void, Never>?
    private var scopedOutputURL: URL?
    private var scopedCookiesURL: URL?

    init(
        coordinator: OperationCoordinator,
        storage: StorageContainer?,
        logger: LocalLogger?,
        engineRegistry: EngineRegistry? = nil,
        engineDiagnostics: EngineDiagnosticService? = nil
    ) {
        self.coordinator = coordinator
        settingsRepository = storage?.settings

        if let storage {
            bookmarkStore = SecurityScopedFolderBookmarkStore(settings: storage.settings)
            presetService = YouTubePresetService(settings: storage.settings)
            if let storedDefaults = try? storage.settings.value(forKey: "youtube.defaultSettings", as: YouTubeDownloadSettings.self) {
                let normalized = Self.normalizedDefaults(storedDefaults)
                defaultSettings = normalized
                settings = normalized
            }
            if let storedAdvancedMode = try? storage.settings.value(forKey: "youtube.defaultAdvancedMode", as: Bool.self) {
                defaultAdvancedMode = storedAdvancedMode
                advancedMode = storedAdvancedMode
            }
        } else {
            bookmarkStore = nil
            presetService = nil
        }

        do {
            let localRegistry: EngineRegistry
            if let engineRegistry {
                localRegistry = engineRegistry
            } else {
                localRegistry = try EngineRegistry.bundled()
            }
            let localLocator = YouTubeEngineLocator(
                registry: localRegistry,
                diagnosticsService: engineDiagnostics
            )
            locator = localLocator
            analysisService = YouTubeAnalysisService(locator: localLocator, logger: logger)
            downloadService = YouTubeDownloadService(
                locator: localLocator,
                history: storage.map { YouTubeHistoryService(repository: $0.history) },
                logger: logger
            )
            unavailableMessage = nil
        } catch {
            locator = nil
            analysisService = nil
            downloadService = nil
            unavailableMessage = "Los motores del descargador no están preparados: \(error.localizedDescription)"
        }
    }

    deinit {
        worker?.cancel()
        if let scopedOutputURL { scopedOutputURL.stopAccessingSecurityScopedResource() }
        if let scopedCookiesURL { scopedCookiesURL.stopAccessingSecurityScopedResource() }
    }

    func start() async {
        if let bookmarkStore, let restored = try? bookmarkStore.resolve() {
            setOutputFolder(restored, persist: false)
        }
        presets = (try? presetService?.load()) ?? YouTubePresetService.defaultPresets()
        selectedPresetID = nil
        await refreshDiagnostics()
    }

    func persistDefaultSettings() {
        defaultSettings = Self.normalizedDefaults(defaultSettings)
        do {
            try settingsRepository?.set(defaultSettings, forKey: "youtube.defaultSettings")
            try settingsRepository?.set(defaultAdvancedMode, forKey: "youtube.defaultAdvancedMode")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restoreDefaultSettings() {
        defaultSettings = YouTubeDownloadSettings()
        defaultAdvancedMode = false
        persistDefaultSettings()
    }

    func applyDefaultSettingsToCurrentOperation() {
        guard !state.isBusy else { return }
        settings = Self.normalizedDefaults(defaultSettings)
        advancedMode = defaultAdvancedMode
        selectedPresetID = nil
    }

    private static func normalizedDefaults(_ value: YouTubeDownloadSettings) -> YouTubeDownloadSettings {
        var normalized = value
        normalized.exactVideoFormatID = nil
        normalized.exactAudioFormatID = nil
        return normalized
    }

    private func prepareNewOperationDefaults() {
        settings = Self.normalizedDefaults(defaultSettings)
        advancedMode = defaultAdvancedMode
        selectedPresetID = nil
    }

    func validateInput() {
        let validation = YouTubeURLValidator().validate(text: inputText)
        acceptedURLs = validation.accepted
        duplicates = validation.duplicates
        rejected = validation.rejected
        analyses = []
        analysisFailures = []
        selectedItemIDs = []
        completion = nil
        state = acceptedURLs.isEmpty ? .idle : .ready
    }

    func pasteFromClipboard() {
        if let text = NSPasteboard.general.string(forType: .string) {
            inputText = text
            validateInput()
        }
    }

    func addDroppedText(_ text: String) {
        inputText = inputText.isEmpty ? text : inputText + "\n" + text
        validateInput()
    }

    func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.title = "Elegir carpeta de salida"
        panel.prompt = "Elegir"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        setOutputFolder(url, persist: true)
    }

    func chooseCookiesFile() {
        let panel = NSOpenPanel()
        panel.title = "Seleccionar cookies.txt"
        panel.prompt = "Seleccionar"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let validated = try YouTubePathValidator.validateCookiesFile(url)
            scopedCookiesURL?.stopAccessingSecurityScopedResource()
            _ = validated?.startAccessingSecurityScopedResource()
            scopedCookiesURL = validated
            cookiesFile = validated
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearCookiesFile() {
        scopedCookiesURL?.stopAccessingSecurityScopedResource()
        scopedCookiesURL = nil
        cookiesFile = nil
    }

    func applyPreset(_ preset: YouTubePreset) {
        settings = preset.settings
        selectedPresetID = preset.id
    }

    func toggleFavorite(_ preset: YouTubePreset) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index].isFavorite.toggle()
        presets[index].modifiedAt = Date()
        do { try presetService?.save(presets) }
        catch { errorMessage = error.localizedDescription }
    }

    func saveDefaultSettingsAsPreset(named rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Escribe un nombre para el preset."
            return
        }
        let value = YouTubePreset(
            schemaVersion: YouTubePresetService.currentSchemaVersion,
            name: name,
            settings: Self.normalizedDefaults(defaultSettings)
        )
        presets.append(value)
        persistPresets()
    }

    func updatePresetFromDefaultSettings(_ preset: YouTubePreset) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index].settings = Self.normalizedDefaults(defaultSettings)
        presets[index].modifiedAt = Date()
        persistPresets()
    }

    func usePresetAsDefaults(_ preset: YouTubePreset) {
        defaultSettings = Self.normalizedDefaults(preset.settings)
        persistDefaultSettings()
    }

    func saveCurrentSettingsAsPreset(named rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Escribe un nombre para el preset."
            return
        }
        let value = YouTubePreset(
            schemaVersion: YouTubePresetService.currentSchemaVersion,
            name: name,
            settings: settings
        )
        presets.append(value)
        selectedPresetID = value.id
        persistPresets()
    }

    func renamePreset(_ preset: YouTubePreset, to rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index].name = name
        presets[index].modifiedAt = Date()
        persistPresets()
    }

    func updatePresetFromCurrentSettings(_ preset: YouTubePreset) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index].settings = settings
        presets[index].modifiedAt = Date()
        persistPresets()
    }

    func duplicatePreset(_ preset: YouTubePreset) {
        let copy = YouTubePreset(
            schemaVersion: YouTubePresetService.currentSchemaVersion,
            name: preset.name + " (copia)",
            settings: preset.settings,
            isFavorite: false
        )
        presets.append(copy)
        persistPresets()
    }

    func deletePreset(_ preset: YouTubePreset) {
        presets.removeAll { $0.id == preset.id }
        if selectedPresetID == preset.id { selectedPresetID = nil }
        persistPresets()
    }

    func restoreDefaultPresets() {
        do {
            presets = try presetService?.restoreDefaults() ?? YouTubePresetService.defaultPresets()
            selectedPresetID = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persistPresets() {
        do { try presetService?.save(presets) }
        catch { errorMessage = error.localizedDescription }
    }

    func analyse() {
        guard let analysisService else {
            errorMessage = unavailableMessage ?? "El servicio de análisis no está disponible."
            return
        }
        validateInput()
        guard !acceptedURLs.isEmpty else {
            errorMessage = "Introduce al menos un enlace válido de YouTube."
            return
        }
        prepareNewOperationDefaults()
        let credentials = proxyEnabled && !proxyUsername.isEmpty
            ? YouTubeProxyCredentials(username: proxyUsername, password: proxyPassword)
            : nil
        worker?.cancel()
        worker = Task { [weak self] in
            guard let self else { return }
            do {
                let operationID = try await coordinator.begin(
                    moduleID: youtubeDownloaderModuleIdentifier,
                    name: "Analizando YouTube"
                )
                currentOperationID = operationID
                state = .analysing
                progress = nil
                analyses = []
                analysisFailures = []
                selectedItemIDs = []
                defer {
                    Task { try? await self.coordinator.finish(id: operationID) }
                    self.currentOperationID = nil
                    self.proxyPassword = ""
                    if self.state != .cancelling {
                        self.state = self.analyses.isEmpty && self.analysisFailures.isEmpty ? .idle : .ready
                    }
                }

                for (index, value) in acceptedURLs.enumerated() {
                    guard !Task.isCancelled else { throw CancellationError() }
                    try await coordinator.update(
                        id: operationID,
                        progress: .init(completed: index, total: acceptedURLs.count, phase: "Analizando", currentItem: value.canonicalID)
                    )
                    do {
                        let analysis = try await analysisService.analyze(
                            value,
                            cookiesFile: cookiesFile,
                            proxy: proxyEnabled ? proxyAddress : nil,
                            proxyCredentials: credentials,
                            onPlaylistEntry: { _ in },
                            onProgress: { [weak self] count in
                                Task { @MainActor in
                                    self?.progress = .init(
                                        phase: .analyzing,
                                        currentItem: "\(count) elementos encontrados",
                                        itemIndex: count,
                                        itemTotal: 0
                                    )
                                }
                            }
                        )
                        analyses.append(analysis)
                        selectDownloadableItems(in: analysis)
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        let reference = "YT-AN-\(UUID().uuidString.prefix(8))"
                        analysisFailures.append(.init(
                            canonicalID: value.canonicalID,
                            kind: value.kind,
                            userMessage: "No se ha podido analizar este enlace. Comprueba su disponibilidad, las restricciones y la conexión.",
                            technicalReference: reference
                        ))
                    }
                }
                try await coordinator.update(
                    id: operationID,
                    progress: .init(completed: acceptedURLs.count, total: acceptedURLs.count, phase: "Análisis completado")
                )
                if analyses.isEmpty, !analysisFailures.isEmpty {
                    errorMessage = "No se ha podido analizar ninguno de los enlaces. Revisa los detalles mostrados."
                }
            } catch is CancellationError {
                state = analyses.isEmpty ? .idle : .ready
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func download() {
        guard let downloadService else {
            errorMessage = unavailableMessage ?? "El servicio de descarga no está disponible."
            return
        }
        guard let outputFolder else {
            errorMessage = "Selecciona una carpeta de salida."
            return
        }
        let items = selectedDownloadItems()
        guard !items.isEmpty else {
            errorMessage = "Selecciona al menos un elemento descargable."
            return
        }
        if settings.conflictPolicy == .replaceConfirmed {
            errorMessage = "La sustitución debe confirmarse en la interfaz antes de iniciar la descarga."
            return
        }

        let plan = YouTubeDownloadPlan(
            items: items,
            settings: settings,
            outputFolder: outputFolder,
            cookiesFile: cookiesFile,
            proxyHost: proxyEnabled ? proxyAddress : nil
        )
        let credentials = proxyEnabled && !proxyUsername.isEmpty
            ? YouTubeProxyCredentials(username: proxyUsername, password: proxyPassword)
            : nil
        worker?.cancel()
        worker = Task { [weak self] in
            guard let self else { return }
            do {
                let operationID = try await coordinator.begin(
                    moduleID: youtubeDownloaderModuleIdentifier,
                    name: "Descargando de YouTube"
                )
                currentOperationID = operationID
                state = .downloading
                completion = nil
                defer {
                    Task { try? await self.coordinator.finish(id: operationID) }
                    self.currentOperationID = nil
                    if self.state != .cancelling { self.state = .ready }
                    self.proxyPassword = ""
                }
                let result = try await downloadService.execute(plan: plan, proxyCredentials: credentials) { [weak self] update in
                    Task { @MainActor in
                        self?.progress = update
                        try? await self?.coordinator.update(
                            id: operationID,
                            progress: .init(
                                completed: update.completedItems,
                                total: update.itemTotal,
                                phase: update.phase.spanishName,
                                currentItem: update.currentItem
                            )
                        )
                    }
                }
                completion = result
            } catch is CancellationError {
                state = .ready
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func downloadReplacingConfirmed() {
        let previous = settings.conflictPolicy
        settings.conflictPolicy = .replaceConfirmed
        defer { settings.conflictPolicy = previous }
        downloadAllowingConfirmedReplacement()
    }

    private func downloadAllowingConfirmedReplacement() {
        // El valor confirmado se copia en el plan antes de restablecer la preferencia visible.
        guard let downloadService, let outputFolder else { return }
        let items = selectedDownloadItems()
        guard !items.isEmpty else { return }
        var confirmedSettings = settings
        confirmedSettings.conflictPolicy = .replaceConfirmed
        let plan = YouTubeDownloadPlan(items: items, settings: confirmedSettings, outputFolder: outputFolder, cookiesFile: cookiesFile, proxyHost: proxyEnabled ? proxyAddress : nil)
        let credentials = proxyEnabled && !proxyUsername.isEmpty ? YouTubeProxyCredentials(username: proxyUsername, password: proxyPassword) : nil
        worker?.cancel()
        worker = Task { [weak self] in
            guard let self else { return }
            do {
                let operationID = try await coordinator.begin(moduleID: youtubeDownloaderModuleIdentifier, name: "Descargando de YouTube")
                currentOperationID = operationID
                state = .downloading
                defer {
                    Task { try? await self.coordinator.finish(id: operationID) }
                    self.currentOperationID = nil
                    self.state = .ready
                    self.proxyPassword = ""
                }
                completion = try await downloadService.execute(plan: plan, proxyCredentials: credentials) { [weak self] update in
                    Task { @MainActor in self?.progress = update }
                }
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func cancel() {
        guard state.isBusy else { return }
        state = .cancelling
        worker?.cancel()
        Task {
            if let currentOperationID { try? await coordinator.requestCancellation(id: currentOperationID) }
            try? await analysisService?.cancel()
            try? await downloadService?.cancel()
            state = analyses.isEmpty ? .idle : .ready
        }
    }

    func refreshDiagnostics() async {
        diagnostics = await locator?.diagnostics(forceRefresh: true) ?? []
    }

    func openOutputFolder() {
        if let outputFolder { NSWorkspace.shared.open(outputFolder) }
    }

    private func setOutputFolder(_ url: URL, persist: Bool) {
        do {
            let valid = try YouTubePathValidator.validateOutputFolder(url)
            scopedOutputURL?.stopAccessingSecurityScopedResource()
            _ = valid.startAccessingSecurityScopedResource()
            scopedOutputURL = valid
            outputFolder = valid
            if persist { try bookmarkStore?.save(valid) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func selectDownloadableItems(in analysis: YouTubeMediaAnalysis) {
        if analysis.kind == .video, analysis.isDownloadable {
            selectedItemIDs.insert("video:\(analysis.canonicalID)")
        } else {
            for entry in analysis.playlistEntries where entry.isAvailable {
                selectedItemIDs.insert("playlist:\(analysis.canonicalID):\(entry.videoID)")
            }
        }
    }

    func selectionID(analysis: YouTubeMediaAnalysis, entry: YouTubePlaylistEntry? = nil) -> String {
        if let entry { return "playlist:\(analysis.canonicalID):\(entry.videoID)" }
        return "video:\(analysis.canonicalID)"
    }

    func selectAll(in analysis: YouTubeMediaAnalysis) {
        selectDownloadableItems(in: analysis)
    }

    func clearSelection(in analysis: YouTubeMediaAnalysis) {
        selectedItemIDs = Set(selectedItemIDs.filter { !$0.hasPrefix("playlist:\(analysis.canonicalID):") && $0 != "video:\(analysis.canonicalID)" })
    }

    func selectRange(in analysis: YouTubeMediaAnalysis, start: Int, end: Int) {
        guard analysis.kind == .playlist else { return }
        clearSelection(in: analysis)
        let lower = max(1, min(start, end))
        let upper = max(start, end)
        for entry in analysis.playlistEntries where entry.isAvailable {
            guard let index = entry.playlistIndex, index >= lower, index <= upper else { continue }
            selectedItemIDs.insert(selectionID(analysis: analysis, entry: entry))
        }
    }

    var exactFormatAnalysis: YouTubeMediaAnalysis? {
        let selectedVideos = analyses.filter { analysis in
            analysis.kind == .video && selectedItemIDs.contains(selectionID(analysis: analysis))
        }
        return selectedVideos.count == 1 ? selectedVideos.first : nil
    }

    var availableVideoFormats: [YouTubeFormat] {
        (exactFormatAnalysis?.formats ?? []).filter(\.hasVideo).sorted { lhs, rhs in
            (lhs.height ?? 0, lhs.fps ?? 0, lhs.totalBitrateKbps ?? 0) > (rhs.height ?? 0, rhs.fps ?? 0, rhs.totalBitrateKbps ?? 0)
        }
    }

    var availableAudioFormats: [YouTubeFormat] {
        (exactFormatAnalysis?.formats ?? []).filter { $0.hasAudio && !$0.hasVideo }.sorted { lhs, rhs in
            (lhs.audioBitrateKbps ?? lhs.totalBitrateKbps ?? 0) > (rhs.audioBitrateKbps ?? rhs.totalBitrateKbps ?? 0)
        }
    }

    var availableSubtitleTracks: [YouTubeSubtitleTrack] {
        var values: [String: YouTubeSubtitleTrack] = [:]
        for track in analyses.flatMap(\.subtitles) { values[track.id] = track }
        return values.values.sorted { ($0.kind.rawValue, $0.languageCode) < ($1.kind.rawValue, $1.languageCode) }
    }

    func selectedDownloadItems() -> [YouTubeDownloadItem] {
        var result: [YouTubeDownloadItem] = []
        for analysis in analyses {
            if analysis.kind == .video {
                let key = selectionID(analysis: analysis)
                if selectedItemIDs.contains(key), analysis.isDownloadable {
                    result.append(.init(
                        canonicalID: analysis.canonicalID,
                        sourceURL: URL(string: "https://www.youtube.com/watch?v=\(analysis.canonicalID)")!,
                        title: analysis.title,
                        estimatedBytes: estimatedSize(for: analysis)
                    ))
                }
            } else {
                for entry in analysis.playlistEntries where entry.isAvailable {
                    let key = selectionID(analysis: analysis, entry: entry)
                    if selectedItemIDs.contains(key) {
                        result.append(.init(
                            canonicalID: entry.videoID,
                            sourceURL: entry.canonicalURL,
                            title: entry.title,
                            playlistTitle: analysis.playlistTitle,
                            playlistIndex: entry.playlistIndex
                        ))
                    }
                }
            }
        }
        return result
    }

    var formatExplanation: String {
        YouTubeFormatSelector().selection(for: settings).explanation
    }

    func expectedFilenamePreview() -> String? {
        guard let item = selectedDownloadItems().first else { return nil }
        let index = settings.numberPlaylistItems ? item.playlistIndex.map { String(format: "%04d - ", $0) } ?? "" : ""
        let rawBase: String
        switch settings.filenamePreset {
        case .title:
            rawBase = index + item.title
        case .titleAndID:
            rawBase = index + item.title + " [" + item.canonicalID + "]"
        case .dateAndTitle:
            rawBase = index + "AAAA-MM-DD - " + item.title + " [" + item.canonicalID + "]"
        case .channelAndTitle:
            rawBase = index + "Canal - " + item.title + " [" + item.canonicalID + "]"
        case .playlistIndexAndTitle, .playlistAndIndexAndTitle:
            rawBase = index + item.title + " [" + item.canonicalID + "]"
        }
        let safe = (try? YouTubeFilenamePolicy().sanitize(rawBase)) ?? "resultado"
        let extensionText: String
        if settings.mode == .audio {
            extensionText = settings.audioOutput == .original ? "formato original" : settings.audioOutput.rawValue
        } else {
            extensionText = settings.container == .automatic ? "mp4 o mkv" : settings.container.rawValue
        }
        return safe + "." + extensionText
    }

    private func estimatedSize(for analysis: YouTubeMediaAnalysis) -> Int64? {
        let formats = analysis.formats
        if settings.mode == .audio {
            if let id = settings.exactAudioFormatID { return formats.first(where: { $0.formatID == id })?.bestKnownSize }
            return formats.filter { $0.hasAudio && !$0.hasVideo }.compactMap(\.bestKnownSize).max()
        }
        if let videoID = settings.exactVideoFormatID {
            let video = formats.first(where: { $0.formatID == videoID })?.bestKnownSize
            let audio = settings.exactAudioFormatID.flatMap { id in formats.first(where: { $0.formatID == id })?.bestKnownSize }
            if let video { return video + (audio ?? 0) }
            return nil
        }
        let maxHeight = settings.maximumResolution == .best ? Int.max : settings.maximumResolution.rawValue
        let video = formats.filter { $0.hasVideo && ($0.height ?? 0) <= maxHeight }.compactMap(\.bestKnownSize).max()
        let audio = formats.filter { $0.hasAudio && !$0.hasVideo }.compactMap(\.bestKnownSize).max()
        if let video { return video + (audio ?? 0) }
        return nil
    }
}

private extension YouTubeProgressPhase {
    var spanishName: String {
        switch self {
        case .preparing: return "Preparando"
        case .analyzing: return "Analizando"
        case .downloading: return "Descargando"
        case .merging: return "Uniendo vídeo y audio"
        case .converting: return "Convirtiendo con FFmpeg"
        case .publishing: return "Publicando resultados"
        case .cleaning: return "Limpiando temporales"
        }
    }
}
