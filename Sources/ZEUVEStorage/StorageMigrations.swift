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
            if version < 3 {
                try database.execute("""
                    CREATE TABLE IF NOT EXISTS cleaner_app_inventory (
                        bundle_id TEXT NOT NULL, path TEXT NOT NULL, volume_path TEXT NOT NULL,
                        first_seen TEXT NOT NULL, last_seen TEXT NOT NULL, identity_blob BLOB NOT NULL,
                        PRIMARY KEY(bundle_id, path)
                    )
                    """)
                try database.execute("""
                    CREATE TABLE IF NOT EXISTS cleaner_associated_roots (
                        id TEXT NOT NULL, bundle_id TEXT, path TEXT PRIMARY KEY, category TEXT NOT NULL,
                        logical_size INTEGER NOT NULL, state TEXT NOT NULL, risk TEXT NOT NULL, evidence_blob BLOB NOT NULL, last_seen TEXT NOT NULL
                    )
                    """)
                try database.execute("""
                    CREATE TABLE IF NOT EXISTS cleaner_user_decisions (
                        path TEXT PRIMARY KEY, decision TEXT NOT NULL, updated_at TEXT NOT NULL
                    )
                    """)
                try database.execute("""
                    CREATE TABLE IF NOT EXISTS cleaner_scan_metadata (
                        id TEXT PRIMARY KEY, created_at TEXT NOT NULL, coverage TEXT NOT NULL, logical_size INTEGER NOT NULL,
                        allocated_size INTEGER, issue_count INTEGER NOT NULL
                    )
                    """)
                try database.execute("""
                    CREATE TABLE IF NOT EXISTS cleaner_undo_items (
                        id TEXT PRIMARY KEY, operation_id TEXT NOT NULL, original_path TEXT NOT NULL, trash_path TEXT NOT NULL,
                        fingerprint_blob BLOB NOT NULL, created_at TEXT NOT NULL
                    )
                    """)
                try database.execute("CREATE INDEX IF NOT EXISTS cleaner_apps_last_seen ON cleaner_app_inventory(last_seen DESC)")
                try database.execute("CREATE INDEX IF NOT EXISTS cleaner_roots_bundle ON cleaner_associated_roots(bundle_id)")
                try database.execute("CREATE INDEX IF NOT EXISTS cleaner_undo_operation ON cleaner_undo_items(operation_id)")
                try database.execute(
                    "INSERT INTO schema_migrations(version, applied_at) VALUES(3, ?)",
                    bindings: [.text(ISO8601DateFormatter().string(from: Date()))]
                )
            }
        }
    }
}
