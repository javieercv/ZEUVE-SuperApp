import Foundation

public actor ConversionPlanner {
    private let filenamePolicy: ConverterFilenamePolicy
    private let compatibility: ConverterCompatibilityRegistry
    private var cachedPlan: ConversionPlan?
    private var cachedKey: PlanCacheKey?

    public init(
        filenamePolicy: ConverterFilenamePolicy = ConverterFilenamePolicy(),
        compatibility: ConverterCompatibilityRegistry = .init(availability: .logicalTestEnvironment)
    ) {
        self.filenamePolicy = filenamePolicy
        self.compatibility = compatibility
    }

    public func plan(
        inputs: [ConverterInputItem],
        outputFolder: URL,
        options rawOptions: ConverterOperationOptions,
        revision: UInt64
    ) throws -> ConversionPlan {
        guard !inputs.isEmpty else { throw UniversalConverterError.noInput }
        guard outputFolder.isFileURL else { throw UniversalConverterError.outputFolderMissing }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: outputFolder.path, isDirectory: &isDirectory), isDirectory.boolValue,
              FileManager.default.isWritableFile(atPath: outputFolder.path) else {
            throw UniversalConverterError.outputFolderMissing
        }
        var options = rawOptions
        options.normalize()
        if options.filenameStyle == .suffix, options.conflictPolicy == .replaceConfirmed {
            options.conflictPolicy = .renameAutomatically
        }
        try validateBatch(inputs, operation: options.operation)
        let effectiveOutputFolder = try resolvedOutputFolder(base: outputFolder, options: options)
        let key = PlanCacheKey(inputs: inputs, outputFolder: effectiveOutputFolder, options: options)
        if let cachedPlan, cachedKey == key {
            return ConversionPlan(
                id: cachedPlan.id,
                revision: revision,
                createdAt: cachedPlan.createdAt,
                items: cachedPlan.items,
                outputFolder: effectiveOutputFolder,
                options: cachedPlan.options,
                warnings: cachedPlan.warnings,
                estimatedOutputBytes: cachedPlan.estimatedOutputBytes,
                availableOutputBytes: cachedPlan.availableOutputBytes,
                safetyMarginBytes: cachedPlan.safetyMarginBytes,
                containsArchiveEntries: cachedPlan.containsArchiveEntries
            )
        }

        let rawItems: [ConversionPlanItem]
        switch options.operation {
        case .imagesToPDF:
            rawItems = [try planImagesToPDF(inputs: inputs, options: options)]
        case .imagesToVideo:
            rawItems = [try planImagesToVideo(inputs: inputs, options: options)]
        default:
            rawItems = try inputs.map { try planSingle(input: $0, options: options) }
        }
        guard !rawItems.isEmpty else { throw UniversalConverterError.noInput }
        let items = try resolveDestinations(
            rawItems,
            inputs: inputs,
            outputFolder: effectiveOutputFolder,
            options: options
        )

        var warnings = Array(Set(items.flatMap(\.warnings))).sorted()
        warnings.append(contentsOf: inputs.compactMap { item in
            item.detection?.warning.map { "\(item.displayName): \($0)" }
        })
        let containsArchive = inputs.contains(where: \.isFromArchive)
        if containsArchive {
            warnings.append("Los archivos del ZIP se extraerán únicamente cuando llegue su turno y se conservará la estructura interna salvo que se elija aplanarla.")
        }
        if options.conflictPolicy == .replaceConfirmed {
            warnings.append("Los resultados existentes solo se reemplazarán después de la confirmación expresa de esta operación.")
        }
        let estimates = items.compactMap(\.estimatedOutputBytes)
        let totalEstimate: Int64? = estimates.count == items.count
            ? estimates.reduce(0) { partial, value in
                let addition = partial.addingReportingOverflow(value)
                return addition.overflow ? Int64.max : addition.partialValue
            }
            : nil

        let availableBytes = try? ConverterDiskSpaceChecker().availableBytes(at: outputFolder)
        let safetyMargin = totalEstimate.map { Int64((Double($0) * 0.15).rounded(.up)) }
        if let totalEstimate, let safetyMargin, let availableBytes,
           totalEstimate.addingReportingOverflow(safetyMargin).partialValue > availableBytes {
            warnings.append("El espacio disponible puede ser insuficiente para completar todos los resultados con el margen de seguridad.")
        }
        let result = ConversionPlan(
            revision: revision,
            items: items,
            outputFolder: effectiveOutputFolder,
            options: options,
            warnings: Array(Set(warnings)).sorted(),
            estimatedOutputBytes: totalEstimate,
            availableOutputBytes: availableBytes,
            safetyMarginBytes: safetyMargin,
            containsArchiveEntries: containsArchive
        )
        cachedKey = key
        cachedPlan = result
        return result
    }

    public func invalidate() {
        cachedKey = nil
        cachedPlan = nil
    }

    private func validateBatch(_ inputs: [ConverterInputItem], operation: ConversionOperation) throws {
        if operation == .imagesToPDF || operation == .imagesToVideo { return }
        let categories = Set(inputs.map(\.category))
        guard categories.count <= 1 else {
            throw UniversalConverterError.incompatibleRecipe("No pueden mezclarse categorías diferentes en una misma operación. Retira los archivos incompatibles antes de continuar.")
        }
    }

    private func planSingle(input: ConverterInputItem, options: ConverterOperationOptions) throws -> ConversionPlanItem {
        let target = try resolvedTarget(for: input, options: options)
        let execution = try executionKind(for: input, target: target, operation: options.operation, options: options)
        let destination = try destinationRelativePath(for: input, target: target, options: options)
        var warnings: [String] = []

        if input.format == target, options.operation == .convert {
            if execution == .copy {
                warnings.append("«\(input.displayName)» ya utiliza \(target.displayName); se realizará una copia directa porque la copia rápida está activada expresamente.")
            } else if input.category == .video {
                warnings.append("«\(input.displayName)» ya utiliza \(target.displayName), pero el vídeo se recodificará realmente con los ajustes elegidos.")
            } else {
                warnings.append("«\(input.displayName)» ya utiliza \(target.displayName); se generará un resultado nuevo con los ajustes elegidos.")
            }
        }
        if input.category == .animation, target.category != .animation {
            warnings.append("La animación se recodificará; pueden cambiar la paleta, la transparencia, el tiempo de los fotogramas o el bucle.")
        }
        if input.format == .tiff && target != .tiff && options.operation == .convert {
            warnings.append("Si el TIFF contiene varias páginas, se conservarán como imágenes independientes cuando el motor lo permita.")
        }
        if options.operation == .extractFrames {
            warnings.append("El formato elegido no recupera información eliminada por la compresión del vídeo original.")
        }
        if options.operation == .audioToVideo, options.audioVideoBackground == .image, options.audioVideoImageURL == nil {
            throw UniversalConverterError.incompatibleRecipe("Selecciona la imagen que debe mostrarse durante el audio.")
        }
        if input.category == .video, options.operation == .convert {
            let copyRequested = options.advancedMode
                && options.preferRemuxWhenPossible
                && options.videoCodec == .automatic
                && options.videoResolution == .original
                && options.videoFrameRate == .original
            if copyRequested {
                warnings.append("Copia rápida / remux solicitada: si las pistas son compatibles, no se recodificará el vídeo ni se reducirá su tamaño.")
            } else {
                let codecName: String
                switch options.videoCodec {
                case .automatic, .h264: codecName = "H.264"
                case .hevc: codecName = "HEVC"
                case .proRes: codecName = "Apple ProRes"
                }
                warnings.append("Conversión real: la pista de vídeo se recodificará con \(codecName).")
            }
            if options.videoCodec == .proRes, target != .mov, target != .mkv {
                throw UniversalConverterError.incompatibleRecipe("Apple ProRes requiere salida MOV o MKV.")
            }
            if target == .webm, options.videoAudioMode == .aac {
                throw UniversalConverterError.incompatibleRecipe("WebM no admite AAC. Conserva una pista compatible o utiliza MP4, MOV o MKV.")
            }
        }
        if let entry = compatibility.entry(from: input.format, to: target, operation: options.operation) {
            warnings.append(contentsOf: entry.lossRisks.filter { $0 != .none }.map(\.displayName))
            warnings.append(contentsOf: entry.limitations)
        }

        return ConversionPlanItem(
            sources: [input],
            operation: options.operation,
            targetFormat: target,
            executionKind: execution,
            destinationRelativePath: destination,
            estimatedOutputBytes: estimate(input: input, operation: options.operation, target: target, quality: options.quality),
            warnings: Array(Set(warnings)).sorted()
        )
    }

    private func planImagesToPDF(inputs: [ConverterInputItem], options: ConverterOperationOptions) throws -> ConversionPlanItem {
        guard inputs.allSatisfy({ $0.category == .image }) else {
            throw UniversalConverterError.incompatibleRecipe("Para crear un PDF, todas las entradas deben ser imágenes rasterizadas.")
        }
        return try groupedImagePlan(inputs: inputs, options: options, operation: .imagesToPDF, target: .pdf, execution: .nativeImagesToPDF, suffix: "PDF")
    }

    private func planImagesToVideo(inputs: [ConverterInputItem], options: ConverterOperationOptions) throws -> ConversionPlanItem {
        guard inputs.allSatisfy({ $0.category == .image }) else {
            throw UniversalConverterError.incompatibleRecipe("Para crear un vídeo, todas las entradas deben ser imágenes rasterizadas.")
        }
        let target = options.targetFormat?.category == .video ? options.targetFormat! : .mp4
        return try groupedImagePlan(inputs: inputs, options: options, operation: .imagesToVideo, target: target, execution: .ffmpeg, suffix: "Vídeo")
    }

    private func groupedImagePlan(
        inputs: [ConverterInputItem],
        options: ConverterOperationOptions,
        operation: ConversionOperation,
        target: ConverterFormat,
        execution: ConverterExecutionKind,
        suffix: String
    ) throws -> ConversionPlanItem {
        let rootNames = Set(inputs.map(\.sourceRootName))
        let rawBase = rootNames.count == 1 ? (rootNames.first ?? "Imágenes") : "Imágenes"
        let base = try filenamePolicy.convertedBaseName(
            for: rawBase, style: options.filenameStyle,
            prefix: options.filenamePrefix, suffix: options.filenameSuffix, separator: options.filenameSeparator
        )
        let destination = "\(base) - \(suffix).\(target.fileExtension)"
        let total = inputs.reduce(Int64(0)) { partial, item in
            let addition = partial.addingReportingOverflow(item.size)
            return addition.overflow ? Int64.max : addition.partialValue
        }
        return ConversionPlanItem(
            sources: inputs.sorted { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending },
            operation: operation,
            targetFormat: target,
            executionKind: execution,
            destinationRelativePath: destination,
            estimatedOutputBytes: total,
            warnings: ["Revisa el orden natural de la secuencia en la vista previa antes de convertir."]
        )
    }

    private func resolvedTarget(for input: ConverterInputItem, options: ConverterOperationOptions) throws -> ConverterFormat {
        switch options.operation {
        case .extractFrames:
            guard input.category == .video else { throw UniversalConverterError.unsupportedFormat(input.displayName) }
            return options.frameFormat.converterFormat
        case .extractAudio:
            guard input.category == .video else { throw UniversalConverterError.unsupportedFormat(input.displayName) }
            let target = options.targetFormat ?? .m4a
            guard target.category == .audio else { throw UniversalConverterError.incompatibleRecipe("Elige un formato de audio para la extracción.") }
            return target
        case .audioToVideo:
            guard input.category == .audio else { throw UniversalConverterError.unsupportedFormat(input.displayName) }
            return options.targetFormat?.category == .video ? options.targetFormat! : .mp4
        case .pdfToImages:
            guard input.format == .pdf else { throw UniversalConverterError.unsupportedFormat(input.displayName) }
            let target = options.targetFormat ?? .png
            guard [.png, .jpeg, .tiff, .webp].contains(target) else { throw UniversalConverterError.incompatibleRecipe("PDF a imágenes admite PNG, JPG, TIFF o WebP cuando el motor esté disponible.") }
            return target
        case .pdfToText:
            guard input.format == .pdf else { throw UniversalConverterError.unsupportedFormat(input.displayName) }
            return .txt
        case .imagesToPDF:
            return .pdf
        case .imagesToVideo:
            return options.targetFormat?.category == .video ? options.targetFormat! : .mp4
        case .animationToVideo:
            guard input.category == .animation else { throw UniversalConverterError.unsupportedFormat(input.displayName) }
            return options.targetFormat?.category == .video ? options.targetFormat! : .mp4
        case .videoToAnimation:
            guard input.category == .video else { throw UniversalConverterError.unsupportedFormat(input.displayName) }
            let target = options.targetFormat ?? .gif
            guard target.category == .animation else { throw UniversalConverterError.incompatibleRecipe("Elige GIF, WebP animado o APNG.") }
            return target
        case .convert:
            guard let target = options.targetFormat, target != .unknown, target != .zip else {
                throw UniversalConverterError.incompatibleRecipe("Selecciona un formato de salida.")
            }
            guard isCompatibleConversion(from: input.format, to: target) else {
                throw UniversalConverterError.incompatibleRecipe("No se puede convertir \(input.format.displayName) a \(target.displayName) con los motores aprobados.")
            }
            return target
        }
    }

    private func isCompatibleConversion(from source: ConverterFormat, to target: ConverterFormat) -> Bool {
        compatibility.supports(from: source, to: target)
    }

    private func canUseExactCopy(input: ConverterInputItem, target: ConverterFormat, operation: ConversionOperation, options: ConverterOperationOptions) -> Bool {
        guard operation == .convert, input.format == target, options.preserveMetadata else { return false }
        switch input.category {
        case .image: return options.imageResizeMode == .original
        case .audio:
            return options.audioBitrate == .automatic && options.audioSampleRate == .automatic && options.audioChannels == .automatic && !options.normalizeAudio && options.preserveCoverArt
        case .video:
            return options.advancedMode
                && options.preferRemuxWhenPossible
                && options.videoCodec == .automatic
                && options.videoResolution == .original
                && options.videoFrameRate == .original
                && options.videoAudioMode == .preserve
                && options.preserveSubtitles
                && options.preserveChapters
        case .text, .markup, .ebook, .data, .vectorImage, .animation:
            return true
        case .pdf, .archive, .unknown:
            return true
        }
    }

    private func executionKind(for input: ConverterInputItem, target: ConverterFormat, operation: ConversionOperation, options: ConverterOperationOptions) throws -> ConverterExecutionKind {
        if canUseExactCopy(input: input, target: target, operation: operation, options: options) { return .copy }
        switch operation {
        case .pdfToImages: return .nativePDFToImages
        case .pdfToText: return .nativePDFToText
        case .imagesToPDF: return .nativeImagesToPDF
        case .extractFrames, .extractAudio, .audioToVideo, .imagesToVideo, .animationToVideo, .videoToAnimation: return .ffmpeg
        case .convert:
            if input.format == target {
                switch input.category {
                case .image: return .nativeImage
                case .animation, .audio, .video: return .ffmpeg
                case .text, .markup: return .pandoc
                case .ebook: return .calibre
                case .vectorImage, .data: return .copy
                case .pdf: return .copy
                case .archive, .unknown: throw UniversalConverterError.unsupportedFormat(input.displayName)
                }
            }
            guard let entry = compatibility.entry(from: input.format, to: target) else { throw UniversalConverterError.unsupportedFormat(input.displayName) }
            switch entry.engine {
            case .exactCopy: return .copy
            case .imageIO: return .nativeImage
            case .pdfKit: return target == .pdf ? .nativeImagesToPDF : .nativePDFToImages
            case .ffmpeg: return .ffmpeg
            case .pandoc: return .pandoc
            case .calibre: return .calibre
            case .ghostscript: return .ghostscript
            }
        }
    }

    private func destinationRelativePath(for input: ConverterInputItem, target: ConverterFormat, options: ConverterOperationOptions) throws -> String {
        let sourceRelative = try ConverterSafePath.normalize(input.relativePath)
        let components = sourceRelative.split(separator: "/", omittingEmptySubsequences: true)
        guard let filename = components.last else { throw UniversalConverterError.unsafePath(sourceRelative) }
        let sourceURL = URL(fileURLWithPath: String(filename))
        let parentRaw = components.dropLast().joined(separator: "/")
        let parent = options.zipStructureMode == .flatten ? "" : (parentRaw.isEmpty ? "" : try filenamePolicy.safeRelativeDirectory(parentRaw))
        let rootPrefix: String
        if options.zipStructureMode == .preserve, input.isFromArchive || sourceRelative.contains("/") {
            rootPrefix = try filenamePolicy.sanitize("\(input.sourceRootName) - Converted")
        } else { rootPrefix = "" }
        let directory = [rootPrefix, parent].filter { !$0.isEmpty }.joined(separator: "/")
        let base = sourceURL.deletingPathExtension().lastPathComponent
        let name: String
        switch options.operation {
        case .extractFrames: name = try filenamePolicy.sanitize("\(base) - Fotogramas")
        case .pdfToImages: name = try filenamePolicy.sanitize("\(base) - Páginas")
        default: name = try filenamePolicy.convertedFilename(
                sourceName: input.displayName, targetFormat: target, style: options.filenameStyle,
                prefix: options.filenamePrefix, suffix: options.filenameSuffix, separator: options.filenameSeparator
            )
        }
        return [directory, name].filter { !$0.isEmpty }.joined(separator: "/")
    }

    private func resolvedOutputFolder(base: URL, options: ConverterOperationOptions) throws -> URL {
        let root = base.standardizedFileURL
        guard root.isFileURL else { throw UniversalConverterError.outputFolderMissing }
        guard options.outputFolderMode == .subfolder else { return root }
        let name = try filenamePolicy.sanitize(options.outputSubfolderName, maximumUTF8Bytes: 120)
        let child = root.appendingPathComponent(name, isDirectory: true).standardizedFileURL
        guard ConverterSafePath.isInside(child, root: root) else { throw UniversalConverterError.unsafePath(name) }
        return child
    }

    private func resolveDestinations(
        _ items: [ConversionPlanItem],
        inputs: [ConverterInputItem],
        outputFolder: URL,
        options: ConverterOperationOptions,
        fileManager: FileManager = .default
    ) throws -> [ConversionPlanItem] {
        let protected = Set(inputs.map { $0.sourceURL.standardizedFileURL.resolvingSymlinksInPath().path })
        var reserved = Set<String>()
        var result: [ConversionPlanItem] = []
        for item in items {
            var relative = try ConverterSafePath.normalize(item.destinationRelativePath)
            var candidate = outputFolder.appendingPathComponent(relative).standardizedFileURL
            let mustRename = protected.contains(candidate.resolvingSymlinksInPath().path)
                || reserved.contains(candidate.path)
                || (options.conflictPolicy == .renameAutomatically && fileManager.fileExists(atPath: candidate.path))
            var warnings = item.warnings
            if mustRename {
                let directory = URL(fileURLWithPath: relative).deletingLastPathComponent().relativePath
                let filename = URL(fileURLWithPath: relative).lastPathComponent
                let renamed = try nextFreeName(filename: filename, directory: directory == "." ? "" : directory, outputFolder: outputFolder, protected: protected, reserved: reserved, fileManager: fileManager)
                relative = renamed
                candidate = outputFolder.appendingPathComponent(relative).standardizedFileURL
                warnings.append("El nombre de salida se ha ajustado para evitar una colisión: \(candidate.lastPathComponent).")
            } else if fileManager.fileExists(atPath: candidate.path) {
                if options.conflictPolicy == .replaceConfirmed {
                    warnings.append("Se reemplazará atómicamente el resultado existente: \(candidate.lastPathComponent).")
                } else if options.conflictPolicy == .skip {
                    warnings.append("El resultado existente se omitirá: \(candidate.lastPathComponent).")
                }
            }
            reserved.insert(candidate.path)
            result.append(ConversionPlanItem(
                id: item.id,
                sources: item.sources,
                operation: item.operation,
                targetFormat: item.targetFormat,
                executionKind: item.executionKind,
                destinationRelativePath: relative,
                estimatedOutputBytes: item.estimatedOutputBytes,
                warnings: Array(Set(warnings)).sorted()
            ))
        }
        return result
    }

    private func nextFreeName(
        filename: String,
        directory: String,
        outputFolder: URL,
        protected: Set<String>,
        reserved: Set<String>,
        fileManager: FileManager
    ) throws -> String {
        let source = URL(fileURLWithPath: filename)
        let ext = source.pathExtension
        var base = source.deletingPathExtension().lastPathComponent
        if !base.localizedCaseInsensitiveContains("converted") { base += " - converted" }
        for number in 1...100_000 {
            let stem = number == 1 ? base : "\(base) \(number)"
            let name = try filenamePolicy.sanitize(ext.isEmpty ? stem : "\(stem).\(ext)")
            let relative = [directory, name].filter { !$0.isEmpty }.joined(separator: "/")
            let candidate = outputFolder.appendingPathComponent(relative).standardizedFileURL
            if !fileManager.fileExists(atPath: candidate.path),
               !reserved.contains(candidate.path),
               !protected.contains(candidate.resolvingSymlinksInPath().path) {
                return relative
            }
        }
        throw UniversalConverterError.outputConflict(filename)
    }

    private func estimate(input: ConverterInputItem, operation: ConversionOperation, target: ConverterFormat, quality: ConverterQualityProfile) -> Int64? {
        let source = max(input.size, 1)
        let multiplier: Double
        switch operation {
        case .extractFrames: multiplier = target == .tiff ? 35 : 25
        case .pdfToImages: multiplier = target == .png ? 8 : 3
        case .pdfToText: multiplier = 0.2
        case .audioToVideo, .imagesToVideo: multiplier = quality == .low ? 1.5 : 3
        case .extractAudio: multiplier = 0.3
        case .imagesToPDF: multiplier = 1.1
        case .animationToVideo, .videoToAnimation: multiplier = quality == .low ? 0.6 : 1.2
        case .convert:
            switch target.category {
            case .image, .animation: multiplier = quality == .low ? 0.6 : (target == .png || target == .tiff ? 2.5 : 1.1)
            case .audio: multiplier = target == .wav ? 5 : (target == .flac ? 2 : 1)
            case .video: multiplier = quality == .low ? 0.7 : 1.3
            case .pdf, .text, .markup, .ebook, .data, .vectorImage: multiplier = 1.5
            case .archive, .unknown: return nil
            }
        }
        let value = Double(source) * multiplier
        return value.isFinite && value < Double(Int64.max) ? Int64(value.rounded(.up)) : nil
    }
}

private struct PlanCacheKey: Equatable, Sendable {
    let inputIdentities: [InputIdentity]
    let outputPath: String
    let options: ConverterOperationOptions
    init(inputs: [ConverterInputItem], outputFolder: URL, options: ConverterOperationOptions) {
        inputIdentities = inputs.map(InputIdentity.init)
        outputPath = outputFolder.standardizedFileURL.path
        self.options = options
    }
}

private struct InputIdentity: Equatable, Sendable {
    let path: String
    let archiveEntryPath: String?
    let size: Int64
    let modificationTimeNanoseconds: Int64
    let format: ConverterFormat
    init(_ item: ConverterInputItem) {
        path = item.sourceURL.path
        archiveEntryPath = item.archiveEntryPath
        size = item.fingerprint.size
        modificationTimeNanoseconds = item.fingerprint.modificationTimeNanoseconds
        format = item.format
    }
}
