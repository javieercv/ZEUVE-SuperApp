import Foundation
import ZEUVECore
import ZEUVEOperations
import ZEUVEEngines

public struct MultimediaEditResult: Sendable, Equatable {
    public let operationID: UUID
    public let outputURL: URL
    public let inspection: MediaInspectionResult
    public let historyWarning: String?
}

public actor MultimediaEditService {
    private let coordinator: OperationCoordinator
    private let engines: MultimediaEngineLocator
    private let runner: ExternalProcessRunner
    private let validator: MultimediaResultValidator
    private let publisher: MultimediaOutputPublisher
    private let history: MultimediaInspectorHistoryService
    private let disk: MultimediaDiskSpaceChecker
    private var preferences: MultimediaInspectorPreferences
    private var activeOperationID: UUID?

    public init(
        coordinator: OperationCoordinator,
        engineRegistry: EngineRegistry,
        diagnostics: EngineDiagnosticService? = nil,
        history: MultimediaInspectorHistoryService,
        preferences: MultimediaInspectorPreferences = .defaults
    ) {
        self.coordinator = coordinator
        engines = .init(registry: engineRegistry, diagnostics: diagnostics)
        runner = .init()
        validator = .init()
        publisher = .init()
        self.history = history
        disk = .init()
        self.preferences = preferences
    }


    public func updatePreferences(_ preferences: MultimediaInspectorPreferences) {
        var normalized = preferences
        normalized.normalize()
        self.preferences = normalized
    }

    public func execute(plan: MediaEditPlan, originalInspection: MediaInspectionResult, proposedOutput: URL) async throws -> MultimediaEditResult {
        try verifyInputsUnchanged(plan)
        guard MultimediaFilenamePolicy.canonical(proposedOutput) != MultimediaFilenamePolicy.canonical(plan.originalURL) else { throw MultimediaInspectorError.outputMatchesOriginal }
        let paths = try await engines.paths()
        let operationID = try await coordinator.begin(moduleID: multimediaInspectorModuleIdentifier, name: "Remultiplexando pistas")
        activeOperationID = operationID
        let started = Date()
        let workspace = try MultimediaWorkspace(operationID: operationID, extension: plan.targetContainer.fileExtension)
        defer { workspace.cleanup() }
        do {
            let estimated = estimatedOutputBytes(plan)
            try disk.require(estimatedBytes: estimated, at: workspace.root)
            try disk.require(estimatedBytes: estimated, at: proposedOutput.deletingLastPathComponent())
            try await coordinator.update(id: operationID, progress: .init(completed: 1, total: 10, phase: "Preparando FFmpeg"))
            let chapterMetadataURL: URL?
            if !plan.chapters.isEmpty {
                let url = workspace.auxiliaryFile(named: "chapters.ffmeta")
                try FFmpegChapterMetadataBuilder().write(chapters: plan.chapters, to: url)
                chapterMetadataURL = url
            } else {
                chapterMetadataURL = nil
            }
            let command = try FFmpegMediaEditCommandBuilder().command(
                ffmpeg: paths.ffmpeg,
                plan: plan,
                outputURL: workspace.output,
                chapterMetadataURL: chapterMetadataURL
            )
            let result = try await runner.run(command.request)
            if await coordinator.shouldCancel(id: operationID) { throw MultimediaInspectorError.cancelled }
            guard result.exitCode == 0 else { throw MultimediaInspectorError.processFailed }
            try verifyInputsUnchanged(plan)
            try await coordinator.update(id: operationID, progress: .init(completed: 8, total: 10, phase: "Validando resultado"))
            let inspected = try await validator.validate(url: workspace.output, plan: plan, original: originalInspection, ffprobe: paths.ffprobe)
            let protected = [plan.originalURL]
                + (plan.videoTracks + plan.audioTracks + plan.subtitleTracks).compactMap { if case .external(let url,_,_) = $0.track.source { return url }; return nil }
                + plan.attachments.compactMap { if case .external(let url, _) = $0.attachment.source { return url }; return nil }
                + plan.artworks.compactMap { if case .external(let url, _, _) = $0.artwork.source { return url }; return nil }
            let published = try publisher.publish(temporary: workspace.output, proposed: proposedOutput, protectedOriginals: protected)
            try await coordinator.update(id: operationID, progress: .init(completed: 10, total: 10, phase: "Publicado"))
            let historyWarning = ZEUVEHistoryPersistence.attempt {
                try history.saveRemux(id: operationID, plan: plan, startedAt: started, finishedAt: Date())
            }?.warning
            try await coordinator.finish(id: operationID); activeOperationID = nil
            return MultimediaEditResult(
                operationID: operationID,
                outputURL: published,
                inspection: inspected,
                historyWarning: historyWarning
            )
        } catch {
            try? await coordinator.finish(id: operationID); activeOperationID = nil
            if error is CancellationError { throw MultimediaInspectorError.cancelled }
            throw error
        }
    }



    private func estimatedOutputBytes(_ plan: MediaEditPlan) -> Int64 {
        var total = max(plan.originalFingerprint.size, 1)
        var countedExternalPaths = Set<String>()
        for item in plan.videoTracks + plan.audioTracks + plan.subtitleTracks {
            guard case .external(let url, let fingerprint, _) = item.track.source else { continue }
            let canonical = url.standardizedFileURL.resolvingSymlinksInPath().path
            guard countedExternalPaths.insert(canonical).inserted else { continue }
            let (next, overflow) = total.addingReportingOverflow(max(fingerprint.size, 0))
            total = overflow ? Int64.max : next
        }
        for item in plan.attachments {
            guard case .external(let url, let fingerprint) = item.attachment.source else { continue }
            let canonical = url.standardizedFileURL.resolvingSymlinksInPath().path
            guard countedExternalPaths.insert(canonical).inserted else { continue }
            let (next, overflow) = total.addingReportingOverflow(max(fingerprint.size, 0))
            total = overflow ? Int64.max : next
        }
        return total
    }

    private func verifyInputsUnchanged(_ plan: MediaEditPlan) throws {
        guard plan.originalFingerprint.matches(plan.originalURL) else { throw MultimediaInspectorError.originalChanged }
        for item in plan.videoTracks + plan.audioTracks + plan.subtitleTracks {
            guard case .external(let url, let fingerprint, _) = item.track.source else { continue }
            guard FileManager.default.fileExists(atPath: url.path) else { throw MultimediaInspectorError.inputMissing(url.lastPathComponent) }
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values?.isRegularFile == true, values?.isSymbolicLink != true else { throw MultimediaInspectorError.inputChanged(url.lastPathComponent) }
            guard fingerprint.matches(url) else { throw MultimediaInspectorError.inputChanged(url.lastPathComponent) }
        }
        for item in plan.attachments {
            guard case .external(let url, let fingerprint) = item.attachment.source else { continue }
            guard FileManager.default.fileExists(atPath: url.path) else { throw MultimediaInspectorError.inputMissing(url.lastPathComponent) }
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values?.isRegularFile == true, values?.isSymbolicLink != true else { throw MultimediaInspectorError.inputChanged(url.lastPathComponent) }
            guard fingerprint.matches(url) else { throw MultimediaInspectorError.inputChanged(url.lastPathComponent) }
        }
    }

    public func cancel() async {
        if let id=activeOperationID { try? await coordinator.requestCancellation(id: id) }
        try? await runner.cancel()
    }
}
