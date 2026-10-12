import XCTest
import ZEUVEStorage
@testable import ZEUVEQuickUtilities

final class WindowGeometryTests: XCTestCase {
    func testNormalizesAndAdaptsToSmallerMonitorWithoutOffscreenWindow() {
        let original = WindowDisplayGeometry(frame: .init(x: -1920, y: -100, width: 1920, height: 1080), visibleFrame: .init(x: -1920, y: -80, width: 1920, height: 1000))
        let frame = WindowFrame(x: -960, y: 20, width: 900, height: 800)
        let relative = WindowGeometryPlanner.relative(frame, to: original)
        XCTAssertEqual(relative.x, 0.5, accuracy: 0.001)
        let smaller = WindowDisplayGeometry(frame: .init(x: 0, y: 0, width: 800, height: 600), visibleFrame: .init(x: 0, y: 24, width: 800, height: 540))
        let restored = WindowGeometryPlanner.restored(relative, on: smaller)
        XCTAssertGreaterThanOrEqual(restored.x, 0)
        XCTAssertGreaterThanOrEqual(restored.y, 24)
        XCTAssertLessThanOrEqual(restored.x + restored.width, 800)
        XCTAssertLessThanOrEqual(restored.y + restored.height, 564)
    }
    func testBoundsClampNegativeOffsetsAndOversizedWindows() {
        let display = WindowDisplayGeometry(frame: .init(x: -800, y: 100, width: 800, height: 600), visibleFrame: .init(x: -800, y: 125, width: 800, height: 550))
        let result = WindowGeometryPlanner.restored(.init(x: -2, y: 9, width: 3, height: 4), on: display)
        XCTAssertEqual(result, display.visibleFrame)
    }
    func testTopologyDoesNotTreatMissingOrMovedScreenAsAutomaticMatch() {
        let a = WindowDisplayGeometry(frame: .init(x: 0, y: 0, width: 1000, height: 800), visibleFrame: .init(x: 0, y: 24, width: 1000, height: 776))
        let b = WindowDisplayGeometry(frame: .init(x: 1000, y: 0, width: 1000, height: 800), visibleFrame: .init(x: 1000, y: 24, width: 1000, height: 776))
        XCTAssertTrue(WindowGeometryPlanner.topologyMatches([a, b], [a, b]))
        XCTAssertFalse(WindowGeometryPlanner.topologyMatches([a, b], [a]))
        XCTAssertFalse(WindowGeometryPlanner.topologyMatches([a, b], [b, a]))
    }
    func testMalformedProfilesAndUnsupportedSchemaAreRejected() throws {
        var preferences = WindowLayoutsPreferences(); preferences.schemaVersion = 99
        XCTAssertThrowsError(try preferences.validate())
        preferences = .init(); preferences.automaticallyRestore = true
        XCTAssertThrowsError(try preferences.validate())
        XCTAssertFalse(WindowFrame(x: .infinity, y: 0, width: 1, height: 1).isValid)
        XCTAssertFalse(WindowFrame(x: 0, y: 0, width: -1, height: 1).isValid)
    }
}

#if os(macOS)
private actor TestWindowAccess: WindowAccessBackend {
    var windows: [WindowSnapshot]
    var starts = 0
    var stops = 0
    var selections: [UUID] = []
    var restored: [(UUID, WindowFrame)] = []
    var delayRestore = false
    var failRestore = false
    init(windows: [WindowSnapshot]) { self.windows = windows }
    func startMonitoring(changed: @escaping @Sendable () -> Void) { starts += 1 }
    func stopMonitoring() { stops += 1 }
    func snapshots(applications: [WindowApplication], frontmostPID: Int32?) throws -> [WindowSnapshot] { windows }
    func noteFocus(processIdentifier: Int32) {}
    func activateWindow(_ id: UUID) throws { selections.append(id) }
    func restoreWindow(_ id: UUID, frame: WindowFrame) async throws -> WindowFrame {
        if delayRestore { try await Task.sleep(for: .milliseconds(200)) }
        try Task.checkCancellation()
        if failRestore { throw QuickUtilityError.failure("La ventana ha rechazado la geometría.") }
        restored.append((id, frame)); return frame
    }
    func configure(delay: Bool = false, failure: Bool = false) { delayRestore = delay; failRestore = failure }
    func replaceWindows(_ value: [WindowSnapshot]) { windows = value }
}
@MainActor private final class TestWindowShortcuts: WindowShortcutRegistering {
    var registrations = 0
    var releases = 0
    var action: (@MainActor () -> Void)?
    func register(id: String, shortcut: GlobalShortcut, action: @escaping @MainActor () -> Void) throws { registrations += 1; self.action = action }
    func unregister(id: String) { if action != nil { releases += 1 }; action = nil }
}

@MainActor final class WindowServiceTests: XCTestCase {
    private func store() throws -> SettingsRepository {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("zeuve-window-tests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return try SettingsRepository(database: SQLiteDatabase(url: directory.appendingPathComponent("test.sqlite")))
    }
    private func window(_ id: UUID = UUID(), bundle: String = "com.zeuve.fixture", mutable: Bool = true) -> WindowSnapshot {
        .init(id: id, applicationName: "App de prueba", bundleIdentifier: bundle, title: "CANARIO_DOCUMENTO_PRIVADO", processIdentifier: 1234,
              frame: .init(x: 100, y: 100, width: 600, height: 400), minimized: false, canRestoreGeometry: mutable)
    }
    private var displays: [WindowDisplayGeometry] {
        [.init(frame: .init(x: 0, y: 0, width: 1000, height: 800), visibleFrame: .init(x: 0, y: 24, width: 1000, height: 776))]
    }
    private func settle(_ predicate: @MainActor () -> Bool) async throws {
        for _ in 0..<100 {
            if predicate() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("La operación no terminó dentro del plazo del test.")
    }
    func testSharedBackendKeepsObserversUntilLastUtilityStops() async throws {
        let access = TestWindowAccess(windows: []), backend = WindowServicesBackend(access: TestWindowAccess(windows: []), trusted: { true })
        let shared = WindowServicesBackend(access: access, trusted: { true })
        try await shared.acquire(.windowSwitcher); try await shared.acquire(.windowLayouts); try await shared.acquire(.windowLayouts)
        await shared.release(.windowSwitcher)
        let earlyStops = await access.stops; XCTAssertEqual(earlyStops, 0)
        await shared.release(.windowLayouts)
        let starts = await access.starts, stops = await access.stops
        XCTAssertEqual(starts, 1); XCTAssertEqual(stops, 1)
        // A backend that never acquired resources is also safe to release.
        await backend.release(.windowSwitcher)
    }
    func testSwitcherCancelNeverActivatesAndConfirmOnlyActivatesChosenWindow() async throws {
        let first = window(), second = window()
        let access = TestWindowAccess(windows: [first, second]), shortcuts = TestWindowShortcuts()
        let service = WindowSwitcherService(backend: .init(access: access, trusted: { true }), settings: try store(), shortcuts: shortcuts)
        try await service.start(); try await service.start()
        XCTAssertEqual(shortcuts.registrations, 1)
        service.show(); try await settle { service.isPresented }
        service.cancel()
        let before = await access.selections; XCTAssertTrue(before.isEmpty)
        service.show(); try await settle { service.isPresented }
        service.choose(second.id)
        try await settle { !service.isPresented }
        // The owned selection task finishes on the next actor hop.
        try await Task.sleep(for: .milliseconds(20))
        let selected = await access.selections; XCTAssertEqual(selected, [second.id])
        try await service.stop(); XCTAssertEqual(shortcuts.releases, 1)
        XCTAssertEqual(service.state, .disabled); XCTAssertTrue(service.windows.isEmpty)
    }
    func testProfilesDoNotPersistPrivateTitlesAndRequireReassociationAfterRestart() async throws {
        let original = window(), access = TestWindowAccess(windows: [])
        await access.replaceWindows([original])
        let settings = try store(), backend = WindowServicesBackend(access: access, trusted: { true })
        let displayList = displays
        let service = WindowLayoutsService(backend: backend, settings: settings, displayProvider: { displayList })
        try await service.start(); try await service.saveProfile(name: "Trabajo", windowIDs: [original.id])
        let profile = try XCTUnwrap(service.preferences.profiles.first)
        let bytes = try JSONEncoder().encode(service.preferences)
        let text = try XCTUnwrap(String(data: bytes, encoding: .utf8))
        XCTAssertFalse(text.contains("CANARIO_DOCUMENTO_PRIVADO")); XCTAssertFalse(text.contains(original.id.uuidString)); XCTAssertFalse(text.contains("processIdentifier"))
        try await service.stop(); try await service.start()
        XCTAssertTrue(service.associations.isEmpty)
        service.restoreProfile(profile.id); try await settle { !service.isRestoring }
        XCTAssertEqual(service.lastResult?.restored, 0); XCTAssertEqual(service.lastResult?.omitted, 1)
        service.refreshWindows(); try await settle { service.windows.count == 1 }
        try service.associate(slotID: profile.slots[0].id, windowID: original.id)
        service.restoreProfile(profile.id); try await settle { !service.isRestoring }
        XCTAssertEqual(service.lastResult?.restored, 1)
        try await service.stop()
    }
    func testAmbiguousSameApplicationWindowsAreNeverMatchedByIndexOrTitle() async throws {
        let first = window(), second = window(), access = TestWindowAccess(windows: [])
        await access.replaceWindows([first, second])
        let displayList = displays
        let service = WindowLayoutsService(backend: .init(access: access, trusted: { true }), settings: try store(), displayProvider: { displayList })
        try await service.start(); try await service.saveProfile(name: "Dos ventanas", windowIDs: [first.id, second.id])
        let profile = try XCTUnwrap(service.preferences.profiles.first)
        XCTAssertThrowsError(try service.associate(slotID: profile.slots[1].id, windowID: first.id))
        let replacement = window(); await access.replaceWindows([replacement])
        service.restoreProfile(profile.id); try await settle { !service.isRestoring }
        XCTAssertEqual(service.lastResult?.omitted, 2)
        let calls = await access.restored; XCTAssertTrue(calls.isEmpty)
        try await service.stop()
    }
    func testRejectedGeometryAndCancellationAreNotReportedAsRestored() async throws {
        let original = window(), access = TestWindowAccess(windows: [])
        await access.replaceWindows([original])
        let displayList = displays
        let service = WindowLayoutsService(backend: .init(access: access, trusted: { true }), settings: try store(), displayProvider: { displayList })
        try await service.start(); try await service.saveProfile(name: "Una ventana", windowIDs: [original.id])
        let profile = try XCTUnwrap(service.preferences.profiles.first)
        await access.configure(failure: true)
        service.restoreProfile(profile.id); try await settle { !service.isRestoring }
        XCTAssertEqual(service.lastResult?.failed, 1); XCTAssertEqual(service.lastResult?.restored, 0)
        await access.configure(delay: true)
        service.restoreProfile(profile.id)
        try await Task.sleep(for: .milliseconds(10)); service.cancelRestoration()
        try await settle { !service.isRestoring }
        XCTAssertTrue(service.lastResult?.cancelled == true); XCTAssertEqual(service.lastResult?.restored, 0)
        try await service.stop()
    }
    func testPermissionDenialAndCorruptSettingsNeverActivateResources() async throws {
        let access = TestWindowAccess(windows: []), settings = try store()
        let denied = WindowLayoutsService(backend: .init(access: access, trusted: { false }), settings: settings)
        do { try await denied.start(); XCTFail("Debe rechazar el permiso denegado.") } catch {}
        XCTAssertEqual(denied.state, .requiresPermission(.accessibility))
        let starts = await access.starts; XCTAssertEqual(starts, 0)
        try settings.set("datos dañados", forKey: WindowLayoutsService.settingsKey)
        let corrupt = WindowLayoutsService(backend: .init(access: access, trusted: { true }), settings: settings)
        do { try await corrupt.start(); XCTFail("Debe rechazar la configuración dañada.") } catch {}
        XCTAssertNotEqual(corrupt.state, .active)
    }
    func testResetKeepsProfilesEvenWhenUtilityHasNeverBeenStarted() async throws {
        let settings = try store(), displayList = displays
        let profile = WindowLayoutProfile(name: "Distribución personal", displays: displayList, slots: [
            .init(bundleIdentifier: "com.zeuve.fixture", displayIndex: 0, relativeFrame: .init(x: 0.1, y: 0.1, width: 0.6, height: 0.5))
        ])
        var persisted = WindowLayoutsPreferences()
        persisted.profiles = [profile]; persisted.automaticProfileID = profile.id; persisted.automaticallyRestore = true
        try settings.set(persisted, forKey: WindowLayoutsService.settingsKey)
        let access = TestWindowAccess(windows: [])
        let service = WindowLayoutsService(backend: .init(access: access, trusted: { true }), settings: settings, displayProvider: { displayList })
        XCTAssertEqual(service.preferences.profiles, [profile])
        try await service.restoreDefaultSettings()
        XCTAssertEqual(service.preferences.profiles, [profile]); XCTAssertFalse(service.preferences.automaticallyRestore)
        XCTAssertNil(service.preferences.automaticProfileID); XCTAssertTrue(service.associations.isEmpty)
        XCTAssertEqual(service.state, .disabled)
        let saved = try settings.value(forKey: WindowLayoutsService.settingsKey, as: WindowLayoutsPreferences.self)
        XCTAssertEqual(saved?.profiles, [profile]); XCTAssertFalse(saved?.automaticallyRestore == true)
    }
}
#endif
