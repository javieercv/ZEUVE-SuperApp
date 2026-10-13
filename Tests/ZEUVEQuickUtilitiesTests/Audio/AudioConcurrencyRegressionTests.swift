import XCTest
import ZEUVEStorage
@testable import ZEUVEQuickUtilities

@MainActor final class AudioConcurrencyRegressionTests: XCTestCase {
    private let music = AudioApplicationSource(id: "com.example.music", name: "Música", processIDs: [42])
    private func store() throws -> SettingsRepository {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("zeuve-audio-concurrency-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return try SettingsRepository(database: SQLiteDatabase(url: directory.appendingPathComponent("settings.sqlite")))
    }
    private func waitUntil(_ condition: @escaping @MainActor () async -> Bool) async throws {
        for _ in 0..<200 {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(2))
        }
        XCTFail("La operación controlada no alcanzó su punto de espera")
    }
    func testCancellingOneOpeningWaiterDoesNotCancelAnotherOwner() async throws {
        let backend = GatedAudioBackend(sources: [music])
        await backend.pauseDiscovery()
        let routing = AudioRoutingCoordinator(settings: try store(), backend: backend)
        let first = Task { @MainActor in try await routing.acquire(.mixer) }
        try await waitUntil { await backend.discoveryCalls == 1 }
        var secondEntered = false
        let second = Task { @MainActor in
            secondEntered = true
            try await routing.acquire(.callDiagnostic)
        }
        try await waitUntil { secondEntered }
        first.cancel(); await backend.resumeDiscovery()
        do { try await first.value; XCTFail("Se aceptó al propietario cancelado") } catch {}
        try await second.value
        XCTAssertFalse(routing.isAcquired(.mixer)); XCTAssertTrue(routing.isAcquired(.callDiagnostic))
        let discoveries = await backend.discoveryCalls
        XCTAssertEqual(discoveries, 1, "La apertura compartida no debía cancelarse ni repetirse")
        try await routing.stopAll()
    }
    func testCancellingSoleOpeningWaiterRetiresObservers() async throws {
        let backend = GatedAudioBackend(sources: [music])
        await backend.pauseDiscovery()
        let routing = AudioRoutingCoordinator(settings: try store(), backend: backend)
        let opening = Task { @MainActor in try await routing.acquire(.mixer) }
        try await waitUntil { await backend.discoveryCalls == 1 }
        opening.cancel()
        do { try await opening.value; XCTFail("Apertura cancelada aceptada") } catch {}
        XCTAssertFalse(routing.isAcquired(.mixer)); XCTAssertTrue(routing.sources.isEmpty)
        let observing = await backend.isObserving; XCTAssertFalse(observing)
        await backend.resumeDiscovery(); try await routing.stopAll()
    }
    func testGlobalCleanupBlocksNewAcquisitionUntilComplete() async throws {
        let backend = GatedAudioBackend(sources: [music])
        let routing = AudioRoutingCoordinator(settings: try store(), backend: backend)
        try await routing.acquire(.mixer); await backend.pauseObserverRemoval()
        let stopping = Task { @MainActor in try await routing.stopAll() }
        try await waitUntil { await backend.observerRemovals == 1 }
        do { try await routing.acquire(.callDiagnostic); XCTFail("Se abrió durante un cierre anterior") }
        catch { XCTAssertEqual(error as? AudioRouteLeaseError, .busy) }
        await backend.resumeObserverRemoval(); try await stopping.value
        try await routing.acquire(.callDiagnostic)
        XCTAssertTrue(routing.isAcquired(.callDiagnostic)); try await routing.stopAll()
    }
    func testLastOwnerCleanupBlocksDiagnosticReplayUntilComplete() async throws {
        let backend = GatedAudioBackend(sources: [music])
        let routing = AudioRoutingCoordinator(settings: try store(), backend: backend)
        try await routing.acquire(.mixer); await backend.pauseObserverRemoval()
        let stopping = Task { @MainActor in try await routing.release(.mixer) }
        try await waitUntil { await backend.observerRemovals == 1 }
        do { try await routing.beginCallDiagnostic(sourceIDs: [music.id]); XCTFail("Se enrutó durante el cierre del último cliente") }
        catch { XCTAssertEqual(error as? AudioRouteLeaseError, .busy) }
        let during = await backend.gains; XCTAssertTrue(during.isEmpty)
        await backend.resumeObserverRemoval(); try await stopping.value
        try await routing.beginCallDiagnostic(sourceIDs: [music.id])
        let after = await backend.gains; XCTAssertEqual(after[music.id], 1)
        try await routing.stopAll()
    }
    func testNativeFailureCleanupBlocksNewOwnerUntilComplete() async throws {
        let backend = GatedAudioBackend(sources: [music])
        let routing = AudioRoutingCoordinator(settings: try store(), backend: backend)
        try await routing.acquire(.mixer); await backend.pauseObserverRemoval(); await backend.emitFailure()
        try await waitUntil { await backend.observerRemovals == 1 }
        do { try await routing.acquire(.callDiagnostic); XCTFail("Se abrió durante la limpieza de un error") }
        catch { XCTAssertEqual(error as? AudioRouteLeaseError, .busy) }
        await backend.resumeObserverRemoval(); try await routing.stopAll()
        try await routing.acquire(.callDiagnostic)
        XCTAssertTrue(routing.isAcquired(.callDiagnostic)); try await routing.stopAll()
    }
    func testNewOwnerWaitsForCancelledOpeningCleanupAndStartsFreshSession() async throws {
        let backend = GatedAudioBackend(sources: [music])
        let routing = AudioRoutingCoordinator(settings: try store(), backend: backend)
        await backend.pauseDiscovery(); await backend.pauseObserverRemoval()
        let cancelled = Task { @MainActor in try await routing.acquire(.mixer) }
        try await waitUntil { await backend.discoveryCalls == 1 }
        cancelled.cancel()
        try await waitUntil { await backend.observerRemovals == 1 }
        let replacement = Task { @MainActor in try await routing.acquire(.callDiagnostic) }
        await Task.yield(); await backend.resumeObserverRemoval()
        try await waitUntil { await backend.discoveryCalls == 2 }
        await backend.resumeDiscovery()
        do { try await cancelled.value; XCTFail("Se aceptó la apertura cancelada") } catch {}
        try await replacement.value
        XCTAssertTrue(routing.isAcquired(.callDiagnostic)); XCTAssertFalse(routing.isAcquired(.mixer))
        try await routing.stopAll()
    }
    func testCancelledStopCallerStillWaitsForOwnedCleanup() async throws {
        let backend = GatedAudioBackend(sources: [music])
        let routing = AudioRoutingCoordinator(settings: try store(), backend: backend)
        try await routing.acquire(.mixer); await backend.pauseObserverRemoval()
        let stopping = Task { @MainActor in try await routing.stopAll() }
        try await waitUntil { await backend.observerRemovals == 1 }; stopping.cancel()
        do { try await routing.acquire(.callDiagnostic); XCTFail("La cancelación abrió la barrera demasiado pronto") }
        catch { XCTAssertEqual(error as? AudioRouteLeaseError, .busy) }
        await backend.resumeObserverRemoval(); try await stopping.value
        XCTAssertFalse(routing.isAcquired(.mixer)); XCTAssertTrue(routing.routedSourceIDs.isEmpty)
        let observing = await backend.isObserving; XCTAssertFalse(observing)
    }
    func testPendingMeterReadCannotRepopulateMetersAfterStop() async throws {
        let backend = GatedAudioBackend(sources: [music])
        let service = CallAudioProtectionService(routing: AudioRoutingCoordinator(settings: try store(), backend: backend))
        try await service.beginDiagnostic(sourceIDs: [music.id]); await backend.pauseMeters()
        let reading = Task { @MainActor in try await service.refreshDiagnosticMeters() }
        try await waitUntil { await backend.meterCalls == 1 }
        try await service.stopDiagnostic(); await backend.resumeMeters(); try await reading.value
        XCTAssertTrue(service.meters.isEmpty); XCTAssertEqual(service.diagnosticState, .idle)
        XCTAssertFalse(service.isDiagnosticRunning)
    }
    func testMeterSnapshotFromPriorRouteCannotReplaceRestartedSession() async throws {
        let backend = GatedAudioBackend(sources: [music])
        let service = CallAudioProtectionService(routing: AudioRoutingCoordinator(settings: try store(), backend: backend))
        try await service.beginDiagnostic(sourceIDs: [music.id]); await backend.pauseMeters()
        let stale = Task { @MainActor in try await service.refreshDiagnosticMeters() }
        try await waitUntil { await backend.meterCalls == 1 }
        try await service.stopDiagnostic(); try await service.beginDiagnostic(sourceIDs: [music.id])
        await backend.resumeMeters(); try await stale.value
        XCTAssertTrue(service.meters.isEmpty)
        XCTAssertEqual(service.diagnosticState, .running)
        try await service.refreshDiagnosticMeters()
        XCTAssertEqual(service.meters.first?.inputRMS, 0.2)
        try await service.stopDiagnostic()
    }
    func testMeterFailureFromPriorRouteCannotStopReplacementRoute() async throws {
        let backend = GatedAudioBackend(sources: [music])
        let service = CallAudioProtectionService(routing: AudioRoutingCoordinator(settings: try store(), backend: backend))
        try await service.beginDiagnostic(sourceIDs: [music.id]); await backend.pauseMeters(fail: true)
        let stale = Task { @MainActor in try await service.refreshDiagnosticMeters() }
        try await waitUntil { await backend.meterCalls == 1 }
        try await service.stopDiagnostic(); try await service.beginDiagnostic(sourceIDs: [music.id])
        await backend.resumeMeters(); try await stale.value
        XCTAssertTrue(service.isDiagnosticRunning); XCTAssertEqual(service.diagnosticState, .running)
        let gains = await backend.gains; XCTAssertEqual(gains[music.id], 1)
        try await service.stopDiagnostic()
    }
}

private actor GatedAudioBackend: AudioRouteBackend {
    let sources: [AudioApplicationSource]
    var gains: [String: Float] = [:]
    var metered: Set<String> = []
    var generations: [String: UInt32] = [:]
    var isObserving = false
    var discoveryCalls = 0, meterCalls = 0, observerRemovals = 0
    private var removalPaused = false
    private var removalWaiters: [CheckedContinuation<Void, Never>] = []
    private var handler: (@MainActor @Sendable (String?) -> Void)?
    private var discoveryPaused = false, metersPaused = false, failMeterRead = false
    init(sources: [AudioApplicationSource]) { self.sources = sources }
    func pauseObserverRemoval() { removalPaused = true }
    func resumeObserverRemoval() {
        removalPaused = false
        let pending = removalWaiters; removalWaiters.removeAll()
        pending.forEach { $0.resume() }
    }
    func emitFailure() async { await handler?("Error nativo controlado") }
    func pauseDiscovery() { discoveryPaused = true }
    func resumeDiscovery() { discoveryPaused = false }
    func pauseMeters(fail: Bool = false) { metersPaused = true; failMeterRead = fail }
    func resumeMeters() { metersPaused = false; failMeterRead = false }
    func discoverSources() async throws -> [AudioApplicationSource] {
        discoveryCalls += 1
        while discoveryPaused { try await Task.sleep(for: .milliseconds(1)) }
        return sources
    }
    func startRoute(source: AudioApplicationSource, gain: Float) async throws {
        gains[source.id] = gain; generations[source.id, default: 0] += 1
    }
    func setGain(sourceID: String, gain: Float) async throws { gains[sourceID] = gain }
    func stopRoute(sourceID: String) async throws { gains.removeValue(forKey: sourceID); metered.remove(sourceID) }
    func stopAll() async throws { gains.removeAll(); metered.removeAll() }
    func observeChanges(_ handler: (@MainActor @Sendable (String?) -> Void)?) async throws {
        if handler == nil {
            observerRemovals += 1
            if removalPaused { await withCheckedContinuation { removalWaiters.append($0) } }
        }
        self.handler = handler; isObserving = handler != nil
    }
    func setMeteringEnabled(sourceID: String, enabled: Bool) async throws {
        if enabled { metered.insert(sourceID) } else { metered.remove(sourceID) }
    }
    func readMeters() async throws -> [AudioRouteMeter] {
        meterCalls += 1
        let failing = failMeterRead
        let snapshot = metered.map { id in AudioRouteMeter(id: id, inputRMS: Float(generations[id] ?? 0) / 10, outputRMS: Float(generations[id] ?? 0) / 10, callbackCount: 1) }
        while metersPaused { try await Task.sleep(for: .milliseconds(1)) }
        if failing { throw QuickUtilityError.requiresPermission(.audioCapture) }
        return snapshot
    }
}
