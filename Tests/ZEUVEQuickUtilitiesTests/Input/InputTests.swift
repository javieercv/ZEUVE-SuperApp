import XCTest
import ZEUVEStorage
@testable import ZEUVEQuickUtilities

final class InputTransformationTests: XCTestCase {
    private var sample: DiscreteScrollSample {
        .init(continuous: false, verticalLines: 2, horizontalLines: -3, verticalPoints: 17, horizontalPoints: -23, verticalFixed: 2.25, horizontalFixed: -3.5)
    }
    func testDiscreteVerticalReversesAllRepresentationsAndPreservesHorizontal() {
        let result = sample.transformed(using: .init())
        XCTAssertEqual(result.verticalLines, -2); XCTAssertEqual(result.verticalPoints, -17); XCTAssertEqual(result.verticalFixed, -2.25)
        XCTAssertEqual(result.horizontalLines, -3); XCTAssertEqual(result.horizontalPoints, -23); XCTAssertEqual(result.horizontalFixed, -3.5)
    }
    func testHorizontalOnlyReversesAllRepresentationsAndPreservesVertical() {
        var options = ScrollDirectionOptions(); options.invertVertical = false; options.invertHorizontal = true
        let result = sample.transformed(using: options)
        XCTAssertEqual(result.horizontalLines, 3); XCTAssertEqual(result.horizontalPoints, 23); XCTAssertEqual(result.horizontalFixed, 3.5)
        XCTAssertEqual(result.verticalLines, 2); XCTAssertEqual(result.verticalPoints, 17); XCTAssertEqual(result.verticalFixed, 2.25)
    }
    func testContinuousEventsAreNeverClassifiedAsPhysicalTrackpadOrChanged() {
        var original = sample; original.continuous = true
        var options = ScrollDirectionOptions(); options.invertHorizontal = true
        XCTAssertEqual(original.transformed(using: options), original)
    }
    func testUnknownSchemaDoesNotTransform() {
        var options = ScrollDirectionOptions(); options.schemaVersion = 42
        XCTAssertEqual(sample.transformed(using: options), sample)
        XCTAssertThrowsError(try options.validate())
    }
    func testInvalidNumericDataPassesThroughWithoutOverflow() {
        var original = sample; original.verticalLines = .min
        XCTAssertEqual(original.transformed(using: .init()), original)
        original = sample; original.verticalPoints = .min
        XCTAssertEqual(original.transformed(using: .init()), original)
        original = sample; original.verticalFixed = .infinity
        XCTAssertEqual(original.transformed(using: .init()), original)
    }
    func testNoInversionIsExactPassThrough() {
        var options = ScrollDirectionOptions(); options.invertVertical = false
        XCTAssertEqual(sample.transformed(using: options), sample)
    }
    func testProtectedAndUnsupportedButtonsCannotBePersisted() {
        for button in [-1, 0, 1, 2, 32] {
            var options = AdditionalMouseButtonsOptions(); options.assignments[button] = .missionControl
            XCTAssertThrowsError(try options.validate())
        }
    }
    func testShortcutsRejectBareWritingModifierAndSystemDestructiveCombinations() {
        let invalid: [MouseButtonShortcut] = [
            .init(keyCode: 0, label: "A"), .init(keyCode: 55, label: "⌘", command: true),
            .init(keyCode: 12, label: "Q", command: true), .init(keyCode: 12, label: "Q", command: true, option: true, shift: true),
            .init(keyCode: 53, label: "Esc", command: true, option: true), .init(keyCode: 127, label: "Encendido", control: true),
            .init(keyCode: 102, label: "Eisu"), .init(keyCode: 123, label: "\n", control: true)
        ]
        for shortcut in invalid { XCTAssertThrowsError(try shortcut.validate(), shortcut.displayName) }
        for shortcut in [MouseButtonShortcut.back, .forward, .missionControl, .showDesktop] { XCTAssertNoThrow(try shortcut.validate()) }
    }
    func testAssignmentCodingStoresOnlyConfiguration() throws {
        var options = AdditionalMouseButtonsOptions(); options.assignments[3] = .back; options.assignments[4] = .forward
        let data = try JSONEncoder().encode(options)
        XCTAssertEqual(try JSONDecoder().decode(AdditionalMouseButtonsOptions.self, from: data), options)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["schemaVersion", "assignments"])
    }
    func testOnlyConsumedDownOwnsItsUpAndDrag() {
        var tracker = MouseButtonPairTracker()
        XCTAssertFalse(tracker.up(3)); XCTAssertFalse(tracker.dragging(3))
        XCTAssertFalse(tracker.down(2, mapped: true)); XCTAssertFalse(tracker.down(3, mapped: false))
        XCTAssertTrue(tracker.down(3, mapped: true)); XCTAssertFalse(tracker.down(3, mapped: true))
        XCTAssertTrue(tracker.dragging(3)); XCTAssertTrue(tracker.up(3)); XCTAssertFalse(tracker.up(3)); XCTAssertFalse(tracker.dragging(3))
    }
}

@MainActor final class InputServiceTests: XCTestCase {
    private func store() throws -> SettingsRepository {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("zeuve-input-tests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return try SettingsRepository(database: SQLiteDatabase(url: directory.appendingPathComponent("test.sqlite")))
    }
    func testScrollStartStopAreIdempotentAndPublishReality() async throws {
        let broker = TestInputBroker()
        let actual = ScrollDirectionService(settings: try store(), broker: broker)
        var states: [QuickUtilityState] = []; actual.stateDidChange = { states.append($0) }
        try await actual.start(); try await actual.start()
        XCTAssertEqual(broker.scrollStarts, 1); XCTAssertEqual(actual.state, .active)
        try await actual.stop(); try await actual.stop()
        XCTAssertEqual(broker.scrollStops, 1); XCTAssertEqual(actual.state, .disabled)
        XCTAssertEqual(states, [.activating, .active, .deactivating, .disabled])
    }
    func testPermissionDenialAndRevocationNeverAppearActive() async throws {
        let broker = TestInputBroker(); broker.error = .requiresPermission(.accessibility)
        let service = ScrollDirectionService(settings: try store(), broker: broker)
        do { try await service.start(); XCTFail("Expected denied permission") } catch { }
        XCTAssertEqual(service.state, .requiresPermission(.accessibility))
        broker.error = nil; try await service.start()
        broker.failureHandlers[.scroll]?(.requiresPermission(.accessibility))
        XCTAssertEqual(service.state, .requiresPermission(.accessibility))
        try await service.stop(); XCTAssertEqual(service.state, .disabled)
    }
    func testMissingCorruptAndUnknownConfigurationFailClosed() async throws {
        let broker = TestInputBroker(), missing = ScrollDirectionService(settings: nil, broker: broker)
        do { try await missing.start(); XCTFail() } catch { }
        XCTAssertEqual(broker.scrollStarts, 0)
        let settings = try store()
        try settings.set("corrupt", forKey: ScrollDirectionService.settingsKey)
        let corrupt = ScrollDirectionService(settings: settings, broker: broker)
        do { try await corrupt.start(); XCTFail() } catch { }
        XCTAssertEqual(broker.scrollStarts, 0)
        var options = AdditionalMouseButtonsOptions(); options.schemaVersion = 12
        try settings.set(options, forKey: AdditionalMouseButtonsService.settingsKey)
        let unknown = AdditionalMouseButtonsService(settings: settings, broker: broker)
        do { try await unknown.start(); XCTFail() } catch { }
        XCTAssertEqual(broker.buttonStarts, 0)
    }
    func testOptionsPersistRestoreAndResetStopsFirst() async throws {
        let settings = try store(), broker = TestInputBroker()
        let service = ScrollDirectionService(settings: settings, broker: broker)
        var options = ScrollDirectionOptions(); options.invertVertical = false; options.invertHorizontal = true
        try await service.updateOptions(options)
        XCTAssertEqual(ScrollDirectionService(settings: settings, broker: TestInputBroker()).options, options)
        try await service.start(); try await service.restoreDefaultSettings()
        XCTAssertEqual(service.state, .disabled); XCTAssertEqual(service.options, .init()); XCTAssertEqual(broker.scrollStops, 1)
        XCTAssertEqual(try settings.value(forKey: ScrollDirectionService.settingsKey, as: ScrollDirectionOptions.self), .init())
    }
    func testEmptyAssignmentsCannotClaimActiveThenAssignmentActivatesAndRemoves() async throws {
        let broker = TestInputBroker(), service = AdditionalMouseButtonsService(settings: try store(), broker: broker)
        do { try await service.start(); XCTFail() } catch { }
        XCTAssertEqual(broker.buttonStarts, 0)
        try await service.assign(.missionControl, to: 3); try await service.start(); try await service.start()
        XCTAssertEqual(broker.buttonStarts, 1); XCTAssertEqual(service.state, .active)
        try await service.assign(nil, to: 3)
        XCTAssertEqual(broker.buttonStops, 1); XCTAssertNotEqual(service.state, .active)
        try await service.restoreDefaultSettings(); XCTAssertEqual(service.options.assignments, [:])
    }
    func testButtonCaptureIsExplicitCancelledAndStopsWithService() async throws {
        let broker = TestInputBroker(), service = AdditionalMouseButtonsService(settings: try store(), broker: broker)
        try await service.captureButton(); XCTAssertTrue(service.isCapturing); XCTAssertNil(service.lastCapturedButton)
        broker.captureHandler?(4)
        XCTAssertFalse(service.isCapturing); XCTAssertEqual(service.lastCapturedButton, 4)
        try await service.captureButton(); try await service.cancelCapture()
        XCTAssertFalse(service.isCapturing); XCTAssertEqual(broker.captureCancels, 1)
        try await service.captureButton(); try await service.stop()
        XCTAssertFalse(service.isCapturing); XCTAssertEqual(broker.buttonStops, 1); XCTAssertEqual(service.state, .disabled)
    }
    func testButtonsPermissionFailureAndInvalidAssignmentAreVisible() async throws {
        let broker = TestInputBroker(), service = AdditionalMouseButtonsService(settings: try store(), broker: broker)
        do { try await service.assign(.back, to: 1); XCTFail() } catch { }
        XCTAssertTrue(service.options.assignments.isEmpty); XCTAssertNotNil(service.settingsError)
        try await service.assign(.back, to: 3)
        broker.error = .requiresPermission(.accessibility)
        do { try await service.start(); XCTFail() } catch { }
        XCTAssertEqual(service.state, .requiresPermission(.accessibility))
    }
}

@MainActor private final class TestInputBroker: InputEventTapControlling {
    var error: QuickUtilityError?
    var scrollStarts = 0, scrollStops = 0, buttonStarts = 0, buttonStops = 0, captureCancels = 0
    var failureHandlers: [QuickUtilityID: @MainActor (QuickUtilityError) -> Void] = [:]
    var captureHandler: (@MainActor (Int) -> Void)?
    func setFailureHandler(for id: QuickUtilityID, handler: (@MainActor (QuickUtilityError) -> Void)?) { failureHandlers[id] = handler }
    func startScroll(_ options: ScrollDirectionOptions) async throws { if let error { throw error }; scrollStarts += 1 }
    func stopScroll() async throws { scrollStops += 1 }
    func startButtons(_ options: AdditionalMouseButtonsOptions) async throws { if let error { throw error }; buttonStarts += 1 }
    func stopButtons() async throws { buttonStops += 1; captureHandler = nil }
    func captureNextButton(_ handler: @escaping @MainActor (Int) -> Void) async throws { if let error { throw error }; captureHandler = handler }
    func cancelButtonCapture() async throws { captureCancels += 1; captureHandler = nil }
}
