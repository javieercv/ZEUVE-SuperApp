import Foundation
import SwiftUI
import ZEUVECore
import ZEUVEStorage
import ZEUVEOperations
import ZEUVEEngines
import OrganizerModule
import YouTubeDownloaderModule
import ChatAnalyzerModule
import UniversalConverterModule

enum AppDestination: String, CaseIterable, Identifiable, Hashable {
    case dashboard
    case organizer
    case youtubeDownloader
    case chatAnalyzer
    case universalConverter
    case history
    case settings

    var id: String { rawValue }
    var title: String {
        switch self {
        case .dashboard: return "Inicio"
        case .organizer: return "Organizador"
        case .youtubeDownloader: return "Descargador de YouTube"
        case .chatAnalyzer: return "Analizador de chats"
        case .universalConverter: return "Conversor universal"
        case .history: return "Historial"
        case .settings: return "Ajustes"
        }
    }
    var systemImage: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .organizer: return "folder.badge.gearshape"
        case .youtubeDownloader: return "arrow.down.circle"
        case .chatAnalyzer: return "bubble.left.and.bubble.right"
        case .universalConverter: return "arrow.triangle.2.circlepath"
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
    @Published var startupError: String?
    @Published var activeOperation: OperationSnapshot?

    let coordinator: OperationCoordinator
    let registry: ModuleRegistry
    let organizer: OrganizerViewModel
    let youtubeDownloader: YouTubeDownloaderViewModel
    let chatAnalyzer: ChatAnalyzerViewModel
    let universalConverter: UniversalConverterViewModel
    let globalHistory: GlobalHistoryViewModel
    let storage: StorageContainer?
    let logger: LocalLogger?

    private var operationObserver: Task<Void, Never>?

    init() {
        let localCoordinator = OperationCoordinator()
        let localRegistry = ModuleRegistry()
        let localLogger = try? LocalLogger(directory: AppPaths.logs())
        let sharedEngineRegistry = try? EngineRegistry.bundled()
        let sharedEngineDiagnostics = sharedEngineRegistry.map { EngineDiagnosticService(registry: $0) }

        let initialState: (
            storage: StorageContainer?,
            theme: ThemePreference,
            startupError: String?,
            organizer: OrganizerViewModel
        )

        do {
            let container = try StorageContainer.live()
            let loadedTheme = try container.settings.value(forKey: "appearance.theme", as: ThemePreference.self) ?? .system
            let loadedOrganizer = OrganizerViewModel(
                coordinator: localCoordinator,
                settings: container.settings,
                history: OrganizerHistoryService(repository: container.history),
                logger: localLogger
            )
            initialState = (storage: container, theme: loadedTheme, startupError: nil, organizer: loadedOrganizer)
        } catch {
            let message = "No se ha podido abrir el almacenamiento local: \(error.localizedDescription)"
            initialState = (
                storage: nil,
                theme: .system,
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
        startupError = initialState.startupError
        youtubeDownloader = YouTubeDownloaderViewModel(
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
        globalHistory = GlobalHistoryViewModel(storage: initialState.storage)
    }

    func start() async {
        var registrationErrors: [String] = []
        do { try await registry.register(OrganizerModuleDefinition.manifest()) }
        catch { registrationErrors.append("Organizador: \(error.localizedDescription)") }
        do { try await registry.register(YouTubeDownloaderModuleDefinition.manifest()) }
        catch { registrationErrors.append("Descargador de YouTube: \(error.localizedDescription)") }
        do { try await registry.register(ChatAnalyzerModuleDefinition.manifest()) }
        catch { registrationErrors.append("Analizador de chats: \(error.localizedDescription)") }
        do { try await registry.register(UniversalConverterModuleDefinition.manifest()) }
        catch { registrationErrors.append("Conversor universal: \(error.localizedDescription)") }
        modules = await registry.all()
        if !registrationErrors.isEmpty { startupError = "No se han podido registrar todos los módulos:\n" + registrationErrors.joined(separator: "\n") }
        await organizer.loadHistory()
        await youtubeDownloader.start()
        universalConverter.start()
        globalHistory.load(manifests: modules)
        operationObserver = Task { [weak self, coordinator] in
            for await snapshot in await coordinator.snapshots() {
                guard !Task.isCancelled else { return }
                self?.activeOperation = snapshot
            }
        }
    }

    func saveTheme(_ value: ThemePreference) {
        theme = value
        try? storage?.settings.set(value, forKey: "appearance.theme")
    }

    func terminateExternalProcesses() async {
        organizer.cancel()
        youtubeDownloader.cancel()
        await chatAnalyzer.cancelAndWait()
        await universalConverter.cancelAndWait()
        await ExternalProcessRegistry.shared.terminateAll(gracePeriod: .seconds(2))
    }
}
