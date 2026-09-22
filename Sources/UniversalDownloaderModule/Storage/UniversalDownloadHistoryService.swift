import Foundation
import ZEUVECore
import ZEUVEStorage

public struct UniversalDownloadHistoryPayload: Codable, Sendable, Equatable {
    public let title: String
    public let canonicalIDs: [String]
    public let contentType: String
    public let mode: DownloadMode
    public let formatSummary: String
    public let completed: Int
    public let skipped: Int
    public let failed: Int
    public let durationSeconds: Double
    public let wasCancelled: Bool
    public let errorReferences: [String]

    public init(result: UniversalDownloadResult) {
        title = result.items.first?.title ?? "Descarga universal"
        canonicalIDs = result.items.map(\.canonicalID)
        contentType = result.items.count > 1 ? "lote" : "contenido"
        mode = result.mode
        formatSummary = result.formatSummary
        completed = result.completedCount
        skipped = result.skippedCount
        failed = result.failedCount
        durationSeconds = result.finishedAt.timeIntervalSince(result.startedAt)
        wasCancelled = result.wasCancelled
        errorReferences = result.items.compactMap(\.errorReference)
    }
}

public final class UniversalDownloadHistoryService: @unchecked Sendable {
    private let repository: HistoryRepository
    public init(repository: HistoryRepository) { self.repository = repository }

    @discardableResult
    public func save(_ result: UniversalDownloadResult) throws -> OperationHistoryRecord {
        let payload = UniversalDownloadHistoryPayload(result: result)
        let status: OperationStatus = result.wasCancelled ? .cancelled : (result.failedCount > 0 && result.completedCount == 0 ? .failed : .completed)
        let record = OperationHistoryRecord(
            id: result.id,
            moduleID: universalDownloaderModuleIdentifier,
            kind: {
                switch result.mode {
                case .video: return "download-video"
                case .audio: return "download-audio"
                case .original: return "download-original"
                case .automatic: return "download-by-platform"
                }
            }(),
            baseFolder: result.outputFolder.path,
            createdAt: result.finishedAt,
            status: status,
            undoAvailable: false,
            payload: try JSONEncoder().encode(payload)
        )
        try repository.add(record)
        return record
    }

    public func records(limit: Int = 100) throws -> [OperationHistoryRecord] {
        let current = try repository.records(moduleID: universalDownloaderModuleIdentifier, limit: limit)
        let legacy = try repository.records(moduleID: legacyYouTubeDownloaderModuleIdentifier, limit: limit)
        return (current + legacy).sorted { $0.createdAt > $1.createdAt }.prefix(limit).map { $0 }
    }

    public func downloadedCanonicalIDs(limit: Int = 1_000) throws -> Set<String> {
        var result = Set<String>()
        for record in try records(limit: limit) where record.status == .completed {
            guard let payload = try? JSONDecoder().decode(UniversalDownloadHistoryPayload.self, from: record.payload) else { continue }
            result.formUnion(payload.canonicalIDs)
        }
        return result
    }
}

public struct UniversalDownloadHistoryPresenter: ModuleHistoryPresenter {
    public let moduleID: String
    public init(moduleID: String = universalDownloaderModuleIdentifier) { self.moduleID = moduleID }
    public func presentation(for record: OperationHistoryRecord) -> ModuleHistoryPresentation {
        guard let payload = try? JSONDecoder().decode(UniversalDownloadHistoryPayload.self, from: record.payload) else {
            return GenericModuleHistoryPresenter(moduleID: moduleID).presentation(for: record)
        }
        return ModuleHistoryPresentation(
            title: payload.title,
            subtitle: "\(payload.completed) correctos · \(payload.failed) fallidos · \(payload.skipped) omitidos",
            details: [payload.formatSummary] + payload.errorReferences.map { "Referencia: \($0)" },
            outputFolder: record.baseFolder.map { URL(fileURLWithPath: $0, isDirectory: true) }
        )
    }
}
