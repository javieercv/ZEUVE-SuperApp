import Foundation

public enum LogLevel: String, Codable, Sendable {
    case debug
    case info
    case warning
    case error
}

public struct LocalLogEntry: Codable, Sendable, Equatable {
    public let timestamp: Date
    public let level: LogLevel
    public let category: String
    public let message: String
    public let metadata: [String: String]

    public init(
        timestamp: Date = Date(),
        level: LogLevel,
        category: String,
        message: String,
        metadata: [String: String] = [:]
    ) {
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.metadata = metadata
    }
}

public actor LocalLogger {
    private let directory: URL
    private let encoder: JSONEncoder

    public init(directory: URL) throws {
        self.directory = directory.standardizedFileURL
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        try FileManager.default.createDirectory(
            at: self.directory,
            withIntermediateDirectories: true
        )
    }

    @discardableResult
    public func write(
        _ level: LogLevel,
        category: String,
        message: String,
        metadata: [String: String] = [:],
        timestamp: Date = Date()
    ) throws -> URL {
        let entry = LocalLogEntry(
            timestamp: timestamp,
            level: level,
            category: category,
            message: message,
            metadata: metadata
        )
        var data = try encoder.encode(entry)
        data.append(0x0A)

        let destination = directory.appendingPathComponent(Self.filename(for: timestamp))
        if !FileManager.default.fileExists(atPath: destination.path) {
            try Data().write(to: destination, options: .atomic)
        }
        let handle = try FileHandle(forWritingTo: destination)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
        return destination
    }

    private static func filename(for date: Date) -> String {
        let components = Calendar(identifier: .gregorian).dateComponents(
            in: TimeZone.current,
            from: date
        )
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "zeuve-%04d-%02d-%02d.jsonl", year, month, day)
    }
}
