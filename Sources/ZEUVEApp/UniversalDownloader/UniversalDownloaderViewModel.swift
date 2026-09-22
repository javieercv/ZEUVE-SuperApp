import Foundation
import AppKit
import UniformTypeIdentifiers
import SwiftUI
import ZEUVECore
import ZEUVEStorage
import ZEUVEOperations
import ZEUVEEngines
import UniversalDownloaderModule

@MainActor
enum UniversalDownloaderUIState: Equatable {
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
final class UniversalDownloaderViewModel: ObservableObject {
    @Published var inputText = ""
    @Published var acceptedURLs: [ValidatedDownloadURL] = []
    @Published var duplicates: [String] = []
    @Published var rejected: [String: String] = [:]
    @Published var analyses: [DownloadAnalysis] = []
    @Published var analysisFailures: [DownloadAnalysisFailure] = []
    @Published var selectedItemIDs = Set<String>()
    @Published var settings = UniversalDownloadSettings()
    @Published var defaultSettings = UniversalDownloadSettings()
    @Published var outputFolder: URL?
    @Published var cookiesFile: URL?
    @Published var browserCookiesEnabled = false
    @Published var browserCookieSource: DownloadBrowserCookieSource = .brave
    @Published var proxyEnabled = false
    @Published var proxyAddress = ""
    @Published var proxyUsername = ""
    @Published var proxyPassword = ""
    @Published var advancedMode = false
    @Published var defaultAdvancedMode = false
    @Published var state: UniversalDownloaderUIState = .idle
    @Published var progress: UniversalDownloadProgress?
    @Published var errorMessage: String?
    @Published var warningMessage: String?
    @Published var completion: UniversalDownloadResult?
    @Published var diagnostics: [EngineDiagnostic] = []
    @Published var presets: [UniversalDownloadPreset] = []
    @Published var selectedPresetID: UUID?
    @Published var downloadedCanonicalIDs = Set<String>()
    @Published var possibleDuplicateIDs = Set<String>()
    @Published var selectedPlatform: UniversalDownloadPlatform = .automatic
    @Published var universalPreferences = UniversalDownloaderPreferences()
    @Published var downloadProfiles = UniversalDownloadProfiles()
    @Published var instagramSessionText = ""
    @Published var rememberInstagramSession = false
    @Published var instagramCookieBrowser = "safari"
    @Published var instagramSessionStatus: String?
    @Published var importingInstagramSession = false
    @Published var archivedProfilePictures: [InstagramArchivedProfilePictureCandidate] = []
    @Published var archiveSearchInProgress = false
    @Published var archiveSearchMessage: String?
    @Published var installedEngineOverrides: [InstalledEngineOverride] = []
    @Published var engineUpdateChannel: EngineUpdateChannel = .stable

    let unavailableMessage: String?

    private let coordinator: OperationCoordinator
    private let settingsStore: UniversalDownloaderSettingsStore?
    private let locator: UniversalDownloaderEngineLocator?
    private let analysisService: UniversalDownloadAnalysisService?
    private let downloadService: UniversalDownloadService?
    private let bookmarkStore: DownloadOutputFolderBookmarkStore?
    private let presetService: UniversalDownloadPresetService?
    private let historyService: UniversalDownloadHistoryService?
    private var currentOperationID: UUID?
    private var operationTask: Task<Void, Never>?
    private var instagramSessionImportTask: Task<Void, Never>?
    private struct DuplicateSignature: Hashable {
        let title: String
        let durationBucket: Int?
    }
    private var duplicateGroups: [DuplicateSignature: Set<String>] = [:]
    private var scopedOutputURL: URL?
    private var scopedCookiesURL: URL?
    private var temporaryInstagramSessionFile: URL?
    private var temporaryInstagramCookiesFile: URL?
    private let instagramKeychain = InstagramSessionController()
    private let engineOverrideManager = EngineOverrideManager()

    init(
        coordinator: OperationCoordinator,
        storage: StorageContainer?,
        logger: LocalLogger?,
        engineRegistry: EngineRegistry? = nil,
        engineDiagnostics: EngineDiagnosticService? = nil
    ) {
        self.coordinator = coordinator
        settingsStore = storage.map { UniversalDownloaderSettingsStore(settings: $0.settings) }

        if let storage {
            bookmarkStore = DownloadOutputFolderBookmarkStore(settings: storage.settings)
            presetService = UniversalDownloadPresetService(settings: storage.settings)
            let storedConfiguration = settingsStore?.load() ?? UniversalDownloaderStoredConfiguration(
                preferences: .init(),
                defaultSettings: .init(),
                downloadProfiles: .init(),
                defaultAdvancedMode: false
            )
            universalPreferences = storedConfiguration.preferences
            selectedPlatform = storedConfiguration.preferences.defaultPlatform
            rememberInstagramSession = storedConfiguration.preferences.rememberInstagramSessionByDefault
            defaultSettings = storedConfiguration.defaultSettings
            settings = storedConfiguration.defaultSettings
            downloadProfiles = storedConfiguration.downloadProfiles
            defaultAdvancedMode = storedConfiguration.defaultAdvancedMode
            advancedMode = storedConfiguration.defaultAdvancedMode
        } else {
            bookmarkStore = nil
            presetService = nil
        }
        let localHistoryService = storage.map { UniversalDownloadHistoryService(repository: $0.history) }
        historyService = localHistoryService

        do {
            let localRegistry: EngineRegistry
            if let engineRegistry {
                localRegistry = engineRegistry
            } else {
                localRegistry = try EngineRegistry.bundled()
            }
            let localLocator = UniversalDownloaderEngineLocator(
                registry: localRegistry,
                diagnosticsService: engineDiagnostics
            )
            locator = localLocator
            analysisService = UniversalDownloadAnalysisService(locator: localLocator, logger: logger)
            downloadService = UniversalDownloadService(
                locator: localLocator,
                history: localHistoryService,
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
        operationTask?.cancel()
        instagramSessionImportTask?.cancel()
        if let scopedOutputURL { scopedOutputURL.stopAccessingSecurityScopedResource() }
        if let scopedCookiesURL { scopedCookiesURL.stopAccessingSecurityScopedResource() }
        if let temporaryInstagramSessionFile { InstagramSessionMaterial.removeTemporaryFile(temporaryInstagramSessionFile) }
        if let temporaryInstagramCookiesFile { InstagramSessionMaterial.removeTemporaryFile(temporaryInstagramCookiesFile) }
    }

    func start() async {
        if let bookmarkStore, let restored = try? bookmarkStore.resolve() {
            setOutputFolder(restored, persist: false)
        }
        presets = (try? presetService?.load()) ?? UniversalDownloadPresetService.defaultPresets()
        selectedPresetID = nil
        downloadedCanonicalIDs = (try? historyService?.downloadedCanonicalIDs()) ?? []
        if rememberInstagramSession, let stored = instagramKeychain.load() { instagramSessionText = stored }
        installedEngineOverrides = (try? engineOverrideManager.activeOverrides()) ?? []
        await refreshDiagnostics()
    }

    func persistDefaultSettings() {
        defaultSettings = UniversalDownloaderSettingsStore.normalizedDefaults(defaultSettings)
        do {
            try settingsStore?.saveDefaults(defaultSettings, advancedMode: defaultAdvancedMode)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func persistUniversalPreferences() {
        universalPreferences.defaultPlatform = selectedPlatform
        universalPreferences.rememberInstagramSessionByDefault = rememberInstagramSession
        universalPreferences.useOptionalBrowserFallback = false
        do {
            try settingsStore?.savePreferences(universalPreferences)
            if rememberInstagramSession, !instagramSessionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try instagramKeychain.save(try InstagramSessionMaterial.normalize(instagramSessionText))
            } else if !rememberInstagramSession {
                try instagramKeychain.delete()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func persistDownloadProfiles() {
        downloadProfiles.normalize()
        do {
            try settingsStore?.saveProfiles(downloadProfiles)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addCustomDownloadProfile(
        name rawName: String,
        address: String,
        includesSubdomains: Bool
    ) -> UUID? {
        do {
            let host = try UniversalCustomProfileHost.normalized(address)
            guard !downloadProfiles.customProfiles.contains(where: { $0.host == host }) else {
                throw UniversalCustomProfileError.duplicateHost(host)
            }
            let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            let profile = UniversalCustomDownloadProfile(
                name: name.isEmpty ? host : name,
                host: host,
                includesSubdomains: includesSubdomains,
                settings: UniversalDownloadProfiles.factorySettings(for: .webpage)
            )
            downloadProfiles.customProfiles.append(profile)
            persistDownloadProfiles()
            return profile.id
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func deleteCustomDownloadProfile(id: UUID) {
        downloadProfiles.customProfiles.removeAll { $0.id == id }
        persistDownloadProfiles()
    }

    func restorePlatformProfile(_ platform: UniversalDownloadPlatform) {
        downloadProfiles.restoreFactorySettings(for: platform)
        persistDownloadProfiles()
    }

    func restoreAllPlatformProfiles() {
        downloadProfiles.restoreAllFactorySettings(keepingCustomProfiles: true)
        persistDownloadProfiles()
    }

    func restoreUniversalPreferences() {
        universalPreferences = UniversalDownloaderPreferences()
        selectedPlatform = .automatic
        rememberInstagramSession = false
        try? instagramKeychain.delete()
        persistUniversalPreferences()
    }

    func clearRememberedInstagramSession() {
        do {
            try instagramKeychain.delete()
            instagramSessionText = ""
            rememberInstagramSession = false
            persistUniversalPreferences()
        } catch { errorMessage = error.localizedDescription }
    }

    func restoreDefaultSettings() {
        defaultSettings = UniversalDownloadSettings()
        defaultAdvancedMode = false
        persistDefaultSettings()
    }

    func restorePersistentDefaultsForGlobalReset() -> [String] {
        var failures: [String] = []

        defaultSettings = UniversalDownloadSettings()
        defaultAdvancedMode = false
        do {
            try settingsStore?.saveDefaults(defaultSettings, advancedMode: false)
        } catch {
            failures.append("Descargador universal — valores predeterminados: \(error.localizedDescription)")
        }

        universalPreferences = UniversalDownloaderPreferences()
        selectedPlatform = .automatic
        rememberInstagramSession = false
        instagramSessionText = ""
        do {
            try settingsStore?.savePreferences(universalPreferences)
        } catch {
            failures.append("Descargador universal — preferencias: \(error.localizedDescription)")
        }
        do {
            try instagramKeychain.delete()
        } catch {
            failures.append("Descargador universal — sesión de Instagram: \(error.localizedDescription)")
        }

        downloadProfiles.restoreAllFactorySettings(keepingCustomProfiles: true)
        do {
            try settingsStore?.saveProfiles(downloadProfiles)
        } catch {
            failures.append("Descargador universal — perfiles por plataforma: \(error.localizedDescription)")
        }

        do {
            try bookmarkStore?.clear()
        } catch {
            failures.append("Descargador universal — carpeta de salida recordada: \(error.localizedDescription)")
        }

        return failures
    }

    func applyDefaultSettingsToCurrentOperation() {
        guard !state.isBusy else { return }
        settings = UniversalDownloaderSettingsStore.normalizedDefaults(defaultSettings)
        advancedMode = defaultAdvancedMode
        selectedPresetID = nil
    }

    private func prepareNewOperationDefaults() {
        settings = UniversalDownloaderSettingsStore.normalizedDefaults(defaultSettings)
        advancedMode = defaultAdvancedMode
        selectedPresetID = nil
    }

    func validateInput() {
        let validation = UniversalDownloadInputValidator().validate(
            text: inputText,
            allowInsecureLocalNetwork: settings.network.allowInsecureLocalNetwork,
            platform: selectedPlatform,
            allowAdultContent: universalPreferences.allowAdultContent,
            additionalAdultDomains: universalPreferences.adultDomainsAddedByUser
        )
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
            let validated = try DownloadPathValidator.validateCookiesFile(url)
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

    func applyPreset(_ preset: UniversalDownloadPreset) {
        let pageSource = settings.pageSource
        settings = preset.settings
        settings.pageSource = pageSource
        selectedPresetID = preset.id
    }

    func toggleFavorite(_ preset: UniversalDownloadPreset) {
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
        let value = UniversalDownloadPreset(
            schemaVersion: UniversalDownloadPresetService.currentSchemaVersion,
            name: name,
            settings: UniversalDownloaderSettingsStore.normalizedDefaults(defaultSettings)
        )
        presets.append(value)
        persistPresets()
    }

    func updatePresetFromDefaultSettings(_ preset: UniversalDownloadPreset) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index].settings = UniversalDownloaderSettingsStore.normalizedDefaults(defaultSettings)
        presets[index].modifiedAt = Date()
        persistPresets()
    }

    func usePresetAsDefaults(_ preset: UniversalDownloadPreset) {
        defaultSettings = UniversalDownloaderSettingsStore.normalizedDefaults(preset.settings)
        persistDefaultSettings()
    }

    func saveCurrentSettingsAsPreset(named rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Escribe un nombre para el preset."
            return
        }
        let value = UniversalDownloadPreset(
            schemaVersion: UniversalDownloadPresetService.currentSchemaVersion,
            name: name,
            settings: settings
        )
        presets.append(value)
        selectedPresetID = value.id
        persistPresets()
    }

    func renamePreset(_ preset: UniversalDownloadPreset, to rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index].name = name
        presets[index].modifiedAt = Date()
        persistPresets()
    }

    func updatePresetFromCurrentSettings(_ preset: UniversalDownloadPreset) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index].settings = settings
        presets[index].modifiedAt = Date()
        persistPresets()
    }

    func duplicatePreset(_ preset: UniversalDownloadPreset) {
        let copy = UniversalDownloadPreset(
            schemaVersion: UniversalDownloadPresetService.currentSchemaVersion,
            name: preset.name + " (copia)",
            settings: preset.settings,
            isFavorite: false
        )
        presets.append(copy)
        persistPresets()
    }

    func deletePreset(_ preset: UniversalDownloadPreset) {
        presets.removeAll { $0.id == preset.id }
        if selectedPresetID == preset.id { selectedPresetID = nil }
        persistPresets()
    }

    func restoreDefaultPresets() {
        do {
            presets = try presetService?.restoreDefaults() ?? UniversalDownloadPresetService.defaultPresets()
            selectedPresetID = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persistPresets() {
        do { try presetService?.save(presets) }
        catch { errorMessage = error.localizedDescription }
    }

    private var effectiveCookiesFile: URL? { cookiesFile ?? temporaryInstagramCookiesFile }
    private var effectiveBrowserCookies: DownloadBrowserCookieSource? {
        browserCookiesEnabled && effectiveCookiesFile == nil ? browserCookieSource : nil
    }

    private func clearTemporaryInstagramSessionFiles() {
        if let temporaryInstagramSessionFile { InstagramSessionMaterial.removeTemporaryFile(temporaryInstagramSessionFile) }
        if let temporaryInstagramCookiesFile { InstagramSessionMaterial.removeTemporaryFile(temporaryInstagramCookiesFile) }
        temporaryInstagramSessionFile = nil
        temporaryInstagramCookiesFile = nil
    }

    func importInstagramSessionFromBrowser() {
        guard !state.isBusy else {
            errorMessage = "Espera a que termine la operación actual antes de importar una sesión."
            return
        }
        guard let analysisService else {
            errorMessage = unavailableMessage ?? "El motor de Instagram no está disponible."
            return
        }
        instagramSessionImportTask?.cancel()
        importingInstagramSession = true
        instagramSessionStatus = "Importando la sesión de \(instagramCookieBrowser.capitalized)…"
        instagramSessionImportTask = Task { [weak self] in
            guard let self else { return }
            defer {
                importingInstagramSession = false
                instagramSessionImportTask = nil
            }
            do {
                clearTemporaryInstagramSessionFiles()
                let destination = try InstagramSessionMaterial.makeSecureTemporaryDestination()
                let count = try await analysisService.importInstagramCookies(from: instagramCookieBrowser, to: destination)
                try Task.checkCancellation()
                temporaryInstagramCookiesFile = destination
                instagramSessionText = ""
                instagramSessionStatus = count > 0
                    ? "Sesión importada temporalmente (\(count) cookies de Instagram)."
                    : "Sesión importada temporalmente."
                if rememberInstagramSession {
                    let stored = try String(contentsOf: destination, encoding: .utf8)
                    try instagramKeychain.save(stored)
                }
            } catch is CancellationError {
                clearTemporaryInstagramSessionFiles()
                instagramSessionStatus = nil
            } catch {
                clearTemporaryInstagramSessionFiles()
                instagramSessionStatus = nil
                errorMessage = error.localizedDescription
            }
        }
    }

    func clearTemporaryInstagramSession() {
        guard !state.isBusy else { return }
        clearTemporaryInstagramSessionFiles()
        instagramSessionText = ""
        instagramSessionStatus = nil
    }

    func analyse() {
        guard !importingInstagramSession else {
            errorMessage = "Espera a que termine la importación de la sesión antes de analizar."
            return
        }
        guard !state.isBusy else { return }
        guard let analysisService else {
            errorMessage = unavailableMessage ?? "El servicio de análisis no está disponible."
            return
        }
        validateInput()
        guard !acceptedURLs.isEmpty else {
            errorMessage = "Introduce al menos un enlace válido."
            return
        }
        prepareNewOperationDefaults()
        let credentials = proxyEnabled && !proxyUsername.isEmpty
            ? DownloadProxyCredentials(username: proxyUsername, password: proxyPassword)
            : nil
        let pastedSession = instagramSessionText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !pastedSession.isEmpty {
            do {
                clearTemporaryInstagramSessionFiles()
                temporaryInstagramSessionFile = try InstagramSessionMaterial.writeSecureTemporaryFile(text: pastedSession)
                temporaryInstagramCookiesFile = try InstagramSessionMaterial.writeSecureNetscapeTemporaryFile(text: pastedSession)
                instagramSessionStatus = "Sesión preparada temporalmente para esta operación."
                if rememberInstagramSession { try instagramKeychain.save(try InstagramSessionMaterial.normalize(pastedSession)) }
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        } else if temporaryInstagramSessionFile != nil {
            clearTemporaryInstagramSessionFiles()
            instagramSessionStatus = nil
        }
        operationTask?.cancel()
        operationTask = Task { [weak self] in
            guard let self else { return }
            var operationID: UUID?
            do {
                let startedOperationID = try await coordinator.begin(
                    moduleID: universalDownloaderModuleIdentifier,
                    name: "Analizando enlaces"
                )
                operationID = startedOperationID
                currentOperationID = startedOperationID
                state = .analysing
                progress = nil
                analyses = []
                analysisFailures = []
                selectedItemIDs = []
                possibleDuplicateIDs = []
                duplicateGroups = [:]

                for (index, value) in acceptedURLs.enumerated() {
                    try Task.checkCancellation()
                    try await coordinator.update(
                        id: startedOperationID,
                        progress: .init(completed: index, total: acceptedURLs.count, phase: "Analizando", currentItem: value.canonicalID)
                    )
                    do {
                        let analysis = try await analysisService.analyze(
                            value,
                            cookiesFile: effectiveCookiesFile,
                            cookieHeaderFile: temporaryInstagramSessionFile,
                            browserCookies: effectiveBrowserCookies,
                            proxy: proxyEnabled ? proxyAddress : nil,
                            proxyCredentials: credentials,
                            catalogLimit: universalPreferences.initialCatalogBatchSize,
                            browserFallbackEnabled: false,
                            onPlaylistEntry: { _ in },
                            onProgress: { [weak self] count in
                                Task { @MainActor in
                                    guard let self, self.currentOperationID == startedOperationID else { return }
                                    self.progress = .init(
                                        phase: .analyzing,
                                        currentItem: "\(count) elementos encontrados",
                                        itemIndex: count,
                                        itemTotal: 0
                                    )
                                }
                            }
                        )
                        analyses.append(analysis)
                        registerPossibleDuplicates(in: analysis)
                        selectDownloadableItems(in: analysis, includeDownloaded: false)
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        let classified = DownloadErrorClassifier().classify(stderr: error.localizedDescription)
                        analysisFailures.append(.init(
                            canonicalID: value.host,
                            kind: value.kind,
                            userMessage: classified.userMessage,
                            technicalReference: classified.technicalReference
                        ))
                    }
                }
                try await coordinator.update(
                    id: startedOperationID,
                    progress: .init(completed: acceptedURLs.count, total: acceptedURLs.count, phase: "Análisis completado")
                )
                if analyses.isEmpty, !analysisFailures.isEmpty {
                    errorMessage = "No se ha podido analizar ninguno de los enlaces. Revisa los detalles mostrados."
                }
                await finishOperation(startedOperationID, nextState: analyses.isEmpty && analysisFailures.isEmpty ? .idle : .ready)
                operationID = nil
            } catch is CancellationError {
                if let operationID { await finishOperation(operationID, nextState: analyses.isEmpty ? .idle : .ready) }
            } catch {
                if let operationID { await finishOperation(operationID, nextState: analyses.isEmpty ? .idle : .ready) }
                errorMessage = error.localizedDescription
            }
            operationTask = nil
        }
    }

    func download() {
        startDownload(allowingConfirmedReplacement: false)
    }

    func downloadReplacingConfirmed() {
        startDownload(allowingConfirmedReplacement: true)
    }

    private func startDownload(allowingConfirmedReplacement: Bool) {
        guard !importingInstagramSession else {
            errorMessage = "Espera a que termine la importación de la sesión antes de descargar."
            return
        }
        guard !state.isBusy else { return }
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
        if requiresReplacementConfirmation && !allowingConfirmedReplacement {
            errorMessage = "La sustitución debe confirmarse en la interfaz antes de iniciar la descarga."
            return
        }

        let plan = makeDownloadPlan(
            items: items,
            settings: settings,
            outputFolder: outputFolder,
            cookiesFile: effectiveCookiesFile,
            cookieHeaderFile: temporaryInstagramSessionFile,
            browserCookies: effectiveBrowserCookies,
            proxyHost: proxyEnabled ? proxyAddress : nil
        )
        let credentials = proxyEnabled && !proxyUsername.isEmpty
            ? DownloadProxyCredentials(username: proxyUsername, password: proxyPassword)
            : nil

        operationTask?.cancel()
        operationTask = Task { [weak self] in
            guard let self else { return }
            var operationID: UUID?
            do {
                let startedOperationID = try await coordinator.begin(
                    moduleID: universalDownloaderModuleIdentifier,
                    name: "Descargando contenido"
                )
                operationID = startedOperationID
                currentOperationID = startedOperationID
                state = .downloading
                completion = nil
                warningMessage = nil
                let result = try await downloadService.execute(
                    plan: plan,
                    proxyCredentials: credentials,
                    onProgress: { [weak self] update in
                        Task { @MainActor in
                            guard let self, self.currentOperationID == startedOperationID else { return }
                            self.progress = update
                            try? await self.coordinator.update(
                                id: startedOperationID,
                                progress: .init(
                                    completed: update.completedItems,
                                    total: update.itemTotal,
                                    phase: update.phase.spanishName,
                                    currentItem: update.currentItem
                                )
                            )
                        }
                    },
                    onWarning: { [weak self] warning in
                        Task { @MainActor in
                            guard let self, self.currentOperationID == startedOperationID else { return }
                            self.warningMessage = warning
                        }
                    }
                )
                completion = result
                await finishOperation(startedOperationID, nextState: .ready)
                operationID = nil
            } catch is CancellationError {
                if let operationID { await finishOperation(operationID, nextState: analyses.isEmpty ? .idle : .ready) }
            } catch {
                if let operationID { await finishOperation(operationID, nextState: analyses.isEmpty ? .idle : .ready) }
                errorMessage = error.localizedDescription
            }
            operationTask = nil
        }
    }

    private func finishOperation(_ operationID: UUID, nextState: UniversalDownloaderUIState) async {
        try? await coordinator.finish(id: operationID)
        if currentOperationID == operationID { currentOperationID = nil }
        proxyPassword = ""
        state = nextState
    }

    private func makeDownloadPlan(
        items: [UniversalDownloadItem],
        settings operationSettings: UniversalDownloadSettings,
        outputFolder: URL,
        cookiesFile: URL?,
        cookieHeaderFile: URL?,
        browserCookies: DownloadBrowserCookieSource?,
        proxyHost: String?
    ) -> UniversalDownloadPlan {
        UniversalDownloadPlanBuilder().build(
            items: items,
            operationSettings: operationSettings,
            profiles: downloadProfiles,
            outputFolder: outputFolder,
            cookiesFile: cookiesFile,
            cookieHeaderFile: cookieHeaderFile,
            browserCookies: browserCookies,
            proxyHost: proxyHost
        )
    }

    var requiresReplacementConfirmation: Bool {
        let items = selectedDownloadItems()
        guard !items.isEmpty else { return false }
        if settings.conflictPolicy == .replaceConfirmed { return true }
        return items.contains { resolvedSettings(for: $0).conflictPolicy == .replaceConfirmed }
    }

    func cancel() {
        guard state.isBusy, state != .cancelling else { return }
        state = .cancelling
        operationTask?.cancel()
        Task { [weak self] in
            guard let self else { return }
            if let currentOperationID { try? await coordinator.requestCancellation(id: currentOperationID) }
            try? await analysisService?.cancel()
            try? await downloadService?.cancel()
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
            let valid = try DownloadPathValidator.validateOutputFolder(url)
            scopedOutputURL?.stopAccessingSecurityScopedResource()
            _ = valid.startAccessingSecurityScopedResource()
            scopedOutputURL = valid
            outputFolder = valid
            if persist { try bookmarkStore?.save(valid) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func isCatalogEntryVisible(_ entry: DownloadCatalogItem) -> Bool {
        guard let section = entry.catalogSection, section != .all else { return true }
        return universalPreferences.enabledSections.contains(section)
    }

    private func selectDownloadableItems(in analysis: DownloadAnalysis, includeDownloaded: Bool) {
        if analysis.kind == .video, analysis.isDownloadable {
            if includeDownloaded || !downloadedCanonicalIDs.contains(analysis.canonicalID) {
                selectedItemIDs.insert("video:\(analysis.canonicalID)")
            }
        } else {
            for entry in analysis.playlistEntries where entry.isAvailable && isCatalogEntryVisible(entry) {
                if includeDownloaded || !downloadedCanonicalIDs.contains(entry.canonicalID) {
                    selectedItemIDs.insert("playlist:\(analysis.canonicalID):\(entry.canonicalID)")
                }
            }
        }
    }

    func selectionID(analysis: DownloadAnalysis, entry: DownloadCatalogItem? = nil) -> String {
        if let entry { return "playlist:\(analysis.canonicalID):\(entry.canonicalID)" }
        return "video:\(analysis.canonicalID)"
    }

    func selectAll(in analysis: DownloadAnalysis) {
        selectDownloadableItems(in: analysis, includeDownloaded: true)
    }

    func clearSelection(in analysis: DownloadAnalysis) {
        selectedItemIDs = Set(selectedItemIDs.filter { !$0.hasPrefix("playlist:\(analysis.canonicalID):") && $0 != "video:\(analysis.canonicalID)" })
    }

    func selectRange(in analysis: DownloadAnalysis, start: Int, end: Int) {
        guard analysis.kind == .playlist else { return }
        clearSelection(in: analysis)
        let lower = max(1, min(start, end))
        let upper = max(start, end)
        for entry in analysis.playlistEntries where entry.isAvailable && isCatalogEntryVisible(entry) {
            guard let index = entry.playlistIndex, index >= lower, index <= upper else { continue }
            selectedItemIDs.insert(selectionID(analysis: analysis, entry: entry))
        }
    }

    var exactFormatAnalysis: DownloadAnalysis? {
        let selectedVideos = analyses.filter { analysis in
            analysis.kind == .video
                && analysis.downloadSource == .directContent
                && selectedItemIDs.contains(selectionID(analysis: analysis))
        }
        return selectedVideos.count == 1 ? selectedVideos.first : nil
    }

    var availableVideoFormats: [YTDLPFormat] {
        (exactFormatAnalysis?.formats ?? []).filter(\.hasVideo).sorted { lhs, rhs in
            (lhs.height ?? 0, lhs.fps ?? 0, lhs.totalBitrateKbps ?? 0) > (rhs.height ?? 0, rhs.fps ?? 0, rhs.totalBitrateKbps ?? 0)
        }
    }

    var availableAudioFormats: [YTDLPFormat] {
        (exactFormatAnalysis?.formats ?? []).filter { $0.hasAudio && !$0.hasVideo }.sorted { lhs, rhs in
            (lhs.audioBitrateKbps ?? lhs.totalBitrateKbps ?? 0) > (rhs.audioBitrateKbps ?? rhs.totalBitrateKbps ?? 0)
        }
    }

    var availableSubtitleTracks: [YTDLPSubtitleTrack] {
        var values: [String: YTDLPSubtitleTrack] = [:]
        for track in analyses.filter({ $0.downloadSource == .directContent }).flatMap(\.subtitles) {
            values[track.id] = track
        }
        return values.values.sorted { ($0.kind.rawValue, $0.languageCode) < ($1.kind.rawValue, $1.languageCode) }
    }

    func selectedDownloadItems() -> [UniversalDownloadItem] {
        var result: [UniversalDownloadItem] = []
        for analysis in analyses {
            if analysis.kind == .video {
                let key = selectionID(analysis: analysis)
                if selectedItemIDs.contains(key), analysis.isDownloadable,
                   let sourceURL = analysis.sourceURL ?? acceptedURLs.first(where: { $0.canonicalID == analysis.canonicalID })?.canonicalURL {
                    result.append(.init(
                        canonicalID: analysis.canonicalID,
                        sourceURL: sourceURL,
                        title: analysis.title,
                        estimatedBytes: estimatedSize(for: analysis),
                        downloadSource: analysis.downloadSource,
                        pageOrigin: analysis.pageOrigin,
                        resolvedMedia: analysis.resolvedMedia,
                        platform: analysis.platform ?? .automatic,
                        mediaKind: analysis.mediaKind ?? .video,
                        engineKind: analysis.engineKind ?? .ytDLP,
                        requiresAuthentication: analysis.requiresAuthentication || analysis.isPrivateProfile
                    ))
                }
            } else {
                for entry in analysis.playlistEntries where entry.isAvailable {
                    let key = selectionID(analysis: analysis, entry: entry)
                    if selectedItemIDs.contains(key), isCatalogEntryVisible(entry) {
                        var folderComponents = universalPreferences.createPlatformFolders ? entry.folderComponents : []
                        if universalPreferences.createSubfolderForMultiItemPosts,
                           let postIdentifier = entry.safeMetadata["shortcode"] ?? entry.safeMetadata["post_id"],
                           analysis.playlistEntries.filter({
                               ($0.safeMetadata["shortcode"] ?? $0.safeMetadata["post_id"]) == postIdentifier
                           }).count > 1 {
                            folderComponents.append("Publicación - \(postIdentifier)")
                        }
                        result.append(.init(
                            canonicalID: entry.canonicalID,
                            sourceURL: entry.sourceURL,
                            title: entry.title,
                            playlistTitle: analysis.playlistTitle,
                            playlistIndex: entry.playlistIndex,
                            downloadSource: entry.downloadSource,
                            pageOrigin: entry.pageOrigin ?? analysis.pageOrigin,
                            resolvedMedia: entry.resolvedMedia,
                            platform: entry.platform ?? analysis.platform ?? .automatic,
                            mediaKind: entry.mediaKind ?? .unknown,
                            engineKind: entry.engineKind ?? analysis.engineKind ?? .ytDLP,
                            requiresAuthentication: analysis.requiresAuthentication || analysis.isPrivateProfile,
                            folderComponents: folderComponents,
                            expectedExtension: entry.expectedExtension,
                            safeMetadata: {
                                var metadata = entry.safeMetadata
                                if universalPreferences.keepLocalProfilePictureHistory,
                                   (entry.mediaKind ?? .unknown) == .profilePicture {
                                    metadata["keep_local_profile_history"] = "true"
                                    metadata["profile_username"] = analysis.profileUsername ?? entry.uploader ?? "instagram"
                                }
                                return metadata
                            }(),
                            outputFilenameBase: entry.title
                        ))
                    }
                }
            }
        }

        let pageIndices = result.indices.filter { result[$0].isPageDiscovered }
        if !pageIndices.isEmpty {
            let titles = pageIndices.map { result[$0].title }
            let detectedTitles = analyses.flatMap { analysis -> [String] in
                if analysis.kind == .video {
                    return analysis.downloadSource == .pageDiscovered ? [analysis.title] : []
                }
                return analysis.playlistEntries
                    .filter { $0.downloadSource == .pageDiscovered }
                    .map(\.title)
            }
            if let names = try? DownloadFilenamePolicy().pageDiscoveredBaseNames(
                for: titles,
                detectedTitles: detectedTitles
            ) {
                for (offset, index) in pageIndices.enumerated() { result[index].outputFilenameBase = names[offset] }
            }
        }
        return result
    }

    var hasPageDiscoveredSelection: Bool {
        selectedDownloadItems().contains(where: \.isPageDiscovered)
    }

    var hasDirectSelection: Bool {
        selectedDownloadItems().contains { !$0.isPageDiscovered }
    }

    var onlyPageDiscoveredSelection: Bool {
        let items = selectedDownloadItems()
        return !items.isEmpty && items.allSatisfy(\.isPageDiscovered)
    }



    func isPreviouslyDownloaded(_ canonicalID: String) -> Bool {
        downloadedCanonicalIDs.contains(canonicalID)
    }

    func isPossibleDuplicate(_ canonicalID: String) -> Bool {
        possibleDuplicateIDs.contains(canonicalID)
    }

    func loadMore(in analysis: DownloadAnalysis) {
        guard analysis.hasMoreEntries,
              let cursor = analysis.paginationCursor,
              let sourceURL = analysis.sourceURL,
              let validated = try? UniversalDownloadInputValidator().validate(
                sourceURL.absoluteString,
                allowInsecureLocalNetwork: settings.network.allowInsecureLocalNetwork,
                platform: analysis.platform ?? .automatic,
                allowAdultContent: universalPreferences.allowAdultContent,
                additionalAdultDomains: universalPreferences.adultDomainsAddedByUser
              ),
              let analysisService else { return }
        state = .analysing
        Task { [weak self] in
            guard let self else { return }
            do {
                let page = try await analysisService.analyze(
                    validated,
                    cookiesFile: effectiveCookiesFile,
                    cookieHeaderFile: temporaryInstagramSessionFile,
                    browserCookies: effectiveBrowserCookies,
                    proxy: proxyEnabled ? proxyAddress : nil,
                    proxyCredentials: proxyEnabled && !proxyUsername.isEmpty ? .init(username: proxyUsername, password: proxyPassword) : nil,
                    catalogLimit: universalPreferences.catalogPageSize,
                    paginationCursor: cursor,
                    browserFallbackEnabled: false
                )
                let merged = Self.mergedAnalysis(analysis, with: page)
                if let index = analyses.firstIndex(where: { $0.id == analysis.id }) {
                    analyses[index] = merged
                    selectDownloadableItems(in: page, includeDownloaded: false)
                }
                state = .ready
            } catch {
                errorMessage = error.localizedDescription
                state = .ready
            }
        }
    }

    func addArchivedProfilePicture(_ candidate: InstagramArchivedProfilePictureCandidate, username: String) {
        let dateText = candidate.capturedAt?.formatted(date: .numeric, time: .omitted) ?? "fecha desconocida"
        let id = "archive:\(candidate.id.hashValue)"
        let entry = DownloadCatalogItem(
            canonicalID: id,
            playlistIndex: 1,
            title: "\(username) - foto de perfil archivada - \(dateText)",
            uploader: username,
            availability: "public_archive",
            isAvailable: true,
            sourceURL: candidate.imageURL,
            serviceName: candidate.sourceName,
            extractor: "wayback-profile-picture",
            resolvedMedia: .init(
                mediaURL: candidate.imageURL,
                kind: .directFile,
                protocolName: candidate.imageURL.scheme,
                extensionName: candidate.imageURL.pathExtension.isEmpty ? "jpg" : candidate.imageURL.pathExtension,
                httpHeaders: ["Referer": candidate.snapshotURL.absoluteString]
            ),
            platform: .instagram,
            mediaKind: .profilePicture,
            thumbnailURL: candidate.imageURL,
            engineKind: .genericPage,
            catalogSection: .profile,
            folderComponents: ["Instagram", username, "Perfil", "Históricas"],
            expectedExtension: candidate.imageURL.pathExtension.isEmpty ? "jpg" : candidate.imageURL.pathExtension,
            safeMetadata: [
                "archived_at": candidate.capturedAt?.ISO8601Format() ?? "unknown",
                "archive_source": candidate.sourceName,
                "archive_snapshot": candidate.snapshotURL.absoluteString
            ]
        )
        let value = DownloadAnalysis(
            canonicalID: id,
            kind: .gallery,
            title: "Foto de perfil histórica de @\(username)",
            uploader: username,
            thumbnailURL: candidate.imageURL,
            description: "Resultado de mejor esfuerzo. Fuente: \(candidate.sourceName). \(candidate.confidence).",
            playlistTitle: "Fotos de perfil históricas",
            playlistCount: 1,
            playlistEntries: [entry],
            sourceURL: candidate.snapshotURL,
            serviceName: candidate.sourceName,
            extractor: "wayback-profile-picture",
            platform: .instagram,
            mediaKind: .profilePicture,
            engineKind: .genericPage,
            profileUsername: username,
            availableSections: [.profile]
        )
        if !analyses.contains(where: { $0.canonicalID == id }) { analyses.append(value) }
        selectedItemIDs.insert(selectionID(analysis: value, entry: entry))
    }

    private static func mergedAnalysis(_ current: DownloadAnalysis, with page: DownloadAnalysis) -> DownloadAnalysis {
        var known = Set<String>()
        let entries = (current.playlistEntries + page.playlistEntries).filter { known.insert($0.canonicalID).inserted }
        return DownloadAnalysis(
            canonicalID: current.canonicalID,
            kind: current.kind,
            title: current.title,
            uploader: current.uploader,
            channelID: current.channelID,
            duration: current.duration,
            publicationDate: current.publicationDate,
            thumbnailURL: current.thumbnailURL,
            description: current.description,
            formats: current.formats,
            subtitles: current.subtitles,
            chaptersCount: current.chaptersCount,
            liveStatus: current.liveStatus,
            ageLimit: current.ageLimit,
            availability: page.availability ?? current.availability,
            playlistTitle: current.playlistTitle,
            playlistCount: page.playlistCount ?? current.playlistCount,
            playlistEntries: entries,
            sourceURL: current.sourceURL,
            serviceName: current.serviceName,
            extractor: current.extractor,
            duplicateCount: current.duplicateCount + page.duplicateCount,
            downloadSource: current.downloadSource,
            pageOrigin: current.pageOrigin,
            resolvedMedia: current.resolvedMedia,
            platform: current.platform,
            mediaKind: current.mediaKind,
            engineKind: current.engineKind,
            profileUsername: current.profileUsername,
            isPrivateProfile: current.isPrivateProfile,
            requiresAuthentication: page.requiresAuthentication,
            paginationCursor: page.paginationCursor,
            hasMoreEntries: page.hasMoreEntries,
            availableSections: Array(Set(current.availableSections + page.availableSections)).sorted { $0.rawValue < $1.rawValue },
            authenticationRestrictedSections: {
                let values = Array(Set((current.authenticationRestrictedSections ?? []) + (page.authenticationRestrictedSections ?? [])))
                    .sorted { $0.rawValue < $1.rawValue }
                return values.isEmpty ? nil : values
            }()
        )
    }

    func searchArchivedProfilePictures(for analysis: DownloadAnalysis) {
        guard let username = analysis.profileUsername else { return }
        archivedProfilePictures = []
        archiveSearchMessage = "La búsqueda histórica consulta archivos web públicos y puede no encontrar ninguna fotografía."
        archiveSearchInProgress = true
        Task { [weak self] in
            guard let self else { return }
            do {
                let results = try await InstagramProfilePictureArchiveService().searchInstagramProfile(username: username)
                self.archivedProfilePictures = results
                self.archiveSearchMessage = "Se han encontrado \(results.count) referencias archivadas. Revisa la fecha y la fuente antes de descargar."
            } catch {
                self.archiveSearchMessage = error.localizedDescription
            }
            self.archiveSearchInProgress = false
        }
    }

    func installEngineOverride(named name: String, version: String, source: URL, channel: EngineUpdateChannel) {
        do {
            _ = try engineOverrideManager.installLocalExecutable(named: name, version: version, source: source, channel: channel)
            installedEngineOverrides = try engineOverrideManager.activeOverrides()
            Task { await refreshDiagnostics() }
        } catch { errorMessage = error.localizedDescription }
    }

    func restoreBundledEngine(named name: String) {
        do {
            try engineOverrideManager.restoreBundled(named: name)
            installedEngineOverrides = try engineOverrideManager.activeOverrides()
            Task { await refreshDiagnostics() }
        } catch { errorMessage = error.localizedDescription }
    }

    func openEngineFolder() {
        if let url = try? engineOverrideManager.rootDirectory() { NSWorkspace.shared.open(url) }
    }

    func openLogsFolder() {
        if let logs = try? AppPaths.logs() { NSWorkspace.shared.open(logs) }
    }

    private func registerPossibleDuplicates(in analysis: DownloadAnalysis) {
        func register(id: String, title: String, duration: TimeInterval?) {
            let signature = DuplicateSignature(
                title: Self.normalizedTitle(title),
                durationBucket: duration.map { Int($0.rounded()) }
            )
            duplicateGroups[signature, default: []].insert(id)
            if let group = duplicateGroups[signature], group.count > 1 {
                possibleDuplicateIDs.formUnion(group)
            }
        }

        if analysis.kind == .video {
            register(id: analysis.canonicalID, title: analysis.title, duration: analysis.duration)
        } else {
            for entry in analysis.playlistEntries {
                register(id: entry.canonicalID, title: entry.title, duration: entry.duration)
            }
        }
    }

    private static func normalizedTitle(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var formatExplanation: String {
        let items = selectedDownloadItems()
        guard !items.isEmpty else { return YTDLPFormatSelector().summary(for: items, settings: settings) }
        let explanations = Set(items.map { item in
            YTDLPFormatSelector().selection(for: item, settings: resolvedSettings(for: item)).explanation
        })
        return explanations.sorted().joined(separator: " ")
    }

    func expectedFilenamePreview() -> String? {
        guard let item = selectedDownloadItems().first else { return nil }
        let effectiveSettings = resolvedSettings(for: item)
        let index = effectiveSettings.numberPlaylistItems ? item.playlistIndex.map { String(format: "%04d - ", $0) } ?? "" : ""
        let rawBase: String
        switch effectiveSettings.filenamePreset {
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
        let safe = (try? DownloadFilenamePolicy().sanitize(rawBase)) ?? "resultado"
        let extensionText: String
        if effectiveSettings.mode == .original {
            extensionText = item.expectedExtension ?? "formato original"
        } else if effectiveSettings.mode == .audio {
            extensionText = effectiveSettings.audioOutput == .original ? "formato original" : effectiveSettings.audioOutput.rawValue
        } else {
            extensionText = effectiveSettings.container == .automatic ? "mp4 o mkv" : effectiveSettings.container.rawValue
        }
        return safe + "." + extensionText
    }

    private func resolvedSettings(for item: UniversalDownloadItem) -> UniversalDownloadSettings {
        UniversalDownloadSettingsResolver().settings(
            for: item,
            operationSettings: settings,
            profiles: downloadProfiles
        )
    }

    private func estimatedSize(for analysis: DownloadAnalysis) -> Int64? {
        let formats = analysis.formats
        let platform = analysis.platform ?? .automatic
        let representative = UniversalDownloadItem(
            canonicalID: analysis.canonicalID,
            sourceURL: analysis.sourceURL ?? URL(string: "https://invalid.invalid/")!,
            title: analysis.title,
            downloadSource: analysis.downloadSource,
            pageOrigin: analysis.pageOrigin,
            platform: platform,
            mediaKind: analysis.mediaKind ?? .unknown
        )
        let effectiveSettings = resolvedSettings(for: representative)
        if effectiveSettings.mode == .original {
            let progressive = formats.filter(\.isProgressive).compactMap(\.bestKnownSize).max()
            if let progressive { return progressive }
            let video = formats.filter(\.hasVideo).compactMap(\.bestKnownSize).max()
            let audio = formats.filter { $0.hasAudio && !$0.hasVideo }.compactMap(\.bestKnownSize).max()
            if let video { return video + (audio ?? 0) }
            return audio
        }
        if effectiveSettings.mode == .audio {
            if let id = effectiveSettings.exactAudioFormatID { return formats.first(where: { $0.formatID == id })?.bestKnownSize }
            return formats.filter { $0.hasAudio && !$0.hasVideo }.compactMap(\.bestKnownSize).max()
        }
        if let videoID = effectiveSettings.exactVideoFormatID {
            let video = formats.first(where: { $0.formatID == videoID })?.bestKnownSize
            let audio = effectiveSettings.exactAudioFormatID.flatMap { id in formats.first(where: { $0.formatID == id })?.bestKnownSize }
            if let video { return video + (audio ?? 0) }
            return nil
        }
        let maxHeight = effectiveSettings.maximumResolution == .best ? Int.max : effectiveSettings.maximumResolution.rawValue
        let video = formats.filter { $0.hasVideo && ($0.height ?? 0) <= maxHeight }.compactMap(\.bestKnownSize).max()
        let audio = formats.filter { $0.hasAudio && !$0.hasVideo }.compactMap(\.bestKnownSize).max()
        if let video { return video + (audio ?? 0) }
        return nil
    }
}

private extension DownloadProgressPhase {
    var spanishName: String {
        switch self {
        case .preparing: return "Preparando"
        case .analyzing: return "Analizando"
        case .connecting: return "Conectando con el vídeo"
        case .downloading: return "Descargando"
        case .merging: return "Uniendo vídeo y audio"
        case .converting: return "Convirtiendo con FFmpeg"
        case .embeddingMetadata: return "Guardando procedencia"
        case .verifying: return "Verificando el archivo"
        case .publishing: return "Publicando resultados"
        case .cleaning: return "Limpiando temporales"
        }
    }
}
