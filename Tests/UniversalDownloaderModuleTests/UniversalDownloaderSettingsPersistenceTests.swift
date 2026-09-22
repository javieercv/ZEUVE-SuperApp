import XCTest
import ZEUVEStorage
@testable import UniversalDownloaderModule

final class UniversalDownloaderSettingsPersistenceTests: XCTestCase {
    func testModuleDefaultsPersistWithAdvancedModeUnderDedicatedKeys() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZEUVE-UniversalDownloaderSettings-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storage = try StorageContainer(databaseURL: directory.appendingPathComponent("settings.sqlite"))
        let defaults = UniversalDownloadSettings(
            mode: .audio,
            audioOutput: .mp3,
            mp3Bitrate: .kbps192,
            pageSource: .init(
                embedSourceMetadata: true,
                includeDownloadDate: true,
                applyMacOSWhereFrom: true
            ),
            filenamePreset: .title
        )

        try storage.settings.set(defaults, forKey: "universalDownloader.defaultSettings")
        try storage.settings.set(true, forKey: "universalDownloader.defaultAdvancedMode")

        XCTAssertEqual(
            try storage.settings.value(forKey: "universalDownloader.defaultSettings", as: UniversalDownloadSettings.self),
            defaults
        )
        XCTAssertEqual(
            try storage.settings.value(forKey: "universalDownloader.defaultAdvancedMode", as: Bool.self),
            true
        )
    }

    func testLegacyBrowserFallbackPreferenceIsNormalizedAndPersistedAsDisabled() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZEUVE-UniversalDownloaderBrowserFallbackMigration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storage = try StorageContainer(databaseURL: directory.appendingPathComponent("settings.sqlite"))
        var legacy = UniversalDownloaderPreferences()
        legacy.useOptionalBrowserFallback = true
        try storage.settings.set(legacy, forKey: UniversalDownloaderStorageKeys.preferences)

        let loaded = UniversalDownloaderSettingsStore(settings: storage.settings).load()

        XCTAssertFalse(loaded.preferences.useOptionalBrowserFallback)
        let persisted = try XCTUnwrap(
            storage.settings.value(forKey: UniversalDownloaderStorageKeys.preferences, as: UniversalDownloaderPreferences.self)
        )
        XCTAssertFalse(persisted.useOptionalBrowserFallback)
    }

    func testSchemaOneFactoryYouTubeProfileMigratesAndPersists() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZEUVE-UniversalDownloaderProfileMigration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storage = try StorageContainer(databaseURL: directory.appendingPathComponent("settings.sqlite"))
        var profiles = UniversalDownloadProfiles()
        profiles.setSettings(.init(mode: .audio, audioOutput: .mp3, mp3Bitrate: .kbps320), for: .youtube)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(profiles)) as? [String: Any])
        object["schemaVersion"] = 1
        let legacy = try JSONDecoder().decode(
            UniversalDownloadProfiles.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        try storage.settings.set(legacy, forKey: UniversalDownloaderStorageKeys.downloadProfiles)

        let loaded = UniversalDownloaderSettingsStore(settings: storage.settings).load()

        XCTAssertEqual(loaded.downloadProfiles.profile(for: .youtube).settings.mode, .original)
        XCTAssertEqual(loaded.downloadProfiles.schemaVersion, UniversalDownloadProfiles.currentSchemaVersion)
        let persisted = try XCTUnwrap(
            storage.settings.value(forKey: UniversalDownloaderStorageKeys.downloadProfiles, as: UniversalDownloadProfiles.self)
        )
        XCTAssertEqual(persisted, loaded.downloadProfiles)
    }

    func testIncludedPresetsKeepOriginalAndVideoPurposesSeparated() throws {
        let presets = UniversalDownloadPresetService.defaultPresets()

        XCTAssertEqual(
            presets.first(where: { $0.name == "Mejor calidad compatible" })?.settings.mode,
            .original
        )
        XCTAssertEqual(presets.first(where: { $0.name == "Vídeo 1080p" })?.settings.mode, .video)
        XCTAssertEqual(presets.first(where: { $0.name == "Vídeo 720p" })?.settings.mode, .video)
        XCTAssertEqual(
            presets.first(where: { $0.name == "Vídeo con subtítulos en español" })?.settings.mode,
            .video
        )
        XCTAssertEqual(presets.first(where: { $0.name == "Colección completa" })?.settings.mode, .original)
        XCTAssertTrue(presets.allSatisfy { $0.schemaVersion == UniversalDownloadPresetService.currentSchemaVersion })
    }

    func testLegacyBestCompatiblePresetMigratesWithoutChangingPersonalPresets() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZEUVE-UniversalDownloaderPresetMigration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storage = try StorageContainer(databaseURL: directory.appendingPathComponent("settings.sqlite"))
        let bestID = UUID()
        let personalID = UUID()
        let legacyBest = UniversalDownloadPreset(
            id: bestID,
            schemaVersion: 2,
            name: "Mejor calidad compatible",
            settings: UniversalDownloadSettings(mode: .video),
            isFavorite: true
        )
        let personalSettings = UniversalDownloadSettings(mode: .video, maximumResolution: .p720)
        let personal = UniversalDownloadPreset(
            id: personalID,
            schemaVersion: 2,
            name: "Mi preset personal",
            settings: personalSettings
        )
        try storage.settings.set([legacyBest, personal], forKey: "universalDownloader.presets")

        let migrated = try UniversalDownloadPresetService(settings: storage.settings).load()

        let best = try XCTUnwrap(migrated.first(where: { $0.id == bestID }))
        XCTAssertEqual(best.settings.mode, .original)
        XCTAssertEqual(best.schemaVersion, 3)
        XCTAssertTrue(best.isFavorite)

        let preserved = try XCTUnwrap(migrated.first(where: { $0.id == personalID }))
        XCTAssertEqual(preserved.settings, personalSettings)
        XCTAssertEqual(preserved.schemaVersion, 3)

        let persisted = try XCTUnwrap(
            storage.settings.value(forKey: "universalDownloader.presets", as: [UniversalDownloadPreset].self)
        )
        XCTAssertEqual(persisted, migrated)
    }

    func testCustomizedBestCompatiblePresetIsNotMistakenForLegacyFactoryVideo() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZEUVE-UniversalDownloaderCustomPresetMigration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storage = try StorageContainer(databaseURL: directory.appendingPathComponent("settings.sqlite"))
        let customizedSettings = UniversalDownloadSettings(mode: .video, maximumResolution: .p1080)
        let customized = UniversalDownloadPreset(
            schemaVersion: 2,
            name: "Mejor calidad compatible",
            settings: customizedSettings
        )
        try storage.settings.set([customized], forKey: "universalDownloader.presets")

        let migrated = try UniversalDownloadPresetService(settings: storage.settings).load()

        XCTAssertEqual(migrated.first?.settings, customizedSettings)
        XCTAssertEqual(migrated.first?.schemaVersion, 3)
    }
    func testStorageKeysPreserveCurrentAndLegacyIdentifiersExactly() {
        XCTAssertEqual(UniversalDownloaderStorageKeys.preferences, "universalDownloader.preferences")
        XCTAssertEqual(UniversalDownloaderStorageKeys.defaultSettings, "universalDownloader.defaultSettings")
        XCTAssertEqual(UniversalDownloaderStorageKeys.downloadProfiles, "universalDownloader.downloadProfiles")
        XCTAssertEqual(UniversalDownloaderStorageKeys.defaultAdvancedMode, "universalDownloader.defaultAdvancedMode")
        XCTAssertEqual(UniversalDownloaderStorageKeys.presets, "universalDownloader.presets")
        XCTAssertEqual(UniversalDownloaderStorageKeys.outputFolderBookmark, "universalDownloader.outputFolderBookmark")

        XCTAssertEqual(UniversalDownloaderStorageKeys.Legacy.defaultSettings, "youtube.defaultSettings")
        XCTAssertEqual(UniversalDownloaderStorageKeys.Legacy.defaultAdvancedMode, "youtube.defaultAdvancedMode")
        XCTAssertEqual(UniversalDownloaderStorageKeys.Legacy.presets, "youtubeDownloader.presets")
        XCTAssertEqual(UniversalDownloaderStorageKeys.Legacy.outputFolderBookmark, "youtubeDownloader.outputFolderBookmark")
    }

    func testSettingsStoreReadsLegacyDefaultsAndAdvancedModeWithoutDeletingLegacyValues() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZEUVE-UniversalDownloaderLegacySettings-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storage = try StorageContainer(databaseURL: directory.appendingPathComponent("settings.sqlite"))
        let legacyDefaults = UniversalDownloadSettings(mode: .audio, audioOutput: .mp3, mp3Bitrate: .kbps192)
        try storage.settings.set(legacyDefaults, forKey: UniversalDownloaderStorageKeys.Legacy.defaultSettings)
        try storage.settings.set(true, forKey: UniversalDownloaderStorageKeys.Legacy.defaultAdvancedMode)

        let loaded = UniversalDownloaderSettingsStore(settings: storage.settings).load()

        XCTAssertEqual(loaded.defaultSettings, legacyDefaults)
        XCTAssertTrue(loaded.defaultAdvancedMode)
        XCTAssertEqual(
            try storage.settings.value(forKey: UniversalDownloaderStorageKeys.defaultSettings, as: UniversalDownloadSettings.self),
            legacyDefaults
        )
        XCTAssertEqual(
            try storage.settings.value(forKey: UniversalDownloaderStorageKeys.defaultAdvancedMode, as: Bool.self),
            true
        )
        XCTAssertEqual(
            try storage.settings.value(forKey: UniversalDownloaderStorageKeys.Legacy.defaultSettings, as: UniversalDownloadSettings.self),
            legacyDefaults
        )
        XCTAssertEqual(
            try storage.settings.value(forKey: UniversalDownloaderStorageKeys.Legacy.defaultAdvancedMode, as: Bool.self),
            true
        )
    }

}
