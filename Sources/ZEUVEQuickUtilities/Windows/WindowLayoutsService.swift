#if os(macOS)
import Foundation
import AppKit
import Combine
import ZEUVEStorage

@MainActor public final class WindowLayoutsService: ObservableObject, QuickUtilityService {
    public let id: QuickUtilityID = .windowLayouts
    public static let settingsKey = "quickUtilities.windows.layouts.v1"
    @Published public private(set) var state: QuickUtilityState = .disabled
    @Published public private(set) var preferences = WindowLayoutsPreferences()
    @Published public private(set) var windows: [WindowSnapshot] = []
    @Published public private(set) var isRestoring = false
    @Published public private(set) var lastResult: WindowLayoutResult?
    @Published public private(set) var message: String?
    @Published public private(set) var associations: [UUID: UUID] = [:]
    public var stateDidChange: (@MainActor (QuickUtilityState) -> Void)?
    private let backend: WindowServicesBackend
    private let settings: SettingsRepository?
    private let displayProvider: @MainActor () -> [WindowDisplayGeometry]
    private var screenObserver: NSObjectProtocol?
    private var automaticTask: Task<Void, Never>?
    private var restorationTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var permissionTask: Task<Void, Never>?
    private var cancellationRequested = false
    private var generation: UInt64 = 0

    public init(backend: WindowServicesBackend, settings: SettingsRepository?, displayProvider: @escaping @MainActor () -> [WindowDisplayGeometry] = WindowServicesBackend.displays) {
        self.backend = backend; self.settings = settings; self.displayProvider = displayProvider
        do {
            let loaded = try settings?.value(forKey: Self.settingsKey, as: WindowLayoutsPreferences.self) ?? .init()
            try loaded.validate(); preferences = loaded
        } catch { message = "No se pudieron recuperar las distribuciones guardadas."; state = .failed("La configuración de distribuciones no se pudo leer.") }
    }
    private func transition(_ state: QuickUtilityState) { self.state = state; stateDidChange?(state) }
    public func start() async throws {
        guard state != .active else { return }
        transition(.activating)
        do {
            guard let settings else { throw QuickUtilityError.failure("El almacenamiento de distribuciones no está disponible.") }
            let loaded = try settings.value(forKey: Self.settingsKey, as: WindowLayoutsPreferences.self) ?? .init()
            try loaded.validate(); preferences = loaded
            try await backend.acquire(id); try Task.checkCancellation()
            backend.permissionHandlers[id] = { [weak self] in self?.permissionRevoked() }
            screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.screensChanged() }
            }
            transition(.active)
        } catch {
            await backend.release(id)
            let failure = (error as? QuickUtilityError) ?? .failure("No se pudieron activar las distribuciones de ventanas.")
            transition(failure.state); throw failure
        }
    }
    public func stop() async throws {
        generation &+= 1
        transition(.deactivating)
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }; screenObserver = nil
        cancellationRequested = true
        automaticTask?.cancel(); restorationTask?.cancel(); refreshTask?.cancel()
        if let automaticTask { await automaticTask.value }; self.automaticTask = nil
        if let restorationTask { await restorationTask.value }; self.restorationTask = nil
        if let refreshTask { await refreshTask.value }; self.refreshTask = nil
        associations.removeAll(); windows.removeAll(); isRestoring = false
        await backend.release(id); transition(.disabled)
    }
    public func restoreDefaultSettings() async throws {
        try await stop()
        guard let settings else { throw QuickUtilityError.failure("El almacenamiento de distribuciones no está disponible.") }
        let saved = try settings.value(forKey: Self.settingsKey, as: WindowLayoutsPreferences.self) ?? .init()
        try saved.validate()
        var defaults = WindowLayoutsPreferences(); defaults.profiles = saved.profiles
        try persist(defaults); lastResult = nil; message = nil
    }
    private func persist(_ updated: WindowLayoutsPreferences) throws {
        try updated.validate()
        guard let settings else { throw QuickUtilityError.failure("El almacenamiento de distribuciones no está disponible.") }
        try settings.set(updated, forKey: Self.settingsKey); preferences = updated
    }
    public func refreshWindows() {
        guard state == .active, refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            guard let self else { return }
            do {
                let updated = try await backend.snapshots(); try Task.checkCancellation()
                windows = updated
                let live = Set(updated.map(\.id)); associations = associations.filter { live.contains($0.value) }
                message = nil
            } catch is CancellationError {} catch {
                message = error.localizedDescription
                if (error as? QuickUtilityError) == .requiresPermission(.accessibility) { permissionRevoked() }
            }
            refreshTask = nil
        }
    }
    public func saveProfile(name: String, windowIDs: Set<UUID>) async throws {
        guard state == .active, !isRestoring else { throw QuickUtilityError.failure("Activa la utilidad antes de guardar una distribución.") }
        let currentGeneration = generation
        let current = try await backend.snapshots(); try Task.checkCancellation()
        guard state == .active, generation == currentGeneration else { throw CancellationError() }
        let selected = current.filter { windowIDs.contains($0.id) && $0.canRestoreGeometry }
        guard !selected.isEmpty, selected.count == windowIDs.count else { throw QuickUtilityError.failure("Alguna ventana elegida ya no está disponible o no admite restauración.") }
        let displays = displayProvider()
        var bindings: [UUID: UUID] = [:]
        let slots = try selected.map { window -> WindowLayoutSlot in
            guard let index = WindowGeometryPlanner.displayIndex(for: window.frame, displays: displays) else { throw QuickUtilityError.failure("No hay pantallas disponibles.") }
            let slot = WindowLayoutSlot(bundleIdentifier: window.bundleIdentifier, displayIndex: index,
                                        relativeFrame: WindowGeometryPlanner.relative(window.frame, to: displays[index]))
            bindings[slot.id] = window.id; return slot
        }
        let profile = WindowLayoutProfile(name: name.trimmingCharacters(in: .whitespacesAndNewlines), displays: displays, slots: slots)
        var updated = preferences; updated.profiles.append(profile); try persist(updated)
        associations.merge(bindings) { _, value in value }; windows = current
    }
    public func renameProfile(_ id: UUID, name: String) throws {
        var updated = preferences
        guard let index = updated.profiles.firstIndex(where: { $0.id == id }) else { return }
        updated.profiles[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines); try persist(updated)
    }
    public func deleteProfile(_ id: UUID) throws {
        guard !isRestoring else { throw QuickUtilityError.failure("Espera a que termine la restauración.") }
        let slots = preferences.profiles.first(where: { $0.id == id })?.slots ?? []
        var updated = preferences; updated.profiles.removeAll { $0.id == id }
        if updated.automaticProfileID == id { updated.automaticProfileID = nil; updated.automaticallyRestore = false }
        try persist(updated); for slot in slots { associations[slot.id] = nil }
    }
    public func setAutomaticRestoration(_ enabled: Bool, profileID: UUID?) throws {
        var updated = preferences; updated.automaticallyRestore = enabled; updated.automaticProfileID = profileID; try persist(updated)
    }
    public func associate(slotID: UUID, windowID: UUID?) throws {
        guard !isRestoring, let slot = preferences.profiles.flatMap(\.slots).first(where: { $0.id == slotID }) else { throw QuickUtilityError.failure("La posición guardada ya no está disponible.") }
        guard let windowID else { associations[slotID] = nil; return }
        guard let window = windows.first(where: { $0.id == windowID }), window.bundleIdentifier == slot.bundleIdentifier, window.canRestoreGeometry else {
            throw QuickUtilityError.failure("Elige una ventana manipulable de la aplicación guardada.")
        }
        guard let profile = preferences.profiles.first(where: { $0.slots.contains(where: { $0.id == slotID }) }),
              !profile.slots.contains(where: { $0.id != slotID && associations[$0.id] == windowID }) else {
            throw QuickUtilityError.failure("Esta ventana ya está asociada a otra posición de la distribución.")
        }
        associations[slotID] = windowID
    }
    public func restoreProfile(_ profileID: UUID) { beginRestore(profileID, automatic: false) }
    public func cancelRestoration() { cancellationRequested = true; restorationTask?.cancel() }
    private func beginRestore(_ profileID: UUID, automatic: Bool) {
        guard state == .active, !isRestoring, let profile = preferences.profiles.first(where: { $0.id == profileID }) else { return }
        let displays = displayProvider()
        if automatic && !WindowGeometryPlanner.topologyMatches(profile.displays, displays) { return }
        isRestoring = true; cancellationRequested = false; message = nil
        restorationTask = Task { [weak self] in
            guard let self else { return }
            var result = WindowLayoutResult()
            do {
                let current = try await backend.snapshots()
                windows = current
                let live = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
                for slot in profile.slots {
                    if Task.isCancelled || cancellationRequested { result.cancelled = true; break }
                    // Display changes mid-operation invalidate the plan, rather than
                    // pushing windows using stale coordinates.
                    guard displayProvider() == displays else { result.cancelled = true; message = "La configuración de pantallas cambió durante la restauración."; break }
                    guard let identity = associations[slot.id], let window = live[identity], window.bundleIdentifier == slot.bundleIdentifier, window.canRestoreGeometry else { result.omitted += 1; associations[slot.id] = nil; continue }
                    let targetIndex: Int
                    if displays.indices.contains(slot.displayIndex), profile.displays.count == displays.count { targetIndex = slot.displayIndex }
                    else if !automatic, !displays.isEmpty { targetIndex = 0 }
                    else { result.omitted += 1; continue }
                    let target = WindowGeometryPlanner.restored(slot.relativeFrame, on: displays[targetIndex])
                    do { _ = try await backend.access.restoreWindow(identity, frame: target); result.restored += 1 }
                    catch is CancellationError { result.cancelled = true; break }
                    catch let failure as QuickUtilityError {
                        if failure == .requiresPermission(.accessibility) { throw failure }
                        result.failed += 1
                    } catch { result.failed += 1 }
                }
            } catch is CancellationError { result.cancelled = true } catch {
                message = error.localizedDescription
                if (error as? QuickUtilityError) == .requiresPermission(.accessibility) { permissionRevoked() }
                else { result.failed += 1 }
            }
            lastResult = result; isRestoring = false; restorationTask = nil
        }
    }
    private func screensChanged() {
        guard state == .active, preferences.automaticallyRestore, let profileID = preferences.automaticProfileID else { return }
        automaticTask?.cancel()
        automaticTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            guard let self, !Task.isCancelled else { return }
            beginRestore(profileID, automatic: true); automaticTask = nil
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
