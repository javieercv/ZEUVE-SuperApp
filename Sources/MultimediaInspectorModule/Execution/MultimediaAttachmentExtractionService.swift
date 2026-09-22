import Foundation
import ZEUVECore
import ZEUVEOperations
import ZEUVEEngines

public actor MultimediaAttachmentExtractionService {
    private let coordinator: OperationCoordinator
    private let engines: MultimediaEngineLocator
    private let runner = ExternalProcessRunner()
    private let publisher = MultimediaOutputPublisher()
    private var activeOperationID: UUID?

    public init(coordinator: OperationCoordinator, engineRegistry: EngineRegistry, diagnostics: EngineDiagnosticService? = nil) {
        self.coordinator = coordinator
        self.engines = MultimediaEngineLocator(registry: engineRegistry, diagnostics: diagnostics)
    }

    public func extract(
        inputURL: URL,
        inputFingerprint: FileFingerprint,
        attachmentOrdinal: Int,
        proposedOutput: URL
    ) async throws -> URL {
        guard inputFingerprint.matches(inputURL) else { throw MultimediaInspectorError.originalChanged }
        let ffmpeg = try await engines.ffmpeg()
        let operationID = try await coordinator.begin(moduleID: multimediaInspectorModuleIdentifier, name: "Extrayendo adjunto")
        activeOperationID = operationID
        let fileExtension = proposedOutput.pathExtension.isEmpty ? "bin" : proposedOutput.pathExtension
        let workspace = try MultimediaWorkspace(operationID: operationID, extension: fileExtension)
        defer { workspace.cleanup() }
        do {
            let request = ExternalProcessRequest(
                executable: ffmpeg,
                arguments: [
                    "-hide_banner", "-nostdin", "-y",
                    "-dump_attachment:t:\(attachmentOrdinal)", workspace.output.path,
                    "-i", inputURL.path,
                    "-f", "null", "-"
                ]
            )
            try await coordinator.update(id: operationID, progress: .init(completed: 1, total: 3, phase: "Extrayendo"))
            let result = try await runner.run(request)
            if await coordinator.shouldCancel(id: operationID) { throw MultimediaInspectorError.cancelled }
            guard result.exitCode == 0 else { throw MultimediaInspectorError.attachmentExtractionFailed("FFmpeg terminó con error") }
            guard inputFingerprint.matches(inputURL) else { throw MultimediaInspectorError.originalChanged }
            let values = try workspace.output.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true, (values.fileSize ?? 0) > 0 else { throw MultimediaInspectorError.attachmentExtractionFailed("el archivo extraído está vacío") }
            let published = try publisher.publish(temporary: workspace.output, proposed: proposedOutput, protectedOriginals: [inputURL])
            try await coordinator.update(id: operationID, progress: .init(completed: 3, total: 3, phase: "Publicado"))
            try await coordinator.finish(id: operationID)
            activeOperationID = nil
            return published
        } catch {
            try? await coordinator.finish(id: operationID)
            activeOperationID = nil
            if error is CancellationError { throw MultimediaInspectorError.cancelled }
            throw error
        }
    }

    public func cancel() async {
        if let activeOperationID { try? await coordinator.requestCancellation(id: activeOperationID) }
        try? await runner.cancel()
    }
}
