import Foundation

enum AnalysisExecutionBudget {
    static func run<T: Sendable>(seconds: Double?, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        guard let seconds else { return try await operation() }
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw UniversalDownloaderError.analysisTimedOut
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else { throw CancellationError() }
            return result
        }
    }
}

final class AnalysisCatalogSnapshot: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [DownloadCatalogItem] = []
    func append(_ entry: DownloadCatalogItem) {
        lock.lock()
        defer { lock.unlock() }
        if !entries.contains(where: { $0.id == entry.id }) { entries.append(entry) }
    }
    var values: [DownloadCatalogItem] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }
}
