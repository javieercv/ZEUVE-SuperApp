import Foundation
import ZEUVECore
import ZEUVEStorage

public struct MultimediaInspectorHistoryPayload: Codable, Sendable, Equatable {
    public let kind: String
    public let container: String?
    public let audioTracks: Int
    public let subtitleTracks: Int
    public let convertedSubtitleTracks: Int
    public let durationSeconds: Double
    public let chapterCount: Int?
    public let attachmentsAdded: Int?
    public let attachmentsRemoved: Int?
    public let metadataFieldsChanged: Int?
    public let batchTotal: Int?
    public let batchCompleted: Int?
    public let batchWarnings: Int?
    public let batchSkipped: Int?
    public let batchFailed: Int?
    public let batchCancelled: Int?
    public let reportsGenerated: Int?
    public let spectrogramsGenerated: Int?

    public init(
        kind: String,
        container: String?,
        audioTracks: Int,
        subtitleTracks: Int,
        convertedSubtitleTracks: Int,
        durationSeconds: Double,
        chapterCount: Int? = nil,
        attachmentsAdded: Int? = nil,
        attachmentsRemoved: Int? = nil,
        metadataFieldsChanged: Int? = nil,
        batchTotal: Int? = nil,
        batchCompleted: Int? = nil,
        batchWarnings: Int? = nil,
        batchSkipped: Int? = nil,
        batchFailed: Int? = nil,
        batchCancelled: Int? = nil,
        reportsGenerated: Int? = nil,
        spectrogramsGenerated: Int? = nil
    ) {
        self.kind = kind
        self.container = container
        self.audioTracks = audioTracks
        self.subtitleTracks = subtitleTracks
        self.convertedSubtitleTracks = convertedSubtitleTracks
        self.durationSeconds = durationSeconds
        self.chapterCount = chapterCount
        self.attachmentsAdded = attachmentsAdded
        self.attachmentsRemoved = attachmentsRemoved
        self.metadataFieldsChanged = metadataFieldsChanged
        self.batchTotal = batchTotal
        self.batchCompleted = batchCompleted
        self.batchWarnings = batchWarnings
        self.batchSkipped = batchSkipped
        self.batchFailed = batchFailed
        self.batchCancelled = batchCancelled
        self.reportsGenerated = reportsGenerated
        self.spectrogramsGenerated = spectrogramsGenerated
    }
}

public final class MultimediaInspectorHistoryService: @unchecked Sendable {
    private let repository: HistoryRepository?
    public init(repository: HistoryRepository?) { self.repository = repository }

    public func saveRemux(id: UUID, plan: MediaEditPlan, startedAt: Date, finishedAt: Date) throws {
        guard let repository else { return }
        let metadataChanges = plan.metadata.touchedContainerKeys.count + plan.metadata.touchedVideoKeysByStream.values.reduce(0) { $0 + $1.count }
        let payload = MultimediaInspectorHistoryPayload(
            kind: "remux",
            container: plan.targetContainer.rawValue,
            audioTracks: plan.audioTracks.count,
            subtitleTracks: plan.subtitleTracks.count,
            convertedSubtitleTracks: plan.subtitleTracks.filter { $0.action == .convertSubtitle }.count,
            durationSeconds: finishedAt.timeIntervalSince(startedAt),
            chapterCount: plan.chapters.count,
            attachmentsAdded: plan.attachments.filter { $0.action == .add }.count,
            attachmentsRemoved: plan.removedAttachments.count,
            metadataFieldsChanged: metadataChanges
        )
        try repository.add(.init(id: id, moduleID: multimediaInspectorModuleIdentifier, kind: "remux", baseFolder: nil, createdAt: finishedAt, status: .completed, undoAvailable: false, payload: try JSONEncoder().encode(payload)))
    }


    public func saveBatch(id: UUID, summary: MultimediaBatchRunSummary, startedAt: Date, finishedAt: Date) throws {
        guard let repository else { return }
        let payload = MultimediaInspectorHistoryPayload(
            kind: "batch-analysis",
            container: nil,
            audioTracks: 0,
            subtitleTracks: 0,
            convertedSubtitleTracks: 0,
            durationSeconds: finishedAt.timeIntervalSince(startedAt),
            batchTotal: summary.total,
            batchCompleted: summary.completed,
            batchWarnings: summary.warnings,
            batchSkipped: summary.skipped,
            batchFailed: summary.failed,
            batchCancelled: summary.cancelled,
            reportsGenerated: summary.reportsGenerated,
            spectrogramsGenerated: summary.spectrogramsGenerated
        )
        try repository.add(.init(
            id: id,
            moduleID: multimediaInspectorModuleIdentifier,
            kind: "batch-analysis",
            baseFolder: nil,
            createdAt: finishedAt,
            status: summary.cancelled == summary.total ? .cancelled : .completed,
            undoAvailable: false,
            payload: try JSONEncoder().encode(payload)
        ))
    }

    public func savePNG(id: UUID, startedAt: Date, finishedAt: Date) throws {
        guard let repository else { return }
        let payload = MultimediaInspectorHistoryPayload(kind: "spectrogram-png", container: "png", audioTracks: 0, subtitleTracks: 0, convertedSubtitleTracks: 0, durationSeconds: finishedAt.timeIntervalSince(startedAt))
        try repository.add(.init(id: id, moduleID: multimediaInspectorModuleIdentifier, kind: "spectrogram-png", baseFolder: nil, createdAt: finishedAt, status: .completed, undoAvailable: false, payload: try JSONEncoder().encode(payload)))
    }
}

public struct MultimediaInspectorHistoryPresenter: ModuleHistoryPresenter {
    public let moduleID = multimediaInspectorModuleIdentifier
    public init() {}
    public func presentation(for record: OperationHistoryRecord) -> ModuleHistoryPresentation {
        guard let payload = try? JSONDecoder().decode(MultimediaInspectorHistoryPayload.self, from: record.payload) else { return GenericModuleHistoryPresenter(moduleID: moduleID).presentation(for: record) }
        if payload.kind == "spectrogram-png" {
            return .init(title: "Espectrograma exportado", subtitle: "PNG · operación local", details: [String(format: "Duración: %.1f s", payload.durationSeconds)])
        }
        if payload.kind == "batch-analysis" {
            let total = payload.batchTotal ?? 0
            let completed = payload.batchCompleted ?? 0
            let warnings = payload.batchWarnings ?? 0
            let skipped = payload.batchSkipped ?? 0
            let failed = payload.batchFailed ?? 0
            let cancelled = payload.batchCancelled ?? 0
            return .init(
                title: "Lote de análisis multimedia",
                subtitle: "\(total) archivos · \(completed) correctos",
                details: [
                    "Avisos: \(warnings) · omitidos: \(skipped) · fallidos: \(failed) · cancelados: \(cancelled)",
                    "Informes: \(payload.reportsGenerated ?? 0) · espectrogramas: \(payload.spectrogramsGenerated ?? 0)",
                    String(format: "Duración: %.1f s", payload.durationSeconds),
                ]
            )
        }
        var details = ["\(payload.convertedSubtitleTracks) subtítulos convertidos de forma auxiliar"]
        if let chapterCount = payload.chapterCount { details.append("\(chapterCount) capítulos en el resultado") }
        if let added = payload.attachmentsAdded, let removed = payload.attachmentsRemoved { details.append("Adjuntos: +\(added) / -\(removed)") }
        if let changed = payload.metadataFieldsChanged { details.append("\(changed) campos de metadatos editados") }
        details.append(String(format: "Duración: %.1f s", payload.durationSeconds))
        return .init(title: "Edición multimedia", subtitle: "\(payload.container?.uppercased() ?? "") · \(payload.audioTracks) audios · \(payload.subtitleTracks) subtítulos", details: details)
    }
}
