import Foundation
import ZEUVECore
import ZEUVEStorage
import ZEUVEOperations
import ZEUVEEngines

public actor UniversalConverterExecutionService {
    public typealias ProgressHandler = @Sendable (ConverterProgressSnapshot) -> Void

    private let coordinator: OperationCoordinator
    private let history: UniversalConverterHistoryService?
    private let logger: LocalLogger?
    private let engineLocator: UniversalConverterEngineLocator?
    private let runner: ExternalProcessRunner
    private let probeService: MediaInspectionService
    private let timingService: FrameTimingService
    private let pdfService: NativePDFService
    private let imageService: NativeImageService
    private let publisher: ConverterOutputPublisher
    private let visibleFrameOutputs: VisibleFrameOutputCoordinator
    private let diskChecker: ConverterDiskSpaceChecker
    private let zipWriter: ConverterZIPWriter
    private let resultValidator: ConverterResultValidator
    private var activeOperationID: UUID?

    public init(
        coordinator: OperationCoordinator,
        history: UniversalConverterHistoryService?,
        logger: LocalLogger?,
        engineLocator: UniversalConverterEngineLocator? = try? .bundled(),
        runner: ExternalProcessRunner = ExternalProcessRunner()
    ) {
        self.coordinator = coordinator
        self.history = history
        self.logger = logger
        self.engineLocator = engineLocator
        self.runner = runner
        self.probeService = MediaInspectionService()
        self.timingService = FrameTimingService()
        self.pdfService = NativePDFService()
        self.imageService = NativeImageService()
        self.publisher = ConverterOutputPublisher()
        self.visibleFrameOutputs = VisibleFrameOutputCoordinator()
        self.diskChecker = ConverterDiskSpaceChecker()
        self.zipWriter = ConverterZIPWriter()
        self.resultValidator = ConverterResultValidator()
    }

    public func execute(
        _ plan: ConversionPlan,
        archivePassword: String? = nil,
        progress: @escaping ProgressHandler = { _ in },
        onWarning: @escaping @Sendable (String) -> Void = { _ in }
    ) async throws -> UniversalConverterResult {
        guard !plan.items.isEmpty else { throw UniversalConverterError.noInput }
        let operationID = try await coordinator.begin(moduleID: universalConverterModuleIdentifier, name: plan.options.operation.displayName)
        activeOperationID = operationID
        let startedAt = Date()
        let workspace = try ConverterWorkspace(operationID: operationID)
        let protectedOriginalPaths = ConverterOutputPublisher.protectedCanonicalPaths(
            for: plan.items.flatMap(\.sources).map(\.sourceURL)
        )
        var itemResults: [ConverterItemResult] = []
        var archiveURL: URL?
        var coordinatorFinished = false

        do {
            try FileManager.default.createDirectory(at: plan.outputFolder, withIntermediateDirectories: true)
            guard FileManager.default.isWritableFile(atPath: plan.outputFolder.path) else {
                throw UniversalConverterError.permissionDenied(plan.outputFolder.path)
            }
            try diskChecker.require(estimatedBytes: plan.estimatedOutputBytes, at: plan.outputFolder)
            var requirements = UniversalConverterEngineRequirements()
            requirements.media = plan.items.contains { $0.executionKind == .ffmpeg }
            requirements.pandoc = plan.items.contains { $0.executionKind == .pandoc }
            let needsExternalEngine = requirements.media || requirements.pandoc
            let enginePaths: UniversalConverterEnginePaths?
            if let engineLocator {
                enginePaths = try await engineLocator.paths(requirements: requirements)
            } else if needsExternalEngine {
                throw UniversalConverterError.engineUnavailable("Los motores necesarios no están disponibles.")
            } else {
                enginePaths = nil
            }
            let parallelism = Self.parallelismLimit(for: plan)
            if parallelism > 1 {
                itemResults = await executeParallelItems(
                    plan: plan,
                    workspace: workspace,
                    engines: enginePaths,
                    archivePassword: archivePassword,
                    protectedOriginalPaths: protectedOriginalPaths,
                    operationID: operationID,
                    startedAt: startedAt,
                    limit: parallelism,
                    progress: progress
                )
            } else {
                for (index, item) in plan.items.enumerated() {
                    if await coordinator.shouldCancel(id: operationID) || Task.isCancelled {
                        itemResults.append(contentsOf: plan.items[index...].map {
                            ConverterItemResult(sourceNames: $0.sources.map(\.displayName), status: .cancelled, message: "Cancelado")
                        })
                        break
                    }
                    let priorResults = itemResults
                    let snapshot = Self.makeProgressSnapshot(
                        plan: plan,
                        currentIndex: index,
                        currentFraction: nil,
                        priorResults: priorResults,
                        phase: "Convirtiendo",
                        startedAt: startedAt
                    )
                    progress(snapshot)
                    try? await coordinator.update(id: operationID, progress: .init(completed: snapshot.completedItems, total: plan.items.count, phase: snapshot.phase, currentItem: snapshot.currentItem))
                    let result = await processPlanItem(
                        item,
                        plan: plan,
                        workspace: workspace,
                        engines: enginePaths,
                        archivePassword: archivePassword,
                        protectedOriginalPaths: protectedOriginalPaths,
                        progress: { update in
                            progress(Self.makeProgressSnapshot(
                                plan: plan,
                                currentIndex: index,
                                currentFraction: update.fraction,
                                priorResults: priorResults,
                                phase: update.phase,
                                startedAt: startedAt
                            ))
                        }
                    )
                    itemResults.append(result)
                    if result.status == .cancelled {
                        itemResults.append(contentsOf: plan.items.dropFirst(index + 1).map {
                            .init(sourceNames: $0.sources.map(\.displayName), status: .cancelled, message: "Cancelado")
                        })
                        break
                    }
                }
            }

            if plan.options.recompressZIPResults, plan.containsArchiveEntries, !itemResults.flatMap(\.outputURLs).isEmpty,
               !(await coordinator.shouldCancel(id: operationID)) {
                progress(Self.makeProgressSnapshot(plan: plan, currentIndex: nil, currentFraction: nil, priorResults: itemResults, phase: "Creando ZIP de resultados", startedAt: startedAt))
                archiveURL = try await createResultArchive(
                    itemResults: itemResults,
                    outputFolder: plan.outputFolder,
                    workspace: workspace,
                    policy: plan.options.conflictPolicy,
                    protectedOriginalPaths: protectedOriginalPaths
                )
            }

            let result = UniversalConverterResult(
                operationID: operationID, startedAt: startedAt, outputFolder: plan.outputFolder,
                items: itemResults, archiveURL: archiveURL
            )
            if let history, let failure = ZEUVEHistoryPersistence.attempt({ try history.save(result, plan: plan) }) {
                onWarning(failure.warning)
                await log(.warning, "No se ha podido guardar el historial", failure.logMetadata)
            }
            try await coordinator.finish(id: operationID); coordinatorFinished = true
            activeOperationID = nil
            try? workspace.clean()
            progress(Self.makeProgressSnapshot(plan: plan, currentIndex: nil, currentFraction: 1, priorResults: itemResults, phase: "Finalizado", startedAt: startedAt))
            await log(.info, "Conversión finalizada", ["correctos": String(result.completedCount), "fallidos": String(result.failedCount), "omitidos": String(result.skippedCount)])
            return result
        } catch {
            if !coordinatorFinished { try? await coordinator.finish(id: operationID) }
            activeOperationID = nil
            try? workspace.clean()
            throw error
        }
    }

    public func cancel() async {
        if let id = activeOperationID { try? await coordinator.requestCancellation(id: id) }
        try? await runner.cancel()
        await probeService.cancel()
        await timingService.cancel()
        await resultValidator.cancel()
    }

    private func processPlanItem(
        _ item: ConversionPlanItem,
        plan: ConversionPlan,
        workspace: ConverterWorkspace,
        engines: UniversalConverterEnginePaths?,
        archivePassword: String?,
        protectedOriginalPaths: Set<String>,
        progress: @escaping @Sendable (ItemProgressUpdate) -> Void
    ) async -> ConverterItemResult {
        if item.operation == .extractFrames {
            return await processVisibleFrameItem(
                item,
                plan: plan,
                workspace: workspace,
                engines: engines,
                archivePassword: archivePassword,
                protectedOriginalPaths: protectedOriginalPaths,
                progress: progress
            )
        }

        do {
            try Task.checkCancellation()
            try validateSources(item.sources)
            let progressCoalescer = LatestValueCoalescer<ItemProgressUpdate>(
                minimumIntervalNanoseconds: 100_000_000,
                delivery: progress
            )
            let generated: URL
            do {
                generated = try await executeItem(
                    item,
                    options: plan.options,
                    workspace: workspace,
                    engines: engines,
                    archivePassword: archivePassword,
                    progress: { fraction in
                        let update = ItemProgressUpdate(fraction: fraction, phase: "Convirtiendo")
                        progressCoalescer.submit(update, immediately: fraction == 1)
                    }
                )
                progressCoalescer.flush()
                progressCoalescer.cancel()
            } catch {
                progressCoalescer.cancel()
                throw error
            }
            try Task.checkCancellation()
            guard let published = try publisher.publish(
                source: generated,
                relativePath: item.destinationRelativePath,
                to: plan.outputFolder,
                policy: plan.options.conflictPolicy,
                protectedCanonicalPaths: protectedOriginalPaths
            ) else {
                return .init(sourceNames: item.sources.map(\.displayName), status: .skipped, message: "El resultado ya existía y se omitió.")
            }
            if plan.options.preserveDates, let source = item.sources.first, source.kind == .file {
                preserveDates(from: source.sourceURL, to: published)
            }
            return .init(sourceNames: item.sources.map(\.displayName), status: .completed, outputURLs: [published])
        } catch is CancellationError {
            return .init(sourceNames: item.sources.map(\.displayName), status: .cancelled, message: "Cancelado")
        } catch {
            await log(.error, "Conversión fallida", ["entrada": item.sources.map(\.displayName).joined(separator: ", "), "error": error.localizedDescription])
            return .init(sourceNames: item.sources.map(\.displayName), status: .failed, message: error.localizedDescription)
        }
    }

    private func processVisibleFrameItem(
        _ item: ConversionPlanItem,
        plan: ConversionPlan,
        workspace: ConverterWorkspace,
        engines: UniversalConverterEnginePaths?,
        archivePassword: String?,
        protectedOriginalPaths: Set<String>,
        progress: @escaping @Sendable (ItemProgressUpdate) -> Void
    ) async -> ConverterItemResult {
        let sourceNames = item.sources.map(\.displayName)
        var session: VisibleFrameOutputSession?
        let progressCoalescer = LatestValueCoalescer<ItemProgressUpdate>(
            minimumIntervalNanoseconds: 100_000_000,
            delivery: progress
        )
        do {
            try Task.checkCancellation()
            try validateSources(item.sources)
            session = try visibleFrameOutputs.prepare(
                operationID: workspace.operationID,
                relativePath: item.destinationRelativePath,
                outputRoot: plan.outputFolder,
                policy: plan.options.conflictPolicy,
                protectedCanonicalPaths: protectedOriginalPaths,
                recordURL: workspace.visibleFrameRecordURL(itemID: item.id)
            )
            guard let session else {
                progressCoalescer.cancel()
                return .init(sourceNames: sourceNames, status: .skipped, message: "El resultado ya existía y se omitió.")
            }

            _ = try await executeItem(
                item,
                options: plan.options,
                workspace: workspace,
                engines: engines,
                archivePassword: archivePassword,
                directOutputURL: session.workingURL,
                progress: { fraction in
                    progressCoalescer.submit(
                        ItemProgressUpdate(fraction: fraction, phase: "Extrayendo fotogramas"),
                        immediately: fraction == 1
                    )
                },
                frameProgress: { fraction, frameCount in
                    let phase = frameCount.map { "Extrayendo fotogramas · \($0.formatted()) creados" } ?? "Extrayendo fotogramas"
                    progressCoalescer.submit(ItemProgressUpdate(fraction: fraction, phase: phase), immediately: fraction == 1)
                },
                phaseUpdate: { phase in
                    progressCoalescer.submit(ItemProgressUpdate(fraction: nil, phase: phase), immediately: true)
                }
            )
            progressCoalescer.flush()
            try Task.checkCancellation()
            let published = try visibleFrameOutputs.complete(session, protectedCanonicalPaths: protectedOriginalPaths)
            progressCoalescer.cancel()
            if plan.options.preserveDates, let source = item.sources.first, source.kind == .file {
                preserveDates(from: source.sourceURL, to: published)
            }
            return .init(sourceNames: sourceNames, status: .completed, outputURLs: [published])
        } catch is CancellationError {
            progressCoalescer.cancel()
            let preserved = await preserveIncompleteFrames(session: session, item: item)
            let message = preserved.map { "Cancelado. Se han conservado \($0.count.formatted()) fotogramas válidos en una carpeta marcada como incompleta." } ?? "Cancelado"
            return .init(sourceNames: sourceNames, status: .cancelled, outputURLs: preserved.map { [$0.url] } ?? [], message: message)
        } catch {
            progressCoalescer.cancel()
            let preserved = await preserveIncompleteFrames(session: session, item: item)
            var message = error.localizedDescription
            if let preserved {
                message += " Se han conservado \(preserved.count.formatted()) fotogramas válidos en una carpeta marcada como incompleta."
            }
            await log(.error, "Extracción de fotogramas fallida", ["entrada": sourceNames.joined(separator: ", "), "error": error.localizedDescription])
            return .init(sourceNames: sourceNames, status: .failed, outputURLs: preserved.map { [$0.url] } ?? [], message: message)
        }
    }

    private func preserveIncompleteFrames(
        session: VisibleFrameOutputSession?,
        item: ConversionPlanItem
    ) async -> (url: URL, count: Int)? {
        guard let session else { return nil }
        let count = (try? await resultValidator.retainValidFramePrefix(url: session.workingURL, expectedFormat: item.targetFormat)) ?? 0
        guard let url = try? visibleFrameOutputs.preserveIncomplete(session) else { return nil }
        return (url, count)
    }

    private func executeParallelItems(
        plan: ConversionPlan,
        workspace: ConverterWorkspace,
        engines: UniversalConverterEnginePaths?,
        archivePassword: String?,
        protectedOriginalPaths: Set<String>,
        operationID: UUID,
        startedAt: Date,
        limit: Int,
        progress: @escaping ProgressHandler
    ) async -> [ConverterItemResult] {
        var results = Array<ConverterItemResult?>(repeating: nil, count: plan.items.count)
        var running: Set<Int> = []
        var nextIndex = 0

        await withTaskGroup(of: (Int, ConverterItemResult).self) { group in
            func enqueue(_ index: Int) {
                let item = plan.items[index]
                running.insert(index)
                group.addTask { [self] in
                    let coordinatorCancelled = await coordinator.shouldCancel(id: operationID)
                    if Task.isCancelled || coordinatorCancelled {
                        return (index, .init(sourceNames: item.sources.map(\.displayName), status: .cancelled, message: "Cancelado"))
                    }
                    let result = await processPlanItem(
                        item,
                        plan: plan,
                        workspace: workspace,
                        engines: engines,
                        archivePassword: archivePassword,
                        protectedOriginalPaths: protectedOriginalPaths,
                        progress: { _ in }
                    )
                    return (index, result)
                }
            }

            while nextIndex < min(limit, plan.items.count) {
                enqueue(nextIndex)
                nextIndex += 1
            }
            progress(Self.makeParallelProgressSnapshot(plan: plan, results: results, running: running, startedAt: startedAt))

            while let (index, result) = await group.next() {
                running.remove(index)
                results[index] = result
                let snapshot = Self.makeParallelProgressSnapshot(plan: plan, results: results, running: running, startedAt: startedAt)
                progress(snapshot)
                try? await coordinator.update(id: operationID, progress: .init(completed: snapshot.completedItems, total: plan.items.count, phase: snapshot.phase, currentItem: snapshot.currentItem))

                let coordinatorCancelled = await coordinator.shouldCancel(id: operationID)
                if Task.isCancelled || coordinatorCancelled {
                    group.cancelAll()
                } else if nextIndex < plan.items.count {
                    enqueue(nextIndex)
                    nextIndex += 1
                }
            }
        }

        for index in results.indices where results[index] == nil {
            results[index] = .init(sourceNames: plan.items[index].sources.map(\.displayName), status: .cancelled, message: "Cancelado")
        }
        return results.compactMap { $0 }
    }

    private nonisolated static func parallelismLimit(for plan: ConversionPlan) -> Int {
        guard plan.items.count > 1,
              plan.items.allSatisfy({ $0.executionKind == .copy || $0.executionKind == .nativeImage }) else {
            return 1
        }
        switch plan.options.parallelismMode {
        case .manual:
            return min(max(plan.options.manualParallelism, 1), 8, plan.items.count)
        case .automatic:
            let cores = max(ProcessInfo.processInfo.activeProcessorCount, 1)
            return min(max(cores / 2, 1), 4, plan.items.count)
        }
    }

    private func executeItem(
        _ item: ConversionPlanItem,
        options: ConverterOperationOptions,
        workspace: ConverterWorkspace,
        engines: UniversalConverterEnginePaths?,
        archivePassword: String?,
        directOutputURL: URL? = nil,
        progress: @escaping @Sendable (Double?) -> Void,
        frameProgress: (@Sendable (Double?, Int?) -> Void)? = nil,
        phaseUpdate: @escaping @Sendable (String) -> Void = { _ in }
    ) async throws -> URL {
        let sources = try item.sources.map { try workspace.inputURL(for: $0, archivePassword: archivePassword) }
        switch item.executionKind {
        case .copy:
            guard let source = sources.first else { throw UniversalConverterError.noInput }
            let output = try workspace.generatedURL(relativePath: item.destinationRelativePath)
            if FileManager.default.fileExists(atPath: output.path) { try FileManager.default.removeItem(at: output) }
            try FileManager.default.copyItem(at: source, to: output)
            try validateGenerated(output, directory: false)
            return output

        case .nativeImage:
            guard let source = sources.first else { throw UniversalConverterError.noInput }
            let output = try workspace.generatedURL(relativePath: item.destinationRelativePath)
            let directoryOutput = (item.sources.first?.format == .gif || item.sources.first?.format == .tiff)
                && item.targetFormat != item.sources.first?.format
            _ = try await imageService.convert(
                source: source,
                destination: output,
                target: item.targetFormat,
                options: options,
                outputAsDirectory: directoryOutput,
                progress: progress
            )
            try validateGenerated(output, directory: directoryOutput)
            return output

        case .ffmpeg:
            guard let ffmpeg = engines?.ffmpeg, let ffprobe = engines?.ffprobe else {
                throw UniversalConverterError.engineUnavailable("FFmpeg y FFprobe no están disponibles.")
            }
            guard let firstSource = sources.first else { throw UniversalConverterError.noInput }
            let output = if item.operation == .extractFrames, let directOutputURL {
                directOutputURL
            } else {
                try workspace.generatedURL(relativePath: item.destinationRelativePath)
            }
            let source: URL
            let probe: MediaInspectionResult?
            if item.operation == .imagesToVideo {
                source = try makeImageSequenceManifest(sources: sources, workspace: workspace, itemID: item.id, durationPerImage: options.sequenceDurationPerImage)
                probe = nil
            } else {
                source = firstSource
                probe = try await probeService.inspect(url: source, ffprobe: ffprobe, fingerprint: item.sources.first?.kind == .file ? item.sources.first?.fingerprint : nil)
            }
            let command = try FFmpegCommandBuilder().command(ffmpeg: ffmpeg, source: source, planItem: item, options: options, destination: output, probe: probe)
            let errors = FFmpegDiagnosticCollector(maximumBytes: 1_024 * 1_024)
            let timingCollector: FrameTimingCSVCollector?
            if item.operation == .extractFrames, options.createFrameTimingCSV {
                timingCollector = try await timingService.makeCollector(destination: command.outputURL.appendingPathComponent("tiempos.csv"))
            } else {
                timingCollector = nil
            }
            let monitor = FFmpegProgressMonitor(duration: probe?.durationSeconds) { fraction, frameCount in
                if let frameProgress { frameProgress(fraction, frameCount) }
                else { progress(fraction) }
            }
            let result: ExternalProcessResult
            do {
                result = try await runner.run(command.request, onStdout: { _ in }, onStderr: { data in
                    monitor.append(data)
                    timingCollector?.append(data)
                    errors.append(data)
                })
                try monitor.finish(success: result.succeeded)
                if timingCollector != nil { phaseUpdate("Finalizando tiempos.csv…") }
                try timingCollector?.finish()
                errors.finish()
            } catch {
                try? monitor.finish(success: false)
                try? timingCollector?.finish()
                errors.finish()
                throw error
            }
            if result.wasCancelled { throw CancellationError() }
            guard result.succeeded else { throw UniversalConverterError.processFailed(cleanProcessError(errors.string)) }
            if item.operation == .extractFrames { phaseUpdate("Comprobando los fotogramas generados…") }
            try await resultValidator.validate(url: command.outputURL, expectedFormat: item.targetFormat, directory: command.outputIsDirectory, ffprobe: ffprobe)
            if item.operation == .convert, item.sources.first?.category == .video,
               !commandCopiesVideo(command.request.arguments) {
                phaseUpdate("Validando la recodificación del vídeo…")
                try await validateRecodedVideo(url: command.outputURL, options: options, ffprobe: ffprobe)
            }
            return command.outputURL

        case .pandoc:
            guard let executable = engines?.pandoc else { throw UniversalConverterError.dependencyMissing("Pandoc") }
            guard let source = sources.first else { throw UniversalConverterError.noInput }
            let output = try workspace.generatedURL(relativePath: item.destinationRelativePath)
            try await runExternal(
                PandocCommandBuilder().request(executable: executable, source: source, target: item.targetFormat, destination: output, metadataPolicy: options.metadataPolicy),
                engineName: "Pandoc",
                progress: progress
            )
            try await resultValidator.validate(url: output, expectedFormat: item.targetFormat, directory: false, ffprobe: engines?.ffprobe)
            return output


        case .nativePDFToImages:
            guard let source = sources.first else { throw UniversalConverterError.noInput }
            let output = try workspace.generatedURL(relativePath: item.destinationRelativePath)
            _ = try pdfService.pdfToImages(source: source, destinationDirectory: output, format: item.targetFormat, dpi: options.pdfRasterDPI, password: archivePassword)
            try await resultValidator.validate(url: output, expectedFormat: item.targetFormat, directory: true, ffprobe: engines?.ffprobe)
            return output

        case .nativePDFToText:
            guard let source = sources.first else { throw UniversalConverterError.noInput }
            let output = try pdfService.pdfToText(source: source, destination: workspace.generatedURL(relativePath: item.destinationRelativePath), password: archivePassword)
            try await resultValidator.validate(url: output, expectedFormat: item.targetFormat, directory: false, ffprobe: engines?.ffprobe)
            return output

        case .nativeImagesToPDF:
            let output = try pdfService.imagesToPDF(sources: sources, destination: workspace.generatedURL(relativePath: item.destinationRelativePath))
            try await resultValidator.validate(url: output, expectedFormat: item.targetFormat, directory: false, ffprobe: engines?.ffprobe)
            return output
        }
    }

    private func runExternal(
        _ request: ExternalProcessRequest,
        engineName: String,
        progress: @escaping @Sendable (Double?) -> Void
    ) async throws {
        progress(nil)
        let errors = LimitedOutputCollector(maximumBytes: 1_024 * 1_024)
        let result = try await runner.run(request, onStderr: { errors.append($0) })
        if result.wasCancelled { throw CancellationError() }
        guard result.succeeded else {
            throw UniversalConverterError.processFailed("\(engineName): \(cleanProcessError(errors.string))")
        }
        progress(1)
    }

    private func makeImageSequenceManifest(
        sources: [URL],
        workspace: ConverterWorkspace,
        itemID: UUID,
        durationPerImage: Double
    ) throws -> URL {
        guard !sources.isEmpty else { throw UniversalConverterError.noInput }
        let ordered = sources.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        let manifest = workspace.metadata.appendingPathComponent("sequence-\(itemID.uuidString).txt")
        func quoted(_ path: String) -> String { path.replacingOccurrences(of: "'", with: "'\\''") }
        var lines: [String] = []
        for source in ordered {
            lines.append("file '\(quoted(source.path))'")
            lines.append("duration \(String(format: "%.6f", durationPerImage))")
        }
        if let last = ordered.last { lines.append("file '\(quoted(last.path))'") }
        try (lines.joined(separator: "\n") + "\n").write(to: manifest, atomically: true, encoding: .utf8)
        return manifest
    }

    private func validateSources(_ sources: [ConverterInputItem]) throws {
        for source in sources {
            guard FileManager.default.fileExists(atPath: source.sourceURL.path) else { throw UniversalConverterError.sourceMissing(source.displayName) }
            guard source.fingerprint.matches(source.sourceURL) else { throw UniversalConverterError.sourceChanged(source.displayName) }
        }
    }

    private func validateGenerated(_ url: URL, directory: Bool) throws {
        if directory {
            let files = try regularFiles(in: url)
            guard !files.isEmpty else { throw UniversalConverterError.invalidResult("No se ha generado ningún archivo.") }
        } else {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true, (values.fileSize ?? 0) > 0 else {
                throw UniversalConverterError.invalidResult("El archivo generado está vacío o no es válido.")
            }
        }
    }

    private func regularFiles(in root: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey]) else { return [] }
        var files: [URL] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            if values.isRegularFile == true && values.isSymbolicLink != true { files.append(url) }
        }
        return files
    }

    private func preserveDates(from source: URL, to destination: URL) {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: source.path) else { return }
        var dates: [FileAttributeKey: Any] = [:]
        if let modified = attributes[.modificationDate] { dates[.modificationDate] = modified }
        if let created = attributes[.creationDate] { dates[.creationDate] = created }
        try? FileManager.default.setAttributes(dates, ofItemAtPath: destination.path)
    }

    private func createResultArchive(
        itemResults: [ConverterItemResult],
        outputFolder: URL,
        workspace: ConverterWorkspace,
        policy: ConverterConflictPolicy,
        protectedOriginalPaths: Set<String>
    ) async throws -> URL? {
        let root = workspace.metadata.appendingPathComponent("zip-results", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for output in itemResults.flatMap(\.outputURLs) {
            try Task.checkCancellation()
            let relative = output.path.replacingOccurrences(of: outputFolder.path + "/", with: "")
            let safe = try ConverterSafePath.normalize(relative)
            let destination = root.appendingPathComponent(safe)
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: output, to: destination)
        }
        try Task.checkCancellation()
        let zip = workspace.metadata.appendingPathComponent("Resultados convertidos.zip")
        try zipWriter.createZIP(from: root, at: zip)
        let catalog = try ConverterArchiveReader(url: zip).catalog()
        guard !catalog.entries.isEmpty else {
            throw UniversalConverterError.invalidResult("El ZIP de resultados se ha generado vacío.")
        }
        return try publisher.publish(
            source: zip,
            relativePath: "Resultados convertidos.zip",
            to: outputFolder,
            policy: policy,
            protectedCanonicalPaths: protectedOriginalPaths
        )
    }

    private nonisolated static func makeParallelProgressSnapshot(
        plan: ConversionPlan,
        results: [ConverterItemResult?],
        running: Set<Int>,
        startedAt: Date,
        now: Date = Date()
    ) -> ConverterProgressSnapshot {
        var completed = 0
        var failed = 0
        var skipped = 0
        var cancelled = 0
        var states: [ConverterProgressItem] = []
        states.reserveCapacity(plan.items.count)

        for (index, item) in plan.items.enumerated() {
            let result = results[index]
            let status: ConverterProgressItemStatus
            if let result {
                switch result.status {
                case .completed:
                    status = .completed
                    completed += 1
                case .skipped:
                    status = .skipped
                    skipped += 1
                case .failed:
                    status = .failed
                    failed += 1
                case .cancelled:
                    status = .cancelled
                    cancelled += 1
                }
            } else if running.contains(index) {
                status = .running
            } else {
                status = .pending
            }
            states.append(.init(
                id: item.id,
                sourceNames: item.sources.map(\.displayName),
                status: status,
                fraction: status == .completed ? 1 : nil,
                phase: status == .running ? "Convirtiendo" : status.rawValue,
                message: result?.message
            ))
        }

        let processed = completed + failed + skipped + cancelled
        let elapsed = now.timeIntervalSince(startedAt)
        let remaining = processed > 0 && processed < plan.items.count
            ? (elapsed / Double(processed)) * Double(plan.items.count - processed)
            : nil
        let currentIndex = running.min()
        let current = currentIndex.map { plan.items[$0].sources.map(\.displayName).joined(separator: ", ") }
        return ConverterProgressSnapshot(
            phase: "Convirtiendo en paralelo",
            currentItem: current,
            completedItems: completed,
            totalItems: plan.items.count,
            itemFraction: nil,
            failedItems: failed,
            skippedItems: skipped,
            cancelledItems: cancelled,
            elapsed: elapsed,
            estimatedRemaining: remaining,
            itemStates: states
        )
    }

    private nonisolated static func makeProgressSnapshot(
        plan: ConversionPlan,
        currentIndex: Int?,
        currentFraction: Double?,
        priorResults: [ConverterItemResult],
        phase: String,
        startedAt: Date,
        now: Date = Date()
    ) -> ConverterProgressSnapshot {
        var completed = 0
        var failed = 0
        var skipped = 0
        var cancelled = 0
        let fraction = currentFraction.map { min(max($0, 0), 1) }
        var states: [ConverterProgressItem] = []
        states.reserveCapacity(plan.items.count)

        for (index, item) in plan.items.enumerated() {
            let result = index < priorResults.count ? priorResults[index] : nil
            let status: ConverterProgressItemStatus
            let message: String?
            if let result {
                switch result.status {
                case .completed:
                    status = .completed
                    completed += 1
                case .skipped:
                    status = .skipped
                    skipped += 1
                case .failed:
                    status = .failed
                    failed += 1
                case .cancelled:
                    status = .cancelled
                    cancelled += 1
                }
                message = result.message
            } else if index == currentIndex {
                status = .running
                message = nil
            } else {
                status = .pending
                message = nil
            }
            states.append(.init(
                id: item.id,
                sourceNames: item.sources.map(\.displayName),
                status: status,
                fraction: index == currentIndex ? fraction : (status == .completed ? 1 : nil),
                phase: index == currentIndex ? phase : status.rawValue,
                message: message
            ))
        }

        let processed = completed + failed + skipped + cancelled
        let elapsed = now.timeIntervalSince(startedAt)
        let equivalent = Double(processed) + (fraction ?? 0)
        let remaining: TimeInterval?
        if equivalent > 0, elapsed > 0, plan.items.count > processed {
            remaining = (elapsed / equivalent) * max(Double(plan.items.count) - equivalent, 0)
        } else {
            remaining = nil
        }
        let currentName = currentIndex.map { plan.items[$0].sources.map(\.displayName).joined(separator: ", ") }
        return ConverterProgressSnapshot(
            phase: phase,
            currentItem: currentName,
            completedItems: completed,
            totalItems: plan.items.count,
            itemFraction: fraction,
            failedItems: failed,
            skippedItems: skipped,
            cancelledItems: cancelled,
            elapsed: elapsed,
            estimatedRemaining: remaining,
            itemStates: states
        )
    }

    private func commandCopiesVideo(_ arguments: [String]) -> Bool {
        for index in arguments.indices.dropLast() where arguments[index] == "-c:v" {
            if arguments[index + 1] == "copy" { return true }
        }
        return false
    }

    private func validateRecodedVideo(
        url: URL,
        options: ConverterOperationOptions,
        ffprobe: URL
    ) async throws {
        let probe = try await probeService.inspect(url: url, ffprobe: ffprobe)
        guard let codec = probe.videoStream?.codec_name?.lowercased() else {
            throw UniversalConverterError.invalidResult("No se ha podido confirmar el códec del vídeo convertido.")
        }
        let valid: Bool
        switch options.videoCodec {
        case .automatic, .h264:
            valid = codec == "h264"
        case .hevc:
            valid = codec == "hevc" || codec == "h265"
        case .proRes:
            valid = codec.hasPrefix("prores")
        }
        guard valid else {
            throw UniversalConverterError.invalidResult("La salida no utiliza el códec de vídeo solicitado; se detectó \(codec).")
        }
    }

    private func cleanProcessError(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "El motor terminó sin generar un resultado válido." : String(trimmed.suffix(4_000))
    }

    private func log(_ level: LogLevel, _ message: String, _ metadata: [String: String]) async {
        _ = try? await logger?.write(level, category: "universal-converter", message: message, metadata: metadata)
    }
}
