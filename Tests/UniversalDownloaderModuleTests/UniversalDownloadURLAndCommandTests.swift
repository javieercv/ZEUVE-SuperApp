import Foundation
import XCTest
@testable import UniversalDownloaderModule

final class UniversalDownloadURLAndCommandTests: XCTestCase {
    private let engines = DownloadEnginePaths(
        ytDLP: URL(fileURLWithPath: "/Applications/ZEUVE.app/Contents/Resources/Engines/yt-dlp/yt-dlp_macos"),
        deno: URL(fileURLWithPath: "/Applications/ZEUVE.app/Contents/Resources/Engines/deno/deno"),
        ffmpeg: URL(fileURLWithPath: "/Applications/ZEUVE.app/Contents/Resources/Engines/ffmpeg/ffmpeg"),
        ffprobe: URL(fileURLWithPath: "/Applications/ZEUVE.app/Contents/Resources/Engines/ffmpeg/ffprobe"),
        cacheDirectory: URL(fileURLWithPath: "/Users/test/Library/Caches/ZEUVE/yt-dlp", isDirectory: true)
    )


    func testNewDefaultsUseAutomaticPlatformPolicyAndKeepManualOptionDefaults() {
        let settings = UniversalDownloadSettings()
        XCTAssertEqual(settings.mode, .automatic)
        XCTAssertEqual(settings.container, .mp4)
        XCTAssertEqual(settings.audioOutput, .mp3)
        XCTAssertEqual(settings.mp3Bitrate, .kbps320)
        XCTAssertEqual(settings.filenamePreset, .title)
    }

    func testMP3BitrateIsAppliedOnlyToMP3() throws {
        let item = UniversalDownloadItem(
            canonicalID: "audio123456",
            sourceURL: URL(string: "https://www.youtube.com/watch?v=audio123456")!,
            title: "Audio"
        )
        let root = URL(fileURLWithPath: "/tmp/output")
        let builder = YTDLPDownloadCommandBuilder()

        for bitrate in MP3Bitrate.allCases {
            var settings = UniversalDownloadSettings(mode: .audio, audioOutput: .mp3, mp3Bitrate: bitrate)
            let args = try builder.arguments(
                item: item,
                settings: settings,
                engines: engines,
                downloadDirectory: root,
                temporaryDirectory: root,
                cookiesFile: nil,
                proxy: nil
            )
            XCTAssertEqual(value(after: "--audio-quality", in: args), bitrate.ytDLPValue)

            settings.audioOutput = .m4a
            let m4aArgs = try builder.arguments(
                item: item,
                settings: settings,
                engines: engines,
                downloadDirectory: root,
                temporaryDirectory: root,
                cookiesFile: nil,
                proxy: nil
            )
            XCTAssertFalse(m4aArgs.contains("--audio-quality"))
        }
    }

    func testAutomaticPolicyUsesOriginalForYouTubeAndInstagram() throws {
        let root = URL(fileURLWithPath: "/tmp/output")
        let builder = YTDLPDownloadCommandBuilder()
        let settings = UniversalDownloadSettings()
        let youtube = UniversalDownloadItem(
            canonicalID: "youtube:auto",
            sourceURL: URL(string: "https://www.youtube.com/watch?v=auto1234567")!,
            title: "YouTube",
            platform: .youtube
        )
        let instagram = UniversalDownloadItem(
            canonicalID: "instagram:auto",
            sourceURL: URL(string: "https://www.instagram.com/reel/Auto123/")!,
            title: "Instagram",
            platform: .instagram,
            mediaKind: .reel
        )

        let youtubeArguments = try builder.arguments(
            item: youtube, settings: settings, engines: engines,
            downloadDirectory: root, temporaryDirectory: root,
            cookiesFile: nil, proxy: nil
        )
        XCTAssertEqual(value(after: "--format", in: youtubeArguments), "bestvideo*+bestaudio/best")
        XCTAssertFalse(youtubeArguments.contains("--extract-audio"))
        XCTAssertFalse(youtubeArguments.contains("--audio-format"))
        XCTAssertFalse(youtubeArguments.contains("--audio-quality"))
        XCTAssertFalse(youtubeArguments.contains("--merge-output-format"))

        let instagramArguments = try builder.arguments(
            item: instagram, settings: settings, engines: engines,
            downloadDirectory: root, temporaryDirectory: root,
            cookiesFile: nil, proxy: nil
        )
        XCTAssertEqual(value(after: "--format", in: instagramArguments), "bestvideo*+bestaudio/best")
        XCTAssertFalse(instagramArguments.contains("--extract-audio"))
        XCTAssertFalse(instagramArguments.contains("--audio-format"))
        XCTAssertFalse(instagramArguments.contains("--merge-output-format"))
    }

    func testAutomaticPolicySummarizesMixedBatchAndManualAudioStillOverridesInstagram() throws {
        let youtube = UniversalDownloadItem(
            canonicalID: "youtube:mixed",
            sourceURL: URL(string: "https://youtu.be/mixed123456")!,
            title: "YouTube",
            platform: .youtube
        )
        let instagram = UniversalDownloadItem(
            canonicalID: "instagram:mixed",
            sourceURL: URL(string: "https://www.instagram.com/p/Mixed123/")!,
            title: "Instagram",
            platform: .instagram,
            mediaKind: .video
        )
        let summary = YTDLPFormatSelector().summary(for: [youtube, instagram], settings: .init())
        XCTAssertTrue(summary.contains("perfil predeterminado"))

        let root = URL(fileURLWithPath: "/tmp/output")
        let arguments = try YTDLPDownloadCommandBuilder().arguments(
            item: instagram,
            settings: UniversalDownloadSettings(mode: .audio, audioOutput: .mp3, mp3Bitrate: .kbps192),
            engines: engines,
            downloadDirectory: root,
            temporaryDirectory: root,
            cookiesFile: nil,
            proxy: nil
        )
        XCTAssertEqual(value(after: "--audio-format", in: arguments), "mp3")
        XCTAssertEqual(value(after: "--audio-quality", in: arguments), "192K")
    }

    func testSettingsWithoutMP3BitrateDecodeCompatibly() throws {
        var legacy = UniversalDownloadSettings(
            container: .automatic,
            audioOutput: .mp3,
            filenamePreset: .titleAndID
        )
        legacy.mp3Bitrate = .kbps128
        let encoded = try JSONEncoder().encode(legacy)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "mp3Bitrate")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(UniversalDownloadSettings.self, from: legacyData)
        XCTAssertEqual(decoded.container, .automatic)
        XCTAssertEqual(decoded.audioOutput, .mp3)
        XCTAssertEqual(decoded.mp3Bitrate, .kbps320)
        XCTAssertEqual(decoded.filenamePreset, .titleAndID)
    }

    func testValidVideoShortAndPlaylistURLs() throws {
        let validator = UniversalDownloadInputValidator()
        XCTAssertEqual(try validator.validate("https://www.youtube.com/watch?v=dQw4w9WgXcQ").canonicalID, "dQw4w9WgXcQ")
        XCTAssertEqual(try validator.validate("https://youtu.be/dQw4w9WgXcQ").canonicalURL.absoluteString, "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        let playlist = try validator.validate("https://www.youtube.com/playlist?list=PL1234567890")
        XCTAssertEqual(playlist.kind, .playlist)
        XCTAssertEqual(playlist.canonicalID, "PL1234567890")
    }

    func testUniversalURLsMalformedLocalNetworkAndDuplicates() throws {
        let result = UniversalDownloadInputValidator().validate(text: """
        file:///etc/passwd
        https://example.com/article-with-videos
        https://youtu.be/dQw4w9WgXcQ
        https://www.youtube.com/watch?v=dQw4w9WgXcQ&utm_source=test
        http://192.168.1.10/videos
        no-es-un-enlace
        """)
        XCTAssertEqual(result.accepted.count, 2)
        XCTAssertEqual(result.duplicates.count, 1)
        XCTAssertEqual(result.rejected.count, 3)
        XCTAssertEqual(try UniversalDownloadInputValidator().validate("https://example.com/article-with-videos").kind, .webpage)
        XCTAssertThrowsError(try UniversalDownloadInputValidator().validate("http://192.168.1.10/videos"))
        XCTAssertEqual(
            try UniversalDownloadInputValidator().validate("http://192.168.1.10/videos", allowInsecureLocalNetwork: true).kind,
            .webpage
        )
        XCTAssertThrowsError(try UniversalDownloadInputValidator().validate("http://example.com/videos"))
        XCTAssertEqual(
            try UniversalDownloadInputValidator().validate("http://example.com/videos", allowInsecureLocalNetwork: true).kind,
            .webpage
        )
        XCTAssertThrowsError(try UniversalDownloadInputValidator().validate("https://localhost/videos"))
        XCTAssertEqual(
            try UniversalDownloadInputValidator().validate("https://localhost/videos", allowInsecureLocalNetwork: true).kind,
            .webpage
        )
    }

    func testAnalysisCommandUsesExplicitEnginesAndNoRemoteComponents() throws {
        let url = try UniversalDownloadInputValidator().validate("https://youtu.be/dQw4w9WgXcQ")
        let args = try YTDLPAnalysisCommandBuilder().arguments(for: url, engines: engines)
        XCTAssertTrue(args.contains("--no-update"))
        XCTAssertEqual(value(after: "--cache-dir", in: args), engines.cacheDirectory?.path)
        XCTAssertFalse(args.contains("--no-cache-dir"))
        XCTAssertEqual(value(after: "--js-runtimes", in: args), "deno:\(engines.deno.path)")
        XCTAssertEqual(value(after: "--ffmpeg-location", in: args), engines.ffmpeg.path)
        XCTAssertFalse(args.contains("--remote-components"))
        XCTAssertFalse(args.contains("/bin/sh"))
        XCTAssertEqual(value(after: "--extractor-args", in: args), "youtube:player_client=web_embedded,web_safari")
        XCTAssertEqual(args.suffix(2).first, "--")
    }

    func testBrowserSessionIsExplicitEphemeralAndRedacted() throws {
        let url = try UniversalDownloadInputValidator().validate("https://youtu.be/dQw4w9WgXcQ")
        let analysisArgs = try YTDLPAnalysisCommandBuilder().arguments(
            for: url,
            engines: engines,
            browserCookies: .brave
        )
        XCTAssertEqual(value(after: "--cookies-from-browser", in: analysisArgs), "brave")
        XCTAssertFalse(analysisArgs.contains("--extractor-args"))

        let root = URL(fileURLWithPath: "/tmp/output")
        let item = UniversalDownloadItem(
            canonicalID: "dQw4w9WgXcQ",
            sourceURL: url.canonicalURL,
            title: "Vídeo"
        )
        let builder = YTDLPDownloadCommandBuilder()
        let downloadArgs = try builder.arguments(
            item: item,
            settings: UniversalDownloadSettings(),
            engines: engines,
            downloadDirectory: root,
            temporaryDirectory: root,
            cookiesFile: nil,
            browserCookies: .brave,
            proxy: nil
        )
        XCTAssertEqual(value(after: "--cookies-from-browser", in: downloadArgs), "brave")
        XCTAssertFalse(downloadArgs.contains("--extractor-args"))
        XCTAssertEqual(value(after: "--cookies-from-browser", in: builder.redacted(arguments: downloadArgs)), "<oculto>")
    }

    func testAnonymousYouTubeDownloadUsesPublicClientChainWithoutCookies() throws {
        let root = URL(fileURLWithPath: "/tmp/output")
        let item = UniversalDownloadItem(
            canonicalID: "youtube:dQw4w9WgXcQ",
            sourceURL: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")!,
            title: "Vídeo público",
            platform: .youtube
        )
        let arguments = try YTDLPDownloadCommandBuilder().arguments(
            item: item,
            settings: UniversalDownloadSettings(mode: .audio),
            engines: engines,
            downloadDirectory: root,
            temporaryDirectory: root,
            cookiesFile: nil,
            proxy: nil
        )

        XCTAssertEqual(
            value(after: "--extractor-args", in: arguments),
            "youtube:player_client=web_embedded,web_safari"
        )
        XCTAssertFalse(arguments.contains("--cookies"))
        XCTAssertFalse(arguments.contains("--cookies-from-browser"))
        XCTAssertEqual(arguments.last, item.sourceURL.absoluteString)
    }

    func testAnonymousClientPolicyDoesNotAffectOtherPlatforms() throws {
        let input = try UniversalDownloadInputValidator().validate(
            "https://vimeo.com/123456789",
            platform: .vimeo
        )
        let arguments = try YTDLPAnalysisCommandBuilder().arguments(for: input, engines: engines)
        XCTAssertFalse(arguments.contains("--extractor-args"))
    }

    func testDownloadCommandIsSeparatedSafeAndRedactsSecrets() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ZEUVE Command Test \(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let cookies = root.appendingPathComponent("cookies.txt")
        try Data("# Netscape HTTP Cookie File".utf8).write(to: cookies)
        var settings = UniversalDownloadSettings(mode: .audio, audioOutput: .mp3)
        settings.subtitles = .init(languages: ["es", "en"], includeAutomatic: true, embed: true, convertToSRT: true)
        settings.network.speedLimit = "10m"
        let item = UniversalDownloadItem(canonicalID: "dQw4w9WgXcQ", sourceURL: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")!, title: "Título ; rm -rf /")
        let builder = YTDLPDownloadCommandBuilder()
        let args = try builder.arguments(item: item, settings: settings, engines: engines, downloadDirectory: root, temporaryDirectory: root, cookiesFile: cookies, proxy: "https://proxy.example:8443", proxyCredentials: .init(username: "usuario", password: "secreto"))
        XCTAssertTrue(args.contains("--extract-audio"))
        XCTAssertEqual(value(after: "--cache-dir", in: args), engines.cacheDirectory?.path)
        XCTAssertFalse(args.contains("--no-cache-dir"))
        XCTAssertEqual(value(after: "--audio-format", in: args), "mp3")
        XCTAssertEqual(value(after: "--limit-rate", in: args), "10M")
        XCTAssertFalse(args.contains("--exec"))
        XCTAssertFalse(args.contains("--config-location"))
        XCTAssertFalse(args.contains("--remote-components"))
        XCTAssertEqual(args.suffix(2).first, "--")
        let redacted = builder.redacted(arguments: args).joined(separator: " ")
        XCTAssertFalse(redacted.contains("secreto"))
        XCTAssertFalse(redacted.contains(cookies.path))
        XCTAssertTrue(redacted.contains("<oculto>"))
    }

    func testNativeYTDLPInformationFilesAreAlwaysDisabled() throws {
        var settings = UniversalDownloadSettings()
        settings.metadata.saveInfoJSON = true
        settings.metadata.savePlaylistMetadata = true
        let item = UniversalDownloadItem(
            canonicalID: "safe1234567",
            sourceURL: URL(string: "https://www.youtube.com/watch?v=safe1234567")!,
            title: "Vídeo"
        )
        let root = URL(fileURLWithPath: "/tmp/output")
        let args = try YTDLPDownloadCommandBuilder().arguments(
            item: item,
            settings: settings,
            engines: engines,
            downloadDirectory: root,
            temporaryDirectory: root,
            cookiesFile: nil,
            proxy: nil
        )
        XCTAssertTrue(args.contains("--no-write-info-json"))
        XCTAssertTrue(args.contains("--no-write-playlist-metafiles"))
        XCTAssertFalse(args.contains("--write-info-json"))
        XCTAssertFalse(args.contains("--write-playlist-metafiles"))
    }

    func testExactFormatsResolutionAndPlaylistNumbering() throws {
        var settings = UniversalDownloadSettings(mode: .video, maximumResolution: .p1080, exactVideoFormatID: "137", exactAudioFormatID: "140")
        settings.filenamePreset = .playlistIndexAndTitle
        let item = UniversalDownloadItem(canonicalID: "id123456", sourceURL: URL(string: "https://youtu.be/id123456")!, title: "Vídeo", playlistTitle: "Lista", playlistIndex: 7)
        let root = URL(fileURLWithPath: "/tmp/output")
        let args = try YTDLPDownloadCommandBuilder().arguments(item: item, settings: settings, engines: engines, downloadDirectory: root, temporaryDirectory: root, cookiesFile: nil, proxy: nil)
        XCTAssertEqual(value(after: "--format", in: args), "137+140")
        XCTAssertTrue(value(after: "--output", in: args)?.hasPrefix("0007 - ") == true)
    }


    func testPageDiscoveredVideoIgnoresConversionResolutionAndAuxiliaryOptions() throws {
        let origin = DownloadPageOrigin(
            pageURL: URL(string: "https://www.ejemplo.com/a/JVwS60hN?utm_source=test&token=secret")!,
            pageIdentifier: "JVwS60hN"
        )
        let item = UniversalDownloadItem(
            canonicalID: "JVwS60hN-1",
            sourceURL: URL(string: "https://cdn.ejemplo.com/video/master.m3u8?signature=private")!,
            title: "de ig 3 (1)",
            downloadSource: .pageDiscovered,
            pageOrigin: origin,
            outputFilenameBase: "de ig 3 (1)"
        )
        var settings = UniversalDownloadSettings(
            mode: .original,
            maximumResolution: .p720,
            container: .mp4,
            audioOutput: .mp3,
            mp3Bitrate: .kbps128,
            exactVideoFormatID: "137",
            exactAudioFormatID: "140",
            hdrPreference: .preferHDR
        )
        settings.subtitles = .init(languages: ["es"], includeAutomatic: true, embed: true, convertToSRT: true)
        settings.metadata = .init(
            embedMetadata: true,
            embedThumbnail: true,
            saveThumbnail: true,
            preservePublicationDate: true,
            addChapters: true,
            saveDescription: true,
            saveInfoJSON: true,
            savePlaylistMetadata: true
        )

        let root = URL(fileURLWithPath: "/tmp/output")
        let args = try YTDLPDownloadCommandBuilder().arguments(
            item: item,
            settings: settings,
            engines: engines,
            downloadDirectory: root,
            temporaryDirectory: root,
            cookiesFile: nil,
            proxy: nil
        )

        XCTAssertEqual(value(after: "--format", in: args), "bestvideo*+bestaudio/best")
        XCTAssertEqual(value(after: "--output", in: args), "de ig 3 (1).%(ext)s")
        XCTAssertFalse(args.contains("--merge-output-format"))
        XCTAssertFalse(args.contains("--extract-audio"))
        XCTAssertFalse(args.contains("--audio-format"))
        XCTAssertFalse(args.contains("--audio-quality"))
        XCTAssertFalse(args.contains("--embed-subs"))
        XCTAssertFalse(args.contains("--write-subs"))
        XCTAssertFalse(args.contains("--write-auto-subs"))
        XCTAssertFalse(args.contains("--convert-subs"))
        XCTAssertFalse(args.contains("--embed-metadata"))
        XCTAssertFalse(args.contains("--embed-thumbnail"))
        XCTAssertFalse(args.contains("--write-thumbnail"))
        XCTAssertFalse(args.contains("--embed-chapters"))
        XCTAssertFalse(args.contains("--write-description"))
        XCTAssertTrue(args.contains("--no-embed-metadata"))
        XCTAssertTrue(args.contains("--no-write-info-json"))
        XCTAssertFalse(value(after: "--output", in: args)?.contains("JVwS60hN") == true)
    }


    func testPageDownloadUsesResolvedMediaWithoutReopeningPageAndRedactsHeaders() throws {
        let page = URL(string: "https://www.ejemplo.com/a/JVwS60hN")!
        let media = URL(string: "https://cdn.ejemplo.com/master.m3u8?token=privado")!
        let reference = ResolvedMediaReference(
            mediaURL: media,
            kind: .hls,
            protocolName: "m3u8_native",
            httpHeaders: [
                "Referer": page.absoluteString,
                "Authorization": "Bearer secreto"
            ]
        )
        let item = UniversalDownloadItem(
            canonicalID: "page-video-1",
            sourceURL: page,
            title: "Vídeo",
            downloadSource: .pageDiscovered,
            resolvedMedia: reference
        )
        let root = URL(fileURLWithPath: "/tmp/output")
        let builder = YTDLPDownloadCommandBuilder()
        let arguments = try builder.arguments(
            item: item,
            settings: UniversalDownloadSettings(),
            engines: engines,
            downloadDirectory: root,
            temporaryDirectory: root,
            cookiesFile: nil,
            proxy: nil,
            resolvedMedia: reference,
            concurrentFragmentsOverride: 16
        )
        XCTAssertEqual(arguments.last, media.absoluteString)
        XCTAssertFalse(arguments.contains(page.absoluteString))
        XCTAssertEqual(value(after: "--concurrent-fragments", in: arguments), "16")
        XCTAssertTrue(arguments.contains("Referer:\(page.absoluteString)"))
        XCTAssertTrue(arguments.contains("Authorization:Bearer secreto"))

        let redacted = builder.redacted(arguments: arguments).joined(separator: " ")
        XCTAssertFalse(redacted.contains("Bearer secreto"))
        XCTAssertFalse(redacted.contains(page.absoluteString))
        XCTAssertTrue(redacted.contains("<oculto>"))
    }

    func testResolvedReferenceExpiredBeforeDownloadCanBeDetected() {
        let reference = ResolvedMediaReference(
            mediaURL: URL(string: "https://cdn.ejemplo.com/video.mp4")!,
            kind: .directFile,
            expiresAt: Date(timeIntervalSince1970: 100)
        )
        XCTAssertTrue(reference.isExpired(at: Date(timeIntervalSince1970: 101)))
    }

    func testDirectVideoStillUsesSelectedOptions() throws {
        let item = UniversalDownloadItem(
            canonicalID: "direct12345",
            sourceURL: URL(string: "https://www.youtube.com/watch?v=direct12345")!,
            title: "Directo"
        )
        var settings = UniversalDownloadSettings(
            mode: .video,
            maximumResolution: .p1080,
            container: .mkv,
            exactVideoFormatID: "137",
            exactAudioFormatID: "140"
        )
        settings.metadata.embedMetadata = true
        let root = URL(fileURLWithPath: "/tmp/output")
        let args = try YTDLPDownloadCommandBuilder().arguments(
            item: item,
            settings: settings,
            engines: engines,
            downloadDirectory: root,
            temporaryDirectory: root,
            cookiesFile: nil,
            proxy: nil
        )
        XCTAssertEqual(value(after: "--format", in: args), "137+140")
        XCTAssertEqual(value(after: "--merge-output-format", in: args), "mkv")
        XCTAssertTrue(args.contains("--embed-metadata"))
    }

    func testOriginMetadataUsesStreamCopyAndCleanPageURL() throws {
        let origin = DownloadPageOrigin(
            pageURL: URL(string: "https://www.ejemplo.com/a/JVwS60hN?token=secret&utm_source=test&quality=original#fragment")!,
            pageIdentifier: "JVwS60hN"
        )
        let input = URL(fileURLWithPath: "/tmp/video.mp4")
        let output = URL(fileURLWithPath: "/tmp/video-origin.mp4")
        let builder = DownloadOriginMetadataCommandBuilder()
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let args = builder.arguments(
            input: input,
            output: output,
            origin: origin,
            includeDownloadDate: true,
            generatedAt: fixedDate
        )
        let joined = args.joined(separator: " ")
        XCTAssertTrue(args.contains("copy"))
        XCTAssertTrue(joined.contains("https://www.ejemplo.com/a/JVwS60hN?quality=original"))
        XCTAssertTrue(joined.contains("zeuve_source_page_id=JVwS60hN"))
        XCTAssertTrue(joined.contains("zeuve_source_domain=www.ejemplo.com"))
        XCTAssertTrue(joined.contains("-metadata date="))
        XCTAssertFalse(joined.contains("secret"))
        XCTAssertFalse(joined.contains("utm_source"))
        XCTAssertFalse(joined.contains("#fragment"))
        XCTAssertTrue(args.contains("use_metadata_tags"))

        let withoutDate = builder.arguments(
            input: input,
            output: output,
            origin: origin,
            includeDownloadDate: false,
            generatedAt: fixedDate
        )
        XCTAssertFalse(withoutDate.contains { $0.hasPrefix("date=") })
    }

    func testLegacySettingsDecodeWithPageSourceDisabled() throws {
        let settings = UniversalDownloadSettings()
        let encoded = try JSONEncoder().encode(settings)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "pageSource")
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(UniversalDownloadSettings.self, from: legacyData)
        XCTAssertFalse(decoded.pageSource.embedSourceMetadata)
        XCTAssertFalse(decoded.pageSource.includeDownloadDate)
        XCTAssertFalse(decoded.pageSource.applyMacOSWhereFrom)
    }

    func testCommandsDisableCacheOnlyWhenNoSafeCacheDirectoryIsAvailable() throws {
        let uncached = DownloadEnginePaths(
            ytDLP: engines.ytDLP,
            deno: engines.deno,
            ffmpeg: engines.ffmpeg,
            ffprobe: engines.ffprobe
        )
        let url = try UniversalDownloadInputValidator().validate("https://youtu.be/dQw4w9WgXcQ")
        let args = try YTDLPAnalysisCommandBuilder().arguments(for: url, engines: uncached)
        XCTAssertTrue(args.contains("--no-cache-dir"))
        XCTAssertFalse(args.contains("--cache-dir"))
    }

    private func value(after option: String, in values: [String]) -> String? {
        guard let index = values.firstIndex(of: option), values.indices.contains(index + 1) else { return nil }
        return values[index + 1]
    }
}
