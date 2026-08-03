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

    public func analyze(_ request: ChatAnalysisRequest) async throws -> ChatAnalysisSession {
        guard !request.inputs.isEmpty else { throw ChatAnalyzerError.noInput }
        let operationID = try await coordinator.begin(moduleID: chatAnalyzerModuleIdentifier, name: "Analizando chats")
        activeOperationID = operationID
        let token = ChatCancellationToken(); self.token = token
        let startedAt = Date()
        var messages: [NormalizedMessage] = []
        var summary = ChatImportSummary()
        summary.sourceCount = request.inputs.count
        let workspace: ChatTemporaryWorkspace
        do { workspace = try ChatTemporaryWorkspace(operationID: operationID) }
        catch { try? await coordinator.finish(id: operationID); throw ChatAnalyzerError.storageUnavailable(error.localizedDescription) }

        do {
            try await update(operationID, completed: 0, total: request.inputs.count + 4, phase: "Validando archivos")
            for input in request.inputs where !input.fingerprint.matches(input.url) { throw ChatAnalyzerError.sourceChanged(input.url.lastPathComponent) }
            let htmlInputs = request.inputs.filter { $0.kind == .instagramHTML }
            let regularInputs = request.inputs.filter { $0.kind != .instagramHTML }
            for (index, input) in regularInputs.enumerated() {
                if token.isCancelled { throw ChatAnalyzerError.cancelled }
                try await update(operationID, completed: index + 1, total: request.inputs.count + 4, phase: "Procesando fuentes", current: input.url.lastPathComponent)
                let imported = try await Task.detached(priority: .userInitiated) { () -> ([NormalizedMessage], ChatImportSummary) in
                    switch input.kind {
                    case .whatsappText:
                        let value = try WhatsAppImporter(settings: request.settings).importText(at: input.url, cancellation: { token.isCancelled })
                        return (value.messages, value.summary)
                    case .zip:
                        if input.estimatedPlatform == .instagram || request.instagramConversationSelections[input.url] != nil {
                            guard let selection = request.instagramConversationSelections[input.url] else { throw ChatAnalyzerError.instagramConversationRequired }
                            let value = try InstagramImporter(settings: request.settings).importArchive(at: input.url, conversationID: selection, cancellation: { token.isCancelled })
                            return (value.messages, value.summary)
                        }
                        let value = try WhatsAppImporter(settings: request.settings).importArchive(at: input.url, selectedTextPath: request.whatsappTextSelections[input.url], cancellation: { token.isCancelled })
                        return (value.messages, value.summary)
                    case .instagramFolder:
                        guard let selection = request.instagramConversationSelections[input.url] else { throw ChatAnalyzerError.instagramConversationRequired }
                        let value = try InstagramImporter(settings: request.settings).importFolder(at: input.url, conversationID: selection, cancellation: { token.isCancelled })
                        return (value.messages, value.summary)
                    case .instagramHTML:
                        throw ChatAnalyzerError.unsupportedInput(input.url.lastPathComponent)
                    }
                }.value
                messages.append(contentsOf: imported.0)
                summary.processedFiles += imported.1.processedFiles; summary.processedHTMLPages += imported.1.processedHTMLPages
                summary.discardedMessages += imported.1.discardedMessages; summary.referencedAttachments += imported.1.referencedAttachments
                summary.missingAttachments += imported.1.missingAttachments
                summary.unverifiedAttachments = (summary.unverifiedAttachments ?? 0) + (imported.1.unverifiedAttachments ?? 0)
                summary.unreferencedAttachments += imported.1.unreferencedAttachments
                summary.warnings.append(contentsOf: imported.1.warnings)
            }
            if !htmlInputs.isEmpty {
                if token.isCancelled { throw ChatAnalyzerError.cancelled }
                let imported = try await Task.detached(priority: .userInitiated) {
                    let value = try InstagramImporter(settings: request.settings).importHTMLFiles(htmlInputs.map(\.url), cancellation: { token.isCancelled })
                    return (value.messages, value.summary)
                }.value
                messages.append(contentsOf: imported.0)
                summary.processedFiles += imported.1.processedFiles; summary.processedHTMLPages += imported.1.processedHTMLPages
                summary.discardedMessages += imported.1.discardedMessages; summary.referencedAttachments += imported.1.referencedAttachments
                summary.missingAttachments += imported.1.missingAttachments
                summary.unverifiedAttachments = (summary.unverifiedAttachments ?? 0) + (imported.1.unverifiedAttachments ?? 0)
                summary.warnings.append(contentsOf: imported.1.warnings)
            }
            try await update(operationID, completed: request.inputs.count + 1, total: request.inputs.count + 4, phase: "Eliminando duplicados")
            let deduplicated = MessageDeduplicator.deduplicate(messages)
            messages = deduplicated.messages.sorted {
                if $0.timestamp != $1.timestamp { return $0.timestamp < $1.timestamp }
                if $0.platform != $1.platform { return $0.platform.rawValue < $1.platform.rawValue }
                return $0.sourcePosition < $1.sourcePosition
            }
            if deduplicated.removed > 0 { summary.warnings.append(.init(code: "duplicates", message: "Se omitieron \(deduplicated.removed) mensajes duplicados exactos.")) }
            if messages.count > request.settings.archiveLimits.messageMaximumCount { throw ChatAnalyzerError.archiveLimit("demasiados mensajes") }
            if messages.count > request.settings.archiveLimits.messageWarningCount { summary.warnings.append(.init(code: "many-messages", message: "El análisis contiene varios millones de mensajes.")) }
            summary.recognizedMessages = messages.count
            try await update(operationID, completed: request.inputs.count + 2, total: request.inputs.count + 4, phase: "Preparando índices")
            let store = try TemporaryChatStore(workspace: workspace)
            try await Task.detached(priority: .utility) { try store.replace(messages: messages) }.value
            try await update(operationID, completed: request.inputs.count + 3, total: request.inputs.count + 4, phase: "Preparando resultados")
            let result = ChatAnalysisResult(id: operationID, startedAt: startedAt, finishedAt: Date(), messages: messages, summary: summary, settings: request.settings)
            try history.save(result)
            try await update(operationID, completed: request.inputs.count + 4, total: request.inputs.count + 4, phase: "Finalizando")
            try await coordinator.finish(id: operationID)
            activeOperationID = nil; self.token = nil
            _ = try? await logger?.write(.info, category: "chat-analyzer", message: "Análisis completado", metadata: ["sources": String(request.inputs.count), "messages": String(messages.count), "warnings": String(summary.warnings.count)])
            return ChatAnalysisSession(result: result, store: store, workspace: workspace)
        } catch {
            try? await coordinator.finish(id: operationID)
            activeOperationID = nil; self.token = nil
            try? workspace.cleanup()
            let cancelled = error is CancellationError || (error as? ChatAnalyzerError) == .cancelled
            _ = try? history.save(
                id: operationID,
                startedAt: startedAt,
                finishedAt: Date(),
                summary: summary,
                messages: messages,
                status: cancelled ? .cancelled : .failed
            )
            _ = try? await logger?.write(cancelled ? .info : .error, category: "chat-analyzer", message: "Análisis interrumpido", metadata: ["errorType": String(describing: type(of: error))])
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
}
