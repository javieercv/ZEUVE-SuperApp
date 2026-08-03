import Foundation
import XCTest
@testable import YouTubeDownloaderModule

final class YouTubeURLAndCommandTests: XCTestCase {
    private let engines = YouTubeEnginePaths(
        ytDLP: URL(fileURLWithPath: "/Applications/ZEUVE.app/Contents/Resources/Engines/yt-dlp/yt-dlp_macos"),
        deno: URL(fileURLWithPath: "/Applications/ZEUVE.app/Contents/Resources/Engines/deno/deno"),
        ffmpeg: URL(fileURLWithPath: "/Applications/ZEUVE.app/Contents/Resources/Engines/ffmpeg/ffmpeg"),
        ffprobe: URL(fileURLWithPath: "/Applications/ZEUVE.app/Contents/Resources/Engines/ffmpeg/ffprobe"),
        cacheDirectory: URL(fileURLWithPath: "/Users/test/Library/Caches/ZEUVE/yt-dlp", isDirectory: true)
    )


    func testNewDefaultsUseMP4MP3320AndTitle() {
        let settings = YouTubeDownloadSettings()
        XCTAssertEqual(settings.container, .mp4)
        XCTAssertEqual(settings.audioOutput, .mp3)
        XCTAssertEqual(settings.mp3Bitrate, .kbps320)
        XCTAssertEqual(settings.filenamePreset, .title)
    }

    func testMP3BitrateIsAppliedOnlyToMP3() throws {
        let item = YouTubeDownloadItem(
            canonicalID: "audio123456",
            sourceURL: URL(string: "https://www.youtube.com/watch?v=audio123456")!,
            title: "Audio"
        )
        let root = URL(fileURLWithPath: "/tmp/output")
        let builder = YouTubeDownloadCommandBuilder()

        for bitrate in YouTubeMP3Bitrate.allCases {
            var settings = YouTubeDownloadSettings(mode: .audio, audioOutput: .mp3, mp3Bitrate: bitrate)
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

    func testSettingsWithoutMP3BitrateDecodeCompatibly() throws {
        var legacy = YouTubeDownloadSettings(
            container: .automatic,
            audioOutput: .mp3,
            filenamePreset: .titleAndID
        )
        legacy.mp3Bitrate = .kbps128
        let encoded = try JSONEncoder().encode(legacy)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "mp3Bitrate")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(YouTubeDownloadSettings.self, from: legacyData)
        XCTAssertEqual(decoded.container, .automatic)
        XCTAssertEqual(decoded.audioOutput, .mp3)
        XCTAssertEqual(decoded.mp3Bitrate, .kbps320)
        XCTAssertEqual(decoded.filenamePreset, .titleAndID)
    }

    func testValidVideoShortAndPlaylistURLs() throws {
        let validator = YouTubeURLValidator()
        XCTAssertEqual(try validator.validate("https://www.youtube.com/watch?v=dQw4w9WgXcQ").canonicalID, "dQw4w9WgXcQ")
        XCTAssertEqual(try validator.validate("https://youtu.be/dQw4w9WgXcQ").canonicalURL.absoluteString, "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        let playlist = try validator.validate("https://www.youtube.com/playlist?list=PL1234567890")
        XCTAssertEqual(playlist.kind, .playlist)
        XCTAssertEqual(playlist.canonicalID, "PL1234567890")
    }

    func testInvalidSchemesHostsMalformedAndDuplicates() {
        let result = YouTubeURLValidator().validate(text: """
        file:///etc/passwd
        https://example.com/watch?v=dQw4w9WgXcQ
        https://youtu.be/dQw4w9WgXcQ
        https://www.youtube.com/watch?v=dQw4w9WgXcQ
        no-es-un-enlace
        """)
        XCTAssertEqual(result.accepted.count, 1)
        XCTAssertEqual(result.duplicates.count, 1)
        XCTAssertEqual(result.rejected.count, 3)
    }

    func testAnalysisCommandUsesExplicitEnginesAndNoRemoteComponents() throws {
        let url = try YouTubeURLValidator().validate("https://youtu.be/dQw4w9WgXcQ")
        let args = try YouTubeAnalysisCommandBuilder().arguments(for: url, engines: engines)
        XCTAssertTrue(args.contains("--no-update"))
        XCTAssertEqual(value(after: "--cache-dir", in: args), engines.cacheDirectory?.path)
        XCTAssertFalse(args.contains("--no-cache-dir"))
        XCTAssertEqual(value(after: "--js-runtimes", in: args), "deno:\(engines.deno.path)")
        XCTAssertEqual(value(after: "--ffmpeg-location", in: args), engines.ffmpeg.path)
        XCTAssertFalse(args.contains("--remote-components"))
        XCTAssertFalse(args.contains("/bin/sh"))
        XCTAssertEqual(args.suffix(2).first, "--")
    }

    func testDownloadCommandIsSeparatedSafeAndRedactsSecrets() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ZEUVE Command Test \(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let cookies = root.appendingPathComponent("cookies.txt")
        try Data("# Netscape HTTP Cookie File".utf8).write(to: cookies)
        var settings = YouTubeDownloadSettings(mode: .audio, audioOutput: .mp3)
        settings.subtitles = .init(languages: ["es", "en"], includeAutomatic: true, embed: true, convertToSRT: true)
        settings.network.speedLimit = "10m"
        let item = YouTubeDownloadItem(canonicalID: "dQw4w9WgXcQ", sourceURL: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")!, title: "Título ; rm -rf /")
        let builder = YouTubeDownloadCommandBuilder()
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
        var settings = YouTubeDownloadSettings()
        settings.metadata.saveInfoJSON = true
        settings.metadata.savePlaylistMetadata = true
        let item = YouTubeDownloadItem(
            canonicalID: "safe1234567",
            sourceURL: URL(string: "https://www.youtube.com/watch?v=safe1234567")!,
            title: "Vídeo"
        )
        let root = URL(fileURLWithPath: "/tmp/output")
        let args = try YouTubeDownloadCommandBuilder().arguments(
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
        var settings = YouTubeDownloadSettings(maximumResolution: .p1080, exactVideoFormatID: "137", exactAudioFormatID: "140")
        settings.filenamePreset = .playlistIndexAndTitle
        let item = YouTubeDownloadItem(canonicalID: "id123456", sourceURL: URL(string: "https://youtu.be/id123456")!, title: "Vídeo", playlistTitle: "Lista", playlistIndex: 7)
        let root = URL(fileURLWithPath: "/tmp/output")
        let args = try YouTubeDownloadCommandBuilder().arguments(item: item, settings: settings, engines: engines, downloadDirectory: root, temporaryDirectory: root, cookiesFile: nil, proxy: nil)
        XCTAssertEqual(value(after: "--format", in: args), "137+140")
        XCTAssertTrue(value(after: "--output", in: args)?.hasPrefix("0007 - ") == true)
    }


    func testCommandsDisableCacheOnlyWhenNoSafeCacheDirectoryIsAvailable() throws {
        let uncached = YouTubeEnginePaths(
            ytDLP: engines.ytDLP,
            deno: engines.deno,
            ffmpeg: engines.ffmpeg,
            ffprobe: engines.ffprobe
        )
        let url = try YouTubeURLValidator().validate("https://youtu.be/dQw4w9WgXcQ")
        let args = try YouTubeAnalysisCommandBuilder().arguments(for: url, engines: uncached)
        XCTAssertTrue(args.contains("--no-cache-dir"))
        XCTAssertFalse(args.contains("--cache-dir"))
    }

    private func value(after option: String, in values: [String]) -> String? {
        guard let index = values.firstIndex(of: option), values.indices.contains(index + 1) else { return nil }
        return values[index + 1]
    }
}
