import Foundation
import XCTest
@testable import UniversalDownloaderModule
import ZEUVEEngines

final class YTDLPParsingTests: XCTestCase {
    func testFormatsSubtitlesHDRLiveAndMissingSizes() throws {
        let json = #"""
        {
          "id":"abc12345678","title":"Ejemplo","uploader":"Canal","upload_date":"20260630","live_status":"post_live","age_limit":18,
          "formats":[
            {"format_id":"137","ext":"mp4","height":1080,"fps":60,"vcodec":"avc1","acodec":"none","filesize":1234,"dynamic_range":"SDR"},
            {"format_id":"337","ext":"webm","height":2160,"fps":60,"vcodec":"vp9.2","acodec":"none","filesize_approx":9999,"dynamic_range":"HDR10"},
            {"format_id":"140","ext":"m4a","vcodec":"none","acodec":"mp4a.40.2","abr":128,"language":"es"}
          ],
          "subtitles":{"es":[{"ext":"vtt","name":"Español"}]},
          "automatic_captions":{"en":[{"ext":"vtt","name":"English"}]},
          "chapters":[{"title":"Uno"}]
        }
        """#
        let value = try YTDLPAnalysisParser().parse(data: Data(json.utf8))
        XCTAssertEqual(value.formats.count, 3)
        XCTAssertEqual(value.formats.first(where: { $0.formatID == "337" })?.dynamicRange, .hdr)
        XCTAssertNil(value.formats.first(where: { $0.formatID == "140" })?.fileSize)
        XCTAssertEqual(value.subtitles.filter { $0.kind == .manual }.count, 1)
        XCTAssertEqual(value.subtitles.filter { $0.kind == .automatic }.count, 1)
        XCTAssertEqual(value.liveStatus, .postLive)
        XCTAssertTrue(value.isDownloadable)
    }

    func testActiveAndUpcomingLiveCannotDownload() throws {
        for status in ["is_live", "is_upcoming"] {
            let value = try YTDLPAnalysisParser().parse(data: Data("{\"id\":\"abc12345678\",\"title\":\"Live\",\"live_status\":\"\(status)\"}".utf8))
            XCTAssertFalse(value.isDownloadable)
        }
    }

    func testUnavailablePlaylistEntriesRemainVisibleButUnselected() throws {
        let json = #"{"_type":"playlist","id":"PL123456","title":"Lista","entries":[{"id":"a123456","title":"Uno","playlist_index":1},{"id":"b123456","title":"Privado","playlist_index":2,"availability":"private"}]}"#
        let value = try YTDLPAnalysisParser().parse(data: Data(json.utf8))
        XCTAssertEqual(value.playlistEntries.count, 2)
        XCTAssertFalse(value.playlistEntries[1].isAvailable)
    }


    func testAdaptiveFragmentPolicyStartsFastAndReducesOnlyForNetworkOrFragmentLimits() {
        let policy = YTDLPAdaptiveFragmentPolicy()
        XCTAssertEqual(policy.levels(startingAt: 16), [16, 8, 4, 1])
        XCTAssertEqual(policy.levels(startingAt: 8), [8, 4, 1])
        XCTAssertEqual(policy.levels(startingAt: 1), [1])
        XCTAssertTrue(policy.shouldReduce(after: "HTTP Error 429: Too Many Requests"))
        XCTAssertTrue(policy.shouldReduce(after: "fragment 7 not found; connection reset"))
        XCTAssertFalse(policy.shouldReduce(after: "HTTP Error 403: URL expired"))
        XCTAssertFalse(policy.shouldReduce(after: "Unsupported URL"))
    }

    func testProgressKnownUnknownFragmentAndFFmpegPhases() {
        let parser = YTDLPProgressParser()
        let known = parser.parse(line: "ZEUVE_PROGRESS| 50.0%|500|1000||100|5", itemIndex: 2, itemTotal: 4, title: "Vídeo", completed: 1, failed: 0, skipped: 0)
        XCTAssertEqual(known?.fraction, 0.5)
        XCTAssertEqual(known?.totalBytes, 1000)
        let unknown = parser.parse(line: "ZEUVE_PROGRESS| N/A|500|||100|", itemIndex: 1, itemTotal: 1, title: "Vídeo", completed: 0, failed: 0, skipped: 0)
        XCTAssertNil(unknown?.fraction)
        XCTAssertEqual(parser.parse(line: "[Merger] Merging formats", itemIndex: 1, itemTotal: 1, title: "Vídeo", completed: 0, failed: 0, skipped: 0)?.phase, .merging)
        XCTAssertEqual(parser.parse(line: "[ExtractAudio] Destination", itemIndex: 1, itemTotal: 1, title: "Audio", completed: 0, failed: 0, skipped: 0)?.phase, .converting)
    }


    func testResolvedMediaReferenceKeepsDirectManifestInMemoryAndStablePageAsFallback() throws {
        let json = #"""
        {
          "id":"video-1",
          "title":"Vídeo de página",
          "webpage_url":"https://www.ejemplo.com/a/JVwS60hN",
          "url":"https://cdn.ejemplo.com/master.m3u8?token=privado&expire=2000000000",
          "protocol":"m3u8_native",
          "ext":"mp4",
          "http_headers":{
            "Referer":"https://www.ejemplo.com/a/JVwS60hN",
            "User-Agent":"ZEUVE-Test",
            "Cookie":"sesion=privada"
          }
        }
        """#
        let value = try YTDLPAnalysisParser().parse(data: Data(json.utf8))
        XCTAssertEqual(value.sourceURL?.absoluteString, "https://www.ejemplo.com/a/JVwS60hN")
        XCTAssertEqual(value.resolvedMedia?.mediaURL?.host, "cdn.ejemplo.com")
        XCTAssertEqual(value.resolvedMedia?.kind, .hls)
        XCTAssertEqual(value.resolvedMedia?.httpHeaders["Referer"], "https://www.ejemplo.com/a/JVwS60hN")
        XCTAssertNil(value.resolvedMedia?.httpHeaders["Cookie"])
        XCTAssertFalse(value.resolvedMedia?.isExpired(at: Date(timeIntervalSince1970: 1_900_000_000)) ?? true)

        let encoded = String(decoding: try JSONEncoder().encode(value.resolvedMedia), as: UTF8.self)
        XCTAssertFalse(encoded.contains("cdn.ejemplo.com"))
        XCTAssertFalse(encoded.contains("token=privado"))
        XCTAssertFalse(encoded.contains("Referer"))
        XCTAssertFalse(encoded.contains("ZEUVE-Test"))
    }

    func testResolvedMediaUsesCommonManifestForSeparateRequestedFormats() throws {
        let json = #"""
        {
          "id":"video-2",
          "title":"Vídeo DASH",
          "webpage_url":"https://www.ejemplo.com/video/2",
          "requested_formats":[
            {"format_id":"v","vcodec":"avc1","acodec":"none","manifest_url":"https://cdn.ejemplo.com/master.mpd","protocol":"http_dash_segments"},
            {"format_id":"a","vcodec":"none","acodec":"mp4a","manifest_url":"https://cdn.ejemplo.com/master.mpd","protocol":"http_dash_segments"}
          ]
        }
        """#
        let value = try YTDLPAnalysisParser().parse(data: Data(json.utf8))
        XCTAssertEqual(value.resolvedMedia?.mediaURL?.absoluteString, "https://cdn.ejemplo.com/master.mpd")
        XCTAssertEqual(value.resolvedMedia?.kind, .dash)
        XCTAssertTrue(value.resolvedMedia?.isSegmented == true)
    }

    func testThousandsOfPlaylistEntriesAreParsedIncrementallyWithBoundedBuffer() throws {
        let decoder = IncrementalLineDecoder(maximumBufferedBytes: 32_768)
        let parser = YTDLPAnalysisParser()
        var count = 0
        for index in 0..<5_000 {
            let line = "{\"id\":\"video\(String(format: "%06d", index))\",\"title\":\"Elemento \(index)\",\"playlist_index\":\(index + 1)}\n"
            for parsed in try decoder.append(Data(line.utf8)) {
                _ = try parser.parsePlaylistEntry(data: Data(parsed.utf8))
                count += 1
            }
            XCTAssertLessThan(decoder.bufferedByteCount, 512)
        }
        XCTAssertEqual(count, 5_000)
    }
}
