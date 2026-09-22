import Foundation
import ZEUVECore
import ZEUVEOperations
import ZEUVEEngines

private final class ArtworkPreviewCollector: @unchecked Sendable {
    private let lock = NSLock()
    private let limit: Int
    private var storage = Data()
    private var overflow = false

    init(limit: Int = 32 * 1024 * 1024) { self.limit = limit }

    func append(_ data: Data) {
        lock.lock(); defer { lock.unlock() }
        guard !overflow else { return }
        guard storage.count + data.count <= limit else { overflow = true; storage.removeAll(); return }
        storage.append(data)
    }

    func result() -> Data? {
        lock.lock(); defer { lock.unlock() }
        return overflow || storage.isEmpty ? nil : storage
    }
}

public actor MultimediaArtworkService {
    private let coordinator: OperationCoordinator
    private let engines: MultimediaEngineLocator
    private let runner = ExternalProcessRunner()
    private let publisher = MultimediaOutputPublisher()
    private var activeOperationID: UUID?

    public init(coordinator: OperationCoordinator, engineRegistry: EngineRegistry, diagnostics: EngineDiagnosticService? = nil) {
        self.coordinator = coordinator
        self.engines = MultimediaEngineLocator(registry: engineRegistry, diagnostics: diagnostics)
    }

    public func extract(inputURL: URL, fingerprint: FileFingerprint, streamIndex: Int, proposedOutput: URL) async throws -> URL {
        guard fingerprint.matches(inputURL) else { throw MultimediaInspectorError.originalChanged }
        let ffmpeg = try await engines.ffmpeg()
        let operationID = try await coordinator.begin(moduleID: multimediaInspectorModuleIdentifier, name: "Extrayendo carátula")
        activeOperationID = operationID
        let ext = proposedOutput.pathExtension.isEmpty ? "jpg" : proposedOutput.pathExtension
        let workspace = try MultimediaWorkspace(operationID: operationID, extension: ext)
        defer { workspace.cleanup() }
        do {
            let request = ExternalProcessRequest(executable: ffmpeg, arguments: [
                "-hide_banner", "-nostdin", "-y", "-i", inputURL.path,
                "-map", "0:\(streamIndex)", "-frames:v", "1", "-c:v", "copy", workspace.output.path,
            ])
            try await coordinator.update(id: operationID, progress: .init(completed: 1, total: 3, phase: "Extrayendo"))
            let result = try await runner.run(request)
            if await coordinator.shouldCancel(id: operationID) { throw MultimediaInspectorError.cancelled }
            guard result.succeeded else { throw MultimediaInspectorError.attachmentExtractionFailed("FFmpeg no ha podido extraer la carátula") }
            guard fingerprint.matches(inputURL) else { throw MultimediaInspectorError.originalChanged }
            let values = try workspace.output.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true, (values.fileSize ?? 0) > 0 else { throw MultimediaInspectorError.attachmentExtractionFailed("la carátula extraída está vacía") }
            let published = try publisher.publish(temporary: workspace.output, proposed: proposedOutput, protectedOriginals: [inputURL])
            try await coordinator.update(id: operationID, progress: .init(completed: 3, total: 3, phase: "Publicado"))
            try await coordinator.finish(id: operationID)
            activeOperationID = nil
            return published
        } catch {
            try? await coordinator.finish(id: operationID); activeOperationID = nil
            if error is CancellationError { throw MultimediaInspectorError.cancelled }
            throw error
        }
    }

    public func previewData(inputURL: URL, fingerprint: FileFingerprint, streamIndex: Int) async throws -> Data {
        guard fingerprint.matches(inputURL) else { throw MultimediaInspectorError.originalChanged }
        let ffmpeg = try await engines.ffmpeg()
        let collector = ArtworkPreviewCollector()
        let result = try await runner.run(.init(executable: ffmpeg, arguments: [
            "-hide_banner", "-nostdin", "-v", "error", "-i", inputURL.path,
            "-map", "0:\(streamIndex)", "-frames:v", "1", "-c:v", "copy", "-f", "image2pipe", "pipe:1",
        ]), onStdout: { collector.append($0) })
        guard result.succeeded, let data = collector.result() else {
            throw MultimediaInspectorError.attachmentExtractionFailed("no se ha podido preparar la previsualización de la carátula")
        }
        guard fingerprint.matches(inputURL) else { throw MultimediaInspectorError.originalChanged }
        return data
    }

    public func cancel() async {
        if let activeOperationID { try? await coordinator.requestCancellation(id: activeOperationID) }
        try? await runner.cancel()
    }
}
