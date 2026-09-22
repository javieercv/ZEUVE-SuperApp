import Foundation
import ZEUVEStorage

/// La exclusión mutua protege completamente el único estado mutable.
public final class ChatCancellationToken: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    public init() {}
    public func cancel() { lock.lock(); value = true; lock.unlock() }
    public var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return value }
}

/// La limpieza está serializada y solo elimina carpetas que contienen el marcador de propiedad de ZEUVE.
public final class ChatTemporaryWorkspace: @unchecked Sendable {
    public let directory: URL
    private let fileManager: FileManager
    private let lock = NSLock()
    private var cleaned = false

    public init(operationID: UUID, fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        let root = fileManager.temporaryDirectory.appendingPathComponent("ZEUVE/ChatAnalyzer", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        directory = root.appendingPathComponent(operationID.uuidString, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: false)
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        var mutable = directory; try? mutable.setResourceValues(values)
        try Data(operationID.uuidString.utf8).write(to: directory.appendingPathComponent(".zeuve-chat-operation"), options: .atomic)
    }

    public func cleanup() throws {
        lock.lock(); defer { lock.unlock() }
        guard !cleaned else { return }
        let marker = directory.appendingPathComponent(".zeuve-chat-operation")
        guard fileManager.fileExists(atPath: marker.path) else { throw ChatAnalyzerError.storageUnavailable("No se ha podido verificar la propiedad de los temporales.") }
        try fileManager.removeItem(at: directory)
        cleaned = true
    }

    deinit { try? cleanup() }

    public static func cleanupAbandoned(fileManager: FileManager = .default) {
        let root = fileManager.temporaryDirectory.appendingPathComponent("ZEUVE/ChatAnalyzer", isDirectory: true)
        guard let folders = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else { return }
        let cutoff = Date().addingTimeInterval(-24 * 3_600)
        for folder in folders {
            let marker = folder.appendingPathComponent(".zeuve-chat-operation")
            let modified = (try? folder.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantFuture
            if modified < cutoff && fileManager.fileExists(atPath: marker.path) { try? fileManager.removeItem(at: folder) }
        }
    }
}

public struct TemporaryChatStoreStatistics: Sendable, Equatable {
    public let messages: Int
    public let participants: Int
    public let platforms: Set<ChatPlatform>
    public let firstMessage: Date?
    public let lastMessage: Date?
}

/// SQLite es la fuente principal de la sesión. Las inserciones se deduplican en la propia base y
/// las lecturas se realizan por páginas para no obligar a materializar el dataset completo.
public final class TemporaryChatStore: @unchecked Sendable {
    public let url: URL
    private let lock = NSLock()
    private var database: SQLiteDatabase?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(workspace: ChatTemporaryWorkspace) throws {
        url = workspace.directory.appendingPathComponent("analysis.sqlite")
        encoder = JSONEncoder(); encoder.dateEncodingStrategy = .millisecondsSince1970
        decoder = JSONDecoder(); decoder.dateDecodingStrategy = .millisecondsSince1970
        let database = try SQLiteDatabase(url: url)
        try database.execute("""
            CREATE TABLE IF NOT EXISTS messages(
                position INTEGER PRIMARY KEY AUTOINCREMENT,
                id TEXT NOT NULL UNIQUE,
                dedupe_key TEXT NOT NULL UNIQUE,
                timestamp REAL NOT NULL,
                author TEXT NOT NULL,
                original_author TEXT NOT NULL,
                platform TEXT NOT NULL,
                content_type TEXT NOT NULL,
                source_position INTEGER NOT NULL,
                is_system INTEGER NOT NULL,
                payload BLOB NOT NULL
            )
            """)
        try database.execute("CREATE INDEX IF NOT EXISTS idx_messages_order ON messages(timestamp, platform, source_position, position)")
        try database.execute("CREATE INDEX IF NOT EXISTS idx_messages_author ON messages(author)")
        try database.execute("CREATE INDEX IF NOT EXISTS idx_messages_original_author ON messages(original_author)")
        try database.execute("CREATE INDEX IF NOT EXISTS idx_messages_platform ON messages(platform)")
        try database.execute("CREATE INDEX IF NOT EXISTS idx_messages_type ON messages(content_type)")
        self.database = database
    }

    /// Inserta un lote y devuelve cuántos mensajes nuevos se conservaron tras deduplicar.
    @discardableResult
    public func append(messages: [NormalizedMessage]) throws -> Int {
        guard !messages.isEmpty else { return 0 }
        lock.lock(); defer { lock.unlock() }
        guard let database else { throw ChatAnalyzerError.storageUnavailable("La base temporal está cerrada.") }
        // Cualquier inserción invalida el índice cronológico materializado. Durante una
        // importación normal este índice se crea una sola vez, cuando ya no quedan lotes.
        try database.execute("DROP TABLE IF EXISTS timeline")
        let before = try countLocked(database)
        try database.transaction {
            try database.executeBatch(
                """
                INSERT OR IGNORE INTO messages(
                    id, dedupe_key, timestamp, author, original_author, platform,
                    content_type, source_position, is_system, payload
                ) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                rowCount: messages.count
            ) { [encoder] index in
                let message = messages[index]
                return [
                    .text(message.id),
                    .text(MessageDeduplicator.conservativeKey(for: message)),
                    .real(message.timestamp.timeIntervalSince1970),
                    .text(message.author),
                    .text(message.originalAuthor),
                    .text(message.platform.rawValue),
                    .text(message.contentType.rawValue),
                    .integer(Int64(message.sourcePosition)),
                    .integer(message.isSystem ? 1 : 0),
                    .blob(try encoder.encode(message)),
                ]
            }
        }
        return try countLocked(database) - before
    }

    /// API conservada para pruebas y consumidores pequeños; internamente usa la misma ruta por lotes.
    public func replace(messages: [NormalizedMessage]) throws {
        lock.lock()
        guard let database else { lock.unlock(); throw ChatAnalyzerError.storageUnavailable("La base temporal está cerrada.") }
        do {
            try database.execute("DROP TABLE IF EXISTS timeline")
            try database.execute("DELETE FROM messages")
        } catch {
            lock.unlock()
            throw error
        }
        lock.unlock()
        _ = try append(messages: messages)
    }

    public func messageCount() throws -> Int {
        lock.lock(); defer { lock.unlock() }
        guard let database else { throw ChatAnalyzerError.storageUnavailable("La base temporal está cerrada.") }
        return try countLocked(database)
    }

    public func statistics() throws -> TemporaryChatStoreStatistics {
        lock.lock(); defer { lock.unlock() }
        guard let database else { throw ChatAnalyzerError.storageUnavailable("La base temporal está cerrada.") }
        let aggregate = try database.query("""
            SELECT COUNT(*) AS messages,
                   COUNT(DISTINCT CASE WHEN is_system = 0 THEN author END) AS participants,
                   MIN(timestamp) AS first_timestamp,
                   MAX(timestamp) AS last_timestamp
            FROM messages
            """).first ?? [:]
        let platformRows = try database.query("SELECT DISTINCT platform FROM messages ORDER BY platform")
        let platforms = Set(platformRows.compactMap { row -> ChatPlatform? in
            guard let raw = try? row.string("platform") else { return nil }
            return ChatPlatform(rawValue: raw)
        })
        return TemporaryChatStoreStatistics(
            messages: Int((try? aggregate.integer("messages")) ?? 0),
            participants: Int((try? aggregate.integer("participants")) ?? 0),
            platforms: platforms,
            firstMessage: Self.date(from: aggregate["first_timestamp"]),
            lastMessage: Self.date(from: aggregate["last_timestamp"])
        )
    }

    /// Materializa una secuencia cronológica estable en disco. Esto evita OFFSET crecientes
    /// cuando la sesión tiene millones de mensajes y convierte SQLite en la fuente ordenada
    /// reutilizable por todas las analíticas posteriores.
    public func prepareTimeline() throws {
        lock.lock(); defer { lock.unlock() }
        guard let database else { throw ChatAnalyzerError.storageUnavailable("La base temporal está cerrada.") }
        try database.transaction {
            try database.execute("DROP TABLE IF EXISTS timeline")
            try database.execute("""
                CREATE TABLE timeline(
                    sequence INTEGER PRIMARY KEY AUTOINCREMENT,
                    message_position INTEGER NOT NULL UNIQUE
                )
                """)
            try database.execute("""
                INSERT INTO timeline(message_position)
                SELECT position
                FROM messages
                ORDER BY timestamp, platform, source_position, position
                """)
            try database.execute("CREATE INDEX IF NOT EXISTS idx_timeline_message_position ON timeline(message_position)")
        }
    }

    public func messages(offset: Int, limit: Int) throws -> [NormalizedMessage] {
        guard limit > 0, offset >= 0 else { return [] }
        lock.lock(); defer { lock.unlock() }
        guard let database else { throw ChatAnalyzerError.storageUnavailable("La base temporal está cerrada.") }
        let rows: [[String: SQLiteValue]]
        if try timelineExistsLocked(database) {
            // `sequence` es 1-based por AUTOINCREMENT; la API pública continúa siendo 0-based.
            let first = Int64(offset + 1)
            let lastExclusive = first + Int64(limit)
            rows = try database.query(
                """
                SELECT m.payload
                FROM timeline t
                JOIN messages m ON m.position = t.message_position
                WHERE t.sequence >= ? AND t.sequence < ?
                ORDER BY t.sequence
                """,
                bindings: [.integer(first), .integer(lastExclusive)]
            )
        } else {
            rows = try database.query(
                """
                SELECT payload FROM messages
                ORDER BY timestamp, platform, source_position, position
                LIMIT ? OFFSET ?
                """,
                bindings: [.integer(Int64(limit)), .integer(Int64(offset))]
            )
        }
        return try rows.map { try decoder.decode(NormalizedMessage.self, from: $0.blob("payload")) }
    }

    public func message(at index: Int) throws -> NormalizedMessage? {
        try messages(offset: index, limit: 1).first
    }

    public func allMessages(batchSize: Int = 4_096, cancellation: @Sendable () -> Bool = { false }) throws -> [NormalizedMessage] {
        var result: [NormalizedMessage] = []
        let count = try messageCount()
        result.reserveCapacity(count)
        try forEachBatch(batchSize: batchSize, cancellation: cancellation) { result.append(contentsOf: $0) }
        return result
    }

    public func forEachBatch(
        batchSize: Int = 4_096,
        cancellation: @Sendable () -> Bool = { false },
        _ consume: ([NormalizedMessage]) throws -> Void
    ) throws {
        try forEachIndexedBatch(batchSize: batchSize, cancellation: cancellation) { _, batch in
            try consume(batch)
        }
    }

    public func forEachIndexedBatch(
        batchSize: Int = 4_096,
        cancellation: @Sendable () -> Bool = { false },
        _ consume: (Int, [NormalizedMessage]) throws -> Void
    ) throws {
        let size = max(128, batchSize)
        var offset = 0
        while true {
            if cancellation() || Task.isCancelled { throw ChatAnalyzerError.cancelled }
            let batch = try messages(offset: offset, limit: size)
            guard !batch.isEmpty else { return }
            try consume(offset, batch)
            offset += batch.count
            if batch.count < size { return }
        }
    }

    public func originalAuthors(
        matchingDisplayedParticipants participants: Set<String>,
        identityMap: [String: String],
        cancellation: @Sendable () -> Bool = { false }
    ) throws -> Set<String> {
        guard !participants.isEmpty else { return [] }
        if cancellation() || Task.isCancelled { throw ChatAnalyzerError.cancelled }
        lock.lock(); defer { lock.unlock() }
        guard let database else { throw ChatAnalyzerError.storageUnavailable("La base temporal está cerrada.") }
        let rows = try database.query("""
            SELECT DISTINCT original_author, author
            FROM messages
            WHERE is_system = 0
            ORDER BY original_author
            """)
        var result = Set<String>()
        for (index, row) in rows.enumerated() {
            if index.isMultiple(of: 512), (cancellation() || Task.isCancelled) { throw ChatAnalyzerError.cancelled }
            let original = try row.string("original_author")
            let author = try row.string("author")
            let displayed = identityMap[original] ?? author
            if participants.contains(displayed) { result.insert(original) }
        }
        return result
    }

    public func closeAndDelete() {
        lock.lock(); defer { lock.unlock() }
        database = nil
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: url)
        try? fileManager.removeItem(at: URL(fileURLWithPath: url.path + "-wal"))
        try? fileManager.removeItem(at: URL(fileURLWithPath: url.path + "-shm"))
    }

    deinit { closeAndDelete() }

    private func countLocked(_ database: SQLiteDatabase) throws -> Int {
        let row = try database.query("SELECT COUNT(*) AS count FROM messages").first ?? [:]
        return Int(try row.integer("count"))
    }

    private func timelineExistsLocked(_ database: SQLiteDatabase) throws -> Bool {
        let row = try database.query(
            "SELECT COUNT(*) AS count FROM sqlite_master WHERE type = 'table' AND name = 'timeline'"
        ).first ?? [:]
        return try row.integer("count") > 0
    }

    private static func date(from value: SQLiteValue?) -> Date? {
        guard case .real(let seconds) = value else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }
}

/// La sesión expone metadatos inmutables y el store paginado; el cierre idempotente está serializado.
public final class ChatAnalysisSession: @unchecked Sendable, Identifiable {
    public let result: ChatAnalysisResult
    public let store: TemporaryChatStore
    private let workspace: ChatTemporaryWorkspace
    private let lock = NSLock()
    private var closed = false
    public var id: UUID { result.id }
    public var temporaryDirectory: URL { workspace.directory }

    public init(result: ChatAnalysisResult, store: TemporaryChatStore, workspace: ChatTemporaryWorkspace) {
        self.result = result; self.store = store; self.workspace = workspace
    }

    public func close() {
        lock.lock(); defer { lock.unlock() }
        guard !closed else { return }
        store.closeAndDelete()
        try? workspace.cleanup()
        closed = true
    }

    deinit { close() }
}

/// El repositorio subyacente ya serializa sus accesos; el servicio no mantiene estado mutable.
public final class ChatAnalyzerSettingsService: @unchecked Sendable {
    private let repository: SettingsRepository?
    public static let key = "chatAnalyzer.defaultSettings"
    public init(repository: SettingsRepository?) { self.repository = repository }
    public func load() -> ChatAnalyzerSettings { (try? repository?.value(forKey: Self.key, as: ChatAnalyzerSettings.self)) ?? ChatAnalyzerSettings() }
    public func save(_ settings: ChatAnalyzerSettings) throws { try repository?.set(settings, forKey: Self.key) }
    public func restoreDefaults() throws { try repository?.removeValue(forKey: Self.key) }
}
