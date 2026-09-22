import XCTest
@testable import ZEUVEStorage
import ZEUVECore

final class StorageTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZEUVE-StorageTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testSettingsPersistAcrossRepositoryInstances() throws {
        struct Settings: Codable, Sendable, Equatable { let theme: String; let recent: [String] }
        let url = directory.appendingPathComponent("test.sqlite")
        let database = try SQLiteDatabase(url: url)
        let first = try SettingsRepository(database: database)
        try first.set(Settings(theme: "dark", recent: ["/tmp/a"]), forKey: "ui")
        let second = try SettingsRepository(database: database)
        XCTAssertEqual(
            try second.value(forKey: "ui", as: Settings.self),
            Settings(theme: "dark", recent: ["/tmp/a"])
        )
    }

    func testHistoryCanBeAddedQueriedAndUpdated() throws {
        let database = try SQLiteDatabase(url: directory.appendingPathComponent("history.sqlite"))
        let history = try HistoryRepository(database: database)
        let record = OperationHistoryRecord(
            moduleID: "com.zeuve.test",
            kind: "test",
            baseFolder: "/tmp/example",
            status: .completed,
            undoAvailable: true,
            payload: Data("payload".utf8)
        )
        try history.add(record)
        let stored = try XCTUnwrap(history.record(id: record.id))
        XCTAssertEqual(stored.id, record.id)
        XCTAssertEqual(stored.moduleID, record.moduleID)
        XCTAssertEqual(stored.kind, record.kind)
        XCTAssertEqual(stored.baseFolder, record.baseFolder)
        XCTAssertEqual(stored.status, record.status)
        XCTAssertEqual(stored.undoAvailable, record.undoAvailable)
        XCTAssertEqual(stored.payload, record.payload)
        XCTAssertLessThan(abs(stored.createdAt.timeIntervalSince(record.createdAt)), 0.001)
        XCTAssertEqual(try history.latestUndoable(moduleID: record.moduleID, baseFolder: "/tmp/example")?.id, record.id)
        try history.updateUndoState(id: record.id, status: .undone, undoAvailable: false)
        let updated = try XCTUnwrap(history.record(id: record.id))
        XCTAssertEqual(updated.status, .undone)
        XCTAssertFalse(updated.undoAvailable)
    }
    func testBatchExecutionReusesOneStatementForAllRows() throws {
        let database = try SQLiteDatabase(url: directory.appendingPathComponent("batch.sqlite"))
        try database.execute("CREATE TABLE values_table(position INTEGER PRIMARY KEY, value TEXT NOT NULL)")
        try database.transaction {
            try database.executeBatch(
                "INSERT INTO values_table(position, value) VALUES(?, ?)",
                rowCount: 1_000
            ) { index in
                [.integer(Int64(index)), .text("value-\(index)")]
            }
        }
        let rows = try database.query("SELECT COUNT(*) AS total FROM values_table")
        XCTAssertEqual(try rows[0].integer("total"), 1_000)
    }

    func testGlobalHistoryIndexIsCreatedByMigration() throws {
        let database = try SQLiteDatabase(url: directory.appendingPathComponent("migration.sqlite"))
        _ = try HistoryRepository(database: database)
        let indexes = try database.query("PRAGMA index_list('operation_history')")
        let names = Set(try indexes.map { try $0.string("name") })
        XCTAssertTrue(names.contains("history_module_created"))
        XCTAssertTrue(names.contains("history_created"))
        let versions = try database.query("SELECT MAX(version) AS version FROM schema_migrations")
        XCTAssertEqual(try versions[0].integer("version"), 3)
        let cleanerTables = Set(try database.query("SELECT name FROM sqlite_master WHERE type=\'table\'").map { try $0.string("name") })
        XCTAssertTrue(cleanerTables.contains("cleaner_app_inventory"))
        XCTAssertTrue(cleanerTables.contains("cleaner_undo_items"))
    }

}
