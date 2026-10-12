import SwiftUI
import AppKit
import ServiceManagement
import ZEUVECore
import ZEUVEStorage
import ZEUVEOperations
import ZEUVEQuickUtilities

@MainActor final class ResidentRuntime: ObservableObject {
    @Published private(set) var isReady = false
    @Published private(set) var startupError: String?
    @Published var loginError: String?
    @Published private(set) var loginRequested = false
    @Published private(set) var isRestoringDefaults = false
    @Published private(set) var utilitiesResetError: String?
    @Published private(set) var loginStatus = SMAppService.mainApp.status
    @Published private(set) var registeredModules: [ModuleManifest] = []
    @Published private(set) var navigationPreferences = NavigationPreferences()
    @Published private(set) var theme = ThemePreference.system
    @Published private(set) var appModel: AppModel?
    let storage: StorageContainer?
    let logger: LocalLogger?
    let operations = OperationCoordinator()
    let shortcuts: GlobalShortcutRegistry
    let scroll: ScrollDirectionService
    let mouseButtons: AdditionalMouseButtonsService
    let windowSwitcher: WindowSwitcherService
    let windowLayouts: WindowLayoutsService
    let audioMixer: ApplicationAudioMixerService?
    let audioProtection: CallAudioProtectionService?
    let newFiles: NewFileUtilityService
    let fileShelf: FileShelfUtilityService
    let textActions: TextActionsUtilityService
    let filePanel: NewFilePanelController
    let shelfPanel: FileShelfPanelController
    let switcherPanel: WindowSwitcherPanelController
    private let servicesProvider: QuickUtilitiesServicesProvider
    let utilities: QuickUtilitiesCoordinator
    private var mainWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var startupTask: Task<Void, Never>?
    private var activationTasks: [QuickUtilityID: Task<Void, Never>] = [:]
    private var mainStartupTask: Task<Void, Never>?
    private var stopAllTask: Task<Void, Never>?
    private var resetTask: Task<Void, Never>?
    private var didStart = false
    private var terminating = false
    private static let loginKey = "quickUtilities.launchAtLogin.v1"

    init() {
        var issues: [String] = []
        let container: StorageContainer?
        do { container = try StorageContainer.live() }
        catch { container = nil; issues.append("No se pudo abrir el almacenamiento local.") }
        let localLogger: LocalLogger?
        do { localLogger = try LocalLogger(directory: AppPaths.logs()) }
        catch { localLogger = nil; issues.append("Los registros técnicos no están disponibles.") }
        storage = container; logger = localLogger
        let registry = GlobalShortcutRegistry()
        shortcuts = registry
        let input = InputEventTapBroker()
        let scrollService = ScrollDirectionService(settings: container?.settings, broker: input)
        let buttonsService = AdditionalMouseButtonsService(settings: container?.settings, broker: input)
        scroll = scrollService; mouseButtons = buttonsService
        let windows = WindowServicesBackend()
        let switcher = WindowSwitcherService(backend: windows, settings: container?.settings, shortcuts: registry)
        let layouts = WindowLayoutsService(backend: windows, settings: container?.settings)
        windowSwitcher = switcher; windowLayouts = layouts
        switcherPanel = WindowSwitcherPanelController(service: switcher)
        let files = NewFileUtilityService(settings: container?.settings, operationCoordinator: operations)
        let shelf = FileShelfUtilityService()
        let text = TextActionsUtilityService()
        newFiles = files; fileShelf = shelf; textActions = text
        let creationPanel = NewFilePanelController(service: files)
        filePanel = creationPanel; shelfPanel = FileShelfPanelController(service: shelf)
        servicesProvider = QuickUtilitiesServicesProvider(files: creationPanel, text: text)
        var services: [any QuickUtilityService] = [scrollService, buttonsService, switcher, layouts, files, shelf, text]
        if let settings = container?.settings {
            let routing = AudioRoutingCoordinator(settings: settings)
            let mixer = ApplicationAudioMixerService(routing: routing)
            let protection = CallAudioProtectionService(routing: routing)
            audioMixer = mixer; audioProtection = protection
            services += [mixer, protection]
        } else { audioMixer = nil; audioProtection = nil }
        utilities = QuickUtilitiesCoordinator(settings: container?.settings, services: services)
        startupError = issues.isEmpty ? nil : issues.joined(separator: "\n")
        utilities.didChange = { [weak self] in self?.objectWillChange.send() }
        audioProtection?.diagnosticDidChange = { [weak self] in self?.objectWillChange.send() }
    }

    var navigationModules: [RegisteredBuiltInModule] {
        let order = navigationPreferences.moduleOrder.compactMap { BuiltInModuleCatalog.descriptor(forIdentifier: $0) }
        return BuiltInModuleCatalog.registeredModules(from: registeredModules, orderedBy: order)
    }
    var settingsModules: [RegisteredBuiltInModule] {
        BuiltInModuleCatalog.registeredModules(from: registeredModules, orderedBy: BuiltInModuleCatalog.settings)
    }
    func beginLaunch(showMainWindow: Bool) {
        guard !didStart else { return }
        didStart = true
        startupTask = Task { [weak self] in
            guard let self else { return }
            do {
                if let settings = storage?.settings {
                    theme = try settings.value(forKey: ZEUVEAppStorageKeys.theme, as: ThemePreference.self) ?? .system
                    let raw = try settings.value(forKey: ZEUVEAppStorageKeys.navigationPreferences, as: NavigationPreferences.self) ?? .init()
                    navigationPreferences = KeyboardShortcutValidator.normalized(raw, availableModuleIDs: BuiltInModuleCatalog.navigationDefaults.moduleOrder, defaults: BuiltInModuleCatalog.navigationDefaults)
                    loginRequested = try settings.value(forKey: Self.loginKey, as: Bool.self) ?? false
                }
            } catch { startupError = "No se pudieron recuperar algunas preferencias locales." }
            for descriptor in BuiltInModuleCatalog.all {
                do { registeredModules.append(try descriptor.loadManifest()) }
                catch { startupError = "No se pudo registrar \(descriptor.registrationName)." }
            }
            refreshShortcutConflicts()
            NSApp.servicesProvider = servicesProvider
            await utilities.initialize()
            guard !Task.isCancelled else { return }
            isReady = true; refreshLoginStatus()
            if showMainWindow { openMainWindow() }
        }
    }
    func requireAppModel() -> AppModel {
        if let appModel { return appModel }
        let model = AppModel(runtime: self)
        appModel = model
        mainStartupTask = Task { await model.start() }
        return model
    }
    func openMainWindow(destination: AppDestination? = nil) {
        guard !terminating else { return }
        let model = requireAppModel()
        if let destination { model.selection = destination }
        if mainWindow == nil {
            let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 1180, height: 780), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "ZEUVE"; window.isReleasedWhenClosed = false
            let controller = NSHostingController(rootView: ResidentMainWindowContent(model: model, runtime: self))
            controller.sizingOptions = []
            window.contentViewController = controller
            window.setContentSize(.init(width: 1180, height: 780))
            window.minSize = .init(width: 1000, height: 680); window.center()
            mainWindow = window
        }
        mainWindow?.makeKeyAndOrderFront(nil); NSApp.activate()
    }
    func openSettings(quickUtilities: Bool = false) {
        guard !terminating else { return }
        if settingsWindow == nil {
            let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 920, height: 680), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.title = "Ajustes de ZEUVE"; window.isReleasedWhenClosed = false
            window.minSize = .init(width: 820, height: 600)
            window.center()
            settingsWindow = window
        }
        let controller = NSHostingController(rootView: SettingsView(initialArea: quickUtilities ? .quickUtilities : .general).environmentObject(self))
        controller.sizingOptions = []
        settingsWindow?.contentViewController = controller
        if let window = settingsWindow, window.frame.height < 600 || window.frame.width < 820 {
            window.setContentSize(.init(width: 920, height: 680))
        }
        settingsWindow?.makeKeyAndOrderFront(nil); NSApp.activate()
    }
    func setUtilityEnabled(_ enabled: Bool, id: QuickUtilityID) {
        guard !terminating, stopAllTask == nil, activationTasks[id] == nil else { return }
        activationTasks[id] = Task { [weak self] in
            guard let self else { return }
            await utilities.setEnabled(enabled, for: id); activationTasks[id] = nil
        }
    }
    func retryUtility(_ id: QuickUtilityID) {
        guard !terminating, activationTasks[id] == nil else { return }
        activationTasks[id] = Task { [weak self] in
            guard let self else { return }
            await utilities.retry(id); activationTasks[id] = nil
        }
    }
    func stopUtilities() {
        guard stopAllTask == nil else { return }
        activationTasks.values.forEach { $0.cancel() }
        stopAllTask = Task { [weak self] in
            guard let self else { return }
            await utilities.stopAll()
            stopAllTask = nil
        }
    }
    func refreshLoginStatus() { loginStatus = SMAppService.mainApp.status }
    func setLaunchAtLogin(_ requested: Bool) {
        loginError = nil
        do {
            guard let storage else { throw QuickUtilityError.failure("El almacenamiento no está disponible.") }
            if requested {
                try storage.settings.set(true, forKey: Self.loginKey)
                loginRequested = true
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else {
                try storage.settings.set(false, forKey: Self.loginKey)
                loginRequested = false
                if SMAppService.mainApp.status != .notRegistered && SMAppService.mainApp.status != .notFound {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch { loginError = "No se pudo completar el cambio de inicio automático: \(error.localizedDescription)" }
        refreshLoginStatus()
    }
    var loginStatusText: String {
        switch loginStatus {
        case .enabled: "Registrado y autorizado"
        case .notRegistered: "Sin registrar"
        case .requiresApproval: "Pendiente de autorización en macOS"
        case .notFound: "macOS no encuentra la aplicación registrada"
        @unknown default: "Estado no reconocido"
        }
    }
    func refreshShortcutConflicts() {
        navigationPreferences = appModel?.navigationPreferences ?? navigationPreferences
        shortcuts.navigationShortcuts = (BuiltInModuleCatalog.navigationDefaults.moduleOrder + [BuiltInModuleCatalog.historyTargetID]).compactMap { id in
            guard let value = navigationPreferences.effectiveShortcut(for: id, defaults: BuiltInModuleCatalog.navigationDefaults), let code = GlobalShortcutRegistry.keyCode(for: value.key) else { return nil }
            return GlobalShortcut(keyCode: code, command: value.command, option: value.option, control: value.control, shift: value.shift)
        }
    }
    func syncTheme(_ theme: ThemePreference) { self.theme = theme }
    func restoreUtilitiesDefaults(includeModules: Bool = false) {
        guard !terminating, resetTask == nil else { return }
        isRestoringDefaults = true; utilitiesResetError = nil
        resetTask = Task { [weak self] in
            guard let self else { return }
            defer { isRestoringDefaults = false; resetTask = nil }
            var failures = await utilities.restoreDefaults()
            setLaunchAtLogin(false)
            if let loginError { failures.append(loginError) }
            if includeModules, let model = appModel {
                model.restoreAllSettingsToDefaults()
                if !failures.isEmpty { model.settingsError = ([model.settingsError].compactMap { $0 } + failures).joined(separator: "\n") }
            }
            utilitiesResetError = failures.isEmpty ? nil : failures.joined(separator: "\n")
        }
    }
    func shutdown() async {
        guard !terminating else { return }
        terminating = true; startupTask?.cancel(); mainStartupTask?.cancel()
        activationTasks.values.forEach { $0.cancel() }
        await stopAllTask?.value
        await resetTask?.value
        await utilities.shutdown()
        await startupTask?.value
        for task in activationTasks.values { await task.value }
        await mainStartupTask?.value
        await filePanel.shutdown()
        NSApp.servicesProvider = nil
        await appModel?.terminateExternalProcesses()
        shortcuts.unregisterAll()
    }
}

private struct ResidentMainWindowContent: View {
    @ObservedObject var model: AppModel
    @ObservedObject var runtime: ResidentRuntime
    var body: some View {
        RootView().environmentObject(model).environmentObject(runtime).preferredColorScheme(model.theme.colorScheme)
    }
}
