import Foundation

struct ChatSearchTextRange: Sendable, Equatable {
    let location: Int
    let length: Int
}

/// Representación compacta de los textos de una sesión para evitar normalizarlos en cada búsqueda.
public struct ChatSearchTextIndex: Sendable {
    fileprivate enum Storage: Sendable {
        case memory(buffer: String, ranges: [ChatSearchTextRange])
        case mapped(data: Data, ranges: [ChatSearchTextRange])
    }

    fileprivate let storage: Storage
    public let messageCount: Int
    public let approximateBytes: Int
    public let isFileBacked: Bool

    fileprivate init(storage: Storage, messageCount: Int, approximateBytes: Int, isFileBacked: Bool) {
        self.storage = storage
        self.messageCount = messageCount
        self.approximateBytes = approximateBytes
        self.isFileBacked = isFileBacked
    }

    func matchCounts(regexes: [NSRegularExpression], messageIndex: Int) -> [Int]? {
        guard messageIndex >= 0, messageIndex < messageCount else { return nil }
        switch storage {
        case .memory(let buffer, let ranges):
            let range = ranges[messageIndex]
            let nsRange = NSRange(location: range.location, length: range.length)
            return regexes.map { $0.numberOfMatches(in: buffer, range: nsRange) }
        case .mapped(let data, let ranges):
            let range = ranges[messageIndex]
            let start = data.startIndex + range.location
            let end = start + range.length
            guard start >= data.startIndex, end <= data.endIndex else { return nil }
            let text = String(decoding: data[start..<end], as: UTF8.self)
            let nsRange = NSRange(text.startIndex..., in: text)
            return regexes.map { $0.numberOfMatches(in: text, range: nsRange) }
        }
    }
}

struct ChatSearchNormalizationKey: Hashable, Sendable {
    let ignoreCase: Bool
    let ignoreDiacritics: Bool
}

enum ChatSearchTextNormalizer {
    static func transform(_ value: String, ignoreCase: Bool, ignoreDiacritics: Bool) -> String {
        var result = value
        if ignoreDiacritics {
            result = result.folding(options: .diacriticInsensitive, locale: Locale(identifier: "es_ES"))
        }
        if ignoreCase { result = result.lowercased() }
        return result
    }
}

/// Caché exclusiva de una sesión. Las variantes se crean bajo demanda y se eliminan junto con sus temporales.
public final class ChatSearchTextCache: @unchecked Sendable {
    private let lock = NSLock()
    private let directory: URL
    private let fileManager: FileManager
    private let memoryThresholdBytes: Int
    private var indexes: [ChatSearchNormalizationKey: ChatSearchTextIndex] = [:]
    private var generation: UInt64 = 0

    public init(
        directory: URL,
        memoryThresholdBytes: Int = 64 * 1_024 * 1_024,
        fileManager: FileManager = .default
    ) {
        self.directory = directory
        self.memoryThresholdBytes = max(memoryThresholdBytes, 1 * 1_024 * 1_024)
        self.fileManager = fileManager
    }

    public func index(
        for timeline: [NormalizedMessage],
        ignoreCase: Bool,
        ignoreDiacritics: Bool,
        cancellation: @Sendable () -> Bool = { false }
    ) throws -> ChatSearchTextIndex {
        let key = ChatSearchNormalizationKey(ignoreCase: ignoreCase, ignoreDiacritics: ignoreDiacritics)
        lock.lock()
        if let cached = indexes[key], cached.messageCount == timeline.count {
            lock.unlock()
            return cached
        }
        let currentGeneration = generation
        lock.unlock()

        let estimatedBytes = timeline.reduce(into: 0) { total, message in
            total += message.text.utf8.count + 1
        }
        let built = estimatedBytes <= memoryThresholdBytes
            ? try buildInMemory(timeline, key: key, cancellation: cancellation)
            : try buildMapped(timeline, key: key, generation: currentGeneration, cancellation: cancellation)

        lock.lock()
        defer { lock.unlock() }
        guard generation == currentGeneration else { throw CancellationError() }
        indexes[key] = built
        return built
    }

    public func clear() {
        lock.lock()
        generation &+= 1
        indexes.removeAll(keepingCapacity: false)
        lock.unlock()
        try? fileManager.removeItem(at: directory)
    }

    deinit { clear() }

    private func buildInMemory(
        _ timeline: [NormalizedMessage],
        key: ChatSearchNormalizationKey,
        cancellation: @Sendable () -> Bool
    ) throws -> ChatSearchTextIndex {
        let buffer = NSMutableString(capacity: min(timeline.count * 32, memoryThresholdBytes))
        var ranges: [ChatSearchTextRange] = []
        ranges.reserveCapacity(timeline.count)
        for (index, message) in timeline.enumerated() {
            if index.isMultiple(of: 512), cancellation() { throw CancellationError() }
            let transformed = ChatSearchTextNormalizer.transform(
                message.text,
                ignoreCase: key.ignoreCase,
                ignoreDiacritics: key.ignoreDiacritics
            )
            let location = buffer.length
            buffer.append(transformed)
            let length = buffer.length - location
            ranges.append(.init(location: location, length: length))
            buffer.append("\n")
        }
        let value = buffer.copy() as! NSString as String
        return ChatSearchTextIndex(
            storage: .memory(buffer: value, ranges: ranges),
            messageCount: timeline.count,
            approximateBytes: value.utf8.count,
            isFileBacked: false
        )
    }

    private func buildMapped(
        _ timeline: [NormalizedMessage],
        key: ChatSearchNormalizationKey,
        generation: UInt64,
        cancellation: @Sendable () -> Bool
    ) throws -> ChatSearchTextIndex {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = "search-\(generation)-\(key.ignoreCase ? 1 : 0)-\(key.ignoreDiacritics ? 1 : 0).utf8"
        let url = directory.appendingPathComponent(filename)
        guard fileManager.createFile(atPath: url.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let handle = try FileHandle(forWritingTo: url)
        var ranges: [ChatSearchTextRange] = []
        ranges.reserveCapacity(timeline.count)
        var offset = 0
        do {
            for (index, message) in timeline.enumerated() {
                if index.isMultiple(of: 512), cancellation() { throw CancellationError() }
                let transformed = ChatSearchTextNormalizer.transform(
                    message.text,
                    ignoreCase: key.ignoreCase,
                    ignoreDiacritics: key.ignoreDiacritics
                )
                let data = Data(transformed.utf8)
                ranges.append(.init(location: offset, length: data.count))
                try handle.write(contentsOf: data)
                try handle.write(contentsOf: Data([0x0A]))
                offset += data.count + 1
            }
            try handle.close()
            let mapped = try Data(contentsOf: url, options: .mappedIfSafe)
            return ChatSearchTextIndex(
                storage: .mapped(data: mapped, ranges: ranges),
                messageCount: timeline.count,
                approximateBytes: mapped.count,
                isFileBacked: true
            )
        } catch {
            try? handle.close()
            try? fileManager.removeItem(at: url)
            throw error
        }
    }
}
