import XCTest
import ZEUVEStorage
@testable import ZEUVEQuickUtilities

@MainActor final class CallAudioDiagnosticTests: XCTestCase {
    let music = AudioApplicationSource(id: "com.example.music", name: "Música", processIDs: [42])
    let video = AudioApplicationSource(id: "com.example.video", name: "Vídeo", processIDs: [43])
    private func store() throws -> SettingsRepository {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("zeuve-audio-diagnostic-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return try SettingsRepository(database: SQLiteDatabase(url: directory.appendingPathComponent("settings.sqlite")))
    }
    func testDiagnosticForcesUnityReplayWithoutPersistingOrDeclaringProtection() async throws {
        let settings = try store(), backend = DiagnosticAudioBackend(sources: [music])
        let routing = AudioRoutingCoordinator(settings: settings, backend: backend)
        let service = CallAudioProtectionService(routing: routing)
        try await service.prepareDiagnostic()
        let initial = await backend.gains; XCTAssertTrue(initial.isEmpty)
        try await service.beginDiagnostic(sourceIDs: [music.id])
        let gains = await backend.gains
        XCTAssertEqual(gains[music.id], 1); XCTAssertEqual(service.diagnosticState, .running)
        XCTAssertEqual(service.state, .unavailable(CallAudioProtectionService.limitation))
        XCTAssertNil(try settings.value(forKey: AudioRoutingCoordinator.settingsKey, as: AudioMixerPreferences.self))
        try await service.stopDiagnostic()
        XCTAssertFalse(service.isDiagnosticRunning); XCTAssertEqual(service.diagnosticState, .idle)
        let stopped = await backend.gains; XCTAssertTrue(stopped.isEmpty)
    }
    func testStoppingMixerKeepsUnityDiagnosticRouteAndItsMeters() async throws {
        let backend = DiagnosticAudioBackend(sources: [music, video])
        let routing = AudioRoutingCoordinator(settings: try store(), backend: backend)
        let mixer = ApplicationAudioMixerService(routing: routing), diagnostic = CallAudioProtectionService(routing: routing)
        try await mixer.start(); try await mixer.setLevel(sourceID: music.id, level: .init(gain: 0.3))
        try await diagnostic.beginDiagnostic(sourceIDs: [video.id])
        try await mixer.stop()
        let gains = await backend.gains
        XCTAssertNil(gains[music.id]); XCTAssertEqual(gains[video.id], 1)
        XCTAssertTrue(diagnostic.isDiagnosticRunning); XCTAssertEqual(mixer.state, .disabled)
        try await diagnostic.refreshDiagnosticMeters()
        XCTAssertEqual(diagnostic.meters.first?.id, video.id)
        try await diagnostic.stop()
    }
    func testStoppingDiagnosticKeepsMixerGainAndSourceOwnership() async throws {
        let backend = DiagnosticAudioBackend(sources: [music, video])
        let routing = AudioRoutingCoordinator(settings: try store(), backend: backend)
        let mixer = ApplicationAudioMixerService(routing: routing), diagnostic = CallAudioProtectionService(routing: routing)
        try await mixer.start(); try await mixer.setLevel(sourceID: music.id, level: .init(gain: 0.4))
        try await diagnostic.beginDiagnostic(sourceIDs: [video.id]); try await diagnostic.stop()
        let gains = await backend.gains
        XCTAssertEqual(gains[music.id], 0.4); XCTAssertNil(gains[video.id])
        XCTAssertEqual(mixer.state, .active); XCTAssertEqual(routing.routedSources(for: .mixer), [music.id])
        try await mixer.stop()
    }
    func testDiagnosticConflictLeavesMixerGainAndPreferencesUntouched() async throws {
        let settings = try store(), backend = DiagnosticAudioBackend(sources: [music])
        let routing = AudioRoutingCoordinator(settings: settings, backend: backend)
        let mixer = ApplicationAudioMixerService(routing: routing), diagnostic = CallAudioProtectionService(routing: routing)
        try await mixer.start(); try await mixer.setLevel(sourceID: music.id, level: .init(gain: 0.4))
        do { try await diagnostic.beginDiagnostic(sourceIDs: [music.id]); XCTFail("Se sustituyó el volumen del mezclador") }
        catch { XCTAssertEqual(error as? AudioRouteLeaseError, .conflictingGain) }
        let gains = await backend.gains; XCTAssertEqual(gains[music.id], 0.4)
        XCTAssertEqual(try settings.value(forKey: AudioRoutingCoordinator.settingsKey, as: AudioMixerPreferences.self)?.levels[music.id]?.gain, 0.4)
        XCTAssertEqual(mixer.state, .active); XCTAssertFalse(diagnostic.isDiagnosticRunning)
        try await mixer.stop()
    }
    func testMixerConflictLeavesDiagnosticReplayAndConfigurationUntouched() async throws {
        let settings = try store(), backend = DiagnosticAudioBackend(sources: [music])
        let routing = AudioRoutingCoordinator(settings: settings, backend: backend)
        let mixer = ApplicationAudioMixerService(routing: routing), diagnostic = CallAudioProtectionService(routing: routing)
        try await diagnostic.beginDiagnostic(sourceIDs: [music.id]); try await mixer.start()
        do { try await mixer.setLevel(sourceID: music.id, level: .init(gain: 0.4)); XCTFail("Se cambió la ganancia de la prueba") }
        catch { XCTAssertEqual(error as? AudioRouteLeaseError, .conflictingGain) }
        let gains = await backend.gains; XCTAssertEqual(gains[music.id], 1)
        XCTAssertEqual(mixer.state, .active); XCTAssertTrue(diagnostic.isDiagnosticRunning)
        XCTAssertNil(try settings.value(forKey: AudioRoutingCoordinator.settingsKey, as: AudioMixerPreferences.self))
        try await mixer.stop(); XCTAssertTrue(diagnostic.isDiagnosticRunning)
        try await diagnostic.stop()
    }
    func testMixerAtUnityDoesNotRetireAnotherOwnersForcedReplay() async throws {
        let backend = DiagnosticAudioBackend(sources: [music])
        let routing = AudioRoutingCoordinator(settings: try store(), backend: backend)
        let mixer = ApplicationAudioMixerService(routing: routing), diagnostic = CallAudioProtectionService(routing: routing)
        try await mixer.start(); try await diagnostic.beginDiagnostic(sourceIDs: [music.id])
        try await mixer.setLevel(sourceID: music.id, level: .init())
        let gains = await backend.gains; XCTAssertEqual(gains[music.id], 1)
        XCTAssertEqual(routing.routedSources(for: .callDiagnostic), [music.id])
        try await diagnostic.stop(); try await mixer.stop()
    }
    func testGlobalStopRetiresBothOwnersAndAllMetrics() async throws {
        let backend = DiagnosticAudioBackend(sources: [music, video])
        let routing = AudioRoutingCoordinator(settings: try store(), backend: backend)
        let mixer = ApplicationAudioMixerService(routing: routing), diagnostic = CallAudioProtectionService(routing: routing)
        try await mixer.start(); try await mixer.setLevel(sourceID: music.id, level: .init(gain: 0.4))
        try await diagnostic.beginDiagnostic(sourceIDs: [video.id]); try await routing.stopAll()
        XCTAssertTrue(routing.routedSourceIDs.isEmpty); XCTAssertFalse(diagnostic.isDiagnosticRunning)
        XCTAssertEqual(mixer.state, .disabled)
        let meters = try await routing.diagnosticMeters(); XCTAssertTrue(meters.isEmpty)
    }
    func testDeniedCaptureCleansDiagnosticAndDoesNotTouchMixer() async throws {
        let backend = DiagnosticAudioBackend(sources: [music, video])
        let routing = AudioRoutingCoordinator(settings: try store(), backend: backend)
        let mixer = ApplicationAudioMixerService(routing: routing), diagnostic = CallAudioProtectionService(routing: routing)
        try await mixer.start(); try await mixer.setLevel(sourceID: music.id, level: .init(gain: 0.4))
        await backend.setFailure(sourceID: video.id)
        do { try await diagnostic.beginDiagnostic(sourceIDs: [video.id]); XCTFail("Captura denegada aceptada") } catch {}
        let gains = await backend.gains; XCTAssertEqual(gains[music.id], 0.4); XCTAssertNil(gains[video.id])
        XCTAssertFalse(diagnostic.isDiagnosticRunning)
        XCTAssertEqual(diagnostic.state, .unavailable(CallAudioProtectionService.limitation))
        try await mixer.stop()
    }
    func testCancelledDiagnosticDoesNotLeaveReplayOrListeners() async throws {
        let backend = DiagnosticAudioBackend(sources: [music])
        let routing = AudioRoutingCoordinator(settings: try store(), backend: backend)
        let diagnostic = CallAudioProtectionService(routing: routing)
        let task = Task { @MainActor in try await diagnostic.beginDiagnostic(sourceIDs: [music.id]) }
        task.cancel(); do { try await task.value; XCTFail("Prueba cancelada iniciada") } catch {}
        try await diagnostic.stop()
        let gains = await backend.gains, observing = await backend.isObserving
        XCTAssertTrue(gains.isEmpty); XCTAssertFalse(observing); XCTAssertFalse(diagnostic.isDiagnosticRunning)
    }
    func testUnsafeCallSourceIsNeverRoutedByDiagnostic() async throws {
        let call = AudioApplicationSource(id: "com.apple.FaceTime", name: "FaceTime", processIDs: [44], supportsRouting: false, limitation: "Llamada")
        let backend = DiagnosticAudioBackend(sources: [call])
        let routing = AudioRoutingCoordinator(settings: try store(), backend: backend)
        let diagnostic = CallAudioProtectionService(routing: routing)
        do { try await diagnostic.beginDiagnostic(sourceIDs: [call.id]); XCTFail("Se capturó la conversación") } catch {}
        let gains = await backend.gains; XCTAssertTrue(gains.isEmpty)
        try await diagnostic.stop()
    }
    func testDiagnosticCleanupFailureIsVisibleAndDoesNotRetireMixerRoute() async throws {
        let backend = DiagnosticAudioBackend(sources: [music, video])
        let routing = AudioRoutingCoordinator(settings: try store(), backend: backend)
        let mixer = ApplicationAudioMixerService(routing: routing), diagnostic = CallAudioProtectionService(routing: routing)
        try await mixer.start(); try await mixer.setLevel(sourceID: music.id, level: .init(gain: 0.4))
        try await diagnostic.beginDiagnostic(sourceIDs: [video.id])
        await backend.setStopFailure(sourceID: video.id)
        do { try await diagnostic.stop(); XCTFail("Se declaró limpieza no realizada") } catch {}
        guard case .failed = diagnostic.diagnosticState else { return XCTFail("Fallo de limpieza oculto") }
        XCTAssertTrue(diagnostic.isDiagnosticRunning)
        let gains = await backend.gains; XCTAssertEqual(gains[music.id], 0.4); XCTAssertEqual(gains[video.id], 1)
        await backend.setStopFailure(sourceID: nil); try await diagnostic.stop()
        XCTAssertFalse(diagnostic.isDiagnosticRunning); try await mixer.stop()
    }
    func testGlobalStopJoinsPendingRefreshBeforeReturning() async throws {
        let backend = DiagnosticAudioBackend(sources: [music])
        let routing = AudioRoutingCoordinator(settings: try store(), backend: backend)
        try await routing.start(); await backend.pauseDiscovery(); await backend.emitChange()
        for _ in 0..<100 {
            if await backend.discoveries > 1 { break }
            try await Task.sleep(for: .milliseconds(2))
        }
        try await routing.stopAll()
        await backend.resumeDiscovery(); await Task.yield()
        XCTAssertTrue(routing.sources.isEmpty); XCTAssertTrue(routing.routedSourceIDs.isEmpty)
        let observing = await backend.isObserving; XCTAssertFalse(observing)
    }
    func testRMSUsesBothStereoChannelsWithoutPersistingSamples() {
        let input: [Float] = [1, -1, 1, -1], output: [Float] = [0.5, -0.5, 0.5, -0.5]
        let rms = input.withUnsafeBufferPointer { input in output.withUnsafeBufferPointer { output in
            AudioGainProcessor.measureStereo(inputLeft: input.baseAddress!, inputRight: input.baseAddress!.advanced(by: 1), inputStride: 2, outputLeft: output.baseAddress!, outputRight: output.baseAddress!.advanced(by: 1), outputStride: 2, frames: 2)
        } }
        XCTAssertEqual(rms.input, 1); XCTAssertEqual(rms.output, 0.5)
        XCTAssertEqual(AudioRouteMeter.decibels(rms.output)!, -6.020599913, accuracy: 0.000001)
        XCTAssertNil(AudioRouteMeter.decibels(0)); XCTAssertNil(AudioRouteMeter.decibels(.nan))
        XCTAssertEqual(input, [1, -1, 1, -1]); XCTAssertEqual(output, [0.5, -0.5, 0.5, -0.5])
    }
}

private actor DiagnosticAudioBackend: AudioRouteBackend {
    let sources: [AudioApplicationSource]
    var gains: [String: Float] = [:]
    var metered: Set<String> = []
    var failedSource: String?
    var failedStopSource: String?
    var isObserving = false
    var discoveries = 0
    var paused = false
    var handler: (@MainActor @Sendable (String?) -> Void)?
    init(sources: [AudioApplicationSource]) { self.sources = sources }
    func setFailure(sourceID: String) { failedSource = sourceID }
    func setStopFailure(sourceID: String?) { failedStopSource = sourceID }
    func pauseDiscovery() { paused = true }
    func resumeDiscovery() { paused = false }
    func emitChange() async { await handler?(nil) }
    func discoverSources() async throws -> [AudioApplicationSource] {
        discoveries += 1
        while paused { try await Task.sleep(for: .milliseconds(2)) }
        return sources
    }
    func startRoute(source: AudioApplicationSource, gain: Float) async throws {
        if source.id == failedSource { throw QuickUtilityError.requiresPermission(.audioCapture) }
        gains[source.id] = gain
    }
    func setGain(sourceID: String, gain: Float) async throws { gains[sourceID] = gain }
    func stopRoute(sourceID: String) async throws {
        if sourceID == failedStopSource { throw QuickUtilityError.failure("No se pudo verificar la limpieza") }
        gains.removeValue(forKey: sourceID); metered.remove(sourceID)
    }
    func stopAll() async throws { gains.removeAll(); metered.removeAll() }
    func observeChanges(_ handler: (@MainActor @Sendable (String?) -> Void)?) async throws { isObserving = handler != nil; self.handler = handler }
    func setMeteringEnabled(sourceID: String, enabled: Bool) async throws {
        if enabled { metered.insert(sourceID) } else { metered.remove(sourceID) }
    }
    func readMeters() async throws -> [AudioRouteMeter] { metered.map { .init(id: $0, inputRMS: 0.5, outputRMS: 0.5, callbackCount: 1) } }
}
