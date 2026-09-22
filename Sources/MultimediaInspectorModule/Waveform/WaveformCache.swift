import Foundation

actor MultimediaWaveformCache {
    private struct Entry {
        let result: MultimediaWaveformResult
        var access: UInt64
    }

    private var entries: [String: Entry] = [:]
    private var clock: UInt64 = 0
    private let maximumEntries: Int

    init(maximumEntries: Int = 12) {
        self.maximumEntries = max(1, maximumEntries)
    }

    func result(for key: String) -> MultimediaWaveformResult? {
        guard var entry = entries[key] else { return nil }
        clock &+= 1
        entry.access = clock
        entries[key] = entry
        return entry.result
    }

    func insert(_ result: MultimediaWaveformResult, for key: String) {
        clock &+= 1
        entries[key] = Entry(result: result, access: clock)
        while entries.count > maximumEntries,
              let oldest = entries.min(by: { $0.value.access < $1.value.access })?.key {
            entries.removeValue(forKey: oldest)
        }
    }

    func removeAll() { entries.removeAll(keepingCapacity: false) }
}
