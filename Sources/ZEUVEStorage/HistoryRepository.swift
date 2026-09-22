import Foundation
#if SWIFT_PACKAGE
import ZEUVECore
#endif

public final class HistoryRepository: @unchecked Sendable {
    private let database: SQLiteDatabase

    public init(database: SQLiteDatabase) throws {
        self.database = database
        try StorageMigrations.migrate(database)
    }

    public func add(_ record: OperationHistoryRecord) throws {
        try database.execute(
            """
            INSERT INTO operation_history(
                id, module_id, kind, base_folder, created_at, status, undo_available, payload
            ) VALUES(?, ?, ?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                .text(record.id.uuidString),
                .text(record.moduleID),
                .text(record.kind),
                record.baseFolder.map(SQLiteValue.text) ?? .null,
                .text(Self.encodeDate(record.createdAt)),
                .text(record.status.rawValue),
                .integer(record.undoAvailable ? 1 : 0),
                .blob(record.payload),
            ]
        )
    }

    public func updateUndoState(
        id: UUID,
        status: OperationStatus,
        undoAvailable: Bool,
        payload: Data? = nil
    ) throws {
        if let payload {
            try database.execute(
                "UPDATE operation_history SET status = ?, undo_available = ?, payload = ? WHERE id = ?",
                bindings: [.text(status.rawValue), .integer(undoAvailable ? 1 : 0), .blob(payload), .text(id.uuidString)]
            )
        } else {
            try database.execute(
                "UPDATE operation_history SET status = ?, undo_available = ? WHERE id = ?",
                bindings: [.text(status.rawValue), .integer(undoAvailable ? 1 : 0), .text(id.uuidString)]
            )
        }
    }

    public func record(id: UUID) throws -> OperationHistoryRecord? {
        let rows = try database.query("SELECT * FROM operation_history WHERE id = ?", bindings: [.text(id.uuidString)])
        return try rows.first.map(decode)
    }

    public func records(moduleID: String? = nil, limit: Int = 100) throws -> [OperationHistoryRecord] {
        let safeLimit = max(1, min(limit, 1_000))
        let rows: [[String: SQLiteValue]]
        if let moduleID {
            rows = try database.query(
                "SELECT * FROM operation_history WHERE module_id = ? ORDER BY created_at DESC LIMIT ?",
                bindings: [.text(moduleID), .integer(Int64(safeLimit))]
            )
        } else {
            rows = try database.query(
                "SELECT * FROM operation_history ORDER BY created_at DESC LIMIT ?",
                bindings: [.integer(Int64(safeLimit))]
            )
        }
        return try rows.map(decode)
    }

    public func latestUndoable(moduleID: String, baseFolder: String) throws -> OperationHistoryRecord? {
        let rows = try database.query(
            """
            SELECT * FROM operation_history
            WHERE module_id = ? AND base_folder = ? AND undo_available = 1
            ORDER BY created_at DESC LIMIT 1
            """,
            bindings: [.text(moduleID), .text(baseFolder)]
        )
        return try rows.first.map(decode)
    }

    private static func encodeDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func decodeDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }

    private func decode(_ row: [String: SQLiteValue]) throws -> OperationHistoryRecord {
        guard let id = UUID(uuidString: try row.string("id")) else {
            throw SQLiteDatabaseError.invalidColumn("id")
        }
        guard let date = Self.decodeDate(try row.string("created_at")) else {
            throw SQLiteDatabaseError.invalidColumn("created_at")
        }
        guard let status = OperationStatus(rawValue: try row.string("status")) else {
            throw SQLiteDatabaseError.invalidColumn("status")
        }
        return OperationHistoryRecord(
            id: id,
            moduleID: try row.string("module_id"),
            kind: try row.string("kind"),
            baseFolder: try row.optionalString("base_folder"),
            createdAt: date,
            status: status,
            undoAvailable: try row.integer("undo_available") != 0,
            payload: try row.blob("payload")
        )
    }
}
