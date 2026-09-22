import Foundation
#if SWIFT_PACKAGE
import CSQLite
#else
import SQLite3
#endif

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public enum SQLiteValue: Sendable, Equatable {
    case integer(Int64)
    case real(Double)
    case text(String)
    case blob(Data)
    case null
}

public enum SQLiteDatabaseError: LocalizedError, Equatable {
    case openFailed(String)
    case prepareFailed(String)
    case bindFailed(String)
    case stepFailed(String)
    case missingColumn(String)
    case invalidColumn(String)

    public var errorDescription: String? {
        switch self {
        case .openFailed(let message): return "No se ha podido abrir la base de datos: \(message)"
        case .prepareFailed(let message): return "No se ha podido preparar la consulta: \(message)"
        case .bindFailed(let message): return "No se han podido enlazar los datos: \(message)"
        case .stepFailed(let message): return "La base de datos no ha podido completar la operación: \(message)"
        case .missingColumn(let name): return "Falta la columna esperada: \(name)."
        case .invalidColumn(let name): return "El valor de la columna \(name) no es válido."
        }
    }
}

public final class SQLiteDatabase: @unchecked Sendable {
    private let lock = NSRecursiveLock()
    private var handle: OpaquePointer?
    public let url: URL

    public init(url: URL) throws {
        self.url = url
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var database: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &database, flags, nil) == SQLITE_OK, let database else {
            let message = database.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Error desconocido"
            if let database { sqlite3_close(database) }
            throw SQLiteDatabaseError.openFailed(message)
        }
        self.handle = database
        try execute("PRAGMA foreign_keys = ON")
        try execute("PRAGMA journal_mode = WAL")
        try execute("PRAGMA synchronous = NORMAL")
    }

    deinit {
        lock.lock()
        if let handle { sqlite3_close(handle) }
        handle = nil
        lock.unlock()
    }

    public func execute(_ sql: String, bindings: [SQLiteValue] = []) throws {
        try lock.withLock {
            let statement = try prepare(sql)
            defer { sqlite3_finalize(statement) }
            try bind(bindings, to: statement)
            let result = sqlite3_step(statement)
            guard result == SQLITE_DONE || result == SQLITE_ROW else {
                throw SQLiteDatabaseError.stepFailed(lastErrorMessage)
            }
        }
    }

    public func executeBatch(
        _ sql: String,
        rowCount: Int,
        bindingsForRow: (Int) throws -> [SQLiteValue]
    ) throws {
        guard rowCount > 0 else { return }
        try lock.withLock {
            let statement = try prepare(sql)
            defer { sqlite3_finalize(statement) }
            for index in 0..<rowCount {
                guard sqlite3_reset(statement) == SQLITE_OK else {
                    throw SQLiteDatabaseError.stepFailed(lastErrorMessage)
                }
                guard sqlite3_clear_bindings(statement) == SQLITE_OK else {
                    throw SQLiteDatabaseError.bindFailed(lastErrorMessage)
                }
                try bind(try bindingsForRow(index), to: statement)
                guard sqlite3_step(statement) == SQLITE_DONE else {
                    throw SQLiteDatabaseError.stepFailed(lastErrorMessage)
                }
            }
        }
    }

    public func query(_ sql: String, bindings: [SQLiteValue] = []) throws -> [[String: SQLiteValue]] {
        try lock.withLock {
            let statement = try prepare(sql)
            defer { sqlite3_finalize(statement) }
            try bind(bindings, to: statement)
            var rows: [[String: SQLiteValue]] = []
            while true {
                let result = sqlite3_step(statement)
                if result == SQLITE_DONE { return rows }
                guard result == SQLITE_ROW else {
                    throw SQLiteDatabaseError.stepFailed(lastErrorMessage)
                }
                var row: [String: SQLiteValue] = [:]
                for index in 0..<sqlite3_column_count(statement) {
                    let name = String(cString: sqlite3_column_name(statement, index))
                    row[name] = value(statement: statement, index: index)
                }
                rows.append(row)
            }
        }
    }

    public func transaction<T>(_ body: () throws -> T) throws -> T {
        try lock.withLock {
            try execute("BEGIN IMMEDIATE")
            do {
                let value = try body()
                try execute("COMMIT")
                return value
            } catch {
                try? execute("ROLLBACK")
                throw error
            }
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        guard let handle else { throw SQLiteDatabaseError.openFailed("Conexión cerrada") }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw SQLiteDatabaseError.prepareFailed(lastErrorMessage)
        }
        return statement
    }

    private func bind(_ bindings: [SQLiteValue], to statement: OpaquePointer) throws {
        for (offset, value) in bindings.enumerated() {
            let index = Int32(offset + 1)
            let result: Int32
            switch value {
            case .integer(let value):
                result = sqlite3_bind_int64(statement, index, value)
            case .real(let value):
                result = sqlite3_bind_double(statement, index, value)
            case .text(let value):
                result = value.withCString {
                    sqlite3_bind_text(statement, index, $0, -1, sqliteTransient)
                }
            case .blob(let data):
                result = data.withUnsafeBytes { bytes in
                    sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(data.count), sqliteTransient)
                }
            case .null:
                result = sqlite3_bind_null(statement, index)
            }
            guard result == SQLITE_OK else { throw SQLiteDatabaseError.bindFailed(lastErrorMessage) }
        }
    }

    private func value(statement: OpaquePointer, index: Int32) -> SQLiteValue {
        switch sqlite3_column_type(statement, index) {
        case SQLITE_INTEGER:
            return .integer(sqlite3_column_int64(statement, index))
        case SQLITE_FLOAT:
            return .real(sqlite3_column_double(statement, index))
        case SQLITE_TEXT:
            guard let text = sqlite3_column_text(statement, index) else { return .null }
            return .text(String(cString: text))
        case SQLITE_BLOB:
            let count = Int(sqlite3_column_bytes(statement, index))
            guard count > 0, let bytes = sqlite3_column_blob(statement, index) else { return .blob(Data()) }
            return .blob(Data(bytes: bytes, count: count))
        default:
            return .null
        }
    }

    private var lastErrorMessage: String {
        guard let handle else { return "Conexión cerrada" }
        return String(cString: sqlite3_errmsg(handle))
    }
}

private extension NSRecursiveLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}

public extension Dictionary where Key == String, Value == SQLiteValue {
    func string(_ key: String) throws -> String {
        guard let value = self[key] else { throw SQLiteDatabaseError.missingColumn(key) }
        guard case .text(let text) = value else { throw SQLiteDatabaseError.invalidColumn(key) }
        return text
    }

    func optionalString(_ key: String) throws -> String? {
        guard let value = self[key] else { throw SQLiteDatabaseError.missingColumn(key) }
        if case .null = value { return nil }
        guard case .text(let text) = value else { throw SQLiteDatabaseError.invalidColumn(key) }
        return text
    }

    func integer(_ key: String) throws -> Int64 {
        guard let value = self[key] else { throw SQLiteDatabaseError.missingColumn(key) }
        guard case .integer(let number) = value else { throw SQLiteDatabaseError.invalidColumn(key) }
        return number
    }

    func blob(_ key: String) throws -> Data {
        guard let value = self[key] else { throw SQLiteDatabaseError.missingColumn(key) }
        guard case .blob(let data) = value else { throw SQLiteDatabaseError.invalidColumn(key) }
        return data
    }
}
