import XCTest
import ZEUVEStorage
@testable import YouTubeDownloaderModule

final class YouTubeModuleSettingsPersistenceTests: XCTestCase {
    func testModuleDefaultsPersistWithAdvancedModeUnderDedicatedKeys() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZEUVE-YouTubeSettings-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storage = try StorageContainer(databaseURL: directory.appendingPathComponent("settings.sqlite"))
        let defaults = YouTubeDownloadSettings(
            mode: .audio,
            audioOutput: .mp3,
            mp3Bitrate: .kbps192,
            filenamePreset: .title
        )

        try storage.settings.set(defaults, forKey: "youtube.defaultSettings")
        try storage.settings.set(true, forKey: "youtube.defaultAdvancedMode")

        XCTAssertEqual(
            try storage.settings.value(forKey: "youtube.defaultSettings", as: YouTubeDownloadSettings.self),
            defaults
        )
        XCTAssertEqual(
            try storage.settings.value(forKey: "youtube.defaultAdvancedMode", as: Bool.self),
            true
        )
    }
}
