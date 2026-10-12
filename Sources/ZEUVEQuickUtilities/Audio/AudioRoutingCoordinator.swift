import Foundation
#if SWIFT_PACKAGE
import ZEUVEStorage
#endif

public enum AudioRouteOwner: Hashable, Sendable { case mixer, callDiagnostic }
public enum AudioRouteLeaseError: LocalizedError, Equatable, Sendable {
    case conflictingGain, busy
    public var errorDescription: String? {
        switch self {
        case .conflictingGain: "La fuente ya está controlada por otra utilidad de audio con un volumen distinto. Detén esa ruta antes de probar; su volumen no se ha cambiado."
        case .busy: "La ruta de esta fuente está cambiando. Espera a que termine antes de volver a intentarlo."
        }
    }
}

@MainActor public final class AudioRoutingCoordinator {
    public static let settingsKey = "quickUtilities.audioMixer.v1"
    public private(set) var sources: [AudioApplicationSource] = []
    public private(set) var preferences = AudioMixerPreferences()
    public private(set) var routedSourceIDs: Set<String> = []
    public var didChange: (@MainActor () -> Void)?
    public var didFail: (@MainActor (QuickUtilityError) -> Void)?
    private let settings: SettingsRepository
    private let backend: any AudioRouteBackend
    private var running = false
    private var refreshing = false
    private var refreshPending = false
    private var generation: UInt64 = 0
    private var ownerGeneration: [AudioRouteOwner: UInt64] = [:]
    private var reservations: Set<String> = []
    private var openingTask: Task<Void, any Error>?
    private var acquiringOwners: Set<AudioRouteOwner> = []
    private var refreshTask: Task<Void, Never>?
    private var pendingFailure: String?
    private var clients: Set<AudioRouteOwner> = []
    private var leases: [String: [AudioRouteOwner: Float]] = [:]
    private var changed: [AudioRouteOwner: @MainActor () -> Void] = [:]
    private var failed: [AudioRouteOwner: @MainActor (QuickUtilityError) -> Void] = [:]

    public init(settings: SettingsRepository, backend: (any AudioRouteBackend)? = nil) {
        self.settings = settings; self.backend = backend ?? CoreAudioRoutingBackend()
    }
    public func observe(owner: AudioRouteOwner, changed: @escaping @MainActor () -> Void, failed: @escaping @MainActor (QuickUtilityError) -> Void) {
        self.changed[owner] = changed; self.failed[owner] = failed
    }
    public func isAcquired(_ owner: AudioRouteOwner) -> Bool { running && clients.contains(owner) }
    public func routedSources(for owner: AudioRouteOwner) -> Set<String> {
        Set(leases.compactMap { $0.value[owner] == nil ? nil : $0.key })
    }
    public func diagnosticAvailabilityReason(sourceID: String) -> String? {
        guard sources.contains(where: { $0.id == sourceID && $0.supportsRouting }) else { return "La fuente no ofrece una salida segura compatible." }
        if leases[sourceID]?.contains(where: { $0.key != .callDiagnostic && $0.value != 1 }) == true { return AudioRouteLeaseError.conflictingGain.errorDescription }
        return nil
    }
    public func start() async throws { try await acquire(.mixer) }
    public func stop() async throws { try await release(.mixer) }
    public func acquire(_ owner: AudioRouteOwner) async throws {
        try Task.checkCancellation()
        if running { clients.insert(owner); notifyChange(); return }
        let version = generation, ownerVersion = ownerGeneration[owner, default: 0]
        acquiringOwners.insert(owner); defer { acquiringOwners.remove(owner) }
        let task: Task<Void, any Error>
        if let openingTask { task = openingTask }
        else {
            task = Task { @MainActor in try await self.openRuntime() }
            openingTask = task
        }
        do {
            try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
            openingTask = nil
            try Task.checkCancellation()
            guard generation == version, ownerGeneration[owner, default: 0] == ownerVersion, running else { throw CancellationError() }
            clients.insert(owner); notifyChange()
        } catch {
            openingTask = nil
            if clients.isEmpty && acquiringOwners.subtracting([owner]).isEmpty {
                do { try await closeRuntime() } catch { throw Self.problem(error) }
            }
            throw error
        }
    }
    private func openRuntime() async throws {
        do {
            try Task.checkCancellation(); try await backend.stopAll()
            preferences = try settings.value(forKey: Self.settingsKey, as: AudioMixerPreferences.self) ?? AudioMixerPreferences()
            try preferences.validate()
            sources = try await backend.discoverSources(); try Task.checkCancellation()
            try await backend.observeChanges { [weak self] failure in self?.recordNativeChange(failure) }
            try Task.checkCancellation(); running = true
        } catch {
            let original = Self.problem(error)
            var cleanupFailed = false
            do { try await backend.observeChanges(nil) } catch { cleanupFailed = true }
            do { try await backend.stopAll() } catch { cleanupFailed = true }
            if cleanupFailed { throw QuickUtilityError.failure("No se pudo verificar la retirada completa del audio. Vuelve a detener las utilidades de audio.") }
            throw original
        }
    }
    private func recordNativeChange(_ failure: String?) {
        guard running else { return }
        if let failure { pendingFailure = failure }
        refreshPending = true
        guard refreshTask == nil else { return }
        refreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.refreshTask = nil }
            do {
                while self.running && self.refreshPending {
                    try Task.checkCancellation()
                    if let failure = self.pendingFailure { self.pendingFailure = nil; throw QuickUtilityError.failure(failure) }
                    try await self.refresh()
                }
            } catch is CancellationError { return }
            catch {
                let affected = self.clients, problem = Self.problem(error)
                do { try await self.closeRuntime() }
                catch { self.notifyFailure(Self.problem(error), owners: affected); return }
                self.notifyFailure(problem, owners: affected)
            }
        }
    }
    private func joinRefreshTask() async {
        let pending = refreshTask; pending?.cancel()
        if let pending { await pending.value }
        refreshTask = nil; pendingFailure = nil; refreshPending = false
    }
    public func release(_ owner: AudioRouteOwner) async throws {
        ownerGeneration[owner, default: 0] &+= 1
        var first: Error?
        for id in Array(routedSources(for: owner)) {
            do { try await removeLease(sourceID: id, owner: owner) } catch { if first == nil { first = error } }
        }
        if let first { throw Self.problem(first) }
        clients.remove(owner)
        if clients.isEmpty && acquiringOwners.subtracting([owner]).isEmpty {
            running = false
            let pending = openingTask; pending?.cancel()
            if let pending { _ = await pending.result }
            openingTask = nil
            await joinRefreshTask()
            try await closeRuntime()
        }
        notifyChange()
    }
    /// Explicit global stop for shutdown/reset or an invalid shared physical route.
    public func stopAll() async throws {
        running = false; generation &+= 1
        let pending = openingTask; pending?.cancel()
        if let pending { _ = await pending.result }
        openingTask = nil
        await joinRefreshTask()
        try await closeRuntime()
    }
    private func closeRuntime() async throws {
        running = false; generation &+= 1
        var first: Error?
        do { try await backend.observeChanges(nil) } catch { first = error }
        do { try await backend.stopAll() } catch { if first == nil { first = error } }
        if let first { throw Self.problem(first) }
        clients.removeAll(); leases.removeAll(); routedSourceIDs.removeAll(); sources.removeAll(); notifyChange()
    }
    public func setLevel(sourceID: String, level: AudioApplicationLevel) async throws {
        guard running, clients.contains(.mixer), let source = sources.first(where: { $0.id == sourceID }), source.supportsRouting else {
            throw QuickUtilityError.unavailable("Esta fuente de audio no se puede controlar.")
        }
        try Task.checkCancellation(); try level.validate()
        // Validate leases before changing persisted preferences or touching another utility's route.
        if let others = leases[sourceID]?.filter({ $0.key != .mixer }), others.values.contains(where: { $0 != level.effectiveGain }) {
            throw AudioRouteLeaseError.conflictingGain
        }
        guard !reservations.contains(sourceID) else { throw AudioRouteLeaseError.busy }
        reservations.insert(sourceID); defer { reservations.remove(sourceID) }
        var updated = preferences; updated.levels[sourceID] = level; try updated.validate()
        try settings.set(updated, forKey: Self.settingsKey)
        do {
            if level.gain == 1 && !level.muted { try await removeLease(sourceID: sourceID, owner: .mixer) }
            else { try await applyLease(source: source, owner: .mixer, gain: level.effectiveGain) }
            preferences = updated; notifyChange()
        } catch {
            do { try await removeLease(sourceID: sourceID, owner: .mixer) } catch { throw Self.problem(error) }
            throw error
        }
    }
    /// A unity-gain route intentionally forces replay. It never writes mixer preferences.
    public func beginCallDiagnostic(sourceIDs: Set<String>) async throws {
        guard !sourceIDs.isEmpty, sourceIDs.count <= 8 else { throw QuickUtilityError.failure("Elige entre una y ocho fuentes de música o vídeo para la prueba.") }
        try await acquire(.callDiagnostic)
        do {
            let selected = try sourceIDs.sorted().map { id -> AudioApplicationSource in
                guard let source = sources.first(where: { $0.id == id && $0.supportsRouting }) else { throw QuickUtilityError.unavailable("La fuente seleccionada ya no ofrece una salida segura compatible.") }
                if leases[id]?.contains(where: { $0.key != .callDiagnostic && $0.value != 1 }) == true { throw AudioRouteLeaseError.conflictingGain }
                return source
            }
            guard selected.allSatisfy({ !reservations.contains($0.id) }) else { throw AudioRouteLeaseError.busy }
            for source in selected { reservations.insert(source.id) }
            defer { for source in selected { reservations.remove(source.id) } }
            for source in selected {
                try Task.checkCancellation()
                try await applyLease(source: source, owner: .callDiagnostic, gain: 1)
                try await backend.setMeteringEnabled(sourceID: source.id, enabled: true)
            }
            try Task.checkCancellation(); notifyChange()
        } catch {
            do { try await release(.callDiagnostic) } catch { throw Self.problem(error) }
            throw error
        }
    }
    public func diagnosticMeters() async throws -> [AudioRouteMeter] {
        let ids = routedSources(for: .callDiagnostic)
        guard !ids.isEmpty else { return [] }
        return try await backend.readMeters().filter { ids.contains($0.id) }
    }
    public func restoreDefaults() async throws {
        try await release(.mixer)
        try settings.removeValue(forKey: Self.settingsKey)
        preferences = AudioMixerPreferences(); notifyChange()
    }
    private func applyLease(source: AudioApplicationSource, owner: AudioRouteOwner, gain: Float) async throws {
        guard running, clients.contains(owner) else { throw CancellationError() }
        let version = generation, ownerVersion = ownerGeneration[owner, default: 0]
        let previous = leases[source.id] ?? [:]
        guard !previous.contains(where: { $0.key != owner && $0.value != gain }) else { throw AudioRouteLeaseError.conflictingGain }
        if previous.isEmpty {
            do { try await backend.startRoute(source: source, gain: gain) }
            catch {
                let original = error
                do { try await backend.stopRoute(sourceID: source.id) }
                catch {
                    // Retain ownership of a partial native allocation so stop can retry safely.
                    leases[source.id] = [owner: gain]; routedSourceIDs.insert(source.id); notifyChange()
                    throw QuickUtilityError.failure("No se pudo verificar la retirada de la ruta de audio. Detén su utilidad para volver a intentarlo.")
                }
                throw original
            }
        }
        else if previous[owner] != gain && previous.count == 1 { try await backend.setGain(sourceID: source.id, gain: gain) }
        do {
            try Task.checkCancellation()
            guard running, clients.contains(owner), generation == version, ownerGeneration[owner, default: 0] == ownerVersion else { throw CancellationError() }
            leases[source.id, default: [:]][owner] = gain; routedSourceIDs.insert(source.id)
        } catch {
            if previous.isEmpty { try await backend.stopRoute(sourceID: source.id) }
            throw error
        }
    }
    private func removeLease(sourceID: String, owner: AudioRouteOwner) async throws {
        guard var current = leases[sourceID], current[owner] != nil else { return }
        current.removeValue(forKey: owner)
        if current.isEmpty {
            try await backend.stopRoute(sourceID: sourceID)
            leases.removeValue(forKey: sourceID); routedSourceIDs.remove(sourceID)
        } else {
            if owner == .callDiagnostic { try await backend.setMeteringEnabled(sourceID: sourceID, enabled: false) }
            leases[sourceID] = current
        }
        notifyChange()
    }
    private func refresh() async throws {
        guard running else { return }
        if refreshing { refreshPending = true; return }
        refreshing = true; defer { refreshing = false }
        repeat {
            refreshPending = false; generation &+= 1
            try await backend.stopAll(); leases.removeAll(); routedSourceIDs.removeAll()
            guard running else { return }
            sources = try await backend.discoverSources(); notifyChange()
        } while refreshPending && running
        // Device/process changes require explicit selection again; never capture a reused PID.
    }
    private func notifyChange() { didChange?(); for observer in changed.values { observer() } }
    private func notifyFailure(_ problem: QuickUtilityError, owners: Set<AudioRouteOwner>) {
        didFail?(problem); for owner in owners { failed[owner]?(problem) }
    }
    private static func problem(_ error: Error) -> QuickUtilityError {
        error as? QuickUtilityError ?? .failure("No se pudo configurar la ruta de audio: \(error.localizedDescription)")
    }
}

@MainActor public final class ApplicationAudioMixerService: QuickUtilityService {
    public let id: QuickUtilityID = .audioMixer
    public private(set) var state: QuickUtilityState = .disabled { didSet { stateDidChange?(state) } }
    public var stateDidChange: (@MainActor (QuickUtilityState) -> Void)?
    public var contentDidChange: (@MainActor () -> Void)?
    public let routing: AudioRoutingCoordinator
    private var levelTasks: [UUID: Task<Void, any Error>] = [:]
    public init(routing: AudioRoutingCoordinator) {
        self.routing = routing
        routing.observe(owner: .mixer, changed: { [weak self] in
            guard let self else { return }
            if self.state == .active && !self.routing.isAcquired(.mixer) { self.state = .disabled }
            self.contentDidChange?()
        }, failed: { [weak self] in self?.state = $0.state })
    }
    public func start() async throws {
        guard state != .active else { return }; state = .activating
        do { try await routing.start(); state = .active }
        catch { let problem = error as? QuickUtilityError ?? .failure(error.localizedDescription); state = problem.state; throw problem }
    }
    public func stop() async throws {
        guard state != .disabled else { return }; state = .deactivating
        let pending = Array(levelTasks.values); pending.forEach { $0.cancel() }
        for task in pending { _ = await task.result }
        do { try await routing.stop(); state = .disabled }
        catch { state = .failed(error.localizedDescription); throw error }
    }
    public func setLevel(sourceID: String, level: AudioApplicationLevel) async throws {
        let id = UUID()
        let task = Task { @MainActor in try await routing.setLevel(sourceID: sourceID, level: level) }
        levelTasks[id] = task; defer { levelTasks[id] = nil }
        do { try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() } }
        catch let conflict as AudioRouteLeaseError { throw conflict }
        catch {
            let problem = error as? QuickUtilityError ?? .failure(error.localizedDescription)
            do { try await routing.stop() } catch { state = .failed(error.localizedDescription); throw error }
            state = problem.state; throw problem
        }
    }
    public func restoreDefaultSettings() async throws {
        do { try await stop(); try await routing.restoreDefaults(); state = .disabled }
        catch { state = .failed(error.localizedDescription); throw error }
    }
}

public enum CallAudioDiagnosticState: Equatable, Sendable {
    case idle, preparing, ready, starting, running, stopping
    case failed(String)
    public var title: String {
        switch self {
        case .idle: "Prueba detenida"
        case .preparing: "Buscando fuentes…"
        case .ready: "Fuentes disponibles; prueba detenida"
        case .starting: "Preparando ruta de prueba…"
        case .running: "Ruta de prueba en ejecución; eficacia no validada"
        case .stopping: "Retirando ruta de prueba…"
        case .failed(let reason): "Error de la prueba: \(reason)"
        }
    }
    public var isTransitioning: Bool { self == .preparing || self == .starting || self == .stopping }
}

@MainActor public final class CallAudioProtectionService: QuickUtilityService {
    public static let limitation = "Pendiente de diagnóstico real de FaceTime con altavoces. Las APIs públicas no garantizan evitar su atenuación; no se ha validado una ruta eficaz."
    public let id: QuickUtilityID = .audioProtection
    public private(set) var state: QuickUtilityState = .unavailable(CallAudioProtectionService.limitation) { didSet { stateDidChange?(state) } }
    public var stateDidChange: (@MainActor (QuickUtilityState) -> Void)?
    public var contentDidChange: (@MainActor () -> Void)?
    /// Lifecycle callback belongs to the resident runtime; settings UI uses contentDidChange.
    public var diagnosticDidChange: (@MainActor () -> Void)?
    public private(set) var diagnosticState: CallAudioDiagnosticState = .idle {
        didSet { contentDidChange?(); diagnosticDidChange?() }
    }
    public private(set) var meters: [AudioRouteMeter] = []
    public let routing: AudioRoutingCoordinator
    private var operation: Task<Void, any Error>?
    public var isDiagnosticRunning: Bool { !routing.routedSources(for: .callDiagnostic).isEmpty }
    public var diagnosticSources: [AudioApplicationSource] { routing.sources.filter(\.supportsRouting) }
    public init(routing: AudioRoutingCoordinator) {
        self.routing = routing
        routing.observe(owner: .callDiagnostic, changed: { [weak self] in
            guard let self else { return }
            if self.diagnosticState == .running && !self.isDiagnosticRunning {
                self.diagnosticState = self.routing.isAcquired(.callDiagnostic) ? .ready : .idle; self.meters.removeAll()
            }
            self.contentDidChange?(); self.diagnosticDidChange?()
        }, failed: { [weak self] problem in self?.diagnosticState = .failed(problem.localizedDescription) })
    }
    public func start() async throws {
        state = .unavailable(Self.limitation); throw QuickUtilityError.unavailable(Self.limitation)
    }
    public func prepareDiagnostic() async throws {
        guard operation == nil, !isDiagnosticRunning else { return }
        diagnosticState = .preparing
        let task = Task { @MainActor in try await routing.acquire(.callDiagnostic); try Task.checkCancellation() }
        operation = task; defer { operation = nil }
        do {
            try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
            diagnosticState = .ready
        } catch {
            do { try await routing.release(.callDiagnostic) } catch { diagnosticState = .failed(error.localizedDescription); throw error }
            diagnosticState = .failed(error.localizedDescription); throw error
        }
    }
    public func beginDiagnostic(sourceIDs: Set<String>) async throws {
        guard operation == nil, !isDiagnosticRunning else { throw QuickUtilityError.failure("Detén la prueba actual antes de comenzar otra.") }
        diagnosticState = .starting; meters.removeAll()
        let task = Task { @MainActor in try await routing.beginCallDiagnostic(sourceIDs: sourceIDs); try Task.checkCancellation() }
        operation = task; defer { operation = nil }
        do {
            try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
            diagnosticState = .running
        } catch {
            do { try await routing.release(.callDiagnostic) } catch { diagnosticState = .failed(error.localizedDescription); throw error }
            diagnosticState = .failed(error.localizedDescription); throw error
        }
    }
    public func refreshDiagnosticMeters() async throws {
        guard isDiagnosticRunning else { meters.removeAll(); return }
        do { meters = try await routing.diagnosticMeters(); contentDidChange?() }
        catch {
            let original = error
            try await stopDiagnostic()
            diagnosticState = .failed(original.localizedDescription); throw original
        }
    }
    public func stopDiagnostic() async throws {
        diagnosticState = .stopping
        operation?.cancel(); if let operation { _ = await operation.result }
        do { try await routing.release(.callDiagnostic); meters.removeAll(); diagnosticState = .idle }
        catch { diagnosticState = .failed(error.localizedDescription); throw error }
    }
    public func stop() async throws {
        try await stopDiagnostic(); state = .unavailable(Self.limitation)
    }
    public func restoreDefaultSettings() async throws { try await stop() }
}
