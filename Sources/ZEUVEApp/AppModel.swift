import Foundation
import SwiftUI
import ZEUVECore
import ZEUVEStorage
import ZEUVEOperations
import ZEUVEEngines
import OrganizerModule
import UniversalDownloaderModule
import ChatAnalyzerModule
import UniversalConverterModule
import InstagramFollowersModule
import MultimediaInspectorModule
import CleanerModule

enum AppDestination: Identifiable, Hashable {
    case dashboard
    case module(BuiltInModuleID)
    case history
    case settings

    var id: String {
        switch self {
        case .dashboard: return "dashboard"
        case .module(let moduleID): return "module.\(moduleID.rawValue)"
        case .history: return "history"
        case .settings: return "settings"
        }
    }

    var title: String {
        switch self {
        case .dashboard: return "Inicio"
        case .module(let moduleID): return BuiltInModuleCatalog.descriptor(for: moduleID).registrationName
        case .history: return "Historial"
        case .settings: return "Ajustes"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .module: return "puzzlepiece.extension"
        case .history: return "clock.arrow.circlepath"
        case .settings: return "gearshape"
        }
    }
}

enum ThemePreference: String, Codable, CaseIterable, Identifiable, Sendable, Hashable {
    case system
    case light
    case dark

    var id: String { rawValue }
    var name: String {
        switch self {
        case .system: return "Sistema"
        case .light: return "Claro"
        case .dark: return "Oscuro"
        }
    }
    @MainActor var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var selection: AppDestination? = .dashboard
    @Published var modules: [ModuleManifest] = []
    @Published var theme: ThemePreference = .system
    @Published var navigationPreferences = NavigationPreferences()
    @Published var startupError: String?
    @Published var settingsError: String?
    @Published var activeOperation: OperationSnapshot?

    let coordinator: OperationCoordinator
    let registry: ModuleRegistry
    let organizer: OrganizerViewModel
    let universalDownloader: UniversalDownloaderViewModel
    let chatAnalyzer: ChatAnalyzerViewModel
    let universalConverter: UniversalConverterViewModel
    let instagramFollowers: InstagramFollowersViewModel
    let multimediaInspector: MultimediaInspectorViewModel
    let cleaner: CleanerViewModel
    let globalHistory: GlobalHistoryViewModel
    let storage: StorageContainer?
    let logger: LocalLogger?

    private var operationObserver: Task<Void, Never>?
    private var didStart = false

    init() {
        let localCoordinator = OperationCoordinator()
        let localRegistry = ModuleRegistry()
        let localLogger: LocalLogger?
        let loggerInitializationFailed: Bool
        do {
            localLogger = try LocalLogger(directory: AppPaths.logs())
            loggerInitializationFailed = false
        } catch {
            localLogger = nil
            loggerInitializationFailed = true
        }
        let sharedEngineRegistry: EngineRegistry?
        let engineRegistryInitializationFailed: Bool
        do {
            sharedEngineRegistry = try EngineRegistry.bundled()
            engineRegistryInitializationFailed = false
        } catch {
            sharedEngineRegistry = nil
            engineRegistryInitializationFailed = true
        }
        let sharedEngineDiagnostics = sharedEngineRegistry.map { EngineDiagnosticService(registry: $0) }

        let initialState: (
            storage: StorageContainer?,
            theme: ThemePreference,
            navigationPreferences: NavigationPreferences,
            startupError: String?,
            organizer: OrganizerViewModel
        )

        do {
            let container = try StorageContainer.live()
            let loadedTheme = try container.settings.value(forKey: ZEUVEAppStorageKeys.theme, as: ThemePreference.self) ?? .system
            let rawNavigation = try container.settings.value(forKey: ZEUVEAppStorageKeys.navigationPreferences, as: NavigationPreferences.self) ?? NavigationPreferences()
            let loadedNavigation = KeyboardShortcutValidator.normalized(
                rawNavigation,
                availableModuleIDs: BuiltInModuleCatalog.navigationDefaults.moduleOrder,
                defaults: BuiltInModuleCatalog.navigationDefaults
            )
            if loadedNavigation != rawNavigation { try? container.settings.set(loadedNavigation, forKey: ZEUVEAppStorageKeys.navigationPreferences) }
            let loadedOrganizer = OrganizerViewModel(
                coordinator: localCoordinator,
                settings: container.settings,
                history: OrganizerHistoryService(repository: container.history),
                logger: localLogger
            )
            initialState = (storage: container, theme: loadedTheme, navigationPreferences: loadedNavigation, startupError: nil, organizer: loadedOrganizer)
        } catch {
            let message = "No se ha podido abrir el almacenamiento local: \(error.localizedDescription)"
            initialState = (
                storage: nil,
                theme: .system,
                navigationPreferences: KeyboardShortcutValidator.normalized(NavigationPreferences(), availableModuleIDs: BuiltInModuleCatalog.navigationDefaults.moduleOrder, defaults: BuiltInModuleCatalog.navigationDefaults),
                startupError: message,
                organizer: OrganizerViewModel.unavailable(message: message)
            )
        }

        coordinator = localCoordinator
        registry = localRegistry
        logger = localLogger
        storage = initialState.storage
        organizer = initialState.organizer
        theme = initialState.theme
        navigationPreferences = initialState.navigationPreferences
        startupError = initialState.startupError
        universalDownloader = UniversalDownloaderViewModel(
            coordinator: localCoordinator,
            storage: initialState.storage,
            logger: localLogger,
            engineRegistry: sharedEngineRegistry,
            engineDiagnostics: sharedEngineDiagnostics
        )
        chatAnalyzer = ChatAnalyzerViewModel(coordinator: localCoordinator, storage: initialState.storage, logger: localLogger)
        universalConverter = UniversalConverterViewModel(
            coordinator: localCoordinator,
            storage: initialState.storage,
            logger: localLogger,
            engineRegistry: sharedEngineRegistry,
            engineDiagnostics: sharedEngineDiagnostics
        )
        instagramFollowers = InstagramFollowersViewModel(coordinator: localCoordinator, storage: initialState.storage, logger: localLogger)
        multimediaInspector = MultimediaInspectorViewModel(
            coordinator: localCoordinator,
            storage: initialState.storage,
            engineRegistry: sharedEngineRegistry,
            engineDiagnostics: sharedEngineDiagnostics
        )
        cleaner = CleanerViewModel(coordinator: localCoordinator, storage: initialState.storage)
        globalHistory = GlobalHistoryViewModel(storage: initialState.storage)
        if loggerInitializationFailed {
            appendStartupIssue("ZEUVE se ha iniciado, pero los registros locales de diagnóstico no están disponibles.")
        }
        if engineRegistryInitializationFailed {
            appendStartupIssue("ZEUVE se ha iniciado con disponibilidad degradada de motores. Revisa el diagnóstico del Descargador y del Conversor.")
        }
    }

    func start() async {
        guard !didStart else { return }
        didStart = true

        var registrationErrors: [String] = []
        for descriptor in BuiltInModuleCatalog.all {
            do {
                let manifest = try descriptor.loadManifest()
                guard manifest.identifier == descriptor.primaryIdentifier else {
                    registrationErrors.append("\(descriptor.registrationName): el manifiesto utiliza un identificador inesperado.")
                    continue
                }
                try await registry.register(manifest)
            } catch {
                registrationErrors.append("\(descriptor.registrationName): \(error.localizedDescription)")
            }
        }
        modules = await registry.all()
        if case .module(let selectedModule) = selection, !isModuleAvailable(selectedModule) {
            selection = .dashboard
        }
        if !registrationErrors.isEmpty {
            appendStartupIssue("No se han podido registrar todos los módulos:\n" + registrationErrors.joined(separator: "\n"))
        }
        await organizer.loadHistory()
        await universalDownloader.start()
        universalConverter.start()
        globalHistory.load(manifests: modules)
        operationObserver?.cancel()
        operationObserver = Task { [weak self, coordinator] in
            for await snapshot in await coordinator.snapshots() {
                guard !Task.isCancelled else { return }
                self?.activeOperation = snapshot
            }
        }
    }


    private var effectiveNavigationDescriptors: [BuiltInModuleDescriptor] {
        let byIdentifier = Dictionary(uniqueKeysWithValues: BuiltInModuleCatalog.navigation.map { ($0.primaryIdentifier, $0) })
        return navigationPreferences.moduleOrder.compactMap { byIdentifier[$0] }
    }

    var navigationModules: [RegisteredBuiltInModule] {
        BuiltInModuleCatalog.registeredModules(from: modules, orderedBy: effectiveNavigationDescriptors)
    }

    var dashboardModules: [RegisteredBuiltInModule] {
        BuiltInModuleCatalog.dashboardModules(from: modules, orderedBy: effectiveNavigationDescriptors)
    }

    var historyShortcut: KeyboardShortcutDescriptor? {
        navigationPreferences.effectiveShortcut(for: BuiltInModuleCatalog.historyTargetID, defaults: BuiltInModuleCatalog.navigationDefaults)
    }

    func shortcut(for moduleID: BuiltInModuleID) -> KeyboardShortcutDescriptor? {
        let target = BuiltInModuleCatalog.descriptor(for: moduleID).primaryIdentifier
        return navigationPreferences.effectiveShortcut(for: target, defaults: BuiltInModuleCatalog.navigationDefaults)
    }

    func setShortcut(_ shortcut: KeyboardShortcutDescriptor?, forTargetID targetID: String) {
        settingsError = nil
        var updated = navigationPreferences
        if let shortcut {
            do { try KeyboardShortcutValidator.validate(shortcut) } catch { settingsError = error.localizedDescription; return }
            let names = Dictionary(uniqueKeysWithValues: BuiltInModuleCatalog.all.map { ($0.primaryIdentifier, $0.registrationName) } + [(BuiltInModuleCatalog.historyTargetID, "Historial")])
            if let conflict = KeyboardShortcutValidator.conflictTarget(shortcut: shortcut, assigningTo: targetID, preferences: updated, defaults: BuiltInModuleCatalog.navigationDefaults, targetNames: names) {
                settingsError = KeyboardShortcutValidationError.conflict(conflict).localizedDescription
                return
            }
            updated.shortcutOverrides[targetID] = .custom(shortcut.normalized)
        } else {
            updated.shortcutOverrides[targetID] = .disabled
        }
        applyNavigationPreferences(updated)
    }

    func moveNavigationModules(fromOffsets: IndexSet, toOffset: Int) {
        var order = navigationPreferences.moduleOrder
        order.move(fromOffsets: fromOffsets, toOffset: toOffset)
        var updated = navigationPreferences; updated.moduleOrder = order; applyNavigationPreferences(updated)
    }

    func moveNavigationModule(_ draggedID: String, before targetID: String) {
        guard draggedID != targetID else { return }
        var order = navigationPreferences.moduleOrder
        guard let from = order.firstIndex(of: draggedID), let target = order.firstIndex(of: targetID) else { return }
        order.remove(at: from)
        let adjustedTarget = from < target ? target - 1 : target
        order.insert(draggedID, at: max(0, min(adjustedTarget, order.count)))
        var updated = navigationPreferences; updated.moduleOrder = order; applyNavigationPreferences(updated)
    }

    func restoreNavigationDefaults() {
        applyNavigationPreferences(KeyboardShortcutValidator.normalized(NavigationPreferences(), availableModuleIDs: BuiltInModuleCatalog.navigationDefaults.moduleOrder, defaults: BuiltInModuleCatalog.navigationDefaults))
    }

    private func applyNavigationPreferences(_ raw: NavigationPreferences) {
        let normalized = KeyboardShortcutValidator.normalized(raw, availableModuleIDs: BuiltInModuleCatalog.navigationDefaults.moduleOrder, defaults: BuiltInModuleCatalog.navigationDefaults)
        navigationPreferences = normalized
        do { try storage?.settings.set(normalized, forKey: ZEUVEAppStorageKeys.navigationPreferences) } catch { settingsError = "La navegación se ha actualizado para esta sesión, pero no se ha podido guardar: \(error.localizedDescription)" }
    }

    var settingsModules: [RegisteredBuiltInModule] {
        BuiltInModuleCatalog.registeredModules(from: modules, orderedBy: BuiltInModuleCatalog.settings)
    }

    func isModuleAvailable(_ moduleID: BuiltInModuleID) -> Bool {
        modules.contains { $0.identifier == BuiltInModuleCatalog.descriptor(for: moduleID).primaryIdentifier }
    }

    func selectModule(_ moduleID: BuiltInModuleID) {
        guard isModuleAvailable(moduleID) else { return }
        selection = .module(moduleID)
    }

    func saveTheme(_ value: ThemePreference) {
        theme = value
        guard let storage else { return }
        do {
            try storage.settings.set(value, forKey: ZEUVEAppStorageKeys.theme)
        } catch {
            settingsError = "El tema se ha aplicado a esta sesión, pero no se ha podido guardar: \(error.localizedDescription)"
        }
    }

    var canRestoreAllSettings: Bool {
        activeOperation == nil
            && !organizer.state.isBusy
            && !universalDownloader.state.isBusy
            && !chatAnalyzer.isAnalyzing
            && !universalConverter.isBusy
            && !instagramFollowers.isAnalyzing
            && !multimediaInspector.isBusy
            && !cleaner.isBusy
    }

    func restoreAllSettingsToDefaults() {
        guard canRestoreAllSettings else {
            settingsError = "No se pueden restaurar los ajustes mientras hay una operación en curso."
            return
        }

        settingsError = nil
        var failures: [String] = []

        theme = .system
        if let storage {
            do {
                try storage.settings.set(ThemePreference.system, forKey: ZEUVEAppStorageKeys.theme)
            } catch {
                failures.append("Apariencia: \(error.localizedDescription)")
            }
        } else {
            failures.append("Apariencia: el almacenamiento local no está disponible.")
        }

        restoreNavigationDefaults()

        organizer.errorMessage = nil
        organizer.restoreDefaultOptions()
        if let error = organizer.errorMessage {
            failures.append("Organizador: \(error)")
            organizer.errorMessage = nil
        }

        failures.append(contentsOf: universalDownloader.restorePersistentDefaultsForGlobalReset())

        chatAnalyzer.errorMessage = nil
        chatAnalyzer.restoreSettings()
        if let error = chatAnalyzer.errorMessage {
            failures.append("Analizador de chats: \(error)")
            chatAnalyzer.errorMessage = nil
        }

        failures.append(contentsOf: universalConverter.restorePersistentDefaultsForGlobalReset())
        failures.append(contentsOf: multimediaInspector.restorePersistentDefaultsForGlobalReset())
        failures.append(contentsOf: cleaner.restorePersistentDefaultsForGlobalReset())

        if !failures.isEmpty {
            settingsError = "Se han restaurado los ajustes que ha sido posible, pero algunas preferencias no se han podido guardar:\n\n"
                + failures.joined(separator: "\n")
        }
    }

    private func appendStartupIssue(_ issue: String) {
        guard !issue.isEmpty else { return }
        if let existing = startupError, !existing.isEmpty {
            startupError = existing + "\n\n" + issue
        } else {
            startupError = issue
        }
    }

    func terminateExternalProcesses() async {
        organizer.cancel()
        universalDownloader.cancel()
        await chatAnalyzer.cancelAndWait()
        await universalConverter.cancelAndWait()
        await instagramFollowers.cancelAndWait()
        await multimediaInspector.cancelAndWait()
        await cleaner.cancelAndWait()
        await ExternalProcessRegistry.shared.terminateAll(gracePeriod: .seconds(2))
    }
}
