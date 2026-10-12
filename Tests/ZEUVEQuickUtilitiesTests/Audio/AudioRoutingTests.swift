import XCTest
import ZEUVEStorage
@testable import ZEUVEQuickUtilities

@MainActor final class AudioRoutingTests: XCTestCase {
    private func store() throws -> SettingsRepository {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("zeuve-audio-tests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return try SettingsRepository(database: SQLiteDatabase(url: directory.appendingPathComponent("test.sqlite")))
    }
    private let music = AudioApplicationSource(id: "com.example.music", name: "Música", processIDs: [42])

    func testGainMuteAndOriginalSamples() throws {
        let samples: [Float] = [-1, -0.5, 0, 0.5, 1]
        XCTAssertEqual(try AudioGainProcessor.apply(samples, level: .init(gain: 0.5)), [-0.5, -0.25, 0, 0.25, 0.5])
        XCTAssertEqual(try AudioGainProcessor.apply(samples, level: .init(gain: 0.8, muted: true)), [0, 0, 0, 0, 0])
        XCTAssertEqual(samples, [-1, -0.5, 0, 0.5, 1])
        XCTAssertEqual(try AudioGainProcessor.apply([], level: .init()), [])
    }
    func testStereoRampKeepsBothChannelsAligned() {
        let input: [Float] = [1, 1, 1, 1, 1, 1, 1, 1]
        var result = [Float](repeating: 0, count: input.count)
        input.withUnsafeBufferPointer { input in result.withUnsafeMutableBufferPointer { output in
            AudioGainProcessor.render(input: input.baseAddress!, output: output.baseAddress!, count: input.count, channels: 2, from: 0, to: 1)
        } }
        XCTAssertEqual(result, [0.25, 0.25, 0.5, 0.5, 0.75, 0.75, 1, 1])
    }
    func testInterleavedToPlanarConversionPreservesChannelIdentity() {
        let input: [Float] = [1, -1, 0.5, -0.5]
        var left = [Float](repeating: 0, count: 2), right = left
        input.withUnsafeBufferPointer { source in
            left.withUnsafeMutableBufferPointer { left in right.withUnsafeMutableBufferPointer { right in
                AudioGainProcessor.renderStereo(inputLeft: source.baseAddress!, inputRight: source.baseAddress!.advanced(by: 1), inputStride: 2, outputLeft: left.baseAddress!, outputRight: right.baseAddress!, outputStride: 1, frames: 2, from: 0.5, to: 0.5)
            } }
        }
        XCTAssertEqual(left, [0.5, 0.25]); XCTAssertEqual(right, [-0.5, -0.25])
    }
    func testPlanarToInterleavedConversionAndMute() {
        let left: [Float] = [1, 0.5], right: [Float] = [-1, -0.5]
        var result = [Float](repeating: 9, count: 4)
        left.withUnsafeBufferPointer { left in right.withUnsafeBufferPointer { right in
            result.withUnsafeMutableBufferPointer { output in
                AudioGainProcessor.renderStereo(inputLeft: left.baseAddress!, inputRight: right.baseAddress!, inputStride: 1, outputLeft: output.baseAddress!, outputRight: output.baseAddress!.advanced(by: 1), outputStride: 2, frames: 2, from: 1, to: 1)
            }
        } }
        XCTAssertEqual(result, [1, -1, 0.5, -0.5])
        result.withUnsafeMutableBufferPointer { output in
            AudioGainProcessor.renderStereo(inputLeft: output.baseAddress!, inputRight: output.baseAddress!.advanced(by: 1), inputStride: 2, outputLeft: output.baseAddress!, outputRight: output.baseAddress!.advanced(by: 1), outputStride: 2, frames: 2, from: 0, to: 0)
        }
        XCTAssertEqual(result, [0, 0, 0, 0])
    }
    func testInvalidGainAndConfigurationFailClosed() throws {
        for gain: Float in [-0.1, 1.01, .nan, .infinity] { XCTAssertThrowsError(try AudioApplicationLevel(gain: gain).validate()) }
        var incompatible = AudioMixerPreferences(); incompatible.schemaVersion = 2
        XCTAssertThrowsError(try incompatible.validate())
        var corrupt = AudioMixerPreferences(); corrupt.levels[""] = .init()
        XCTAssertThrowsError(try corrupt.validate())
    }
    func testCallAndOwnProcessesAreExcludedWithoutCapturingInput() {
        XCTAssertNotNil(AudioRoutingPolicy.exclusionReason(bundleID: "com.apple.FaceTime", ownBundleID: "com.zeuve.app", runningInput: false))
        XCTAssertNotNil(AudioRoutingPolicy.exclusionReason(bundleID: "com.zeuve.app", ownBundleID: "com.zeuve.app", runningInput: false))
        XCTAssertNotNil(AudioRoutingPolicy.exclusionReason(bundleID: "com.example.music", ownBundleID: "com.zeuve.app", runningInput: true))
        XCTAssertNil(AudioRoutingPolicy.exclusionReason(bundleID: "com.example.music", ownBundleID: "com.zeuve.app", runningInput: false))
    }
    func testDiscoveryDoesNotCaptureAndRepeatedStartIsIdempotent() async throws {
        let backend = TestAudioBackend(sources: [music])
        let routing = AudioRoutingCoordinator(settings: try store(), backend: backend)
        try await routing.start(); try await routing.start()
        let count = await backend.discoveries; let routes = await backend.gains
        XCTAssertEqual(count, 1); XCTAssertTrue(routes.isEmpty); XCTAssertEqual(routing.sources, [music])
        try await routing.stop(); try await routing.stop()
        XCTAssertTrue(routing.sources.isEmpty)
    }
    func testLevelMuteAndResetUseOneSharedRouteAndRestoreOriginalPlayback() async throws {
        let settings = try store(), backend = TestAudioBackend(sources: [music])
        let routing = AudioRoutingCoordinator(settings: settings, backend: backend)
        try await routing.start()
        try await routing.setLevel(sourceID: music.id, level: .init(gain: 0.4))
        try await routing.setLevel(sourceID: music.id, level: .init(gain: 0.4, muted: true))
        let starts = await backend.starts, gains = await backend.gains
        XCTAssertEqual(starts, 1); XCTAssertEqual(gains[music.id], 0)
        XCTAssertEqual(try settings.value(forKey: AudioRoutingCoordinator.settingsKey, as: AudioMixerPreferences.self)?.levels[music.id], .init(gain: 0.4, muted: true))
        try await routing.setLevel(sourceID: music.id, level: .init())
        let restored = await backend.gains
        XCTAssertTrue(restored.isEmpty); XCTAssertTrue(routing.routedSourceIDs.isEmpty)
        try await routing.restoreDefaults()
        XCTAssertNil(try settings.value(forKey: AudioRoutingCoordinator.settingsKey, as: AudioMixerPreferences.self))
    }
    func testPersistedLevelsNeverAuthorizeNewProcessCapture() async throws {
        let settings = try store(), backend = TestAudioBackend(sources: [music])
        var preferences = AudioMixerPreferences(); preferences.levels[music.id] = .init(gain: 0.2)
        try settings.set(preferences, forKey: AudioRoutingCoordinator.settingsKey)
        let routing = AudioRoutingCoordinator(settings: settings, backend: backend)
        try await routing.start()
        let starts = await backend.starts
        XCTAssertEqual(starts, 0); XCTAssertEqual(routing.preferences, preferences)
        try await routing.stop()
    }
    func testCorruptPreferencesNeverReachCapture() async throws {
        let settings = try store(), backend = TestAudioBackend(sources: [music])
        try settings.set("corrupt", forKey: AudioRoutingCoordinator.settingsKey)
        let routing = AudioRoutingCoordinator(settings: settings, backend: backend)
        do { try await routing.start(); XCTFail("Configuración corrupta aceptada") } catch {}
        let starts = await backend.starts, discoveries = await backend.discoveries
        XCTAssertEqual(starts, 0); XCTAssertEqual(discoveries, 0)
    }
    func testPermissionFailureReportsEffectiveStateAndRetiresRoutes() async throws {
        let backend = TestAudioBackend(sources: [music]); await backend.setFailure(.requiresPermission(.audioCapture))
        let routing = AudioRoutingCoordinator(settings: try store(), backend: backend)
        let service = ApplicationAudioMixerService(routing: routing)
        try await service.start()
        do { try await service.setLevel(sourceID: music.id, level: .init(gain: 0.5)); XCTFail("Ruta no autorizada aceptada") } catch {}
        XCTAssertEqual(service.state, .requiresPermission(.audioCapture))
        let gains = await backend.gains; XCTAssertTrue(gains.isEmpty)
        try await service.stop(); XCTAssertEqual(service.state, .disabled)
    }
    func testUnavailableApplicationIsNeverRouted() async throws {
        let source = AudioApplicationSource(id: "com.apple.FaceTime", name: "FaceTime", processIDs: [42], supportsRouting: false, limitation: "Llamada")
        let backend = TestAudioBackend(sources: [source])
        let routing = AudioRoutingCoordinator(settings: try store(), backend: backend)
        try await routing.start()
        do { try await routing.setLevel(sourceID: source.id, level: .init(gain: 0.5)); XCTFail("Se capturó una llamada") } catch {}
        let count = await backend.starts; XCTAssertEqual(count, 0)
        try await routing.stop()
    }
    func testDeviceChangeRetiresRoutesWithoutCapturingReplacementProcess() async throws {
        let backend = TestAudioBackend(sources: [music])
        let routing = AudioRoutingCoordinator(settings: try store(), backend: backend)
        try await routing.start(); try await routing.setLevel(sourceID: music.id, level: .init(gain: 0.5))
        await backend.emitChange()
        for _ in 0..<100 where !routing.routedSourceIDs.isEmpty { try await Task.sleep(for: .milliseconds(2)) }
        XCTAssertTrue(routing.routedSourceIDs.isEmpty)
        let count = await backend.starts, gains = await backend.gains
        XCTAssertEqual(count, 1); XCTAssertTrue(gains.isEmpty)
        try await routing.stop()
    }
    func testCleanupFailureRemainsVisibleAndCanBeRetried() async throws {
        let backend = TestAudioBackend(sources: [music])
        let routing = AudioRoutingCoordinator(settings: try store(), backend: backend)
        let service = ApplicationAudioMixerService(routing: routing)
        try await service.start(); try await service.setLevel(sourceID: music.id, level: .init(gain: 0.5))
        await backend.setStopFailure(true)
        do { try await service.stop(); XCTFail("Se declaró limpieza que falló") } catch {}
        guard case .failed = service.state else { return XCTFail("Error de limpieza oculto") }
        XCTAssertTrue(routing.routedSourceIDs.contains(music.id))
        await backend.setStopFailure(false); try await service.stop()
        XCTAssertEqual(service.state, .disabled)
    }
    func testProtectionDoesNotClaimEfficacyOrAcquireMixerRoute() async throws {
        let backend = TestAudioBackend(sources: [music])
        let routing = AudioRoutingCoordinator(settings: try store(), backend: backend)
        let protection = CallAudioProtectionService(routing: routing)
        do { try await protection.start(); XCTFail("Protección no validada activada") } catch {}
        XCTAssertEqual(protection.state, .unavailable(CallAudioProtectionService.limitation))
        let starts = await backend.starts; XCTAssertEqual(starts, 0)
        try await protection.stop(); XCTAssertEqual(protection.state, .unavailable(CallAudioProtectionService.limitation))
    }
    func testCancelledActivationDoesNotAcquireAudioResources() async throws {
        let backend = TestAudioBackend(sources: [music])
        let routing = AudioRoutingCoordinator(settings: try store(), backend: backend)
        let service = ApplicationAudioMixerService(routing: routing)
        let task = Task { @MainActor in try await service.start() }
        task.cancel()
        do { try await task.value; XCTFail("Activación cancelada aceptada") } catch {}
        let count = await backend.starts
        XCTAssertEqual(count, 0)
        XCTAssertNotEqual(service.state, .active)
        try await service.stop()
    }
    func testPersistenceContainsConfigurationOnly() throws {
        var preferences = AudioMixerPreferences(); preferences.levels[music.id] = .init(gain: 0.5, muted: true)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(preferences)) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["schemaVersion", "levels"])
        let levels = try XCTUnwrap(object["levels"] as? [String: Any])
        let values = try XCTUnwrap(levels[music.id] as? [String: Any])
        XCTAssertEqual(Set(values.keys), ["gain", "muted"])
    }
}

private actor TestAudioBackend: AudioRouteBackend {
    let sources: [AudioApplicationSource]
    var gains: [String: Float] = [:]
    var metered: Set<String> = []
    var starts = 0, discoveries = 0
    var failure: QuickUtilityError?
    var stopFailure = false
    var handler: (@MainActor @Sendable (String?) -> Void)?
    init(sources: [AudioApplicationSource]) { self.sources = sources }
    func setFailure(_ value: QuickUtilityError?) { failure = value }
    func setStopFailure(_ value: Bool) { stopFailure = value }
    func discoverSources() async throws -> [AudioApplicationSource] { discoveries += 1; return sources }
    func startRoute(source: AudioApplicationSource, gain: Float) async throws {
        if let failure { throw failure }; starts += 1; gains[source.id] = gain
    }
    func setGain(sourceID: String, gain: Float) async throws { if let failure { throw failure }; gains[sourceID] = gain }
    func stopRoute(sourceID: String) async throws {
        if stopFailure { throw QuickUtilityError.failure("Limpieza fallida") }; gains.removeValue(forKey: sourceID); metered.remove(sourceID)
    }
    func stopAll() async throws { if stopFailure { throw QuickUtilityError.failure("Limpieza fallida") }; gains.removeAll(); metered.removeAll() }
    func setMeteringEnabled(sourceID: String, enabled: Bool) async throws {
        guard gains[sourceID] != nil else { throw QuickUtilityError.failure("La ruta de prueba ya no existe") }
        if enabled { metered.insert(sourceID) } else { metered.remove(sourceID) }
    }
    func readMeters() async throws -> [AudioRouteMeter] {
        metered.compactMap { id in gains[id].map { .init(id: id, inputRMS: 1, outputRMS: $0, callbackCount: 1) } }
    }
    func observeChanges(_ handler: (@MainActor @Sendable (String?) -> Void)?) async throws { self.handler = handler }
    func emitChange() async { await handler?(nil) }
}
