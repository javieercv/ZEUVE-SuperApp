import Foundation
import XCTest
import ZEUVECore
import ZEUVEEngines
@testable import UniversalDownloaderModule

@MainActor
final class DownloaderCorrectionRegressionTests: XCTestCase {
    func testSessionCookieExpiryRoundTripAndInvalidSyntax() throws {
        for expiry in ["", "0", "2000000000"] {
            let text = "# Netscape HTTP Cookie File\n#HttpOnly_.instagram.com\tTRUE\t/\tTRUE\t\(expiry)\tsessionid\tSYNTHETIC\n"
            let cookies = try NetscapeCookieFile.parse(Data(text.utf8))
            XCTAssertEqual(cookies.first?.expires, expiry.isEmpty ? 0 : Int64(expiry))
            let file = try InstagramSessionMaterial.writeSecureNetscapeTemporaryFile(text: text)
            defer { InstagramSessionMaterial.removeTemporaryFile(file) }
            XCTAssertEqual(try Data(contentsOf: file), Data(text.utf8))
            XCTAssertEqual(try DownloadPathValidator.validateCookiesFile(file), file)
        }
        XCTAssertThrowsError(try NetscapeCookieFile.parse(Data(".instagram.com\tTRUE\t/\tTRUE\tbroken\tsessionid\tSYNTHETIC".utf8))) {
            XCTAssertEqual($0 as? UniversalDownloaderError, .invalidCookiesFormat)
        }
        XCTAssertThrowsError(try NetscapeCookieFile.parse(Data("# Netscape HTTP Cookie File\n".utf8))) {
            XCTAssertEqual($0 as? UniversalDownloaderError, .emptyCookiesFile)
        }
    }

    func testGalleryAudioZeroSelectsIdentityAfterAuxiliaryWithoutRenamingContent() throws {
        let input = try UniversalDownloadInputValidator().validate("https://www.tiktok.com/@zeuve/photo/123456")
        let json = """
        [[2,{"id":"123456"}],
         [3,"https://cdn.example/first.jpg",{"num":1,"file_id":"first","extension":"jpg"}],
         [3,"https://cdn.example/second.jpg",{"num":2,"file_id":"second","extension":"jpg"}],
         [3,"https://cdn.example/captions.vtt",{"num":0,"extension":"vtt"}],
         [3,"https://cdn.example/audio.mp3",{"num":0,"file_id":"audio","extension":"mp3"}]]
        """
        let analysis = try GalleryDLAnalysisParser().parse(data: Data(json.utf8), input: input)
        XCTAssertEqual(analysis.playlistEntries.map(\.mediaKind), [.photo, .photo, .audio])
        let audio = try XCTUnwrap(analysis.playlistEntries.last)
        XCTAssertEqual(audio.playlistIndex, 3)
        XCTAssertEqual(audio.gallerySelector?.index, 4)
        let item = UniversalDownloadItem(canonicalID: audio.canonicalID, sourceURL: audio.sourceURL, title: audio.title,
            playlistIndex: audio.playlistIndex, gallerySelector: audio.gallerySelector, mediaKind: .audio, engineKind: .galleryDL, expectedExtension: "mp3")
        let args = try GalleryDLDownloadCommandBuilder().arguments(item: item, settings: .init(mode: .original), downloadDirectory: URL(fileURLWithPath: "/tmp"), cookiesFile: nil, proxy: nil)
        XCTAssertEqual(value("--range", args), "1")
        XCTAssertTrue(try XCTUnwrap(value("--filter", args)).contains("file_id == \"audio\""))
        XCTAssertTrue(try XCTUnwrap(value("--filter", args)).contains("num == 0"))
        XCTAssertTrue(try XCTUnwrap(value("--filename", args)).hasSuffix(".{extension}"))
    }

    func testGalleryDirectoryMetadataBelongsToEachPost() throws {
        let input = try UniversalDownloadInputValidator().validate("@zeuve", platform: .instagram)
        let data = Data("[[2,{\"id\":\"first\"}],[3,\"https://cdn.example/1.jpg\",{\"num\":1,\"extension\":\"jpg\"}],[2,{\"id\":\"second\"}],[3,\"https://cdn.example/2.jpg\",{\"num\":1,\"extension\":\"jpg\"}]]".utf8)
        let entries = try GalleryDLAnalysisParser().parse(data: data, input: input).playlistEntries
        XCTAssertEqual(entries[0].gallerySelector?.identity["id"], "first")
        XCTAssertEqual(entries[1].gallerySelector?.identity["id"], "second")
        XCTAssertNotEqual(entries[0].canonicalID, entries[1].canonicalID)
    }

    func testEmptyYTDLPDoesNotSucceedAndFlatPlaylistReferenceRemainsUsable() throws {
        let parser = YTDLPAnalysisParser()
        let fallback = URL(string: "https://example.com/post")!
        let empty = try parser.parse(data: Data("{\"_type\":\"playlist\",\"id\":\"empty\",\"entries\":[]}".utf8), fallbackURL: fallback)
        XCTAssertFalse(empty.isDownloadable)
        XCTAssertFalse(try parser.parse(data: Data("{\"id\":\"empty\",\"formats\":[]}".utf8), fallbackURL: fallback).isDownloadable)
        let flat = try parser.parse(data: Data("{\"_type\":\"url\",\"id\":\"test\",\"url\":\"https://www.youtube.com/watch?v=test\",\"ie_key\":\"Youtube\"}".utf8))
        XCTAssertTrue(flat.isDownloadable)
    }

    func testProbeRejectsRenamedImageAndKeepsAudioMP4AndMutedVideo() {
        let image = Data("{\"format\":{\"format_name\":\"jpeg_pipe\"},\"streams\":[{\"codec_type\":\"video\"}]}".utf8)
        XCTAssertFalse(DownloadOutputValidator.isCompatibleProbe(image, extensionName: "mp3", expectedKind: .audio))
        let audio = Data("{\"format\":{\"format_name\":\"mov,mp4,m4a,3gp,3g2,mj2\"},\"streams\":[{\"codec_type\":\"audio\"}]}".utf8)
        XCTAssertTrue(DownloadOutputValidator.isCompatibleProbe(audio, extensionName: "mp4", expectedKind: .audio))
        XCTAssertFalse(DownloadOutputValidator.isCompatibleProbe(audio, extensionName: "mp4", expectedKind: .video))
        let video = Data("{\"format\":{\"format_name\":\"mov,mp4\"},\"streams\":[{\"codec_type\":\"video\",\"disposition\":{\"attached_pic\":0}}]}".utf8)
        XCTAssertTrue(DownloadOutputValidator.isCompatibleProbe(video, extensionName: "mp4", expectedKind: .video))
        XCTAssertFalse(DownloadOutputValidator.isCompatibleProbe(video, extensionName: "mp4", expectedKind: .audio))
    }

    func testRealFFprobeRejectsJPEGAsMP3AndAcceptsAudioOnlyMP4() async throws {
        #if os(macOS) && arch(arm64)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("zeuve-output-test-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let ffmpeg = repo.appendingPathComponent("Resources/Engines/ffmpeg/ffmpeg")
        let ffprobe = repo.appendingPathComponent("Resources/Engines/ffmpeg/ffprobe")
        guard FileManager.default.isExecutableFile(atPath: ffmpeg.path) else { throw XCTSkip("FFmpeg incluido no disponible") }
        let jpeg = root.appendingPathComponent("image.jpg")
        let runner = ExternalProcessRunner()
        let generated = try await runner.run(.init(executable: ffmpeg, arguments: ["-v", "error", "-f", "lavfi", "-i", "color=c=red:s=32x32", "-frames:v", "1", jpeg.path]))
        XCTAssertTrue(generated.succeeded)
        let fake = root.appendingPathComponent("fake.mp3")
        try FileManager.default.copyItem(at: jpeg, to: fake)
        do { try await DownloadOutputValidator().verifyMediaFiles([fake], ffprobe: ffprobe, expectedKind: .audio); XCTFail("JPEG aceptado como MP3") }
        catch { XCTAssertEqual(error as? UniversalDownloaderError, .noPublishedFiles) }
        let audio = root.appendingPathComponent("audio.mp4")
        let generatedAudio = try await runner.run(.init(executable: ffmpeg, arguments: ["-v", "error", "-f", "lavfi", "-i", "anullsrc=r=44100:cl=mono", "-t", "0.1", "-c:a", "aac", audio.path]))
        XCTAssertTrue(generatedAudio.succeeded)
        try await DownloadOutputValidator().verifyMediaFiles([audio], ffprobe: ffprobe, expectedKind: .audio)
        let subtitle = root.appendingPathComponent("only.vtt")
        try Data("WEBVTT\n".utf8).write(to: subtitle)
        do { try await DownloadOutputValidator().verifyMediaFiles([subtitle], ffprobe: ffprobe); XCTFail("Auxiliar aceptado como contenido") }
        catch { XCTAssertEqual(error as? UniversalDownloaderError, .noPublishedFiles) }
        #else
        throw XCTSkip("Los motores incluidos requieren macOS Apple Silicon")
        #endif
    }

    func testDiagnosticsNeverPersistFreeTextOrPrivateURL() throws {
        let raw = ["error": "failed https://example.com/private?token=SYNTHETIC_CANARY", "url": "https://example.com/SYNTHETIC_CANARY", "id": "SYNTHETIC_CANARY", "motor": "gallery-dl", "archivos": "2", "referencia": "YT-12345678", "sesion_aportada": "sí"]
        let safe = DownloadDiagnosticMetadata.sanitized(raw)
        XCTAssertFalse(String(decoding: try JSONEncoder().encode(safe), as: UTF8.self).contains("SYNTHETIC_CANARY"))
        XCTAssertNil(safe["error"])
        XCTAssertEqual(safe["motor"], "gallery-dl")
        XCTAssertEqual(safe["archivos"], "2")
        XCTAssertNotNil(safe["categoria"])
    }

    func testAnalysisServiceLogsSuccessErrorAndFallbackWithoutCanaries() async throws {
        #if os(macOS) && arch(arm64)
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let registry = try EngineRegistry(resourceRoot: repo.appendingPathComponent("Resources/Engines"))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("zeuve-log-test-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let manager = EngineOverrideManager(root: root.appendingPathComponent("overrides"))
        let canary = "SYNTHETIC_LOG_CANARY"
        let helper = root.appendingPathComponent("catalog-fixture.py")
        let gallery = root.appendingPathComponent("gallery-fixture.py")
        let failure = "#!/usr/bin/env python3\nimport sys\nprint('failed https://example.com/private?token=\(canary) password=\(canary) sessionid=\(canary)', file=sys.stderr)\nsys.exit(22)\n"
        try Data(failure.utf8).write(to: gallery)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: gallery.path)
        try manager.installLocalExecutable(named: "gallery-dl", version: "fixture", source: gallery, channel: .stable)
        let logs = root.appendingPathComponent("logs")
        let logger = try LocalLogger(directory: logs)
        let input = try UniversalDownloadInputValidator().validate("@zeuve", platform: .instagram)
        for succeeds in [false, true] {
            let success = """
            #!/usr/bin/env python3
            import json
            print(json.dumps({"record":"profile","username":"zeuve","is_private":False,"requires_authentication":False}))
            print(json.dumps({"record":"media","section":"posts","id":"synthetic","kind":"photo","media_url":"https://cdn.example/image.jpg?token=\(canary)","extension":"jpg"}))
            """
            try Data((succeeds ? success : failure).utf8).write(to: helper)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helper.path)
            try manager.installLocalExecutable(named: "instaloader-zeuve", version: succeeds ? "success" : "failure", source: helper, channel: .stable)
            let service = UniversalDownloadAnalysisService(locator: .init(registry: registry, overrideManager: manager), logger: logger)
            do {
                let result = try await service.analyze(input)
                XCTAssertTrue(succeeds)
                XCTAssertTrue(result.hasUsableMedia)
            } catch { XCTAssertFalse(succeeds) }
        }
        let entries = try FileManager.default.contentsOfDirectory(at: logs, includingPropertiesForKeys: nil)
            .map { try String(contentsOf: $0, encoding: .utf8) }.joined()
        XCTAssertTrue(entries.contains("fallback"))
        XCTAssertTrue(entries.contains("Inicio del análisis"))
        XCTAssertFalse(entries.contains(canary))
        XCTAssertFalse(entries.contains("cdn.example"))
        XCTAssertFalse(entries.contains("example.com/private"))
        #else
        throw XCTSkip("El diagnóstico de motores incluidos requiere macOS Apple Silicon")
        #endif
    }

    func testTumblrConcreteFormsAndProfiles() throws {
        let validator = UniversalDownloadInputValidator()
        for url in ["https://www.tumblr.com/nasa/178184776089/title", "https://nasa.tumblr.com/post/178184776089/title", "https://nasa.tumblr.com/image/178184776089"] {
            XCTAssertEqual(try validator.validate(url).canonicalID, "tumblr:178184776089")
        }
        for url in ["https://www.tumblr.com/nasa", "https://www.tumblr.com/search/example", "https://nasa.tumblr.com/tagged/123"] {
            XCTAssertThrowsError(try validator.validate(url))
        }
    }

    func testXVariantsShareResourceIdentityButDistinctVideosRemainDistinct() {
        func entry(_ id: String, _ dimensions: String) -> DownloadCatalogItem {
            let url = URL(string: "https://video.twimg.com/ext_tw_video/\(id)/pu/vid/\(dimensions)/file.mp4")!
            return .init(canonicalID: "variant:\(dimensions)", title: "Same title", sourceURL: URL(string: "https://x.com/zeuve/status/123")!, resolvedMedia: .init(mediaURL: url, kind: .directFile), platform: .x, mediaKind: .video)
        }
        XCTAssertEqual(DownloadMediaIdentity.key(for: entry("900", "320x180")), DownloadMediaIdentity.key(for: entry("900", "1280x720")))
        XCTAssertNotEqual(DownloadMediaIdentity.key(for: entry("900", "320x180")), DownloadMediaIdentity.key(for: entry("901", "320x180")))
        XCTAssertGreaterThan(DownloadMediaIdentity.qualityRank(for: entry("900", "1280x720")), DownloadMediaIdentity.qualityRank(for: entry("900", "320x180")))
    }

    func testEroMeDiscoveryIncludesOriginalImagesWithoutAvatarsOrVideoPosters() {
        let html = """
        <img class="avatar" src="https://cdn.example/avatar.jpg">
        <div class="media-group"><video><source src="https://cdn.example/one.mp4"></video><img class="img-front" src="https://cdn.example/poster.jpg"></div>
        <div class="media-group"><img class="img-front" data-src="https://cdn.example/two.jpg"></div>
        """
        let result = UniversalHTMLMediaParser().parse(html: html, baseURL: URL(string: "https://www.erome.com/a/Album")!)
        XCTAssertEqual(result.candidates.map { $0.url.lastPathComponent }, ["one.mp4", "two.jpg"])
        let generic = UniversalHTMLMediaParser().parse(html: html, baseURL: URL(string: "https://example.com/page")!)
        XCTAssertFalse(generic.candidates.contains { $0.url.pathExtension == "jpg" })
    }

    func testBudgetCancelsPendingOperation() async throws {
        do {
            let _: Int = try await AnalysisExecutionBudget.run(seconds: 0.02) { try await Task.sleep(for: .seconds(5)); return 1 }
            XCTFail("Presupuesto no aplicado")
        } catch { XCTAssertEqual(error as? UniversalDownloaderError, .analysisTimedOut) }
    }

    func testMergeKeepsHighestXVariantAndOriginalGallerySelector() throws {
        let input = try UniversalDownloadInputValidator().validate("https://x.com/zeuve/status/123")
        let low = URL(string: "https://video.twimg.com/ext_tw_video/900/pu/vid/320x180/file.mp4")!
        let high = URL(string: "https://video.twimg.com/ext_tw_video/900/pu/vid/1280x720/file.mp4")!
        let entries = [low, high].enumerated().map { index, url in
            DownloadCatalogItem(canonicalID: "variant:\(index)", title: "Video", sourceURL: input.canonicalURL,
                resolvedMedia: .init(mediaURL: url, kind: .directFile), platform: .x, mediaKind: .video)
        }
        let analysis = DownloadAnalysis(canonicalID: "post", kind: .playlist, title: "Post", playlistEntries: entries)
        let merged = UniversalDownloadAnalysisService.merge([analysis], input: input, pageTitle: nil, discoveryDuplicateCount: 0)
        XCTAssertEqual(merged.playlistEntries.count, 1)
        XCTAssertEqual(merged.playlistEntries.first?.resolvedMedia?.mediaURL, high)
        XCTAssertEqual(merged.duplicateCount, 1)
        let galleryEntry = DownloadCatalogItem(canonicalID: "gallery:item", playlistIndex: 3, gallerySelector: .init(index: 4, identity: ["num": "0", "file_id": "audio"]), title: "Audio", sourceURL: input.canonicalURL, mediaKind: .audio)
        let gallery = DownloadAnalysis(canonicalID: "gallery", kind: .gallery, title: "Gallery", playlistEntries: [galleryEntry])
        let preserved = UniversalDownloadAnalysisService.merge([gallery], input: input, pageTitle: nil, discoveryDuplicateCount: 0)
        XCTAssertEqual(preserved.playlistEntries.first?.gallerySelector, galleryEntry.gallerySelector)
    }

    func testPublicProfileStoriesCarryAuthenticationAndSectionFailuresRemainPartial() throws {
        let input = try UniversalDownloadInputValidator().validate("@zeuve", platform: .instagram)
        let records = """
        {"record":"profile","username":"zeuve","is_private":false,"requires_authentication":false,"session_supplied":true,"session_validated":true}
        {"record":"media","section":"stories","id":"story-1","index":1,"kind":"storyPhoto","media_url":"https://cdn.example/story.jpg","extension":"jpg"}
        {"record":"warning","section":"posts","code":"section_request_blocked","message":"token=SYNTHETIC_CANARY"}
        """
        let parsed = try InstagramCatalogParser().parseResult(data: Data(records.utf8), input: input)
        XCTAssertFalse(parsed.analysis.requiresAuthentication)
        XCTAssertEqual(parsed.analysis.playlistEntries.first?.requiresAuthentication, true)
        XCTAssertEqual(parsed.issueCode, "catalog_partial")
        XCTAssertEqual(parsed.analysis.availability, "partial")
        XCTAssertFalse(parsed.analysis.description?.contains("SYNTHETIC_CANARY") == true)
        XCTAssertTrue(InstagramCatalogCommandBuilder.requiresSession(URL(string: "https://www.instagram.com/stories/highlights/123/")!))
        XCTAssertFalse(InstagramCatalogCommandBuilder.requiresSession(URL(string: "https://www.instagram.com/p/PublicPost/")!))
    }

    private func value(_ option: String, _ args: [String]) -> String? {
        guard let index = args.firstIndex(of: option), args.indices.contains(index + 1) else { return nil }
        return args[index + 1]
    }
}
