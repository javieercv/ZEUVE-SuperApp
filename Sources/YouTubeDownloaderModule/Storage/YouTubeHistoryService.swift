import Foundation
import ZEUVECore
import ZEUVEStorage

public struct YouTubeHistoryPayload: Codable, Sendable, Equatable {
    public let title: String
    public let canonicalIDs: [String]
    public let contentType: String
    public let mode: YouTubeDownloadMode
    public let formatSummary: String
    public let completed: Int
    public let skipped: Int
    public let failed: Int
    public let durationSeconds: Double
    public let wasCancelled: Bool
    public let errorReferences: [String]

    public init(result: YouTubeOperationResult) {
        title = result.items.first?.title ?? "Descarga de YouTube"
        canonicalIDs = result.items.map(\.canonicalID)
        contentType = result.items.count > 1 ? "lote" : "vídeo"
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

public final class YouTubeHistoryService: @unchecked Sendable {
    private let repository: HistoryRepository
    public init(repository: HistoryRepository) { self.repository = repository }

    @discardableResult
    public func save(_ result: YouTubeOperationResult) throws -> OperationHistoryRecord {
        let payload = YouTubeHistoryPayload(result: result)
        let status: OperationStatus = result.wasCancelled ? .cancelled : (result.failedCount > 0 && result.completedCount == 0 ? .failed : .completed)
        let record = OperationHistoryRecord(
            id: result.id,
            moduleID: youtubeDownloaderModuleIdentifier,
            kind: result.mode == .video ? "download-video" : "download-audio",
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
        try repository.records(moduleID: youtubeDownloaderModuleIdentifier, limit: limit)
    }
}

public struct YouTubeHistoryPresenter: ModuleHistoryPresenter {
    public let moduleID = youtubeDownloaderModuleIdentifier
    public init() {}
    public func presentation(for record: OperationHistoryRecord) -> ModuleHistoryPresentation {
        guard let payload = try? JSONDecoder().decode(YouTubeHistoryPayload.self, from: record.payload) else {
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
