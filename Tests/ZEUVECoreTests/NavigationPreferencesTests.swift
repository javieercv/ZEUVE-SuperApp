import XCTest
@testable import ZEUVECore

final class NavigationPreferencesTests: XCTestCase {
    private let defaults = NavigationPreferencesDefaults(
        moduleOrder: ["one", "two", "three"],
        shortcuts: ["one": .command("1"), "two": .command("2"), "three": .command("3"), "history": .command("4")],
        historyTargetID: "history"
    )

    func testNormalizesOrderAndFutureModules() {
        let input = NavigationPreferences(moduleOrder: ["two", "missing", "two", "one"])
        let normalized = KeyboardShortcutValidator.normalized(input, availableModuleIDs: ["one", "two", "three", "future"], defaults: defaults)
        XCTAssertEqual(normalized.moduleOrder, ["two", "one", "three", "future"])
    }

    func testDisabledShortcutSurvivesCoding() throws {
        let input = NavigationPreferences(moduleOrder: ["one"], shortcutOverrides: ["one": .disabled, "history": .custom(.init(key: "l", option: true, control: true))])
        let decoded = try JSONDecoder().decode(NavigationPreferences.self, from: JSONEncoder().encode(input))
        XCTAssertNil(decoded.effectiveShortcut(for: "one", defaults: defaults))
        XCTAssertEqual(decoded.effectiveShortcut(for: "history", defaults: defaults)?.displayName, "⌃⌥L")
    }

    func testInvalidAndDuplicatePersistedShortcutsAreDisabledSafely() {
        let input = NavigationPreferences(shortcutOverrides: [
            "one": .custom(.command("d")),
            "two": .custom(.command("d")),
            "three": .custom(.command("q")),
        ])
        let normalized = KeyboardShortcutValidator.normalized(input, availableModuleIDs: defaults.moduleOrder, defaults: defaults)
        XCTAssertEqual(normalized.effectiveShortcut(for: "one", defaults: defaults)?.displayName, "⌘D")
        XCTAssertNil(normalized.effectiveShortcut(for: "two", defaults: defaults))
        XCTAssertNil(normalized.effectiveShortcut(for: "three", defaults: defaults))
    }

    func testValidatorRejectsDangerousAndBareWritingKeys() {
        XCTAssertThrowsError(try KeyboardShortcutValidator.validate(.command("q")))
        XCTAssertThrowsError(try KeyboardShortcutValidator.validate(.init(key: "a", shift: true)))
        XCTAssertNoThrow(try KeyboardShortcutValidator.validate(.init(key: "m", command: true, shift: true)))
    }
}
