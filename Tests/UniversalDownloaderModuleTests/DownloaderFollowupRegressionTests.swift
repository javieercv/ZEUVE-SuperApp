import Foundation
import XCTest
import ZEUVECore
import ZEUVEEngines
@testable import UniversalDownloaderModule

@MainActor
final class DownloaderFollowupRegressionTests: XCTestCase {
    func testPublicProfileOffersOptionalSessionWithoutChangingAvailability() throws {
        let input = try UniversalDownloadInputValidator().validate("@zeuve", platform: .instagram)
        let records = #"""
        {"record":"profile","username":"zeuve","biography":"Biografía pública","is_private":null,"requires_authentication":false,"profile_picture_url":"https://cdn.example/avatar.jpg"}
        {"record":"media","section":"profile","id":"profile-zeuve","kind":"profilePicture","media_url":"https://cdn.example/avatar.jpg"}
        {"record":"warning","section":"posts","code":"public_header_only"}
        {"record":"warning","section":"reels","code":"public_header_only"}
        {"record":"warning","section":"stories","code":"section_requires_authentication"}
        {"record":"warning","section":"highlights","code":"section_requires_authentication"}
        """#
        let parsed = try InstagramCatalogParser().parseResult(data: Data(records.utf8), input: input)
        XCTAssertEqual(parsed.analysis.instagramSessionPresentation, .optional)
        XCTAssertFalse(parsed.analysis.requiresAuthentication)
        XCTAssertFalse(parsed.analysis.isPrivateProfile)
        XCTAssertTrue(parsed.analysis.isDownloadable)
        XCTAssertEqual(parsed.analysis.availability, "partial")
        XCTAssertEqual(Set(parsed.analysis.authenticationRestrictedSections ?? []), [.stories, .highlights])
        let description = try XCTUnwrap(parsed.analysis.description)
        XCTAssertTrue(description.contains("Biografía pública"))
        XCTAssertEqual(description.components(separatedBy: "Solo se ha recuperado").count - 1, 1)
    }

    func testSessionPresentationSeparatesProtectedContentFromUnverifiedPublicLookup() {
        let protected = DownloadAnalysis(canonicalID: "story", kind: .gallery, title: "Story", platform: .instagram, requiresAuthentication: true)
        XCTAssertEqual(protected.instagramSessionPresentation, .required)
        let blocked = DownloadAnalysis(canonicalID: "profile", kind: .profile, title: "Perfil", availability: "unavailable", platform: .instagram)
        XCTAssertEqual(blocked.instagramSessionPresentation, .optional)
        let publicPost = DownloadAnalysis(canonicalID: "post", kind: .gallery, title: "Foto", platform: .instagram)
        XCTAssertEqual(publicPost.instagramSessionPresentation, .none)
        let otherPlatform = DownloadAnalysis(canonicalID: "video", kind: .video, title: "Vídeo", platform: .youtube, requiresAuthentication: true)
        XCTAssertEqual(otherPlatform.instagramSessionPresentation, .none)
    }

    func testPublicEmbedIsPartialAndDoesNotRetryBlockedFeedThroughAnotherEngine() async throws {
        #if os(macOS) && arch(arm64)
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("zeuve-public-embed-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let records = #"""
        {"record":"profile","username":"zeuve","userid":"123","biography":"Biografía pública","is_private":false,"requires_authentication":false,"catalog_source":"public_embed","public_embed_posts_count":6,"media_count":999}
        {"record":"media","section":"posts","id":"1","kind":"photo","index":3,"media_url":"https://cdn.example/photo.jpg","extension":"jpg"}
        {"record":"warning","section":"posts","code":"public_embed_limited"}
        {"record":"warning","section":"reels","code":"public_embed_videos_unavailable"}
        {"record":"warning","section":"stories","code":"section_requires_authentication"}
        {"record":"page","known_total":35,"has_more":true,"next_cursor":"24"}
        """#
        let input = try UniversalDownloadInputValidator().validate("@zeuve", platform: .instagram)
        let parsed = try InstagramCatalogParser().parseResult(data: Data(records.utf8), input: input)
        XCTAssertEqual(parsed.issueCode, "catalog_partial")
        XCTAssertEqual(parsed.analysis.availability, "partial")
        XCTAssertEqual(parsed.analysis.extractor, "instagram-public-embed")
        XCTAssertEqual(parsed.analysis.instagramSessionPresentation, .optional)
        XCTAssertEqual(parsed.analysis.playlistCount, 35)
        XCTAssertEqual(parsed.analysis.playlistEntries.first?.playlistIndex, 3)
        XCTAssertTrue(parsed.analysis.description?.contains("Biografía pública") == true)
        XCTAssertTrue(parsed.analysis.description?.contains("6 publicaciones") == true)
        XCTAssertTrue(parsed.analysis.description?.contains("miniaturas no se incluyen") == true)
        let helper = root.appendingPathComponent("catalog.py")
        let literal = String(decoding: try JSONEncoder().encode(records), as: UTF8.self)
        try Data("#!/usr/bin/env python3\nprint(\(literal))\n".utf8).write(to: helper)
        let gallery = root.appendingPathComponent("gallery.py")
        let marker = root.appendingPathComponent("unexpected-feed-retry")
        try Data("#!/usr/bin/env python3\nfrom pathlib import Path\nPath(\(String(decoding: try JSONEncoder().encode(marker.path), as: UTF8.self))).touch()\n".utf8).write(to: gallery)
        for file in [helper, gallery] { try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path) }
        let overrides = EngineOverrideManager(root: root.appendingPathComponent("overrides"))
        try overrides.installLocalExecutable(named: "instaloader-zeuve", version: "fixture", source: helper, channel: .stable)
        try overrides.installLocalExecutable(named: "gallery-dl", version: "fixture", source: gallery, channel: .stable)
        let registry = try EngineRegistry(resourceRoot: repo.appendingPathComponent("Resources/Engines"))
        let result = try await UniversalDownloadAnalysisService(locator: .init(registry: registry, overrideManager: overrides)).analyze(input)
        XCTAssertTrue(result.hasUsableMedia)
        XCTAssertEqual(result.extractor, "instagram-public-embed")
        XCTAssertFalse(result.requiresAuthentication)
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
        #else
        throw XCTSkip("Integración con motores incluidos requiere macOS ARM64")
        #endif
    }

    func testEnrichedPublicCatalogPreservesReelsAndCarouselVideoWithoutSession() throws {
        let input = try UniversalDownloadInputValidator().validate("@zeuve", platform: .instagram)
        let records = #"""
        {"record":"profile","username":"zeuve","userid":"123","is_private":false,"requires_authentication":false,"catalog_source":"public_embed","public_embed_posts_count":6}
        {"record":"media","section":"reels","id":"901","post_id":"901","shortcode":"REEL123","kind":"reel","index":1,"media_url":"https://cdn.example/reel.mp4","source_page":"https://www.instagram.com/reel/REEL123/","requires_authentication":false,"extension":"mp4"}
        {"record":"media","section":"posts","id":"1001","post_id":"900","shortcode":"POST123","kind":"video","index":6,"media_url":"https://cdn.example/child.mp4","source_page":"https://www.instagram.com/p/POST123/","requires_authentication":false,"extension":"mp4"}
        {"record":"warning","section":"posts","code":"public_embed_limited"}
        {"record":"page","known_total":42,"has_more":true,"next_cursor":"24"}
        """#
        let parsed = try InstagramCatalogParser().parseResult(data: Data(records.utf8), input: input)
        XCTAssertEqual(parsed.analysis.instagramSessionPresentation, .optional)
        XCTAssertFalse(parsed.analysis.requiresAuthentication)
        XCTAssertEqual(parsed.analysis.availability, "partial")
        XCTAssertEqual(Set(parsed.analysis.availableSections), [.reels, .videos])
        let reel = try XCTUnwrap(parsed.analysis.playlistEntries.first)
        XCTAssertEqual(reel.mediaKind, .reel)
        XCTAssertEqual(reel.catalogSection, .reels)
        XCTAssertEqual(reel.requiresAuthentication, false)
        XCTAssertEqual(reel.resolvedMedia?.mediaURL?.pathExtension, "mp4")
        XCTAssertEqual(reel.folderComponents, ["Instagram", "zeuve", "Reels"])
        let child = try XCTUnwrap(parsed.analysis.playlistEntries.last)
        XCTAssertEqual(child.canonicalID, "instagram:1001")
        XCTAssertEqual(child.playlistIndex, 6)
        XCTAssertEqual(child.mediaKind, .video)
        XCTAssertEqual(child.catalogSection, .videos)
        XCTAssertEqual(child.requiresAuthentication, false)
    }

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
