import Foundation

public enum StorageMigrations {
    public static func migrate(_ database: SQLiteDatabase) throws {
        try database.transaction {
            try database.execute(
                """
                CREATE TABLE IF NOT EXISTS schema_migrations (
                    version INTEGER PRIMARY KEY,
                    applied_at TEXT NOT NULL
                )
                """
            )
            let rows = try database.query("SELECT COALESCE(MAX(version), 0) AS version FROM schema_migrations")
            let version = rows.first.flatMap { try? $0.integer("version") } ?? 0
            if version < 1 {
                try database.execute(
                    """
                    CREATE TABLE IF NOT EXISTS settings (
                        key TEXT PRIMARY KEY,
                        value BLOB NOT NULL,
                        updated_at TEXT NOT NULL
                    )
                    """
                )
                try database.execute(
                    """
                    CREATE TABLE IF NOT EXISTS operation_history (
                        id TEXT PRIMARY KEY,
                        module_id TEXT NOT NULL,
                        kind TEXT NOT NULL,
                        base_folder TEXT,
                        created_at TEXT NOT NULL,
                        status TEXT NOT NULL,
                        undo_available INTEGER NOT NULL,
                        payload BLOB NOT NULL
                    )
                    """
                )
                try database.execute(
                    "CREATE INDEX IF NOT EXISTS history_module_created ON operation_history(module_id, created_at DESC)"
                )
                try database.execute(
                    "INSERT INTO schema_migrations(version, applied_at) VALUES(1, ?)",
                    bindings: [.text(ISO8601DateFormatter().string(from: Date()))]
                )
            }
            if version < 2 {
                try database.execute(
                    "CREATE INDEX IF NOT EXISTS history_created ON operation_history(created_at DESC)"
                )
                try database.execute(
                    "INSERT INTO schema_migrations(version, applied_at) VALUES(2, ?)",
                    bindings: [.text(ISO8601DateFormatter().string(from: Date()))]
                )
            }
        }
    }
}
