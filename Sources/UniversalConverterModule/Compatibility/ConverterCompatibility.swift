import Foundation

public enum ConverterEngineKind: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case exactCopy
    case imageIO
    case pdfKit
    case ffmpeg
    case pandoc

    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .exactCopy: return "Copia directa"
        case .imageIO: return "ImageIO"
        case .pdfKit: return "PDFKit"
        case .ffmpeg: return "FFmpeg"
        case .pandoc: return "Pandoc"
        }
    }
}

public struct ConverterEngineAvailability: Codable, Sendable, Equatable {
    public var ffmpeg: Bool
    public var imageIO: Bool
    public var pdfKit: Bool
    public var pandoc: Bool
    public var videoToolbox: Bool
    public var softwareH264: Bool
    public var webPEncoder: Bool

    public init(
        ffmpeg: Bool = false,
        imageIO: Bool = false,
        pdfKit: Bool = false,
        pandoc: Bool = false,
        videoToolbox: Bool = false,
        softwareH264: Bool = false,
        webPEncoder: Bool = false
    ) {
        self.ffmpeg = ffmpeg
        self.imageIO = imageIO
        self.pdfKit = pdfKit
        self.pandoc = pandoc
        self.videoToolbox = videoToolbox
        self.softwareH264 = softwareH264
        self.webPEncoder = webPEncoder
    }

    public static let logicalTestEnvironment = ConverterEngineAvailability(
        ffmpeg: true, imageIO: true, pdfKit: true,
        pandoc: true, videoToolbox: true,
        softwareH264: true, webPEncoder: true
    )

    public func isAvailable(_ engine: ConverterEngineKind) -> Bool {
        switch engine {
        case .exactCopy: return true
        case .imageIO: return imageIO
        case .pdfKit: return pdfKit
        case .ffmpeg: return ffmpeg
        case .pandoc: return pandoc
        }
    }
}

public enum ConverterLossRisk: String, Codable, Sendable, Equatable, Hashable {
    case none
    case metadata
    case generational
    case layout
    case vectorRasterization
    case unsupportedFeatures

    public var displayName: String {
        switch self {
        case .none: return "Sin pérdida prevista"
        case .metadata: return "Pueden perderse metadatos no compatibles"
        case .generational: return "Existe pérdida generacional"
        case .layout: return "Puede cambiar el diseño"
        case .vectorRasterization: return "Se perderá la naturaleza vectorial"
        case .unsupportedFeatures: return "Pueden perderse funciones del formato original"
        }
    }
}

public struct ConverterCompatibilityEntry: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let inputCategory: ConverterCategory
    public let inputFormat: ConverterFormat
    public let outputFormat: ConverterFormat
    public let operation: ConversionOperation
    public let engine: ConverterEngineKind
    public let codecsOrFilters: [String]
    public let supportedOptions: [String]
    public let limitations: [String]
    public let lossRisks: [ConverterLossRisk]
    public let requiresReencoding: Bool
    public let permitsDirectCopy: Bool

    public var id: String {
        [inputFormat.rawValue, outputFormat.rawValue, operation.rawValue, engine.rawValue].joined(separator: ":")
    }

    public init(
        inputFormat: ConverterFormat,
        outputFormat: ConverterFormat,
        operation: ConversionOperation = .convert,
        engine: ConverterEngineKind,
        codecsOrFilters: [String] = [],
        supportedOptions: [String] = [],
        limitations: [String] = [],
        lossRisks: [ConverterLossRisk] = [],
        requiresReencoding: Bool = true,
        permitsDirectCopy: Bool = false
    ) {
        self.inputCategory = inputFormat.category
        self.inputFormat = inputFormat
        self.outputFormat = outputFormat
        self.operation = operation
        self.engine = engine
        self.codecsOrFilters = codecsOrFilters
        self.supportedOptions = supportedOptions
        self.limitations = limitations
        self.lossRisks = lossRisks
        self.requiresReencoding = requiresReencoding
        self.permitsDirectCopy = permitsDirectCopy
    }
}

public struct ConverterCompatibilityRegistry: Sendable {
    public let availability: ConverterEngineAvailability
    public let entries: [ConverterCompatibilityEntry]

    public init(availability: ConverterEngineAvailability, entries: [ConverterCompatibilityEntry]? = nil) {
        self.availability = availability
        self.entries = entries ?? Self.makeEntries()
    }

    public func entry(from source: ConverterFormat, to target: ConverterFormat, operation: ConversionOperation = .convert) -> ConverterCompatibilityEntry? {
        entries.first {
            $0.inputFormat == source && $0.outputFormat == target && $0.operation == operation && availability.isAvailable($0.engine)
        }
    }

    public func supports(from source: ConverterFormat, to target: ConverterFormat, operation: ConversionOperation = .convert) -> Bool {
        if source == target, operation == .convert { return Self.supportsSameFormat(source) }
        return entry(from: source, to: target, operation: operation) != nil
    }

    public func outputFormats(for inputs: [ConverterFormat], operation: ConversionOperation = .convert) -> [ConverterFormat] {
        guard !inputs.isEmpty else { return [] }
        let sets = inputs.map { source in
            let availableTargets = Set(entries.lazy.filter {
                $0.inputFormat == source && $0.operation == operation && availability.isAvailable($0.engine)
            }.map(\.outputFormat))
            if operation == .convert, Self.supportsSameFormat(source) {
                return availableTargets.union([source])
            }
            return availableTargets
        }
        let common = sets.dropFirst().reduce(sets[0]) { $0.intersection($1) }
        return common.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    public func entries(for category: ConverterCategory) -> [ConverterCompatibilityEntry] {
        entries.filter { $0.inputCategory == category && availability.isAvailable($0.engine) }
    }

    public static func staticOutputFormats(for category: ConverterCategory) -> [ConverterFormat] {
        let all = ConverterCompatibilityRegistry(availability: .logicalTestEnvironment)
        return Array(Set(all.entries(for: category).map(\.outputFormat)))
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    private static func makeEntries() -> [ConverterCompatibilityEntry] {
        var values: [ConverterCompatibilityEntry] = []
        func addMatrix(_ sources: [ConverterFormat], _ targets: [ConverterFormat], engine: ConverterEngineKind, risks: [ConverterLossRisk] = [.generational], directCopy: Bool = false) {
            for source in sources { for target in targets where source != target {
                values.append(.init(inputFormat: source, outputFormat: target, engine: engine, lossRisks: risks, requiresReencoding: !directCopy, permitsDirectCopy: directCopy))
            }}
        }

        let raster: [ConverterFormat] = [.png, .jpeg, .heic, .tiff, .bmp]
        addMatrix(raster, raster, engine: .imageIO, risks: [.metadata, .generational])
        for source in raster {
            values.append(.init(inputFormat: source, outputFormat: .pdf, engine: .pdfKit, supportedOptions: ["DPI", "orden", "perfil de color"], lossRisks: [.metadata]))
        }

        let animations: [ConverterFormat] = [.gif, .webp, .apng]
        addMatrix(animations, animations, engine: .ffmpeg, risks: [.generational, .metadata])
        addMatrix(animations, [.mp4, .mov, .mkv, .webm], engine: .ffmpeg, risks: [.generational, .metadata])
        for source in [ConverterFormat.mp4, .mov, .mkv, .webm, .avi] {
            for target in animations {
                values.append(.init(inputFormat: source, outputFormat: target, operation: .videoToAnimation, engine: .ffmpeg, codecsOrFilters: ["fps", "scale", "palette"], supportedOptions: ["FPS", "duración", "bucle", "transparencia", "resolución"], lossRisks: [.generational]))
            }
        }

        let audio: [ConverterFormat] = [.mp3, .m4a, .aac, .flac, .wav, .opus, .ogg]
        addMatrix(audio, audio, engine: .ffmpeg, risks: [.metadata, .generational], directCopy: true)
        let video: [ConverterFormat] = [.mp4, .mov, .mkv, .webm, .avi]
        addMatrix(video, [.mp4, .mov, .mkv, .webm], engine: .ffmpeg, risks: [.metadata, .generational], directCopy: true)
        for source in video { for target in audio {
            values.append(.init(inputFormat: source, outputFormat: target, operation: .extractAudio, engine: .ffmpeg, supportedOptions: ["pista", "bitrate", "muestreo", "canales", "metadatos"], lossRisks: [.metadata, .generational], requiresReencoding: false, permitsDirectCopy: true))
        }}
        for source in audio { for target in [ConverterFormat.mp4, .mov, .mkv] {
            values.append(.init(inputFormat: source, outputFormat: target, operation: .audioToVideo, engine: .ffmpeg, supportedOptions: ["fondo", "imagen", "resolución", "FPS", "audio"], lossRisks: [.metadata], requiresReencoding: true, permitsDirectCopy: true))
        }}

        let markup: [ConverterFormat] = [.txt, .markdown, .html]
        addMatrix(markup, markup, engine: .pandoc, risks: [.layout, .metadata])

        for target in raster {
            values.append(.init(inputFormat: .pdf, outputFormat: target, operation: .pdfToImages, engine: .pdfKit, supportedOptions: ["DPI", "páginas", "fondo"], lossRisks: [.vectorRasterization, .metadata]))
        }
        values.append(.init(inputFormat: .pdf, outputFormat: .txt, operation: .pdfToText, engine: .pdfKit, lossRisks: [.layout]))
        return values
    }

    private static func supportsSameFormat(_ format: ConverterFormat) -> Bool {
        switch format {
        case .epub, .mobi, .azw3, .fb2, .eps, .zip, .unknown:
            return false
        default:
            return true
        }
    }
}
