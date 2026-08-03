import Foundation
import XCTest
@testable import YouTubeDownloaderModule
import ZEUVECore
import ZEUVEStorage

final class YouTubeFilesStorageAndManifestTests: XCTestCase {
    private var root: URL!
    private var settings: SettingsRepository!
    private var history: HistoryRepository!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("ZEUVE-YouTubeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let database = try SQLiteDatabase(url: root.appendingPathComponent("data.sqlite"))
        settings = try SettingsRepository(database: database)
        history = try HistoryRepository(database: database)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    func testFilenameSanitizationLongNamesAndAutomaticRename() throws {
        let policy = YouTubeFilenamePolicy()
        let safe = try policy.sanitize(" ../Vídeo: prueba/.. ")
        XCTAssertFalse(safe.contains("/"))
        XCTAssertFalse(safe.hasPrefix("."))
        let long = try policy.sanitize(String(repeating: "á", count: 500), maximumUTF8Bytes: 80)
        XCTAssertLessThanOrEqual(long.utf8.count, 80)
        let existing = root.appendingPathComponent("video.mp4")
        try Data("original".utf8).write(to: existing)
        XCTAssertEqual(try policy.automaticRename(for: existing).lastPathComponent, "video (2).mp4")
    }

    func testTemporaryWorkspaceOwnershipCleanupAndForeignFiles() throws {
        let base = root.appendingPathComponent("temp", isDirectory: true)
        let workspace = try YouTubeTemporaryWorkspace(operationID: UUID(), baseDirectory: base)
        try Data("part".utf8).write(to: workspace.download.appendingPathComponent("video.part"))
        let foreign = root.appendingPathComponent("foreign.txt")
        try Data("keep".utf8).write(to: foreign)
        try workspace.clean()
        XCTAssertFalse(FileManager.default.fileExists(atPath: workspace.root.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: foreign.path))
    }

    func testPublisherNeverPublishesPartAndRenamesByDefault() throws {
        let workspace = try YouTubeTemporaryWorkspace(operationID: UUID(), baseDirectory: root.appendingPathComponent("temp"))
        try Data("valid".utf8).write(to: workspace.download.appendingPathComponent("video.mp4"))
        try Data("partial".utf8).write(to: workspace.download.appendingPathComponent("video.part"))
        let output = root.appendingPathComponent("output", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try Data("existing".utf8).write(to: output.appendingPathComponent("video.mp4"))
        let publisher = YouTubeOutputPublisher()
        let candidates = try publisher.candidateFiles(in: workspace)
        XCTAssertEqual(candidates.map(\.lastPathComponent), ["video.mp4"])
        let published = try publisher.publish(files: candidates, to: output, policy: .renameAutomatically)
        XCTAssertEqual(published.first?.lastPathComponent, "video (2).mp4")
        XCTAssertEqual(try String(contentsOf: output.appendingPathComponent("video.mp4"), encoding: .utf8), "existing")
    }

    func testPublisherRejectsSymbolicLinksEvenWhenTheyPointToRegularFiles() throws {
        let workspace = try YouTubeTemporaryWorkspace(operationID: UUID(), baseDirectory: root.appendingPathComponent("temp"))
        let foreign = root.appendingPathComponent("foreign-video.mp4")
        try Data("foreign".utf8).write(to: foreign)
        let link = workspace.download.appendingPathComponent("linked.mp4")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: foreign)
        XCTAssertTrue(try YouTubeOutputPublisher().candidateFiles(in: workspace).isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: foreign.path))
    }

    func testBookmarkStaleRefreshAndInvalidBookmarkRemoval() throws {
        let folder = root.appendingPathComponent("output", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let codec = StaleBookmarkCodec(folder: folder)
        let store = SecurityScopedFolderBookmarkStore(settings: settings, codec: codec)
        try store.save(folder)
        XCTAssertEqual(try store.resolve(), folder.standardizedFileURL)
        XCTAssertGreaterThanOrEqual(codec.makeCount, 2)

        let broken = SecurityScopedFolderBookmarkStore(settings: settings, codec: BrokenBookmarkCodec())
        try settings.set(Data("broken".utf8), forKey: "youtubeDownloader.outputFolderBookmark")
        XCTAssertNil(try broken.resolve())
        XCTAssertNil(try settings.value(forKey: "youtubeDownloader.outputFolderBookmark", as: Data.self))
    }


    func testPresetSchemaOneMigratesWithoutLosingSettings() throws {
        var legacySettings = YouTubeDownloadSettings(
            mode: .audio,
            container: .automatic,
            audioOutput: .mp3,
            filenamePreset: .titleAndID
        )
        legacySettings.mp3Bitrate = .kbps192
        let legacy = YouTubePreset(
            schemaVersion: 1,
            name: "Preset antiguo",
            settings: legacySettings
        )
        try settings.set([legacy], forKey: "youtubeDownloader.presets")

        let migrated = try YouTubePresetService(settings: settings).load()
        XCTAssertEqual(migrated.count, 1)
        XCTAssertEqual(migrated[0].schemaVersion, YouTubePresetService.currentSchemaVersion)
        XCTAssertEqual(migrated[0].settings.container, .automatic)
        XCTAssertEqual(migrated[0].settings.audioOutput, .mp3)
        XCTAssertEqual(migrated[0].settings.mp3Bitrate, .kbps192)
        XCTAssertEqual(migrated[0].settings.filenamePreset, .titleAndID)
    }

    func testPresetSchemaAndStoredDataContainNoSecretsOrFreeArguments() throws {
        let service = YouTubePresetService(settings: settings)
        let presets = try service.load()
        XCTAssertEqual(presets.count, 7)
        XCTAssertTrue(presets.allSatisfy { $0.schemaVersion == YouTubePresetService.currentSchemaVersion })
        let encoded = String(decoding: try JSONEncoder().encode(presets), as: UTF8.self).lowercased()
        for forbidden in ["cookies", "password", "token", "header", "arguments", "proxyusername"] {
            XCTAssertFalse(encoded.contains(forbidden))
        }
    }

    func testHistoryStoresCanonicalIDsButNoURLOrSecrets() throws {
        let result = YouTubeOperationResult(
            id: UUID(), startedAt: Date(timeIntervalSince1970: 1), finishedAt: Date(timeIntervalSince1970: 2), outputFolder: root,
            mode: .video, formatSummary: "Mejor calidad", items: [.init(canonicalID: "abc12345678", title: "Título", status: .completed)], wasCancelled: false
        )
        let record = try YouTubeHistoryService(repository: history).save(result)
        let text = String(decoding: record.payload, as: UTF8.self).lowercased()
        XCTAssertTrue(text.contains("abc12345678"))
        XCTAssertFalse(text.contains("youtube.com"))
        XCTAssertFalse(text.contains("googlevideo"))
        XCTAssertFalse(text.contains("cookie"))
        XCTAssertFalse(text.contains("token"))
    }

    func testSanitizedInformationAndPlaylistJSONContainNoURLsOrSecrets() throws {
        let item = YouTubeDownloadItem(
            canonicalID: "abc12345678",
            sourceURL: URL(string: "https://www.youtube.com/watch?v=abc12345678&token=secret")!,
            title: "Título",
            playlistTitle: "Lista",
            playlistIndex: 1
        )
        let writer = YouTubeSafeMetadataWriter()
        let info = try writer.writeInfo(
            for: item,
            settings: YouTubeDownloadSettings(),
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

    func testModuleManifestUsesOnlyApprovedPermissions() throws {
        let manifest = try YouTubeDownloaderModuleDefinition.manifest()
        XCTAssertEqual(manifest.identifier, youtubeDownloaderModuleIdentifier)
        XCTAssertEqual(manifest.version, "0.4.1")
        XCTAssertEqual(manifest.minimumZEUVEVersion, "0.2.0")
        XCTAssertFalse(manifest.permissions.contains(.browserCookies))
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
    func resolveBookmark(_ data: Data) throws -> BookmarkResolution { .init(url: folder, isStale: true) }
}

private struct BrokenBookmarkCodec: FolderBookmarkCodec {
    func makeBookmark(for url: URL) throws -> Data { Data() }
    func resolveBookmark(_ data: Data) throws -> BookmarkResolution { throw YouTubeDownloaderError.outputFolderUnavailable }
}
