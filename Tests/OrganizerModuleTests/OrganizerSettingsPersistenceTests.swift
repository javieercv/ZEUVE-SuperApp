import XCTest
import ZEUVEStorage
@testable import OrganizerModule

final class OrganizerSettingsPersistenceTests: XCTestCase {
    func testDefaultOptionsRemainIndependentFromLegacyOperationOptions() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZEUVE-OrganizerSettings-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storage = try StorageContainer(databaseURL: directory.appendingPathComponent("settings.sqlite"))
        let defaults = OrganizerOptions(
            recursive: true,
            organizationLevel: .simple,
            keepRelated: false,
            conflictPolicy: .skip,
            includeHidden: false
        )
        let operation = OrganizerOptions(
            recursive: false,
            organizationLevel: .detailed,
            keepRelated: true,
            conflictPolicy: .rename,
            includeHidden: true
        )

        try storage.settings.set(defaults, forKey: OrganizerStorageKeys.defaultOptions)
        try storage.settings.set(operation, forKey: OrganizerStorageKeys.Legacy.options)

        XCTAssertEqual(
            try storage.settings.value(forKey: OrganizerStorageKeys.defaultOptions, as: OrganizerOptions.self),
            defaults
        )
        XCTAssertEqual(
            try storage.settings.value(forKey: OrganizerStorageKeys.Legacy.options, as: OrganizerOptions.self),
            operation
        )
    }
}
