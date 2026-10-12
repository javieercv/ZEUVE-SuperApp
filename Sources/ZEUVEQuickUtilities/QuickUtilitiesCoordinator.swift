import Foundation
import ZEUVEStorage

@MainActor public final class QuickUtilitiesCoordinator {
    public static let settingsKey = "quickUtilities.activation.v1"
    public private(set) var preferences = QuickUtilitiesPreferences()
    public private(set) var storageError: String?
    public private(set) var operationErrors: [QuickUtilityID: String] = [:]
    public var didChange: (@MainActor () -> Void)?
    private let settings: SettingsRepository?
    private let services: [QuickUtilityID: any QuickUtilityService]
    private var busy: Set<QuickUtilityID> = []
    private var inFlight: [QuickUtilityID: Task<Void, Never>] = [:]
    private var didInitialize = false
    private var shuttingDown = false
    private var stoppingAll = false
    private var resetting = false
    private var stopAllTask: Task<Void, Never>?
    private var resetTask: Task<[String], Never>?

    public init(settings: SettingsRepository?, services: [any QuickUtilityService]) {
        self.settings = settings
        self.services = Dictionary(uniqueKeysWithValues: services.map { ($0.id, $0) })
        for service in services { service.stateDidChange = { [weak self] _ in self?.didChange?() } }
    }
    public var snapshots: [QuickUtilitySnapshot] {
        QuickUtilitiesCatalog.all.map {
            .init(id: $0.id, requested: preferences.enabled.contains($0.id), state: services[$0.id]?.state ?? .unavailable("Servicio no registrado."))
        }
    }
    public func isBusy(_ id: QuickUtilityID) -> Bool { busy.contains(id) }
    public func isActive(_ id: QuickUtilityID) -> Bool { services[id]?.state == .active }

    public func initialize() async {
        guard !didInitialize else { return }
        didInitialize = true
        do {
            guard let settings else { throw QuickUtilityError.failure("El almacenamiento local no está disponible; las utilidades permanecen detenidas.") }
            let loaded = try settings.value(forKey: Self.settingsKey, as: QuickUtilitiesPreferences.self) ?? .init()
            try loaded.validate()
            preferences = loaded
        } catch {
            preferences = .init(); storageError = "No se pudo recuperar la configuración: \(error.localizedDescription)"
            didChange?(); return
        }
        // Each service checks effective permissions again. No global permission request.
        for id in QuickUtilityID.allCases where preferences.enabled.contains(id) {
            guard !Task.isCancelled, !shuttingDown, !stoppingAll, !resetting else { break }
            await reconcile(id)
        }
        didChange?()
    }

    public func setEnabled(_ enabled: Bool, for id: QuickUtilityID) async {
        guard !shuttingDown, !stoppingAll, !resetting, !busy.contains(id), services[id] != nil else { return }
        await updatePreference(enabled, for: id)
    }
    private func updatePreference(_ enabled: Bool, for id: QuickUtilityID) async {
        guard !busy.contains(id), services[id] != nil else { return }
        var updated = preferences
        if enabled { updated.enabled.insert(id) } else { updated.enabled.remove(id) }
        if enabled {
            do { try persist(updated); preferences = updated; storageError = nil }
            catch { storageError = "No se ha activado la utilidad porque no se pudo guardar su configuración: \(error.localizedDescription)"; didChange?(); return }
            await reconcile(id)
        } else {
            preferences = updated
            await reconcile(id)
            do { try persist(preferences); storageError = nil }
            catch { storageError = "La utilidad se ha detenido, pero no se pudo guardar la desactivación. La preferencia anterior podría recuperarse al reiniciar: \(error.localizedDescription)" }
        }
        didChange?()
    }
    public func retry(_ id: QuickUtilityID) async {
        guard !shuttingDown, !stoppingAll, !resetting, preferences.enabled.contains(id) else { return }
        await reconcile(id)
    }
    private func persist(_ value: QuickUtilitiesPreferences) throws {
        guard let settings else { throw QuickUtilityError.failure("El almacenamiento local no está disponible.") }
        try value.validate(); try settings.set(value, forKey: Self.settingsKey)
    }
    private func reconcile(_ id: QuickUtilityID) async {
        guard !busy.contains(id), let service = services[id] else { return }
        busy.insert(id); didChange?()
        defer { busy.remove(id); didChange?() }
        let enabled = preferences.enabled.contains(id) && !shuttingDown
        let task = Task { @MainActor in
            do {
                if enabled { if service.state != .active { try await service.start() } }
                else { try await service.stop() }
                self.operationErrors[id] = nil
            } catch { self.operationErrors[id] = error.localizedDescription }
        }
        inFlight[id] = task
        await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
        inFlight[id] = nil
    }
    public func stopAll() async {
        if let resetTask { _ = await resetTask.value; return }
        if let stopAllTask { await stopAllTask.value; return }
        guard !shuttingDown else { return }
        await beginOrJoinStopAll()
    }
    private func beginOrJoinStopAll() async {
        if let stopAllTask { await stopAllTask.value; return }
        stoppingAll = true
        let task = Task { @MainActor in await self.performStopAll() }
        stopAllTask = task
        await task.value
        stopAllTask = nil; stoppingAll = false
    }
    private func performStopAll() async {
        let pending = Array(inFlight.values)
        pending.forEach { $0.cancel() }
        for task in pending { await task.value }
        while !busy.isEmpty { await Task.yield() }
        // An already requested stop/reset must finish its persisted deactivation
        // even if shutdown begins while native cleanup is suspended.
        for id in QuickUtilityID.allCases { await updatePreference(false, for: id) }
    }
    public func shutdown() async {
        guard !shuttingDown else { return }
        shuttingDown = true
        if let resetTask { _ = await resetTask.value }
        if let stopAllTask { await stopAllTask.value }
        let pending = Array(inFlight.values)
        pending.forEach { $0.cancel() }
        for task in pending { await task.value }
        for id in QuickUtilityID.allCases {
            guard let service = services[id] else { continue }
            do { try await service.stop(); operationErrors[id] = nil } catch { operationErrors[id] = error.localizedDescription }
        }
        didChange?()
    }
    public func restoreDefaults() async -> [String] {
        if let resetTask { return await resetTask.value }
        guard !shuttingDown else { return ["ZEUVE se está cerrando; no se han restaurado las preferencias."] }
        resetting = true
        let task = Task { @MainActor in await self.performRestoreDefaults() }
        resetTask = task
        let failures = await task.value
        resetTask = nil; resetting = false
        return failures
    }
    private func performRestoreDefaults() async -> [String] {
        await beginOrJoinStopAll()
        var failures = operationErrors.map { "\(QuickUtilitiesCatalog.descriptor(for: $0.key).name): \($0.value)" }
        for service in services.values {
            do { try await service.restoreDefaultSettings() }
            catch { failures.append("\(QuickUtilitiesCatalog.descriptor(for: service.id).name): \(error.localizedDescription)") }
        }
        if let storageError { failures.append(storageError) }
        didChange?(); return failures
    }
}
