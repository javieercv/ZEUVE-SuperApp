import XCTest
import ZEUVEStorage
@testable import ZEUVEQuickUtilities

@MainActor final class FoundationRegressionTests: XCTestCase {
    private func store() throws -> SettingsRepository {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("zeuve-foundation-tests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return try SettingsRepository(database: SQLiteDatabase(url: directory.appendingPathComponent("test.sqlite")))
    }

    /// Reset awaits native cleanup. A user activation arriving during that await
    /// must not leave requested=true after the reset has stopped the service.
    func testResetRejectsReactivationUntilServiceDefaultsFinish() async throws {
        let settings = try store()
        let service = SuspendedResetUtility()
        let coordinator = QuickUtilitiesCoordinator(settings: settings, services: [service])
        await coordinator.initialize()
        await coordinator.setEnabled(true, for: service.id)
        let reset = Task { await coordinator.restoreDefaults() }
        for _ in 0..<100 where !service.resetEntered { await Task.yield() }
        XCTAssertTrue(service.resetEntered)
        await coordinator.setEnabled(true, for: service.id)
        service.completeReset()
        let failures = await reset.value
        XCTAssertTrue(failures.isEmpty)
        XCTAssertFalse(coordinator.preferences.enabled.contains(service.id))
        XCTAssertEqual(service.state, .disabled)
        let persisted = try settings.value(forKey: QuickUtilitiesCoordinator.settingsKey, as: QuickUtilitiesPreferences.self)
        XCTAssertFalse(persisted?.enabled.contains(service.id) == true)
    }

    func testStopAllCancelsAnActivationAndWaitsForResourceRelease() async throws {
        let settings = try store()
        let service = SuspendedStartUtility()
        let coordinator = QuickUtilitiesCoordinator(settings: settings, services: [service])
        await coordinator.initialize()
        let activate = Task { await coordinator.setEnabled(true, for: service.id) }
        for _ in 0..<100 where !service.startEntered { await Task.yield() }
        XCTAssertTrue(service.startEntered)
        let stop = Task { await coordinator.stopAll() }
        await Task.yield()
        service.completeStart()
        await activate.value; await stop.value
        XCTAssertFalse(coordinator.preferences.enabled.contains(service.id))
        XCTAssertEqual(service.state, .disabled)
        XCTAssertEqual(service.resources, 0)
        XCTAssertFalse(coordinator.isBusy(service.id))
    }

    func testConcurrentStopsJoinOneNativeCleanup() async throws {
        let service = SuspendedStopUtility()
        let coordinator = QuickUtilitiesCoordinator(settings: try store(), services: [service])
        await coordinator.initialize(); await coordinator.setEnabled(true, for: service.id)
        let first = Task { await coordinator.stopAll() }
        for _ in 0..<100 where !service.stopEntered { await Task.yield() }
        XCTAssertTrue(service.stopEntered)
        let second = Task { await coordinator.stopAll() }
        for _ in 0..<100 { await Task.yield() }
        XCTAssertEqual(service.stopCalls, 1)
        service.completeStop()
        await first.value; await second.value
        XCTAssertEqual(service.stopCalls, 1)
        XCTAssertEqual(service.state, .disabled)
        XCTAssertTrue(coordinator.preferences.enabled.isEmpty)
    }

    func testStopAndShutdownWaitForTheOwnedReset() async throws {
        let settings = try store(), service = SuspendedResetUtility()
        let coordinator = QuickUtilitiesCoordinator(settings: settings, services: [service])
        await coordinator.initialize(); await coordinator.setEnabled(true, for: service.id)
        let first = Task { await coordinator.restoreDefaults() }
        for _ in 0..<100 where !service.resetEntered { await Task.yield() }
        XCTAssertTrue(service.resetEntered)
        let second = Task { await coordinator.restoreDefaults() }
        var stopped = false, closed = false
        let stop = Task { await coordinator.stopAll(); stopped = true }
        let shutdown = Task { await coordinator.shutdown(); closed = true }
        for _ in 0..<100 { await Task.yield() }
        XCTAssertFalse(stopped); XCTAssertFalse(closed)
        XCTAssertEqual(service.resetCalls, 1)
        XCTAssertEqual(service.stopCalls, 1)
        service.completeReset()
        let firstFailures = await first.value, secondFailures = await second.value
        await stop.value; await shutdown.value
        XCTAssertTrue(firstFailures.isEmpty); XCTAssertEqual(firstFailures, secondFailures)
        XCTAssertEqual(service.resetCalls, 1)
        XCTAssertEqual(service.state, .disabled)
        XCTAssertTrue(coordinator.preferences.enabled.isEmpty)
        let persisted = try settings.value(forKey: QuickUtilitiesCoordinator.settingsKey, as: QuickUtilitiesPreferences.self)
        XCTAssertEqual(persisted?.enabled, [])
    }
}

@MainActor private final class SuspendedResetUtility: QuickUtilityService {
    let id: QuickUtilityID = .fileShelf
    var state: QuickUtilityState = .disabled { didSet { stateDidChange?(state) } }
    var stateDidChange: (@MainActor (QuickUtilityState) -> Void)?
    var resetEntered = false
    var resetCalls = 0
    var stopCalls = 0
    private var resetContinuation: CheckedContinuation<Void, Never>?
    func start() async throws { state = .active }
    func stop() async throws { stopCalls += 1; state = .disabled }
    func restoreDefaultSettings() async throws {
        resetEntered = true
        resetCalls += 1
        await withCheckedContinuation { resetContinuation = $0 }
        try await stop()
    }
    func completeReset() { resetContinuation?.resume(); resetContinuation = nil }
}

@MainActor private final class SuspendedStopUtility: QuickUtilityService {
    let id: QuickUtilityID = .fileShelf
    var state: QuickUtilityState = .disabled { didSet { stateDidChange?(state) } }
    var stateDidChange: (@MainActor (QuickUtilityState) -> Void)?
    var stopEntered = false
    var stopCalls = 0
    private var stopContinuation: CheckedContinuation<Void, Never>?
    func start() async throws { state = .active }
    func stop() async throws {
        stopCalls += 1; state = .deactivating
        if stopCalls == 1 {
            stopEntered = true
            await withCheckedContinuation { stopContinuation = $0 }
        }
        state = .disabled
    }
    func restoreDefaultSettings() async throws { try await stop() }
    func completeStop() { stopContinuation?.resume(); stopContinuation = nil }
}

@MainActor private final class SuspendedStartUtility: QuickUtilityService {
    let id: QuickUtilityID = .fileShelf
    var state: QuickUtilityState = .disabled { didSet { stateDidChange?(state) } }
    var stateDidChange: (@MainActor (QuickUtilityState) -> Void)?
    var startEntered = false
    var resources = 0
    private var startContinuation: CheckedContinuation<Void, Never>?
    func start() async throws {
        state = .activating; startEntered = true; resources = 1
        await withCheckedContinuation { startContinuation = $0 }
        if Task.isCancelled { resources = 0; state = .disabled; throw CancellationError() }
        state = .active
    }
    func stop() async throws { resources = 0; state = .disabled }
    func restoreDefaultSettings() async throws { try await stop() }
    func completeStart() { startContinuation?.resume(); startContinuation = nil }
}
