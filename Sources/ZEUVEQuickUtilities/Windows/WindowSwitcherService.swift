#if os(macOS)
import Foundation
import Combine
import ZEUVEStorage

@MainActor public protocol WindowShortcutRegistering: AnyObject {
    func register(id: String, shortcut: GlobalShortcut, action: @escaping @MainActor () -> Void) throws
    func unregister(id: String)
}
extension GlobalShortcutRegistry: WindowShortcutRegistering {}

public struct WindowSwitcherPreferences: Codable, Sendable, Equatable {
    public var schemaVersion = 1
    public var shortcut = GlobalShortcut(keyCode: 48, option: true)
    public init() {}
    public func validate() throws {
        guard schemaVersion == 1 else { throw QuickUtilityError.failure("La configuración del selector es incompatible.") }
        try shortcut.validate()
    }
}

@MainActor public final class WindowSwitcherService: ObservableObject, QuickUtilityService {
    public let id: QuickUtilityID = .windowSwitcher
    public static let settingsKey = "quickUtilities.windows.switcher.v1"
    @Published public private(set) var state: QuickUtilityState = .disabled
    @Published public private(set) var preferences = WindowSwitcherPreferences()
    @Published public private(set) var windows: [WindowSnapshot] = []
    @Published public private(set) var isPresented = false
    @Published public private(set) var message: String?
    public var stateDidChange: (@MainActor (QuickUtilityState) -> Void)?
    public var onShowSwitcher: (@MainActor () -> Void)?
    public var onCloseSwitcher: (@MainActor () -> Void)?
    private let backend: WindowServicesBackend
    private let settings: SettingsRepository?
    private let shortcuts: any WindowShortcutRegistering
    private var presentationTask: Task<Void, Never>?
    private var selectionTask: Task<Void, Never>?
    private var permissionTask: Task<Void, Never>?

    public init(backend: WindowServicesBackend, settings: SettingsRepository?, shortcuts: any WindowShortcutRegistering) {
        self.backend = backend; self.settings = settings; self.shortcuts = shortcuts
        do {
            let loaded = try settings?.value(forKey: Self.settingsKey, as: WindowSwitcherPreferences.self) ?? .init()
            try loaded.validate(); preferences = loaded
        } catch { message = "No se pudo recuperar el atajo guardado."; state = .failed("La configuración del selector no se pudo leer.") }
    }
    private func transition(_ state: QuickUtilityState) { self.state = state; stateDidChange?(state) }
    public func start() async throws {
        guard state != .active else { return }
        transition(.activating)
        do {
            guard let settings else { throw QuickUtilityError.failure("El almacenamiento del selector no está disponible.") }
            let value = try settings.value(forKey: Self.settingsKey, as: WindowSwitcherPreferences.self) ?? .init()
            try value.validate(); preferences = value
            try await backend.acquire(id)
            try Task.checkCancellation()
            try shortcuts.register(id: id.id, shortcut: value.shortcut) { [weak self] in self?.show() }
            backend.changeHandlers[id] = { [weak self] in if self?.isPresented == true { self?.refreshPresented() } }
            backend.permissionHandlers[id] = { [weak self] in self?.permissionRevoked() }
            transition(.active)
        } catch {
            shortcuts.unregister(id: id.id); await backend.release(id)
            let failure = (error as? QuickUtilityError) ?? .failure("No se pudo activar el selector de ventanas.")
            transition(failure.state); throw failure
        }
    }
    public func stop() async throws {
        transition(.deactivating)
        shortcuts.unregister(id: id.id)
        presentationTask?.cancel(); selectionTask?.cancel()
        if let presentationTask { await presentationTask.value }; self.presentationTask = nil
        if let selectionTask { await selectionTask.value }; self.selectionTask = nil
        cancel(); windows.removeAll(); message = nil
        await backend.release(id)
        transition(.disabled)
    }
    public func restoreDefaultSettings() async throws {
        try await stop()
        guard let settings else { throw QuickUtilityError.failure("El almacenamiento del selector no está disponible.") }
        try settings.removeValue(forKey: Self.settingsKey); preferences = .init()
    }
    public func setShortcut(_ shortcut: GlobalShortcut) throws {
        var updated = preferences; updated.shortcut = shortcut; try updated.validate()
        guard let settings else { throw QuickUtilityError.failure("El almacenamiento del selector no está disponible.") }
        if state == .active {
            try shortcuts.register(id: id.id, shortcut: shortcut) { [weak self] in self?.show() }
            do { try settings.set(updated, forKey: Self.settingsKey) }
            catch {
                do { try shortcuts.register(id: id.id, shortcut: preferences.shortcut) { [weak self] in self?.show() } }
                catch { shortcuts.unregister(id: id.id); transition(.failed("El atajo se ha detenido porque no pudo restaurarse su registro.")) }
                throw QuickUtilityError.failure("No se pudo guardar el nuevo atajo.")
            }
        } else { try settings.set(updated, forKey: Self.settingsKey) }
        preferences = updated
    }
    public func show() {
        guard state == .active else { return }
        if isPresented { onShowSwitcher?(); return }
        presentationTask?.cancel()
        presentationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let snapshots = try await backend.snapshots(); try Task.checkCancellation()
                windows = snapshots; message = snapshots.isEmpty ? "No hay ventanas compatibles disponibles." : nil
                isPresented = true; onShowSwitcher?()
            } catch is CancellationError {} catch {
                message = error.localizedDescription
                if (error as? QuickUtilityError) == .requiresPermission(.accessibility) { permissionRevoked() }
                else { isPresented = true; onShowSwitcher?() }
            }
            presentationTask = nil
        }
    }
    private func refreshPresented() {
        guard presentationTask == nil, isPresented else { return }
        presentationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let updated = try await backend.snapshots()
                if !Task.isCancelled && isPresented { windows = updated }
            } catch { if !Task.isCancelled { message = error.localizedDescription } }
            presentationTask = nil
        }
    }
    public func cancel() { isPresented = false; onCloseSwitcher?() }
    public func choose(_ windowID: UUID) {
        guard state == .active, selectionTask == nil, windows.contains(where: { $0.id == windowID }) else { return }
        cancel()
        selectionTask = Task { [weak self] in
            guard let self else { return }
            do { try await backend.access.activateWindow(windowID); message = nil }
            catch is CancellationError {} catch {
                message = error.localizedDescription
                if (error as? QuickUtilityError) == .requiresPermission(.accessibility) { permissionRevoked() }
                else if state == .active { isPresented = true; onShowSwitcher?() }
            }
            selectionTask = nil
        }
    }
    private func permissionRevoked() {
        guard permissionTask == nil else { return }
        permissionTask = Task { [weak self] in
            guard let self else { return }
            try? await stop(); transition(.requiresPermission(.accessibility)); permissionTask = nil
        }
    }
}
#endif
