import Foundation
import XCTest
@testable import OrganizerModule
import ZEUVEStorage

class OrganizerTestCase: XCTestCase {
    var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZEUVE-OrganizerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    func write(_ relativePath: String, contents: String = "x") throws -> URL {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: url)
        return url
    }

    func relativeDestinations(_ plan: OrganizerPlan) -> Set<String> {
        Set(plan.operations.map { operation in
            String(operation.destination.path.dropFirst(plan.baseFolder.path.count + 1))
        })
    }

    func makeHistory() throws -> OrganizerHistoryService {
        let database = try SQLiteDatabase(url: root.appendingPathComponent("data/history.sqlite"))
        return OrganizerHistoryService(repository: try HistoryRepository(database: database))
    }
}
