import XCTest
import ZEUVEStorage
@testable import ZEUVEQuickUtilities

@MainActor final class CoordinatorTests: XCTestCase {
    private func store() throws -> SettingsRepository {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("zeuve-quick-tests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return try SettingsRepository(database: SQLiteDatabase(url: directory.appendingPathComponent("test.sqlite")))
    }
    func testRepeatedActivationAndStopReleaseExactlyOnce() async throws {
        let settings = try store(), service = CountingService()
        let coordinator = QuickUtilitiesCoordinator(settings: settings, services: [service])
        await coordinator.initialize(); await coordinator.initialize()
        await coordinator.setEnabled(true, for: service.id)
        await coordinator.setEnabled(true, for: service.id)
        XCTAssertEqual(service.starts, 1); XCTAssertTrue(coordinator.isActive(service.id))
        await coordinator.setEnabled(false, for: service.id)
        await coordinator.setEnabled(false, for: service.id)
        XCTAssertEqual(service.stops, 1); XCTAssertFalse(coordinator.isActive(service.id))
        XCTAssertEqual(try settings.value(forKey: QuickUtilitiesCoordinator.settingsKey, as: QuickUtilitiesPreferences.self)?.enabled, [])
    }
    func testRestoresRequestsButNeverConfusesPermissionWithActive() async throws {
        let settings = try store(), service = CountingService()
        var preferences = QuickUtilitiesPreferences(); preferences.enabled = [.scroll]
        try settings.set(preferences, forKey: QuickUtilitiesCoordinator.settingsKey)
        service.denied = true
        let coordinator = QuickUtilitiesCoordinator(settings: settings, services: [service])
        await coordinator.initialize()
        XCTAssertEqual(service.state, .requiresPermission(.accessibility))
        XCTAssertFalse(coordinator.isActive(.scroll))
        XCTAssertTrue(coordinator.snapshots.first { $0.id == .scroll }!.requested)
        service.denied = false; await coordinator.retry(.scroll)
        XCTAssertTrue(coordinator.isActive(.scroll))
        await coordinator.shutdown(); XCTAssertEqual(service.state, .disabled)
        XCTAssertTrue(try settings.value(forKey: QuickUtilitiesCoordinator.settingsKey, as: QuickUtilitiesPreferences.self)!.enabled.contains(.scroll))
    }
    func testMissingStorageDoesNotActivateAndCorruptConfigurationFailsClosed() async throws {
        let service = CountingService()
        let unavailable = QuickUtilitiesCoordinator(settings: nil, services: [service])
        await unavailable.initialize(); await unavailable.setEnabled(true, for: .scroll)
        XCTAssertEqual(service.starts, 0); XCTAssertNotNil(unavailable.storageError)
        let settings = try store()
        try settings.set("invalid", forKey: QuickUtilitiesCoordinator.settingsKey)
        let invalid = QuickUtilitiesCoordinator(settings: settings, services: [service])
        await invalid.initialize()
        XCTAssertTrue(invalid.preferences.enabled.isEmpty); XCTAssertNotNil(invalid.storageError)
    }
    func testGlobalResetStopsAndRestoresOwnSettings() async throws {
        let service = CountingService()
        let coordinator = QuickUtilitiesCoordinator(settings: try store(), services: [service])
        await coordinator.initialize(); await coordinator.setEnabled(true, for: .scroll)
        let failures = await coordinator.restoreDefaults()
        XCTAssertTrue(failures.isEmpty); XCTAssertEqual(service.resets, 1)
        XCTAssertEqual(service.state, .disabled); XCTAssertTrue(coordinator.preferences.enabled.isEmpty)
    }
}

@MainActor private final class CountingService: QuickUtilityService {
    let id = QuickUtilityID.scroll
    var state = QuickUtilityState.disabled { didSet { stateDidChange?(state) } }
    var stateDidChange: (@MainActor (QuickUtilityState) -> Void)?
    var starts = 0, stops = 0, resets = 0
    var denied = false
    func start() async throws {
        guard state != .active else { return }
        state = .activating
        if denied { state = .requiresPermission(.accessibility); throw QuickUtilityError.requiresPermission(.accessibility) }
        starts += 1; state = .active
    }
    func stop() async throws {
        guard state != .disabled else { return }
        if state == .active { stops += 1 }
        state = .deactivating; state = .disabled
    }
    func restoreDefaultSettings() async throws { resets += 1 }
}
