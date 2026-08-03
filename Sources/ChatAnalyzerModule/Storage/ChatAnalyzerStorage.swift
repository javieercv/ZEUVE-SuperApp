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

/// SQLite se abre en modo serializado y todas las operaciones del contenedor se protegen además con un bloqueo local.
public final class TemporaryChatStore: @unchecked Sendable {
    public let url: URL
    private let lock = NSLock()
    private var database: SQLiteDatabase?

    public init(workspace: ChatTemporaryWorkspace) throws {
        url = workspace.directory.appendingPathComponent("analysis.sqlite")
        let database = try SQLiteDatabase(url: url)
        try database.execute("""
            CREATE TABLE IF NOT EXISTS messages(
                position INTEGER PRIMARY KEY,
                id TEXT NOT NULL UNIQUE,
                timestamp REAL NOT NULL,
                author TEXT NOT NULL,
                platform TEXT NOT NULL,
                content_type TEXT NOT NULL,
                payload BLOB NOT NULL
            )
            """)
        try database.execute("CREATE INDEX IF NOT EXISTS idx_messages_timestamp ON messages(timestamp)")
        try database.execute("CREATE INDEX IF NOT EXISTS idx_messages_author ON messages(author)")
        try database.execute("CREATE INDEX IF NOT EXISTS idx_messages_platform ON messages(platform)")
        try database.execute("CREATE INDEX IF NOT EXISTS idx_messages_type ON messages(content_type)")
        self.database = database
    }

    public func replace(messages: [NormalizedMessage]) throws {
        lock.lock(); defer { lock.unlock() }
        guard let database else { throw ChatAnalyzerError.storageUnavailable("La base temporal está cerrada.") }
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .millisecondsSince1970
        try database.transaction {
            try database.execute("DELETE FROM messages")
            try database.executeBatch(
                "INSERT INTO messages(position, id, timestamp, author, platform, content_type, payload) VALUES(?, ?, ?, ?, ?, ?, ?)",
                rowCount: messages.count
            ) { index in
                let message = messages[index]
                return [
                    .integer(Int64(index)),
                    .text(message.id),
                    .real(message.timestamp.timeIntervalSince1970),
                    .text(message.author),
                    .text(message.platform.rawValue),
                    .text(message.contentType.rawValue),
                    .blob(try encoder.encode(message)),
                ]
            }
        }
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
}

/// La sesión expone un resultado inmutable; el cierre idempotente está serializado.
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
