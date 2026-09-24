import Foundation
import ZEUVEStorage

public final class CleanerRepository: @unchecked Sendable {
    private let database: SQLiteDatabase
    private let fileManager: FileManager
    public init(database: SQLiteDatabase, fileManager: FileManager = .default) throws { self.database=database; self.fileManager=fileManager; try StorageMigrations.migrate(database) }

    public func upsertInventory(_ apps: [CleanerAppInventoryItem]) throws {
        let encoder=JSONEncoder(); let now=Date()
        try database.executeBatch("""
            INSERT INTO cleaner_app_inventory(bundle_id,path,volume_path,first_seen,last_seen,identity_blob)
            VALUES(?,?,?,?,?,?)
            ON CONFLICT(bundle_id,path) DO UPDATE SET volume_path=excluded.volume_path,last_seen=excluded.last_seen,identity_blob=excluded.identity_blob
            """, rowCount: apps.count) { i in
                var app=apps[i]; let existing=try self.inventoryItem(bundleID:app.identity.bundleID,path:app.identity.path)
                if let existing { app.firstSeen = existing.firstSeen }; app.lastSeen = now; app.availability = .installed
                return [.text(app.identity.bundleID ?? "path:\(app.identity.path)"),.text(app.identity.path),app.identity.volumePath.map(SQLiteValue.text) ?? .null,.text(Self.date(app.firstSeen)),.text(Self.date(app.lastSeen)),.blob(try encoder.encode(app))]
            }
    }

    public func markMissingInventory(except presentKeys: Set<String>) throws {
        let items=try loadInventory(); let encoder=JSONEncoder()
        for var item in items {
            let key=(item.identity.bundleID ?? "unsigned") + "|" + item.identity.path
            guard !presentKeys.contains(key) else { continue }
            let unavailable:Bool
            if let volume=item.identity.volumePath, volume != "/" { unavailable = !fileManager.fileExists(atPath: volume) } else { unavailable=false }
            item.availability = unavailable ? .externalVolumeUnavailable : .missing
            try database.execute("UPDATE cleaner_app_inventory SET identity_blob=? WHERE bundle_id=? AND path=?",bindings:[.blob(try encoder.encode(item)),.text(item.identity.bundleID ?? "path:\(item.identity.path)"),.text(item.identity.path)])
        }
    }

    public func loadInventory() throws -> [CleanerAppInventoryItem] {
        let decoder=JSONDecoder(); return try database.query("SELECT identity_blob FROM cleaner_app_inventory ORDER BY last_seen DESC").compactMap { row in try? decoder.decode(CleanerAppInventoryItem.self,from:row.blob("identity_blob")) }
    }

    public func upsertAssociatedRoots(_ candidates: [CleanerCandidate]) throws {
        let encoder=JSONEncoder(); let now=Self.date(Date())
        try database.executeBatch("""
            INSERT INTO cleaner_associated_roots(id,bundle_id,path,category,logical_size,state,risk,evidence_blob,last_seen)
            VALUES(?,?,?,?,?,?,?,?,?)
            ON CONFLICT(path) DO UPDATE SET bundle_id=excluded.bundle_id,category=excluded.category,logical_size=excluded.logical_size,state=excluded.state,risk=excluded.risk,evidence_blob=excluded.evidence_blob,last_seen=excluded.last_seen
            """,rowCount:candidates.count){i in let c=candidates[i];return [.text(c.id.uuidString),c.associatedBundleID.map(SQLiteValue.text) ?? .null,.text(c.url.path),.text(c.category.rawValue),.integer(c.logicalSize ?? 0),.text(c.status.rawValue),.text(c.risk.rawValue),.blob(try encoder.encode(c.evidences)),.text(now)]}
    }

    public func keep(path: String, value: Bool) throws {
        if value { try database.execute("INSERT INTO cleaner_user_decisions(path,decision,updated_at) VALUES(?,'keep',?) ON CONFLICT(path) DO UPDATE SET decision='keep',updated_at=excluded.updated_at",bindings:[.text(path),.text(Self.date(Date()))]) }
        else { try database.execute("DELETE FROM cleaner_user_decisions WHERE path=?",bindings:[.text(path)]) }
    }
    public func keptPaths() throws -> Set<String> { Set(try database.query("SELECT path FROM cleaner_user_decisions WHERE decision='keep'").compactMap{try? $0.string("path")}) }
    public func isKept(path:String)throws->Bool{!((try database.query("SELECT path FROM cleaner_user_decisions WHERE path=? AND decision='keep' LIMIT 1",bindings:[.text(path)])).isEmpty)}

    public func saveScanMetadata(_ summary: CleanerScanSummary) throws { try database.execute("INSERT INTO cleaner_scan_metadata(id,created_at,coverage,logical_size,allocated_size,issue_count) VALUES(?,?,?,?,?,?)",bindings:[.text(UUID().uuidString),.text(Self.date(summary.finishedAt)),.text(summary.coverage.rawValue),.integer(summary.scannedLogicalBytes),.integer(summary.potentialRecoverableBytes),.integer(Int64(summary.inaccessibleLocations))]) }

    public func addUndoItem(_ item: CleanerUndoItem) throws { try database.execute("INSERT INTO cleaner_undo_items(id,operation_id,original_path,trash_path,fingerprint_blob,created_at) VALUES(?,?,?,?,?,?)",bindings:[.text(item.id.uuidString),.text(item.historyID.uuidString),.text(item.originalURL.path),.text(item.trashURL.path),.blob(try JSONEncoder().encode(item.fingerprint)),.text(Self.date(Date()))]) }
    public func undoItems(historyID: UUID) throws -> [CleanerUndoItem] { let d=JSONDecoder();return try database.query("SELECT * FROM cleaner_undo_items WHERE operation_id=? ORDER BY created_at DESC",bindings:[.text(historyID.uuidString)]).compactMap{row in guard let id=UUID(uuidString:try row.string("id")),let fp=try? d.decode(CleanerFileFingerprint.self,from:row.blob("fingerprint_blob")) else{return nil};return .init(id:id,historyID:historyID,originalURL:URL(fileURLWithPath:try row.string("original_path")),trashURL:URL(fileURLWithPath:try row.string("trash_path")),fingerprint:fp)} }
    public func removeUndoItem(id: UUID) throws { try database.execute("DELETE FROM cleaner_undo_items WHERE id=?",bindings:[.text(id.uuidString)]) }
    public func clearInventoryHistory() throws { try database.transaction { try database.execute("DELETE FROM cleaner_associated_roots");try database.execute("DELETE FROM cleaner_app_inventory");try database.execute("DELETE FROM cleaner_scan_metadata") } }

    private func inventoryItem(bundleID:String?,path:String)throws->CleanerAppInventoryItem?{let rows=try database.query("SELECT identity_blob FROM cleaner_app_inventory WHERE bundle_id=? AND path=?",bindings:[.text(bundleID ?? "path:\(path)"),.text(path)]);guard let row=rows.first else{return nil};return try? JSONDecoder().decode(CleanerAppInventoryItem.self,from:row.blob("identity_blob"))}
    private static func date(_ date:Date)->String{let f=ISO8601DateFormatter();f.formatOptions=[.withInternetDateTime,.withFractionalSeconds];return f.string(from:date)}
}
