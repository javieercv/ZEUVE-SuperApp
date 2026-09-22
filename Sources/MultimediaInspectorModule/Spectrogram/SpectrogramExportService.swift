import Foundation
import ZEUVECore
import ZEUVEOperations

public struct SpectrogramExportResult: Sendable, Equatable {
    public let outputURL: URL
    public let historyWarning: String?
}

public actor SpectrogramExportService {
    private let coordinator: OperationCoordinator
    private let history: MultimediaInspectorHistoryService
    private let exporter: SpectrogramExporter
    private let publisher: MultimediaOutputPublisher
    private var activeOperationID: UUID?
    private var cancellationFlag: SpectrogramCancellationFlag?

    public init(
        coordinator: OperationCoordinator,
        history: MultimediaInspectorHistoryService,
        exporter: SpectrogramExporter = .init(),
        publisher: MultimediaOutputPublisher = .init()
    ) {
        self.coordinator = coordinator
        self.history = history
        self.exporter = exporter
        self.publisher = publisher
    }

    public func export(
        result: SpectrogramResult,
        frequencyScale: SpectrogramFrequencyScale,
        proposedOutput: URL,
        protectedOriginals: [URL],
        width: Int = 1600,
        height: Int = 900,
        recordHistory: Bool = true
    ) async throws -> SpectrogramExportResult {
        let id = try await coordinator.begin(moduleID: multimediaInspectorModuleIdentifier, name: "Exportando espectrograma")
        activeOperationID = id
        let flag = SpectrogramCancellationFlag()
        cancellationFlag = flag
        let started = Date()
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("zeuve-spectrum-\(id.uuidString).png")
        defer {
            try? FileManager.default.removeItem(at: temporary)
            cancellationFlag = nil
        }
        do {
            try await coordinator.update(id: id, progress: .init(completed: 1, total: 3, phase: "Renderizando PNG"))
            try await Task.detached(priority: .userInitiated) { [exporter] in
                try exporter.exportPNG(
                    result,
                    frequencyScale: frequencyScale,
                    to: temporary,
                    width: width,
                    height: height,
                    shouldCancel: { flag.isCancelled }
                )
            }.value
            if await coordinator.shouldCancel(id: id) || flag.isCancelled { throw MultimediaInspectorError.cancelled }
            try await coordinator.update(id: id, progress: .init(completed: 2, total: 3, phase: "Publicando"))
            let output = try publisher.publish(temporary: temporary, proposed: proposedOutput, protectedOriginals: protectedOriginals)
            let historyWarning = recordHistory ? ZEUVEHistoryPersistence.attempt {
                try history.savePNG(id: id, startedAt: started, finishedAt: Date())
            }?.warning : nil
            try await coordinator.update(id: id, progress: .init(completed: 3, total: 3, phase: "Publicado"))
            try await coordinator.finish(id: id)
            activeOperationID = nil
            return SpectrogramExportResult(outputURL: output, historyWarning: historyWarning)
        } catch {
            try? await coordinator.finish(id: id)
            activeOperationID = nil
            if error is CancellationError { throw MultimediaInspectorError.cancelled }
            throw error
        }
    }

    public func cancel() async {
        cancellationFlag?.cancel()
        if let id = activeOperationID { try? await coordinator.requestCancellation(id: id) }
    }
}

private final class SpectrogramCancellationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
}
