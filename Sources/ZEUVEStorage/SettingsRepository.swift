import Foundation
#if SWIFT_PACKAGE
import ZEUVECore
#endif

public final class SettingsRepository: @unchecked Sendable {
    private let database: SQLiteDatabase

    public init(database: SQLiteDatabase) throws {
        self.database = database
        try StorageMigrations.migrate(database)
    }

    public func set<T: Encodable & Sendable>(_ value: T, forKey key: String) throws {
        let data = try JSONEncoder().encode(value)
        try database.execute(
            """
            INSERT INTO settings(key, value, updated_at)
            VALUES(?, ?, ?)
            ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at
            """,
            bindings: [
                .text(key),
                .blob(data),
                .text(ISO8601DateFormatter().string(from: Date())),
            ]
        )
    }

    public func value<T: Decodable & Sendable>(forKey key: String, as type: T.Type) throws -> T? {
        let rows = try database.query("SELECT value FROM settings WHERE key = ?", bindings: [.text(key)])
        guard let row = rows.first else { return nil }
        return try JSONDecoder().decode(type, from: row.blob("value"))
    }

    public func removeValue(forKey key: String) throws {
        try database.execute("DELETE FROM settings WHERE key = ?", bindings: [.text(key)])
    }
}
