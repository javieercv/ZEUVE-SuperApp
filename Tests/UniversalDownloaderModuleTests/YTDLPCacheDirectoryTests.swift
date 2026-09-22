import Foundation
import XCTest
@testable import UniversalDownloaderModule

final class YTDLPCacheDirectoryTests: XCTestCase {
    func testCacheDirectoryIsStableAndCreated() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZEUVE-CacheTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try YTDLPCacheDirectory.prepare(baseDirectory: root)
        let second = try YTDLPCacheDirectory.prepare(baseDirectory: root)
        XCTAssertEqual(first, second)
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.path))
        XCTAssertTrue(first.path.hasSuffix("/ZEUVE/yt-dlp"))
    }
}
