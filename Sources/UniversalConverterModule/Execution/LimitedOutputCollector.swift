import Foundation

public final class LimitedOutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private let maximumBytes: Int
    private var storage = Data()
    private var exceeded = false

    public init(maximumBytes: Int) { self.maximumBytes = max(1_024, maximumBytes) }
    public func append(_ data: Data) {
        lock.lock(); defer { lock.unlock() }
        guard !exceeded else { return }
        let remaining = maximumBytes - storage.count
        if data.count > remaining {
            if remaining > 0 { storage.append(data.prefix(remaining)) }
            exceeded = true
        } else { storage.append(data) }
    }
    public var data: Data { lock.lock(); defer { lock.unlock() }; return storage }
    public var string: String { String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) }
    public var didExceedLimit: Bool { lock.lock(); defer { lock.unlock() }; return exceeded }
}
