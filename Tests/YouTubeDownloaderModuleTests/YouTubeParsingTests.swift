import Foundation
import XCTest
@testable import YouTubeDownloaderModule
import ZEUVEEngines

final class YouTubeParsingTests: XCTestCase {
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
        let value = try YouTubeAnalysisParser().parse(data: Data(json.utf8))
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
            let value = try YouTubeAnalysisParser().parse(data: Data("{\"id\":\"abc12345678\",\"title\":\"Live\",\"live_status\":\"\(status)\"}".utf8))
            XCTAssertFalse(value.isDownloadable)
        }
    }

    func testUnavailablePlaylistEntriesRemainVisibleButUnselected() throws {
        let json = #"{"_type":"playlist","id":"PL123456","title":"Lista","entries":[{"id":"a123456","title":"Uno","playlist_index":1},{"id":"b123456","title":"Privado","playlist_index":2,"availability":"private"}]}"#
        let value = try YouTubeAnalysisParser().parse(data: Data(json.utf8))
        XCTAssertEqual(value.playlistEntries.count, 2)
        XCTAssertFalse(value.playlistEntries[1].isAvailable)
    }

    func testProgressKnownUnknownFragmentAndFFmpegPhases() {
        let parser = YouTubeProgressParser()
        let known = parser.parse(line: "ZEUVE_PROGRESS| 50.0%|500|1000||100|5", itemIndex: 2, itemTotal: 4, title: "Vídeo", completed: 1, failed: 0, skipped: 0)
        XCTAssertEqual(known?.fraction, 0.5)
        XCTAssertEqual(known?.totalBytes, 1000)
        let unknown = parser.parse(line: "ZEUVE_PROGRESS| N/A|500|||100|", itemIndex: 1, itemTotal: 1, title: "Vídeo", completed: 0, failed: 0, skipped: 0)
        XCTAssertNil(unknown?.fraction)
        XCTAssertEqual(parser.parse(line: "[Merger] Merging formats", itemIndex: 1, itemTotal: 1, title: "Vídeo", completed: 0, failed: 0, skipped: 0)?.phase, .merging)
        XCTAssertEqual(parser.parse(line: "[ExtractAudio] Destination", itemIndex: 1, itemTotal: 1, title: "Audio", completed: 0, failed: 0, skipped: 0)?.phase, .converting)
    }

    func testThousandsOfPlaylistEntriesAreParsedIncrementallyWithBoundedBuffer() throws {
        let decoder = IncrementalLineDecoder(maximumBufferedBytes: 32_768)
        let parser = YouTubeAnalysisParser()
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
