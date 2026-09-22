import Foundation
import XCTest
@testable import ZEUVECore

final class FolderBookmarkAndHistoryPolicyTests: XCTestCase {
    func testSystemFolderBookmarkCodecRoundTripsFolderWithoutChangingPath() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZEUVE-Bookmark-\(UUID().uuidString)", isDirectory: true)
            .standardizedFileURL
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let codec = SystemFolderBookmarkCodec()
        let data: Data
        do {
            data = try codec.makeBookmark(for: folder)
        } catch {
            #if os(macOS)
            throw XCTSkip("ScopedBookmarksAgent no está disponible en este entorno de test: \(error.localizedDescription)")
            #else
            throw error
            #endif
        }
        let resolution = try codec.resolveBookmark(data)

        XCTAssertEqual(resolution.url.standardizedFileURL, folder)
        #if !os(macOS)
        XCTAssertFalse(resolution.isStale)
        #endif
    }

    func testHistoryPersistenceFailureBecomesSanitizedWarningInsteadOfThrowing() {
        enum TestFailure: Error { case databaseUnavailable }

        let failure = ZEUVEHistoryPersistence.attempt {
            throw TestFailure.databaseUnavailable
        }

        XCTAssertEqual(failure?.warning, ZEUVEHistoryPersistence.warningMessage)
        XCTAssertEqual(failure?.logMetadata.keys.sorted(), ["tipo_error"])
        XCTAssertFalse(failure?.logMetadata.values.joined().contains("databaseUnavailable") ?? true)
    }

    func testHistoryPersistenceSuccessReturnsNoWarning() {
        var saved = false
        let failure = ZEUVEHistoryPersistence.attempt { saved = true }
        XCTAssertTrue(saved)
        XCTAssertNil(failure)
    }
}
