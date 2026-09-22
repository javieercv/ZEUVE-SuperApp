import XCTest
import ZEUVEStorage
@testable import UniversalDownloaderModule

final class UniversalDownloadProfilesTests: XCTestCase {
    func testFactoryProfilesRemainEditableAndRestorable() {
        var profiles = UniversalDownloadProfiles()

        for platform in UniversalDownloadProfiles.configurablePlatforms {
            let factory = profiles.profile(for: platform).settings
            XCTAssertEqual(factory.mode, .original, "\(platform) debe partir de Original")
            XCTAssertEqual(factory.maximumResolution, .best)
            XCTAssertEqual(factory.container, .automatic)
        }

        profiles.setSettings(.init(mode: .video, maximumResolution: .p720), for: .youtube)
        XCTAssertEqual(profiles.profile(for: .youtube).settings.mode, .video)
        XCTAssertEqual(profiles.profile(for: .youtube).settings.maximumResolution, .p720)

        profiles.restoreFactorySettings(for: .youtube)
        XCTAssertEqual(profiles.profile(for: .youtube).settings.mode, .original)
        XCTAssertEqual(profiles.profile(for: .youtube).settings.maximumResolution, .best)
        XCTAssertEqual(profiles.profile(for: .youtube).settings.container, .automatic)
    }

    func testSchemaOneFactoryYouTubeMP3320MigratesToOriginalWithoutTouchingCustomProfiles() throws {
        var profiles = UniversalDownloadProfiles()
        profiles.setSettings(.init(mode: .audio, audioOutput: .mp3, mp3Bitrate: .kbps320), for: .youtube)
        profiles.customProfiles = [
            .init(name: "Cursos", host: "academy.example.com", settings: .init(mode: .audio, audioOutput: .flac))
        ]
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(profiles)) as? [String: Any])
        object["schemaVersion"] = 1
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        var legacy = try JSONDecoder().decode(UniversalDownloadProfiles.self, from: legacyData)

        legacy.normalize()

        XCTAssertEqual(legacy.schemaVersion, UniversalDownloadProfiles.currentSchemaVersion)
        XCTAssertEqual(legacy.profile(for: .youtube).settings.mode, .original)
        XCTAssertEqual(legacy.profile(for: .youtube).settings.maximumResolution, .best)
        XCTAssertEqual(legacy.customProfiles.first?.settings.audioOutput, .flac)
    }

    func testSchemaOneCustomizedYouTubeProfileIsPreserved() throws {
        var profiles = UniversalDownloadProfiles()
        let customized = UniversalDownloadSettings(mode: .video, maximumResolution: .p720)
        profiles.setSettings(customized, for: .youtube)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(profiles)) as? [String: Any])
        object["schemaVersion"] = 1
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        var legacy = try JSONDecoder().decode(UniversalDownloadProfiles.self, from: legacyData)

        legacy.normalize()

        XCTAssertEqual(legacy.profile(for: .youtube).settings, customized)
        XCTAssertEqual(legacy.schemaVersion, UniversalDownloadProfiles.currentSchemaVersion)
    }

    func testCustomAddressKeepsOnlyNormalizedHost() throws {
        let host = try UniversalCustomProfileHost.normalized(
            "https://Videos.Example.com/course/123?token=private#fragment"
        )
        XCTAssertEqual(host, "videos.example.com")
        XCTAssertThrowsError(try UniversalCustomProfileHost.normalized("https://user:secret@example.com/video"))

        let profile = UniversalCustomDownloadProfile(
            name: "Cursos",
            host: host,
            settings: .init(mode: .audio)
        )
        let data = try JSONEncoder().encode(profile)
        let encoded = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(encoded.contains("videos.example.com"))
        XCTAssertFalse(encoded.contains("course"))
        XCTAssertFalse(encoded.contains("private"))
    }

    func testCustomRuleUsesStablePageOriginAndOverridesBuiltInPlatformProfile() {
        var profiles = UniversalDownloadProfiles()
        profiles.setSettings(.init(mode: .video, maximumResolution: .p1080), for: .webpage)
        profiles.customProfiles = [
            .init(
                name: "Cursos",
                host: "academy.example.com",
                includesSubdomains: true,
                settings: .init(mode: .audio, audioOutput: .mp3, mp3Bitrate: .kbps192)
            )
        ]
        profiles.normalize()

        let item = UniversalDownloadItem(
            canonicalID: "page:1",
            sourceURL: URL(string: "https://cdn.provider.invalid/signed.mp4?token=secret")!,
            title: "Clase",
            downloadSource: .pageDiscovered,
            pageOrigin: .init(pageURL: URL(string: "https://video.academy.example.com/course/1")!),
            platform: .webpage,
            mediaKind: .video,
            engineKind: .genericPage
        )

        let resolved = UniversalDownloadSettingsResolver().settings(
            for: item,
            operationSettings: .init(),
            profiles: profiles
        )
        XCTAssertEqual(resolved.mode, .audio)
        XCTAssertEqual(resolved.audioOutput, .mp3)
        XCTAssertEqual(resolved.mp3Bitrate, .kbps192)
    }

    func testExactHostWinsOverBroaderSubdomainRule() {
        var profiles = UniversalDownloadProfiles()
        profiles.customProfiles = [
            .init(name: "General", host: "example.com", settings: .init(mode: .video)),
            .init(name: "Vídeos", host: "videos.example.com", settings: .init(mode: .audio, audioOutput: .opus))
        ]
        profiles.normalize()
        let item = UniversalDownloadItem(
            canonicalID: "custom:1",
            sourceURL: URL(string: "https://videos.example.com/watch/1")!,
            title: "Vídeo",
            platform: .webpage,
            mediaKind: .video
        )

        let resolved = UniversalDownloadSettingsResolver().settings(for: item, operationSettings: .init(), profiles: profiles)
        XCTAssertEqual(resolved.mode, .audio)
        XCTAssertEqual(resolved.audioOutput, .opus)
    }

    func testManualOperationChoiceOverridesProfilesAndImagesStayOriginal() {
        var profiles = UniversalDownloadProfiles()
        profiles.setSettings(.init(mode: .audio), for: .instagram)
        let video = UniversalDownloadItem(
            canonicalID: "instagram:video",
            sourceURL: URL(string: "https://instagram.com/reel/abc")!,
            title: "Reel",
            platform: .instagram,
            mediaKind: .video
        )
        let photo = UniversalDownloadItem(
            canonicalID: "instagram:photo",
            sourceURL: URL(string: "https://instagram.com/p/photo")!,
            title: "Foto",
            platform: .instagram,
            mediaKind: .photo
        )
        let resolver = UniversalDownloadSettingsResolver()

        XCTAssertEqual(resolver.settings(for: video, operationSettings: .init(mode: .video), profiles: profiles).mode, .video)
        XCTAssertEqual(resolver.settings(for: photo, operationSettings: .init(), profiles: profiles).mode, .original)
    }

    func testLegacyManualDefaultMigratesToEveryBuiltInPlatform() {
        let legacy = UniversalDownloadSettings(mode: .audio, audioOutput: .flac)
        let profiles = UniversalDownloadProfiles.migrated(from: legacy)

        for platform in UniversalDownloadProfiles.configurablePlatforms {
            XCTAssertEqual(profiles.profile(for: platform).settings.mode, .audio)
            XCTAssertEqual(profiles.profile(for: platform).settings.audioOutput, .flac)
        }
    }

    func testProfileCollectionPersistsUnderDedicatedKey() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZEUVE-DownloadProfiles-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storage = try StorageContainer(databaseURL: directory.appendingPathComponent("settings.sqlite"))
        var profiles = UniversalDownloadProfiles()
        profiles.customProfiles = [
            .init(name: "Ejemplo", host: "downloads.example.com", settings: .init(mode: .original))
        ]
        try storage.settings.set(profiles, forKey: "universalDownloader.downloadProfiles")

        let restored = try storage.settings.value(
            forKey: "universalDownloader.downloadProfiles",
            as: UniversalDownloadProfiles.self
        )
        XCTAssertEqual(restored, profiles)
    }
}
