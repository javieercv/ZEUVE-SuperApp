import Foundation
import XCTest
@testable import UniversalDownloaderModule
import ZEUVECore
import ZEUVEStorage

final class UniversalDownloaderFilesStorageAndManifestTests: XCTestCase {
    private var root: URL!
    private var settings: SettingsRepository!
    private var history: HistoryRepository!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("ZEUVE-UniversalDownloaderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let database = try SQLiteDatabase(url: root.appendingPathComponent("data.sqlite"))
        settings = try SettingsRepository(database: database)
        history = try HistoryRepository(database: database)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    func testFilenameSanitizationLongNamesAndAutomaticRename() throws {
        let policy = DownloadFilenamePolicy()
        let safe = try policy.sanitize(" ../Vídeo: prueba/.. ")
        XCTAssertFalse(safe.contains("/"))
        XCTAssertFalse(safe.hasPrefix("."))
        let long = try policy.sanitize(String(repeating: "á", count: 500), maximumUTF8Bytes: 80)
        XCTAssertLessThanOrEqual(long.utf8.count, 80)
        let existing = root.appendingPathComponent("video.mp4")
        try Data("original".utf8).write(to: existing)
        XCTAssertEqual(try policy.automaticRename(for: existing).lastPathComponent, "video (2).mp4")
    }

    func testPageDiscoveredNamesRemoveExtractorIDsAndNumberEveryDuplicateFromOne() throws {
        let policy = DownloadFilenamePolicy()
        XCTAssertEqual(
            try policy.pageDiscoveredBaseNames(for: [
                "de ig 3 (1)",
                "de ig 3 (3)",
                "de ig 3 (5)",
            ]),
            ["de ig 3 (1)", "de ig 3 (2)", "de ig 3 (3)"]
        )
        XCTAssertEqual(
            try policy.pageDiscoveredBaseNames(for: ["Vídeo", "Vídeo"]),
            ["Vídeo (1)", "Vídeo (2)"]
        )
        XCTAssertEqual(
            try policy.pageDiscoveredBaseNames(for: ["Película (1976)"]),
            ["Película (1976)"]
        )
        XCTAssertEqual(
            try policy.pageDiscoveredBaseNames(
                for: ["de ig 3 (5)"],
                detectedTitles: ["de ig 3 (1)", "de ig 3 (3)", "de ig 3 (5)"]
            ),
            ["de ig 3"]
        )
    }

    func testTemporaryWorkspaceOwnershipCleanupAndForeignFiles() throws {
        let base = root.appendingPathComponent("temp", isDirectory: true)
        let workspace = try DownloadWorkspace(operationID: UUID(), baseDirectory: base)
        try Data("part".utf8).write(to: workspace.download.appendingPathComponent("video.part"))
        let foreign = root.appendingPathComponent("foreign.txt")
        try Data("keep".utf8).write(to: foreign)
        try workspace.clean()
        XCTAssertFalse(FileManager.default.fileExists(atPath: workspace.root.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: foreign.path))
    }

    func testPublisherNeverPublishesPartAndRenamesByDefault() throws {
        let workspace = try DownloadWorkspace(operationID: UUID(), baseDirectory: root.appendingPathComponent("temp"))
        try Data("valid".utf8).write(to: workspace.download.appendingPathComponent("video.mp4"))
        try Data("partial".utf8).write(to: workspace.download.appendingPathComponent("video.part"))
        let output = root.appendingPathComponent("output", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try Data("existing".utf8).write(to: output.appendingPathComponent("video.mp4"))
        let publisher = DownloadOutputPublisher()
        let candidates = try publisher.candidateFiles(in: workspace)
        XCTAssertEqual(candidates.map(\.lastPathComponent), ["video.mp4"])
        let published = try publisher.publish(files: candidates, to: output, policy: .renameAutomatically)
        XCTAssertEqual(published.first?.lastPathComponent, "video (2).mp4")
        XCTAssertEqual(try String(contentsOf: output.appendingPathComponent("video.mp4"), encoding: .utf8), "existing")
    }


    func testPublisherMovesAtomicallyInsideSameVolumeInsteadOfCopyingWholeFile() throws {
        let workspace = try DownloadWorkspace(operationID: UUID(), baseDirectory: root.appendingPathComponent("temp"))
        let source = workspace.download.appendingPathComponent("video.mp4")
        try Data(repeating: 0x5A, count: 1_048_576).write(to: source)
        let output = root.appendingPathComponent("output", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let publisher = DownloadOutputPublisher()
        XCTAssertTrue(publisher.sameVolume(source, output))
        let published = try publisher.publish(files: [source], to: output, policy: .renameAutomatically)
        XCTAssertEqual(published.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertEqual(try published[0].resourceValues(forKeys: [.fileSizeKey]).fileSize, 1_048_576)
    }

    func testPublisherRejectsSymbolicLinksEvenWhenTheyPointToRegularFiles() throws {
        let workspace = try DownloadWorkspace(operationID: UUID(), baseDirectory: root.appendingPathComponent("temp"))
        let foreign = root.appendingPathComponent("foreign-video.mp4")
        try Data("foreign".utf8).write(to: foreign)
        let link = workspace.download.appendingPathComponent("linked.mp4")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: foreign)
        XCTAssertTrue(try DownloadOutputPublisher().candidateFiles(in: workspace).isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: foreign.path))
    }

    func testBookmarkStaleRefreshAndUnresolvedBookmarkPreservation() throws {
        let folder = root.appendingPathComponent("output", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let codec = StaleBookmarkCodec(folder: folder)
        let store = DownloadOutputFolderBookmarkStore(settings: settings, codec: codec)
        try store.save(folder)
        XCTAssertEqual(try store.resolve(), folder.standardizedFileURL)
        XCTAssertGreaterThanOrEqual(codec.makeCount, 2)

        let broken = DownloadOutputFolderBookmarkStore(settings: settings, codec: BrokenBookmarkCodec())
        try settings.set(Data("broken".utf8), forKey: "youtubeDownloader.outputFolderBookmark")
        XCTAssertNil(try broken.resolve())
        XCTAssertEqual(
            try settings.value(forKey: "youtubeDownloader.outputFolderBookmark", as: Data.self),
            Data("broken".utf8)
        )
    }

    func testBookmarkClearRemovesCurrentAndLegacyValues() throws {
        let folder = root.appendingPathComponent("output-clear", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let store = DownloadOutputFolderBookmarkStore(settings: settings, codec: StaleBookmarkCodec(folder: folder))
        try settings.set(Data("current".utf8), forKey: UniversalDownloaderStorageKeys.outputFolderBookmark)
        try settings.set(Data("legacy".utf8), forKey: UniversalDownloaderStorageKeys.Legacy.outputFolderBookmark)

        try store.clear()

        XCTAssertNil(try settings.value(forKey: UniversalDownloaderStorageKeys.outputFolderBookmark, as: Data.self))
        XCTAssertNil(try settings.value(forKey: UniversalDownloaderStorageKeys.Legacy.outputFolderBookmark, as: Data.self))
    }


    func testPresetSchemaOneMigratesWithoutLosingSettings() throws {
        var legacySettings = UniversalDownloadSettings(
            mode: .audio,
            container: .automatic,
            audioOutput: .mp3,
            filenamePreset: .titleAndID
        )
        legacySettings.mp3Bitrate = .kbps192
        let legacy = UniversalDownloadPreset(
            schemaVersion: 1,
            name: "Preset antiguo",
            settings: legacySettings
        )
        try settings.set([legacy], forKey: "youtubeDownloader.presets")

        let migrated = try UniversalDownloadPresetService(settings: settings).load()
        XCTAssertEqual(migrated.count, 1)
        XCTAssertEqual(migrated[0].schemaVersion, UniversalDownloadPresetService.currentSchemaVersion)
        XCTAssertEqual(migrated[0].settings.container, .automatic)
        XCTAssertEqual(migrated[0].settings.audioOutput, .mp3)
        XCTAssertEqual(migrated[0].settings.mp3Bitrate, .kbps192)
        XCTAssertEqual(migrated[0].settings.filenamePreset, .titleAndID)
    }

    func testPresetSchemaAndStoredDataContainNoSecretsOrFreeArguments() throws {
        let service = UniversalDownloadPresetService(settings: settings)
        let presets = try service.load()
        XCTAssertEqual(presets.count, 7)
        XCTAssertTrue(presets.allSatisfy { $0.schemaVersion == UniversalDownloadPresetService.currentSchemaVersion })
        let encoded = String(decoding: try JSONEncoder().encode(presets), as: UTF8.self).lowercased()
        for forbidden in ["cookies", "password", "token", "header", "arguments", "proxyusername"] {
            XCTAssertFalse(encoded.contains(forbidden))
        }
    }

    func testHistoryStoresCanonicalIDsButNoURLOrSecrets() throws {
        let result = UniversalDownloadResult(
            id: UUID(), startedAt: Date(timeIntervalSince1970: 1), finishedAt: Date(timeIntervalSince1970: 2), outputFolder: root,
            mode: .video, formatSummary: "Mejor calidad", items: [.init(canonicalID: "abc12345678", title: "Título", status: .completed)], wasCancelled: false
        )
        let record = try UniversalDownloadHistoryService(repository: history).save(result)
        let text = String(decoding: record.payload, as: UTF8.self).lowercased()
        XCTAssertTrue(text.contains("abc12345678"))
        XCTAssertFalse(text.contains("youtube.com"))
        XCTAssertFalse(text.contains("googlevideo"))
        XCTAssertFalse(text.contains("cookie"))
        XCTAssertFalse(text.contains("token"))
    }

    func testSanitizedInformationAndPlaylistJSONContainNoURLsOrSecrets() throws {
        let item = UniversalDownloadItem(
            canonicalID: "abc12345678",
            sourceURL: URL(string: "https://www.youtube.com/watch?v=abc12345678&token=secret")!,
            title: "Título",
            playlistTitle: "Lista",
            playlistIndex: 1
        )
        let writer = DownloadSafeMetadataWriter()
        let info = try writer.writeInfo(
            for: item,
            settings: UniversalDownloadSettings(),
            formatSummary: "Mejor vídeo y audio",
            to: root
        )
        let playlist = try writer.writePlaylist(
            title: "Lista",
            items: [item],
            resultsByCanonicalID: [item.canonicalID: .completed],
            to: root
        )
        let combined = try [info, playlist]
            .map { try String(contentsOf: $0, encoding: .utf8).lowercased() }
            .joined(separator: "\n")
        XCTAssertTrue(combined.contains("abc12345678"))
        for forbidden in ["http://", "https://", "youtube.com", "googlevideo", "cookie", "token", "header", "proxy", "secret"] {
            XCTAssertFalse(combined.contains(forbidden), "El JSON sanitario contiene: \(forbidden)")
        }
    }


    func testCatalogItemUsesUniversalSwiftNameWhileKeepingLegacyVideoIDCodingKey() throws {
        let item = DownloadCatalogItem(
            canonicalID: "instagram:item-1",
            title: "Elemento",
            sourceURL: URL(string: "https://www.instagram.com/p/example/")!,
            platform: .instagram,
            mediaKind: .photo
        )
        let data = try JSONEncoder().encode(item)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains("\"videoID\""))
        XCTAssertFalse(json.contains("\"canonicalID\""))
        XCTAssertEqual(try JSONDecoder().decode(DownloadCatalogItem.self, from: data).canonicalID, item.canonicalID)
    }

    func testModuleManifestUsesOnlyApprovedPermissions() throws {
        let manifest = try UniversalDownloaderModuleDefinition.manifest()
        XCTAssertEqual(manifest.identifier, universalDownloaderModuleIdentifier)
        XCTAssertEqual(manifest.version, "0.7.3")
        XCTAssertEqual(manifest.minimumZEUVEVersion, "0.10.4")
        XCTAssertTrue(manifest.permissions.contains(.browserCookies))
        XCTAssertTrue(manifest.permissions.contains(.networkAccess))
        XCTAssertTrue(manifest.permissions.contains(.executeBundledTools))
        XCTAssertFalse(manifest.capabilities.map(\.rawValue).contains("batch"))
    }

    func testNoRuntimeEngineDownloadOrRemoteComponentsExistInSources() throws {
        let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let sourceRoot = project.appendingPathComponent("Sources")
        let files = try FileManager.default.subpathsOfDirectory(atPath: sourceRoot.path).filter { $0.hasSuffix(".swift") || $0.hasSuffix(".c") }
        let source = try files.map { try String(contentsOf: sourceRoot.appendingPathComponent($0), encoding: .utf8) }.joined(separator: "\n")
        XCTAssertFalse(source.contains("--remote-components"))
        XCTAssertFalse(source.contains("downloadEngine"))
        XCTAssertFalse(source.contains("URLSession.shared.downloadTask"))
        XCTAssertFalse(source.contains("/bin/sh"))
    }
}

private final class StaleBookmarkCodec: FolderBookmarkCodec, @unchecked Sendable {
    let folder: URL
    var makeCount = 0
    init(folder: URL) { self.folder = folder }
    func makeBookmark(for url: URL) throws -> Data { makeCount += 1; return Data(url.path.utf8) }
    func resolveBookmark(_ data: Data) throws -> FolderBookmarkResolution { .init(url: folder, isStale: true) }
}

private struct BrokenBookmarkCodec: FolderBookmarkCodec {
    func makeBookmark(for url: URL) throws -> Data { Data() }
    func resolveBookmark(_ data: Data) throws -> FolderBookmarkResolution { throw UniversalDownloaderError.outputFolderUnavailable }
}
