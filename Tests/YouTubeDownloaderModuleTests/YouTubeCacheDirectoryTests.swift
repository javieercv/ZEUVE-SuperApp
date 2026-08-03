import Foundation
import XCTest
@testable import YouTubeDownloaderModule

final class YouTubeCacheDirectoryTests: XCTestCase {
    func testCacheDirectoryIsStableAndCreated() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZEUVE-CacheTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try YouTubeCacheDirectory.prepare(baseDirectory: root)
        let second = try YouTubeCacheDirectory.prepare(baseDirectory: root)
        XCTAssertEqual(first, second)
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.path))
        XCTAssertTrue(first.path.hasSuffix("/ZEUVE/yt-dlp"))
    }
}
