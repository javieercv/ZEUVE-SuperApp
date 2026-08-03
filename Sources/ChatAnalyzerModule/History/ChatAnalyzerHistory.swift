import Foundation
import ZEUVECore
import ZEUVEStorage

public struct ChatAnalyzerHistoryPayload: Codable, Sendable, Equatable {
    public let sourceCount: Int
    public let platforms: [String]
    public let processedFiles: Int
    public let htmlPages: Int
    public let messages: Int
    public let participants: Int
    public let warningCount: Int
    public let durationSeconds: Double
    public let cancelled: Bool

    public init(
        sourceCount: Int,
        platforms: [String],
        processedFiles: Int,
        htmlPages: Int,
        messages: Int,
        participants: Int,
        warningCount: Int,
        durationSeconds: Double,
        cancelled: Bool
    ) {
        self.sourceCount = sourceCount
        self.platforms = platforms
        self.processedFiles = processedFiles
        self.htmlPages = htmlPages
        self.messages = messages
        self.participants = participants
        self.warningCount = warningCount
        self.durationSeconds = durationSeconds
        self.cancelled = cancelled
    }

    public init(result: ChatAnalysisResult, cancelled: Bool = false) {
        self.init(
            sourceCount: result.summary.sourceCount,
            platforms: Set(result.messages.map { $0.platform.displayName }).sorted(),
            processedFiles: result.summary.processedFiles,
            htmlPages: result.summary.processedHTMLPages,
            messages: result.messages.count,
            participants: Set(result.messages.filter { !$0.isSystem }.map(\.author)).count,
            warningCount: result.summary.warnings.count,
            durationSeconds: result.finishedAt.timeIntervalSince(result.startedAt),
            cancelled: cancelled
        )
    }
}

public final class ChatAnalyzerHistoryService: @unchecked Sendable {
    private let repository: HistoryRepository?
    public init(repository: HistoryRepository?) { self.repository = repository }

    public func save(_ result: ChatAnalysisResult) throws {
        try save(
            id: result.id,
            startedAt: result.startedAt,
            finishedAt: result.finishedAt,
            summary: result.summary,
            messages: result.messages,
            status: .completed
        )
    }

    public func save(
        id: UUID,
        startedAt: Date,
        finishedAt: Date,
        summary: ChatImportSummary,
        messages: [NormalizedMessage],
        status: OperationStatus
    ) throws {
        guard let repository else { return }
        let payload = ChatAnalyzerHistoryPayload(
            sourceCount: summary.sourceCount,
            platforms: Set(messages.map { $0.platform.displayName }).sorted(),
            processedFiles: summary.processedFiles,
            htmlPages: summary.processedHTMLPages,
            messages: messages.count,
            participants: Set(messages.filter { !$0.isSystem }.map(\.author)).count,
            warningCount: summary.warnings.count,
            durationSeconds: finishedAt.timeIntervalSince(startedAt),
            cancelled: status == .cancelled
        )
        try repository.add(OperationHistoryRecord(
            id: id,
            moduleID: chatAnalyzerModuleIdentifier,
            kind: "analyze-chat",
            baseFolder: nil,
            createdAt: finishedAt,
            status: status,
            undoAvailable: false,
            payload: try JSONEncoder().encode(payload)
        ))
    }
}

public struct ChatAnalyzerHistoryPresenter: ModuleHistoryPresenter {
    public let moduleID = chatAnalyzerModuleIdentifier
    public init() {}
    public func presentation(for record: OperationHistoryRecord) -> ModuleHistoryPresentation {
        guard let payload = try? JSONDecoder().decode(ChatAnalyzerHistoryPayload.self, from: record.payload) else {
            return GenericModuleHistoryPresenter(moduleID: moduleID).presentation(for: record)
        }
        let statusText: String
        switch record.status {
        case .completed: statusText = "Completado"
        case .cancelled: statusText = "Cancelado"
        case .failed: statusText = "Fallido"
        default: statusText = record.status.rawValue
        }
        return ModuleHistoryPresentation(
            title: "Análisis de chats",
            subtitle: "\(statusText) · \(payload.messages) mensajes · \(payload.participants) participantes",
            details: [
                payload.platforms.isEmpty ? "Sin plataforma reconocida" : payload.platforms.joined(separator: " + "),
                "\(payload.processedFiles) archivos · \(payload.htmlPages) páginas HTML",
                "\(payload.warningCount) advertencias"
            ],
            outputFolder: nil
        )
    }
}
