import Foundation
import XCTest
import ZEUVECore
import ZEUVEEngines
@testable import UniversalDownloaderModule

@MainActor
final class DownloaderFollowupRegressionTests: XCTestCase {
    func testSessionRateLimitDoesNotStartAnotherEngine() async throws {
        #if os(macOS) && arch(arm64)
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("zeuve-session-rate-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let helper = root.appendingPathComponent("catalog.py")
        try Data("#!/usr/bin/env python3\nprint('{\"record\":\"error\",\"code\":\"session_request_blocked\",\"message\":\"Espera antes de reintentar\",\"requires_authentication\":false,\"session_supplied\":true,\"session_validated\":null}')\n".utf8).write(to: helper)
        let gallery = root.appendingPathComponent("gallery.py")
        let marker = root.appendingPathComponent("unexpected-fallback")
        try Data("#!/usr/bin/env python3\nfrom pathlib import Path\nPath(\(String(decoding: try JSONEncoder().encode(marker.path), as: UTF8.self))).touch()\n".utf8).write(to: gallery)
        for file in [helper, gallery] { try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path) }
        let overrides = EngineOverrideManager(root: root.appendingPathComponent("overrides"))
        try overrides.installLocalExecutable(named: "instaloader-zeuve", version: "fixture", source: helper, channel: .stable)
        try overrides.installLocalExecutable(named: "gallery-dl", version: "fixture", source: gallery, channel: .stable)
        let registry = try EngineRegistry(resourceRoot: repo.appendingPathComponent("Resources/Engines"))
        let input = try UniversalDownloadInputValidator().validate("@zeuve", platform: .instagram)
        let result = try await UniversalDownloadAnalysisService(locator: .init(registry: registry, overrideManager: overrides)).analyze(input)
        XCTAssertFalse(result.hasUsableMedia)
        XCTAssertFalse(result.requiresAuthentication)
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
        #else
        throw XCTSkip("Integración con motores incluidos requiere macOS ARM64")
        #endif
    }

    func testAudioTypeSurvivesAnalysisAnnotationAndMerge() async throws {
        #if os(macOS) && arch(arm64)
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("zeuve-audio-type-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = root.appendingPathComponent("yt-fixture.py")
        try Data("#!/usr/bin/env python3\nprint('{\"id\":\"audio\",\"title\":\"Audio\",\"vcodec\":\"none\",\"acodec\":\"aac\",\"formats\":[{\"format_id\":\"hls\",\"vcodec\":\"none\",\"acodec\":\"aac\",\"ext\":\"mp4\"}]}')\n".utf8).write(to: fixture)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fixture.path)
        let overrides = EngineOverrideManager(root: root.appendingPathComponent("overrides"))
        try overrides.installLocalExecutable(named: "yt-dlp", version: "fixture", source: fixture, channel: .stable)
        let registry = try EngineRegistry(resourceRoot: repo.appendingPathComponent("Resources/Engines"))
        let input = try UniversalDownloadInputValidator().validate("https://soundcloud.com/zeuve/audio.mp4")
        let analysis = try await UniversalDownloadAnalysisService(locator: .init(registry: registry, overrideManager: overrides)).analyze(input)
        XCTAssertEqual(analysis.mediaKind, .audio)
        XCTAssertTrue(analysis.hasUsableMedia)
        let playlist = try YTDLPAnalysisParser().parse(data: Data("{\"_type\":\"playlist\",\"id\":\"list\",\"entries\":[{\"id\":\"audio\",\"url\":\"https://example.com/audio.mp4\",\"vcodec\":\"none\",\"acodec\":\"aac\"}]}".utf8))
        XCTAssertEqual(playlist.playlistEntries.first?.mediaKind, .audio)
        let video = try YTDLPAnalysisParser().parse(data: Data("{\"id\":\"video\",\"vcodec\":\"avc1\",\"acodec\":\"aac\"}".utf8))
        XCTAssertEqual(video.mediaKind, .video)
        #else
        throw XCTSkip("Integración con motores incluidos requiere macOS ARM64")
        #endif
    }

    func testGalleryAudioNormalizationPreservesBytesAndRejectsDisguisedImage() async throws {
        #if os(macOS) && arch(arm64)
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let ffmpeg = repo.appendingPathComponent("Resources/Engines/ffmpeg/ffmpeg")
        let ffprobe = repo.appendingPathComponent("Resources/Engines/ffmpeg/ffprobe")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("zeuve-gallery-audio-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("original.mp4")
        let result = try await ExternalProcessRunner().run(.init(executable: ffmpeg, arguments: ["-v", "error", "-f", "lavfi", "-i", "anullsrc=r=44100:cl=mono", "-t", "0.1", "-c:a", "aac", source.path]))
        XCTAssertTrue(result.succeeded)
        let wrong = root.appendingPathComponent("audio.mp3")
        try FileManager.default.copyItem(at: source, to: wrong)
        let normalized = try await DownloadOutputValidator().normalizeGalleryAudioFiles([wrong], ffprobe: ffprobe)
        XCTAssertEqual(normalized.first?.pathExtension, "m4a")
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(normalized.first)), try Data(contentsOf: source))
        try await DownloadOutputValidator().verifyMediaFiles(normalized, ffprobe: ffprobe, expectedKind: .audio)
        try FileManager.default.copyItem(at: source, to: wrong)
        do {
            _ = try await DownloadOutputValidator().normalizeGalleryAudioFiles([wrong], ffprobe: ffprobe)
            XCTFail("Conflicto sustituido silenciosamente")
        } catch { XCTAssertEqual(error as? UniversalDownloaderError, .overwriteNotConfirmed) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: wrong.path))
        let image = root.appendingPathComponent("fake.mp3")
        try Data([0xFF, 0xD8, 0xFF, 0xE0]).write(to: image)
        let unchanged = try await DownloadOutputValidator().normalizeGalleryAudioFiles([image], ffprobe: ffprobe)
        XCTAssertEqual(unchanged, [image])
        do { try await DownloadOutputValidator().verifyMediaFiles(unchanged, ffprobe: ffprobe, expectedKind: .audio); XCTFail("Imagen aceptada como audio") }
        catch { XCTAssertEqual(error as? UniversalDownloaderError, .noPublishedFiles) }
        #else
        throw XCTSkip("FFmpeg incluido requiere macOS ARM64")
        #endif
    }

    func testXGenericFallbackVariantsMergeWithGalleryByCDNIdentity() throws {
        let input = try UniversalDownloadInputValidator().validate("https://x.com/zeuve/status/123")
        func entry(_ id: String, _ path: String, platform: UniversalDownloadPlatform, selector: GalleryDLResourceSelector? = nil) -> DownloadCatalogItem {
            .init(canonicalID: "\(platform):\(path)", gallerySelector: selector, title: "Identical title", sourceURL: input.canonicalURL,
                resolvedMedia: .init(mediaURL: URL(string: "https://video.twimg.com/amplify_video/\(id)/\(path)")!, kind: .directFile), platform: platform, mediaKind: .video)
        }
        let selector = GalleryDLResourceSelector(index: 1, identity: ["num": "1"])
        let gallery = entry("900", "vid/1280x720/high.mp4", platform: .x, selector: selector)
        let generic = [entry("900", "vid/640x360/low.mp4", platform: .webpage), entry("900", "pl/master.m3u8", platform: .automatic), entry("901", "vid/640x360/other.mp4", platform: .webpage)]
        let analyses = [DownloadAnalysis(canonicalID: "gallery", kind: .gallery, title: "Post", playlistEntries: [gallery]), DownloadAnalysis(canonicalID: "generic", kind: .playlist, title: "Post", playlistEntries: generic)]
        let merged = UniversalDownloadAnalysisService.merge(analyses, input: input, pageTitle: nil, discoveryDuplicateCount: 0)
        XCTAssertEqual(merged.playlistEntries.count, 2)
        XCTAssertEqual(merged.duplicateCount, 2)
        XCTAssertEqual(merged.playlistEntries.first?.gallerySelector, selector)
        XCTAssertEqual(merged.playlistEntries.first?.resolvedMedia?.mediaURL, gallery.resolvedMedia?.mediaURL)
    }

    func testTumblrHTMLUsesOnlyRequestedPostOriginalBlocks() throws {
        let post: [String: Any] = ["idString": "123456", "content": [
            ["type": "image", "media": [["type": "image/png", "width": 640, "height": 400, "url": "https://64.media.tumblr.com/small.pnj"], ["type": "image/png", "width": 1280, "height": 800, "url": "https://64.media.tumblr.com/original.pnj"]]],
            ["type": "video", "embedUrl": "https://www.youtube.com/embed/Video123"]
        ]]
        let unrelated: [String: Any] = ["idString": "999", "content": [["type": "image", "media": [["type": "image/jpeg", "url": "https://64.media.tumblr.com/unrelated.jpg"]]]]]
        let json = String(decoding: try JSONSerialization.data(withJSONObject: ["posts": [post, unrelated]]), as: UTF8.self)
        let html = "<img src='https://64.media.tumblr.com/avatar.jpg'><script type='application/json' id='___INITIAL_STATE___'>\(json)</script><video src='https://example.com/recommended.mp4'></video>"
        let url = URL(string: "https://www.tumblr.com/zeuve/123456/title")!
        let parsed = UniversalHTMLMediaParser().parse(html: html, baseURL: url)
        XCTAssertEqual(parsed.candidates.map { $0.url.lastPathComponent }, ["original.pnj", "Video123"])
        XCTAssertEqual(parsed.candidates.first?.mediaKind, .photo)
        XCTAssertEqual(try UniversalDownloadInputValidator().validate(parsed.candidates[0].url.absoluteString).platform, .webpage)
        let generic = UniversalHTMLMediaParser().parse(html: html, baseURL: URL(string: "https://example.com/page")!)
        XCTAssertFalse(generic.candidates.contains { $0.mediaKind == .photo })
    }
}
