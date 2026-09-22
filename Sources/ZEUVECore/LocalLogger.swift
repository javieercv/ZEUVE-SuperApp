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
    public static let retentionDays = 30
    public static let maximumTotalBytes: Int64 = 50 * 1_024 * 1_024

    private let directory: URL
    private let encoder: JSONEncoder
    private let fileManager: FileManager

    public init(directory: URL, fileManager: FileManager = .default) throws {
        self.directory = directory.standardizedFileURL
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        try fileManager.createDirectory(
            at: self.directory,
            withIntermediateDirectories: true
        )
        try? fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: self.directory.path)
        try Self.prune(
            directory: self.directory,
            fileManager: fileManager,
            now: Date(),
            retentionDays: Self.retentionDays,
            maximumTotalBytes: Self.maximumTotalBytes
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
        if !fileManager.fileExists(atPath: destination.path) {
            try Data().write(to: destination, options: .atomic)
        }
        try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
        let handle = try FileHandle(forWritingTo: destination)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
        try handle.synchronize()

        try Self.prune(
            directory: directory,
            fileManager: fileManager,
            now: timestamp,
            retentionDays: Self.retentionDays,
            maximumTotalBytes: Self.maximumTotalBytes
        )
        return destination
    }

    public func prune(now: Date = Date()) throws {
        try Self.prune(
            directory: directory,
            fileManager: fileManager,
            now: now,
            retentionDays: Self.retentionDays,
            maximumTotalBytes: Self.maximumTotalBytes
        )
    }

    private static func prune(
        directory: URL,
        fileManager: FileManager,
        now: Date,
        retentionDays: Int,
        maximumTotalBytes: Int64
    ) throws {
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        let candidates = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ).compactMap { url -> LogFile? in
            guard isOwnedLogFilename(url.lastPathComponent) else { return nil }
            guard let values = try? url.resourceValues(forKeys: resourceKeys), values.isRegularFile == true else { return nil }
            return LogFile(
                url: url,
                size: Int64(values.fileSize ?? 0),
                modified: values.contentModificationDate ?? .distantPast
            )
        }

        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: now) ?? .distantPast
        for file in candidates where file.modified < cutoff {
            try? fileManager.removeItem(at: file.url)
        }

        var remaining = candidates
            .filter { fileManager.fileExists(atPath: $0.url.path) }
            .sorted { lhs, rhs in
                if lhs.modified != rhs.modified { return lhs.modified < rhs.modified }
                return lhs.url.lastPathComponent < rhs.url.lastPathComponent
            }
        var total = remaining.reduce(Int64(0)) { $0 + $1.size }

        while total > maximumTotalBytes, remaining.count > 1 {
            let oldest = remaining.removeFirst()
            try? fileManager.removeItem(at: oldest.url)
            total -= oldest.size
        }

        if total > maximumTotalBytes, let only = remaining.first, fileManager.fileExists(atPath: only.url.path) {
            try trimNewestJSONLLines(in: only.url, toMaximumBytes: maximumTotalBytes, fileManager: fileManager)
        }
    }

    private static func trimNewestJSONLLines(in url: URL, toMaximumBytes maximumBytes: Int64, fileManager: FileManager) throws {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        guard size > maximumBytes else { return }

        let readTarget = min(size, maximumBytes + 256 * 1_024)
        let startOffset = UInt64(max(0, size - readTarget))
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        try handle.seek(toOffset: startOffset)
        var tail = try handle.readToEnd() ?? Data()

        if startOffset > 0, let newline = tail.firstIndex(of: 0x0A) {
            tail.removeSubrange(tail.startIndex...newline)
        }
        if Int64(tail.count) > maximumBytes {
            let excess = tail.count - Int(maximumBytes)
            let lowerBound = tail.index(tail.startIndex, offsetBy: excess)
            if let newline = tail[lowerBound...].firstIndex(of: 0x0A) {
                tail.removeSubrange(tail.startIndex...newline)
            }
        }
        try tail.write(to: url, options: .atomic)
        try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private static func isOwnedLogFilename(_ filename: String) -> Bool {
        filename.range(
            of: #"^zeuve-[0-9]{4}-[0-9]{2}-[0-9]{2}\.jsonl$"#,
            options: .regularExpression
        ) != nil
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

    private struct LogFile {
        let url: URL
        let size: Int64
        let modified: Date
    }
}
