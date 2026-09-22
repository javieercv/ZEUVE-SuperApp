import Foundation
import ZEUVECore
import ZEUVEStorage
import ZEUVEOperations

public struct ChatAnalysisRequest: Sendable {
    public let inputs: [ChatInput]
    public let whatsappTextSelections: [URL: String]
    public let instagramConversationSelections: [URL: String]
    public let settings: ChatAnalyzerSettings
    public init(inputs: [ChatInput], whatsappTextSelections: [URL: String] = [:], instagramConversationSelections: [URL: String] = [:], settings: ChatAnalyzerSettings) {
        self.inputs = inputs; self.whatsappTextSelections = whatsappTextSelections
        self.instagramConversationSelections = instagramConversationSelections; self.settings = settings
    }
}

public actor ChatAnalyzerService {
    private let coordinator: OperationCoordinator
    private let history: ChatAnalyzerHistoryService
    private let logger: LocalLogger?
    private var token: ChatCancellationToken?
    private var activeOperationID: UUID?

    public init(coordinator: OperationCoordinator, history: ChatAnalyzerHistoryService, logger: LocalLogger?) {
        self.coordinator = coordinator; self.history = history; self.logger = logger
    }

    public func catalogInstagram(url: URL, settings: ChatAnalyzerSettings) async throws -> InstagramCatalogResult {
        let importer = InstagramImporter(settings: settings)
        return try await Task.detached(priority: .userInitiated) { try importer.catalogArchive(at: url) }.value
    }

    public func inspectWhatsApp(url: URL, settings: ChatAnalyzerSettings) async throws -> WhatsAppInspection {
        let importer = WhatsAppImporter(settings: settings)
        return try await Task.detached(priority: .userInitiated) { try importer.inspectArchive(at: url) }.value
    }

    public func analyze(
        _ request: ChatAnalysisRequest,
        onWarning: @escaping @Sendable (String) -> Void = { _ in }
    ) async throws -> ChatAnalysisSession {
        guard !request.inputs.isEmpty else { throw ChatAnalyzerError.noInput }
        let operationID = try await coordinator.begin(moduleID: chatAnalyzerModuleIdentifier, name: "Analizando chats")
        activeOperationID = operationID
        let token = ChatCancellationToken()
        self.token = token
        let startedAt = Date()
        var summary = ChatImportSummary()
        summary.sourceCount = request.inputs.count

        let workspace: ChatTemporaryWorkspace
        do {
            workspace = try ChatTemporaryWorkspace(operationID: operationID)
        } catch {
            try? await coordinator.finish(id: operationID)
            activeOperationID = nil
            self.token = nil
            throw ChatAnalyzerError.storageUnavailable(error.localizedDescription)
        }

        let store: TemporaryChatStore
        do {
            store = try TemporaryChatStore(workspace: workspace)
        } catch {
            try? workspace.cleanup()
            try? await coordinator.finish(id: operationID)
            activeOperationID = nil
            self.token = nil
            throw ChatAnalyzerError.storageUnavailable(error.localizedDescription)
        }

        do {
            try await update(operationID, completed: 0, total: request.inputs.count + 4, phase: "Validando archivos")
            for input in request.inputs where !input.fingerprint.matches(input.url) {
                throw ChatAnalyzerError.sourceChanged(input.url.lastPathComponent)
            }

            let htmlInputs = request.inputs.filter { $0.kind == .instagramHTML }
            let regularInputs = request.inputs.filter { $0.kind != .instagramHTML }
            for (index, input) in regularInputs.enumerated() {
                if token.isCancelled || Task.isCancelled { throw ChatAnalyzerError.cancelled }
                try await update(
                    operationID,
                    completed: index + 1,
                    total: request.inputs.count + 4,
                    phase: "Procesando fuentes",
                    current: input.url.lastPathComponent
                )
                let imported = try await Task.detached(priority: .userInitiated) { () -> ChatImportSummary in
                    let consume: ([NormalizedMessage]) throws -> Void = { batch in
                        if token.isCancelled || Task.isCancelled { throw ChatAnalyzerError.cancelled }
                        _ = try store.append(messages: batch)
                        if try store.messageCount() > request.settings.archiveLimits.messageMaximumCount {
                            throw ChatAnalyzerError.archiveLimit("demasiados mensajes")
                        }
                    }
                    switch input.kind {
                    case .whatsappText:
                        return try WhatsAppImporter(settings: request.settings).streamText(
                            at: input.url,
                            cancellation: { token.isCancelled },
                            consume: consume
                        )
                    case .zip:
                        if input.estimatedPlatform == .instagram || request.instagramConversationSelections[input.url] != nil {
                            guard let selection = request.instagramConversationSelections[input.url] else {
                                throw ChatAnalyzerError.instagramConversationRequired
                            }
                            return try InstagramImporter(settings: request.settings).streamArchive(
                                at: input.url,
                                conversationID: selection,
                                cancellation: { token.isCancelled },
                                consume: consume
                            )
                        }
                        return try WhatsAppImporter(settings: request.settings).streamArchive(
                            at: input.url,
                            selectedTextPath: request.whatsappTextSelections[input.url],
                            cancellation: { token.isCancelled },
                            consume: consume
                        )
                    case .instagramFolder:
                        guard let selection = request.instagramConversationSelections[input.url] else {
                            throw ChatAnalyzerError.instagramConversationRequired
                        }
                        return try InstagramImporter(settings: request.settings).streamFolder(
                            at: input.url,
                            conversationID: selection,
                            cancellation: { token.isCancelled },
                            consume: consume
                        )
                    case .instagramHTML:
                        throw ChatAnalyzerError.unsupportedInput(input.url.lastPathComponent)
                    }
                }.value
                Self.merge(imported, into: &summary)
            }

            if !htmlInputs.isEmpty {
                if token.isCancelled || Task.isCancelled { throw ChatAnalyzerError.cancelled }
                let imported = try await Task.detached(priority: .userInitiated) { () -> ChatImportSummary in
                    let consume: ([NormalizedMessage]) throws -> Void = { batch in
                        if token.isCancelled || Task.isCancelled { throw ChatAnalyzerError.cancelled }
                        _ = try store.append(messages: batch)
                        if try store.messageCount() > request.settings.archiveLimits.messageMaximumCount {
                            throw ChatAnalyzerError.archiveLimit("demasiados mensajes")
                        }
                    }
                    return try InstagramImporter(settings: request.settings).streamHTMLFiles(
                        htmlInputs.map(\.url),
                        cancellation: { token.isCancelled },
                        consume: consume
                    )
                }.value
                Self.merge(imported, into: &summary)
            }

            try await update(operationID, completed: request.inputs.count + 1, total: request.inputs.count + 4, phase: "Consolidando mensajes")
            let rawRecognizedMessages = summary.recognizedMessages
            let statistics = try await Task.detached(priority: .utility) { try store.statistics() }.value
            let removed = max(0, rawRecognizedMessages - statistics.messages)
            if removed > 0 {
                summary.warnings.append(.init(code: "duplicates", message: "Se omitieron \(removed) mensajes duplicados exactos."))
            }
            if statistics.messages > request.settings.archiveLimits.messageMaximumCount {
                throw ChatAnalyzerError.archiveLimit("demasiados mensajes")
            }
            if statistics.messages > request.settings.archiveLimits.messageWarningCount {
                summary.warnings.append(.init(code: "many-messages", message: "El análisis contiene varios millones de mensajes."))
            }
            summary.recognizedMessages = statistics.messages

            try await update(operationID, completed: request.inputs.count + 2, total: request.inputs.count + 4, phase: "Preparando índices")
            if token.isCancelled || Task.isCancelled { throw ChatAnalyzerError.cancelled }
            try await Task.detached(priority: .utility) {
                try store.prepareTimeline()
            }.value

            try await update(operationID, completed: request.inputs.count + 3, total: request.inputs.count + 4, phase: "Preparando resultados")
            let result = ChatAnalysisResult(
                id: operationID,
                startedAt: startedAt,
                finishedAt: Date(),
                messageCount: statistics.messages,
                participantCount: statistics.participants,
                platforms: statistics.platforms,
                summary: summary,
                settings: request.settings
            )
            if let failure = ZEUVEHistoryPersistence.attempt({ try history.save(result) }) {
                onWarning(failure.warning)
                _ = try? await logger?.write(
                    .warning,
                    category: "chat-analyzer",
                    message: "No se ha podido guardar el historial",
                    metadata: failure.logMetadata
                )
            }

            try await update(operationID, completed: request.inputs.count + 4, total: request.inputs.count + 4, phase: "Finalizando")
            try await coordinator.finish(id: operationID)
            activeOperationID = nil
            self.token = nil
            _ = try? await logger?.write(
                .info,
                category: "chat-analyzer",
                message: "Análisis completado",
                metadata: [
                    "sources": String(request.inputs.count),
                    "messages": String(statistics.messages),
                    "warnings": String(summary.warnings.count),
                ]
            )
            return ChatAnalysisSession(result: result, store: store, workspace: workspace)
        } catch {
            let partialStatistics = try? store.statistics()
            try? await coordinator.finish(id: operationID)
            activeOperationID = nil
            self.token = nil
            store.closeAndDelete()
            try? workspace.cleanup()
            let cancelled = error is CancellationError || (error as? ChatAnalyzerError) == .cancelled
            _ = try? history.save(
                id: operationID,
                startedAt: startedAt,
                finishedAt: Date(),
                summary: summary,
                messageCount: partialStatistics?.messages ?? 0,
                participantCount: partialStatistics?.participants ?? 0,
                platforms: partialStatistics?.platforms ?? [],
                status: cancelled ? .cancelled : .failed
            )
            _ = try? await logger?.write(
                cancelled ? .info : .error,
                category: "chat-analyzer",
                message: "Análisis interrumpido",
                metadata: ["errorType": String(describing: type(of: error))]
            )
            throw error
        }
    }

    public func cancel() async {
        token?.cancel()
        if let activeOperationID { try? await coordinator.requestCancellation(id: activeOperationID) }
    }

    private func update(_ id: UUID, completed: Int, total: Int, phase: String, current: String? = nil) async throws {
        try await coordinator.update(id: id, progress: .init(completed: completed, total: total, phase: phase, currentItem: current))
    }

    private static func merge(_ imported: ChatImportSummary, into summary: inout ChatImportSummary) {
        summary.recognizedMessages += imported.recognizedMessages
        summary.processedFiles += imported.processedFiles
        summary.processedHTMLPages += imported.processedHTMLPages
        summary.discardedMessages += imported.discardedMessages
        summary.referencedAttachments += imported.referencedAttachments
        summary.missingAttachments += imported.missingAttachments
        if imported.unverifiedAttachments != nil {
            summary.unverifiedAttachments = (summary.unverifiedAttachments ?? 0) + (imported.unverifiedAttachments ?? 0)
        }
        summary.unreferencedAttachments += imported.unreferencedAttachments
        summary.warnings.append(contentsOf: imported.warnings)
    }
}
