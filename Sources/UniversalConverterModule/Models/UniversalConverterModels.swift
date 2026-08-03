import Foundation
import ZEUVECore

public let universalConverterModuleIdentifier = "com.zeuve.universal-converter"

public enum ConverterCategory: String, Codable, CaseIterable, Sendable, Hashable {
    case image
    case vectorImage
    case animation
    case audio
    case video
    case pdf
    case text
    case markup
    case ebook
    case data
    case archive
    case unknown

    public var displayName: String {
        switch self {
        case .image: return "Imagen rasterizada"
        case .vectorImage: return "Imagen vectorial"
        case .animation: return "Animación"
        case .audio: return "Audio"
        case .video: return "Vídeo"
        case .pdf: return "PDF"
        case .text: return "Texto"
        case .markup: return "Texto y marcado"
        case .ebook: return "Libro electrónico"
        case .data: return "Datos"
        case .archive: return "Archivo comprimido"
        case .unknown: return "Desconocido"
        }
    }

    public var acceptsMixedInputFormats: Bool {
        self != .unknown && self != .archive
    }
}

public enum ConverterFormat: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case png, jpeg, heic, webp, tiff, bmp, gif, apng
    case svg, eps
    case mp3, m4a, aac, flac, wav, opus, ogg
    case mp4, mov, mkv, webm, avi
    case pdf
    case txt, markdown, html, csv, json, xml
    case epub, mobi, azw3, fb2
    case zip
    case unknown

    public var id: String { rawValue }

    public var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .markdown: return "md"
        default: return rawValue
        }
    }

    public var displayName: String {
        switch self {
        case .jpeg: return "JPG / JPEG"
        case .heic: return "HEIC / HEIF"
        case .m4a: return "M4A"
        case .aac: return "AAC"
        case .apng: return "APNG"
        case .svg: return "SVG"
        case .eps: return "EPS"
        case .pdf: return "PDF"
        case .txt: return "Texto (.txt)"
        case .markdown: return "Markdown (.md)"
        case .html: return "HTML"
        case .csv: return "CSV"
        case .json: return "JSON"
        case .xml: return "XML"
        case .epub: return "EPUB"
        case .mobi: return "MOBI"
        case .azw3: return "AZW3"
        case .fb2: return "FB2"
        case .unknown: return "Formato desconocido"
        default: return rawValue.uppercased()
        }
    }

    public var category: ConverterCategory {
        switch self {
        case .png, .jpeg, .heic, .tiff, .bmp: return .image
        case .gif, .apng, .webp: return .animation
        case .svg, .eps: return .vectorImage
        case .mp3, .m4a, .aac, .flac, .wav, .opus, .ogg: return .audio
        case .mp4, .mov, .mkv, .webm, .avi: return .video
        case .pdf: return .pdf
        case .txt: return .text
        case .markdown, .html: return .markup
        case .epub, .mobi, .azw3, .fb2: return .ebook
        case .csv, .json, .xml: return .data
        case .zip: return .archive
        case .unknown: return .unknown
        }
    }


    public var isZIPContainer: Bool {
        switch self {
        case .zip, .epub: return true
        default: return false
        }
    }

    public static func from(pathExtension rawExtension: String) -> ConverterFormat {
        switch rawExtension.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")) {
        case "png": return .png
        case "jpg", "jpeg", "jpe": return .jpeg
        case "heic", "heif": return .heic
        case "webp": return .webp
        case "tif", "tiff": return .tiff
        case "bmp", "dib": return .bmp
        case "gif": return .gif
        case "apng": return .apng
        case "svg", "svgz": return .svg
        case "eps", "epsf", "epsi": return .eps
        case "mp3": return .mp3
        case "m4a", "m4b": return .m4a
        case "aac": return .aac
        case "flac": return .flac
        case "wav", "wave": return .wav
        case "opus": return .opus
        case "ogg", "oga": return .ogg
        case "mp4", "m4v": return .mp4
        case "mov", "qt": return .mov
        case "mkv": return .mkv
        case "webm": return .webm
        case "avi": return .avi
        case "pdf": return .pdf
        case "txt", "log": return .txt
        case "md", "markdown", "mdown", "mkd": return .markdown
        case "html", "htm", "xhtml": return .html
        case "csv", "tsv": return .csv
        case "json": return .json
        case "xml": return .xml
        case "epub": return .epub
        case "mobi": return .mobi
        case "azw", "azw3": return .azw3
        case "fb2": return .fb2
        case "zip": return .zip
        default: return .unknown
        }
    }

    public static func outputFormats(for category: ConverterCategory) -> [ConverterFormat] {
        ConverterCompatibilityRegistry.staticOutputFormats(for: category)
    }
}

public enum ConverterDetectionConfidence: String, Codable, Sendable, Equatable, Hashable {
    case certain, high, medium, low, unknown
}

public enum ConverterDetectionEvidence: String, Codable, Sendable, Equatable, Hashable {
    case extensionValue, uniformType, mime, signature, containerStructure, mediaProbe, textInspection
}

public struct ConverterFormatDetection: Codable, Sendable, Equatable, Hashable {
    public let extensionFormat: ConverterFormat
    public let detectedFormat: ConverterFormat
    public let confidence: ConverterDetectionConfidence
    public let evidence: [ConverterDetectionEvidence]
    public let uniformTypeIdentifier: String?
    public let mimeType: String?
    public let warning: String?

    public init(extensionFormat: ConverterFormat, detectedFormat: ConverterFormat, confidence: ConverterDetectionConfidence, evidence: [ConverterDetectionEvidence], uniformTypeIdentifier: String? = nil, mimeType: String? = nil, warning: String? = nil) {
        self.extensionFormat = extensionFormat
        self.detectedFormat = detectedFormat
        self.confidence = confidence
        self.evidence = evidence
        self.uniformTypeIdentifier = uniformTypeIdentifier
        self.mimeType = mimeType
        self.warning = warning
    }

    public var hasMismatch: Bool {
        extensionFormat != .unknown && detectedFormat != .unknown && extensionFormat != detectedFormat
    }

    public var isReliable: Bool {
        detectedFormat != .unknown && confidence != .low && confidence != .unknown
    }
}

public enum ConversionOperation: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case convert
    case extractFrames
    case extractAudio
    case audioToVideo
    case pdfToImages
    case pdfToText
    case imagesToPDF
    case imagesToVideo
    case animationToVideo
    case videoToAnimation

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .convert: return "Convertir formato"
        case .extractFrames: return "Extraer todos los fotogramas"
        case .extractAudio: return "Extraer el audio"
        case .audioToVideo: return "Crear vídeo desde audio"
        case .pdfToImages: return "Convertir páginas de PDF en imágenes"
        case .pdfToText: return "Extraer texto del PDF"
        case .imagesToPDF: return "Crear un PDF con imágenes"
        case .imagesToVideo: return "Crear vídeo desde una secuencia de imágenes"
        case .animationToVideo: return "Convertir animación en vídeo"
        case .videoToAnimation: return "Convertir vídeo en animación"
        }
    }
}

public enum ConverterQualityProfile: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case low
    case medium
    case high
    case maximum
    case custom

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case Self.low.rawValue, "compact": self = .low
        case Self.medium.rawValue, "balanced": self = .medium
        case Self.high.rawValue: self = .high
        case Self.maximum.rawValue: self = .maximum
        case Self.custom.rawValue: self = .custom
        default:
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Perfil de calidad desconocido: \(value)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .low: return "Bajo"
        case .medium: return "Medio"
        case .high: return "Alto"
        case .maximum: return "Máxima calidad"
        case .custom: return "Personalizado"
        }
    }
}

public enum ConverterConflictPolicy: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case renameAutomatically
    case skip
    case replaceConfirmed

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .renameAutomatically: return "Renombrar automáticamente"
        case .skip: return "Omitir"
        case .replaceConfirmed: return "Reemplazar con confirmación"
        }
    }
}

public enum ConverterFilenameStyle: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case suffix
    case prefix

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .suffix: return "Añadir sufijo"
        case .prefix: return "Añadir «ZEUVE - Converted - »"
        }
    }
}

public enum ConverterFrameFormat: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case png, jpeg, tiff, webp
    public var id: String { rawValue }
    public var displayName: String { rawValue == "jpeg" ? "JPG" : rawValue.uppercased() }
    public var converterFormat: ConverterFormat {
        switch self { case .png: return .png; case .jpeg: return .jpeg; case .tiff: return .tiff; case .webp: return .webp }
    }
}

public enum ConverterVideoCanvas: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case horizontal1080
    case vertical1080
    case square1080
    case custom

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .horizontal1080: return "Horizontal 1920 × 1080"
        case .vertical1080: return "Vertical 1080 × 1920"
        case .square1080: return "Cuadrado 1080 × 1080"
        case .custom: return "Personalizada"
        }
    }

    public var dimensions: (width: Int, height: Int)? {
        switch self {
        case .horizontal1080: return (1_920, 1_080)
        case .vertical1080: return (1_080, 1_920)
        case .square1080: return (1_080, 1_080)
        case .custom: return nil
        }
    }
}

public enum ConverterImageFit: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case fit
    case fill
    case stretch

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .fit: return "Mostrar completa"
        case .fill: return "Rellenar recortando"
        case .stretch: return "Estirar"
        }
    }
}

public enum ConverterAudioVideoBackground: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case black
    case image

    public var id: String { rawValue }
    public var displayName: String { self == .black ? "Fondo negro" : "Imagen seleccionada" }
}

public enum ConverterMetadataPolicy: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case allCompatible
    case essentialOnly
    case removeAll
    public var id: String { rawValue }
    public var displayName: String {
        switch self { case .allCompatible: return "Conservar todos los compatibles"; case .essentialOnly: return "Conservar solo los esenciales"; case .removeAll: return "Eliminar metadatos" }
    }
}

public enum ConverterOutputFolderMode: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case direct
    case subfolder
    public var id: String { rawValue }
    public var displayName: String { self == .direct ? "Guardar directamente" : "Crear una subcarpeta" }
}

public enum ConverterZIPStructureMode: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case preserve
    case flatten
    public var id: String { rawValue }
    public var displayName: String { self == .preserve ? "Conservar estructura" : "Aplanar en una carpeta" }
}

public enum ConverterParallelismMode: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case automatic
    case manual
    public var id: String { rawValue }
    public var displayName: String { self == .automatic ? "Automático" : "Manual" }
}

public enum ConverterAccelerationMode: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case automatic
    case software
    case hardware
    public var id: String { rawValue }
    public var displayName: String {
        switch self { case .automatic: return "Automático"; case .software: return "Codificación por software"; case .hardware: return "Aceleración por hardware" }
    }
}

public enum ConverterSequenceOrder: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case name
    case natural
    case manual
    public var id: String { rawValue }
    public var displayName: String { switch self { case .name: return "Nombre"; case .natural: return "Numeración natural"; case .manual: return "Orden manual" } }
}

public enum ConverterImageResizeMode: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case original
    case percentage
    case dimensions
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .original: return "Tamaño original"
        case .percentage: return "Porcentaje"
        case .dimensions: return "Dimensiones máximas"
        }
    }
}

public enum ConverterAudioBitrate: Int, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case automatic = 0
    case kbps128 = 128
    case kbps192 = 192
    case kbps256 = 256
    case kbps320 = 320
    public var id: Int { rawValue }
    public var displayName: String { self == .automatic ? "Automático" : "\(rawValue) kbps" }
}

public enum ConverterAudioSampleRate: Int, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case automatic = 0
    case hz44100 = 44_100
    case hz48000 = 48_000
    case hz96000 = 96_000
    public var id: Int { rawValue }
    public var displayName: String { self == .automatic ? "Original / automático" : "\(rawValue / 1_000) kHz" }
}

public enum ConverterAudioChannels: Int, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case automatic = 0
    case mono = 1
    case stereo = 2
    public var id: Int { rawValue }
    public var displayName: String {
        switch self { case .automatic: return "Original / automático"; case .mono: return "Mono"; case .stereo: return "Estéreo" }
    }
}

public enum ConverterVideoCodec: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case automatic
    case h264
    case hevc
    case proRes
    public var id: String { rawValue }
    public var displayName: String {
        switch self { case .automatic: return "Automático"; case .h264: return "H.264"; case .hevc: return "HEVC / H.265"; case .proRes: return "Apple ProRes" }
    }
}

public enum ConverterVideoResolution: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case original
    case hd720
    case fullHD1080
    case uhd4K
    case custom
    public var id: String { rawValue }
    public var displayName: String {
        switch self { case .original: return "Original"; case .hd720: return "Hasta 1280 × 720"; case .fullHD1080: return "Hasta 1920 × 1080"; case .uhd4K: return "Hasta 3840 × 2160"; case .custom: return "Personalizada" }
    }
    public var dimensions: (Int, Int)? {
        switch self { case .hd720: return (1280, 720); case .fullHD1080: return (1920, 1080); case .uhd4K: return (3840, 2160); case .original, .custom: return nil }
    }
}

public enum ConverterVideoFrameRate: Int, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case original = 0
    case fps24 = 24
    case fps25 = 25
    case fps30 = 30
    case fps50 = 50
    case fps60 = 60
    public var id: Int { rawValue }
    public var displayName: String { self == .original ? "Original" : "\(rawValue) fps" }
}

public enum ConverterVideoAudioMode: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case preserve
    case aac
    case remove
    public var id: String { rawValue }
    public var displayName: String {
        switch self { case .preserve: return "Conservar si es compatible"; case .aac: return "Convertir a AAC"; case .remove: return "Eliminar audio" }
    }
}

public struct UniversalConverterSettings: Codable, Sendable, Equatable {
    public var defaultAdvancedMode: Bool
    public var quality: ConverterQualityProfile
    public var conflictPolicy: ConverterConflictPolicy
    public var filenameStyle: ConverterFilenameStyle
    public var preserveMetadata: Bool
    public var preserveDates: Bool
    public var avoidUpscaling: Bool
    public var preferRemuxWhenPossible: Bool
    public var frameFormat: ConverterFrameFormat
    public var automaticHighBitDepthFrames: Bool
    public var createFrameTimingCSV: Bool
    public var audioVideoCanvas: ConverterVideoCanvas
    public var audioVideoWidth: Int
    public var audioVideoHeight: Int
    public var audioVideoFPS: Int
    public var audioVideoFit: ConverterImageFit
    public var recompressZIPResults: Bool
    public var pdfRasterDPI: Int
    public var imageResizeMode: ConverterImageResizeMode
    public var imageResizePercentage: Int
    public var imageMaximumWidth: Int
    public var imageMaximumHeight: Int
    public var imageMaintainAspectRatio: Bool
    public var audioBitrate: ConverterAudioBitrate
    public var audioSampleRate: ConverterAudioSampleRate
    public var audioChannels: ConverterAudioChannels
    public var normalizeAudio: Bool
    public var preserveCoverArt: Bool
    public var videoCodec: ConverterVideoCodec
    public var videoResolution: ConverterVideoResolution
    public var videoWidth: Int
    public var videoHeight: Int
    public var videoFrameRate: ConverterVideoFrameRate
    public var videoAudioMode: ConverterVideoAudioMode
    public var preserveSubtitles: Bool
    public var preserveChapters: Bool
    public var metadataPolicy: ConverterMetadataPolicy
    public var outputFolderMode: ConverterOutputFolderMode
    public var outputSubfolderName: String
    public var filenamePrefix: String
    public var filenameSuffix: String
    public var filenameSeparator: String
    public var zipStructureMode: ConverterZIPStructureMode
    public var parallelismMode: ConverterParallelismMode
    public var manualParallelism: Int
    public var accelerationMode: ConverterAccelerationMode
    public var rememberOutputFolder: Bool
    public var saveOutputPathsInHistory: Bool
    public var cleanupTemporaryMaximumAgeDays: Int
    public var archiveLimits: ConverterArchiveLimits

    public init(
        defaultAdvancedMode: Bool = false,
        quality: ConverterQualityProfile = .maximum,
        conflictPolicy: ConverterConflictPolicy = .renameAutomatically,
        filenameStyle: ConverterFilenameStyle = .prefix,
        preserveMetadata: Bool = true,
        preserveDates: Bool = true,
        avoidUpscaling: Bool = true,
        preferRemuxWhenPossible: Bool = false,
        frameFormat: ConverterFrameFormat = .png,
        automaticHighBitDepthFrames: Bool = true,
        createFrameTimingCSV: Bool = true,
        audioVideoCanvas: ConverterVideoCanvas = .horizontal1080,
        audioVideoWidth: Int = 1_920,
        audioVideoHeight: Int = 1_080,
        audioVideoFPS: Int = 30,
        audioVideoFit: ConverterImageFit = .fit,
        recompressZIPResults: Bool = false,
        pdfRasterDPI: Int = 300,
        imageResizeMode: ConverterImageResizeMode = .original,
        imageResizePercentage: Int = 100,
        imageMaximumWidth: Int = 1_920,
        imageMaximumHeight: Int = 1_080,
        imageMaintainAspectRatio: Bool = true,
        audioBitrate: ConverterAudioBitrate = .automatic,
        audioSampleRate: ConverterAudioSampleRate = .automatic,
        audioChannels: ConverterAudioChannels = .automatic,
        normalizeAudio: Bool = false,
        preserveCoverArt: Bool = true,
        videoCodec: ConverterVideoCodec = .automatic,
        videoResolution: ConverterVideoResolution = .original,
        videoWidth: Int = 1_920,
        videoHeight: Int = 1_080,
        videoFrameRate: ConverterVideoFrameRate = .original,
        videoAudioMode: ConverterVideoAudioMode = .preserve,
        preserveSubtitles: Bool = true,
        preserveChapters: Bool = true,
        metadataPolicy: ConverterMetadataPolicy = .allCompatible,
        outputFolderMode: ConverterOutputFolderMode = .subfolder,
        outputSubfolderName: String = "ZEUVE Converted",
        filenamePrefix: String = "ZEUVE - Converted - ",
        filenameSuffix: String = "",
        filenameSeparator: String = " - ",
        zipStructureMode: ConverterZIPStructureMode = .preserve,
        parallelismMode: ConverterParallelismMode = .automatic,
        manualParallelism: Int = 2,
        accelerationMode: ConverterAccelerationMode = .automatic,
        rememberOutputFolder: Bool = false,
        saveOutputPathsInHistory: Bool = false,
        cleanupTemporaryMaximumAgeDays: Int = 7,
        archiveLimits: ConverterArchiveLimits = ConverterArchiveLimits()
    ) {
        self.defaultAdvancedMode = defaultAdvancedMode
        self.quality = quality
        self.conflictPolicy = conflictPolicy
        self.filenameStyle = filenameStyle
        self.preserveMetadata = preserveMetadata
        self.preserveDates = preserveDates
        self.avoidUpscaling = avoidUpscaling
        self.preferRemuxWhenPossible = preferRemuxWhenPossible
        self.frameFormat = frameFormat
        self.automaticHighBitDepthFrames = automaticHighBitDepthFrames
        self.createFrameTimingCSV = createFrameTimingCSV
        self.audioVideoCanvas = audioVideoCanvas
        self.audioVideoWidth = audioVideoWidth
        self.audioVideoHeight = audioVideoHeight
        self.audioVideoFPS = audioVideoFPS
        self.audioVideoFit = audioVideoFit
        self.recompressZIPResults = recompressZIPResults
        self.pdfRasterDPI = pdfRasterDPI
        self.imageResizeMode = imageResizeMode
        self.imageResizePercentage = imageResizePercentage
        self.imageMaximumWidth = imageMaximumWidth
        self.imageMaximumHeight = imageMaximumHeight
        self.imageMaintainAspectRatio = imageMaintainAspectRatio
        self.audioBitrate = audioBitrate
        self.audioSampleRate = audioSampleRate
        self.audioChannels = audioChannels
        self.normalizeAudio = normalizeAudio
        self.preserveCoverArt = preserveCoverArt
        self.videoCodec = videoCodec
        self.videoResolution = videoResolution
        self.videoWidth = videoWidth
        self.videoHeight = videoHeight
        self.videoFrameRate = videoFrameRate
        self.videoAudioMode = videoAudioMode
        self.preserveSubtitles = preserveSubtitles
        self.preserveChapters = preserveChapters
        self.metadataPolicy = metadataPolicy
        self.outputFolderMode = outputFolderMode
        self.outputSubfolderName = outputSubfolderName
        self.filenamePrefix = filenamePrefix
        self.filenameSuffix = filenameSuffix
        self.filenameSeparator = filenameSeparator
        self.zipStructureMode = zipStructureMode
        self.parallelismMode = parallelismMode
        self.manualParallelism = manualParallelism
        self.accelerationMode = accelerationMode
        self.rememberOutputFolder = rememberOutputFolder
        self.saveOutputPathsInHistory = saveOutputPathsInHistory
        self.cleanupTemporaryMaximumAgeDays = cleanupTemporaryMaximumAgeDays
        self.archiveLimits = archiveLimits
    }

    public mutating func normalize() {
        audioVideoWidth = min(max(audioVideoWidth, 16), 8_192)
        audioVideoHeight = min(max(audioVideoHeight, 16), 8_192)
        audioVideoFPS = min(max(audioVideoFPS, 1), 120)
        pdfRasterDPI = min(max(pdfRasterDPI, 72), 600)
        imageResizePercentage = min(max(imageResizePercentage, 1), 400)
        imageMaximumWidth = min(max(imageMaximumWidth, 1), 32_768)
        imageMaximumHeight = min(max(imageMaximumHeight, 1), 32_768)
        videoWidth = min(max(videoWidth, 16), 8_192)
        videoHeight = min(max(videoHeight, 16), 8_192)
        if let dimensions = videoResolution.dimensions {
            videoWidth = dimensions.0
            videoHeight = dimensions.1
        }
        if let dimensions = audioVideoCanvas.dimensions {
            audioVideoWidth = dimensions.width
            audioVideoHeight = dimensions.height
        }
        manualParallelism = min(max(manualParallelism, 1), 8)
        cleanupTemporaryMaximumAgeDays = min(max(cleanupTemporaryMaximumAgeDays, 1), 365)
        outputSubfolderName = outputSubfolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        if outputSubfolderName.isEmpty { outputSubfolderName = "ZEUVE Converted" }
        if metadataPolicy == .removeAll { preserveMetadata = false }
    }
}

public struct ConverterOperationOptions: Codable, Sendable, Equatable {
    public var operation: ConversionOperation
    public var targetFormat: ConverterFormat?
    public var advancedMode: Bool
    public var quality: ConverterQualityProfile
    public var conflictPolicy: ConverterConflictPolicy
    public var filenameStyle: ConverterFilenameStyle
    public var preserveMetadata: Bool
    public var preserveDates: Bool
    public var avoidUpscaling: Bool
    public var preferRemuxWhenPossible: Bool
    public var frameFormat: ConverterFrameFormat
    public var automaticHighBitDepthFrames: Bool
    public var createFrameTimingCSV: Bool
    public var audioVideoBackground: ConverterAudioVideoBackground
    public var audioVideoImageURL: URL?
    public var audioVideoCanvas: ConverterVideoCanvas
    public var audioVideoWidth: Int
    public var audioVideoHeight: Int
    public var audioVideoFPS: Int
    public var audioVideoFit: ConverterImageFit
    public var recompressZIPResults: Bool
    public var pdfRasterDPI: Int
    public var imageResizeMode: ConverterImageResizeMode
    public var imageResizePercentage: Int
    public var imageMaximumWidth: Int
    public var imageMaximumHeight: Int
    public var imageMaintainAspectRatio: Bool
    public var audioBitrate: ConverterAudioBitrate
    public var audioSampleRate: ConverterAudioSampleRate
    public var audioChannels: ConverterAudioChannels
    public var normalizeAudio: Bool
    public var preserveCoverArt: Bool
    public var videoCodec: ConverterVideoCodec
    public var videoResolution: ConverterVideoResolution
    public var videoWidth: Int
    public var videoHeight: Int
    public var videoFrameRate: ConverterVideoFrameRate
    public var videoAudioMode: ConverterVideoAudioMode
    public var preserveSubtitles: Bool
    public var preserveChapters: Bool
    public var metadataPolicy: ConverterMetadataPolicy
    public var outputFolderMode: ConverterOutputFolderMode
    public var outputSubfolderName: String
    public var filenamePrefix: String
    public var filenameSuffix: String
    public var filenameSeparator: String
    public var zipStructureMode: ConverterZIPStructureMode
    public var parallelismMode: ConverterParallelismMode
    public var manualParallelism: Int
    public var accelerationMode: ConverterAccelerationMode
    public var saveOutputPathsInHistory: Bool
    public var selectedAudioStreamIndex: Int?
    public var selectedSubtitleStreamIndex: Int?
    public var sequenceOrder: ConverterSequenceOrder
    public var sequenceDurationPerImage: Double
    public var animationLoopCount: Int

    public init(settings: UniversalConverterSettings = UniversalConverterSettings()) {
        operation = .convert
        targetFormat = nil
        advancedMode = settings.defaultAdvancedMode
        quality = settings.quality
        conflictPolicy = settings.conflictPolicy
        filenameStyle = settings.filenameStyle
        preserveMetadata = settings.preserveMetadata
        preserveDates = settings.preserveDates
        avoidUpscaling = settings.avoidUpscaling
        preferRemuxWhenPossible = settings.preferRemuxWhenPossible
        frameFormat = settings.frameFormat
        automaticHighBitDepthFrames = settings.automaticHighBitDepthFrames
        createFrameTimingCSV = settings.createFrameTimingCSV
        audioVideoBackground = .black
        audioVideoImageURL = nil
        audioVideoCanvas = settings.audioVideoCanvas
        audioVideoWidth = settings.audioVideoWidth
        audioVideoHeight = settings.audioVideoHeight
        audioVideoFPS = settings.audioVideoFPS
        audioVideoFit = settings.audioVideoFit
        recompressZIPResults = settings.recompressZIPResults
        pdfRasterDPI = settings.pdfRasterDPI
        imageResizeMode = settings.imageResizeMode
        imageResizePercentage = settings.imageResizePercentage
        imageMaximumWidth = settings.imageMaximumWidth
        imageMaximumHeight = settings.imageMaximumHeight
        imageMaintainAspectRatio = settings.imageMaintainAspectRatio
        audioBitrate = settings.audioBitrate
        audioSampleRate = settings.audioSampleRate
        audioChannels = settings.audioChannels
        normalizeAudio = settings.normalizeAudio
        preserveCoverArt = settings.preserveCoverArt
        videoCodec = settings.videoCodec
        videoResolution = settings.videoResolution
        videoWidth = settings.videoWidth
        videoHeight = settings.videoHeight
        videoFrameRate = settings.videoFrameRate
        videoAudioMode = settings.videoAudioMode
        preserveSubtitles = settings.preserveSubtitles
        preserveChapters = settings.preserveChapters
        metadataPolicy = settings.metadataPolicy
        outputFolderMode = settings.outputFolderMode
        outputSubfolderName = settings.outputSubfolderName
        filenamePrefix = settings.filenamePrefix
        filenameSuffix = settings.filenameSuffix
        filenameSeparator = settings.filenameSeparator
        zipStructureMode = settings.zipStructureMode
        parallelismMode = settings.parallelismMode
        manualParallelism = settings.manualParallelism
        accelerationMode = settings.accelerationMode
        saveOutputPathsInHistory = settings.saveOutputPathsInHistory
        selectedAudioStreamIndex = nil
        selectedSubtitleStreamIndex = nil
        sequenceOrder = .natural
        sequenceDurationPerImage = 1.0
        animationLoopCount = 0
        normalize()
    }

    public mutating func normalize() {
        audioVideoWidth = min(max(audioVideoWidth, 16), 8_192)
        audioVideoHeight = min(max(audioVideoHeight, 16), 8_192)
        audioVideoFPS = min(max(audioVideoFPS, 1), 120)
        pdfRasterDPI = min(max(pdfRasterDPI, 72), 600)
        imageResizePercentage = min(max(imageResizePercentage, 1), 400)
        imageMaximumWidth = min(max(imageMaximumWidth, 1), 32_768)
        imageMaximumHeight = min(max(imageMaximumHeight, 1), 32_768)
        videoWidth = min(max(videoWidth, 16), 8_192)
        videoHeight = min(max(videoHeight, 16), 8_192)
        if let dimensions = videoResolution.dimensions {
            videoWidth = dimensions.0
            videoHeight = dimensions.1
        }
        if let dimensions = audioVideoCanvas.dimensions {
            audioVideoWidth = dimensions.width
            audioVideoHeight = dimensions.height
        }
        manualParallelism = min(max(manualParallelism, 1), 8)
        sequenceDurationPerImage = min(max(sequenceDurationPerImage, 0.01), 3_600)
        animationLoopCount = min(max(animationLoopCount, 0), 100_000)
        outputSubfolderName = outputSubfolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        if outputSubfolderName.isEmpty { outputSubfolderName = "ZEUVE Converted" }
        preserveMetadata = metadataPolicy != .removeAll
        if operation != .audioToVideo {
            audioVideoImageURL = nil
            audioVideoBackground = .black
        }
        switch operation {
        case .extractFrames:
            targetFormat = frameFormat.converterFormat
        case .audioToVideo:
            targetFormat = .mp4
        case .pdfToImages:
            if targetFormat != .png && targetFormat != .jpeg { targetFormat = .png }
        case .pdfToText:
            targetFormat = .txt
        case .imagesToPDF:
            targetFormat = .pdf
        case .imagesToVideo:
            if targetFormat?.category != .video { targetFormat = .mp4 }
        case .animationToVideo:
            if targetFormat?.category != .video { targetFormat = .mp4 }
        case .videoToAnimation:
            if targetFormat != .gif && targetFormat != .webp && targetFormat != .apng { targetFormat = .gif }
        case .extractAudio:
            if targetFormat?.category != .audio { targetFormat = .m4a }
        case .convert:
            break
        }
    }
}


private struct ConverterCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init(_ stringValue: String) { self.stringValue = stringValue }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

private extension KeyedDecodingContainer where Key == ConverterCodingKey {
    func value<T: Decodable>(_ type: T.Type, for key: String, default defaultValue: T) throws -> T {
        try decodeIfPresent(type, forKey: ConverterCodingKey(key)) ?? defaultValue
    }
}

extension UniversalConverterSettings {
    public init(from decoder: Decoder) throws {
        let defaults = UniversalConverterSettings()
        let container = try decoder.container(keyedBy: ConverterCodingKey.self)
        self.init(
            defaultAdvancedMode: try container.value(Bool.self, for: "defaultAdvancedMode", default: defaults.defaultAdvancedMode),
            quality: try container.value(ConverterQualityProfile.self, for: "quality", default: defaults.quality),
            conflictPolicy: try container.value(ConverterConflictPolicy.self, for: "conflictPolicy", default: defaults.conflictPolicy),
            filenameStyle: try container.value(ConverterFilenameStyle.self, for: "filenameStyle", default: defaults.filenameStyle),
            preserveMetadata: try container.value(Bool.self, for: "preserveMetadata", default: defaults.preserveMetadata),
            preserveDates: try container.value(Bool.self, for: "preserveDates", default: defaults.preserveDates),
            avoidUpscaling: try container.value(Bool.self, for: "avoidUpscaling", default: defaults.avoidUpscaling),
            preferRemuxWhenPossible: try container.value(Bool.self, for: "preferRemuxWhenPossible", default: defaults.preferRemuxWhenPossible),
            frameFormat: try container.value(ConverterFrameFormat.self, for: "frameFormat", default: defaults.frameFormat),
            automaticHighBitDepthFrames: try container.value(Bool.self, for: "automaticHighBitDepthFrames", default: defaults.automaticHighBitDepthFrames),
            createFrameTimingCSV: try container.value(Bool.self, for: "createFrameTimingCSV", default: defaults.createFrameTimingCSV),
            audioVideoCanvas: try container.value(ConverterVideoCanvas.self, for: "audioVideoCanvas", default: defaults.audioVideoCanvas),
            audioVideoWidth: try container.value(Int.self, for: "audioVideoWidth", default: defaults.audioVideoWidth),
            audioVideoHeight: try container.value(Int.self, for: "audioVideoHeight", default: defaults.audioVideoHeight),
            audioVideoFPS: try container.value(Int.self, for: "audioVideoFPS", default: defaults.audioVideoFPS),
            audioVideoFit: try container.value(ConverterImageFit.self, for: "audioVideoFit", default: defaults.audioVideoFit),
            recompressZIPResults: try container.value(Bool.self, for: "recompressZIPResults", default: defaults.recompressZIPResults),
            pdfRasterDPI: try container.value(Int.self, for: "pdfRasterDPI", default: defaults.pdfRasterDPI),
            imageResizeMode: try container.value(ConverterImageResizeMode.self, for: "imageResizeMode", default: defaults.imageResizeMode),
            imageResizePercentage: try container.value(Int.self, for: "imageResizePercentage", default: defaults.imageResizePercentage),
            imageMaximumWidth: try container.value(Int.self, for: "imageMaximumWidth", default: defaults.imageMaximumWidth),
            imageMaximumHeight: try container.value(Int.self, for: "imageMaximumHeight", default: defaults.imageMaximumHeight),
            imageMaintainAspectRatio: try container.value(Bool.self, for: "imageMaintainAspectRatio", default: defaults.imageMaintainAspectRatio),
            audioBitrate: try container.value(ConverterAudioBitrate.self, for: "audioBitrate", default: defaults.audioBitrate),
            audioSampleRate: try container.value(ConverterAudioSampleRate.self, for: "audioSampleRate", default: defaults.audioSampleRate),
            audioChannels: try container.value(ConverterAudioChannels.self, for: "audioChannels", default: defaults.audioChannels),
            normalizeAudio: try container.value(Bool.self, for: "normalizeAudio", default: defaults.normalizeAudio),
            preserveCoverArt: try container.value(Bool.self, for: "preserveCoverArt", default: defaults.preserveCoverArt),
            videoCodec: try container.value(ConverterVideoCodec.self, for: "videoCodec", default: defaults.videoCodec),
            videoResolution: try container.value(ConverterVideoResolution.self, for: "videoResolution", default: defaults.videoResolution),
            videoWidth: try container.value(Int.self, for: "videoWidth", default: defaults.videoWidth),
            videoHeight: try container.value(Int.self, for: "videoHeight", default: defaults.videoHeight),
            videoFrameRate: try container.value(ConverterVideoFrameRate.self, for: "videoFrameRate", default: defaults.videoFrameRate),
            videoAudioMode: try container.value(ConverterVideoAudioMode.self, for: "videoAudioMode", default: defaults.videoAudioMode),
            preserveSubtitles: try container.value(Bool.self, for: "preserveSubtitles", default: defaults.preserveSubtitles),
            preserveChapters: try container.value(Bool.self, for: "preserveChapters", default: defaults.preserveChapters),
            metadataPolicy: try container.value(ConverterMetadataPolicy.self, for: "metadataPolicy", default: defaults.metadataPolicy),
            outputFolderMode: try container.value(ConverterOutputFolderMode.self, for: "outputFolderMode", default: defaults.outputFolderMode),
            outputSubfolderName: try container.value(String.self, for: "outputSubfolderName", default: defaults.outputSubfolderName),
            filenamePrefix: try container.value(String.self, for: "filenamePrefix", default: defaults.filenamePrefix),
            filenameSuffix: try container.value(String.self, for: "filenameSuffix", default: defaults.filenameSuffix),
            filenameSeparator: try container.value(String.self, for: "filenameSeparator", default: defaults.filenameSeparator),
            zipStructureMode: try container.value(ConverterZIPStructureMode.self, for: "zipStructureMode", default: defaults.zipStructureMode),
            parallelismMode: try container.value(ConverterParallelismMode.self, for: "parallelismMode", default: defaults.parallelismMode),
            manualParallelism: try container.value(Int.self, for: "manualParallelism", default: defaults.manualParallelism),
            accelerationMode: try container.value(ConverterAccelerationMode.self, for: "accelerationMode", default: defaults.accelerationMode),
            rememberOutputFolder: try container.value(Bool.self, for: "rememberOutputFolder", default: defaults.rememberOutputFolder),
            saveOutputPathsInHistory: try container.value(Bool.self, for: "saveOutputPathsInHistory", default: defaults.saveOutputPathsInHistory),
            cleanupTemporaryMaximumAgeDays: try container.value(Int.self, for: "cleanupTemporaryMaximumAgeDays", default: defaults.cleanupTemporaryMaximumAgeDays),
            archiveLimits: try container.value(ConverterArchiveLimits.self, for: "archiveLimits", default: defaults.archiveLimits)
        )
        normalize()
    }
}

extension ConverterOperationOptions {
    public init(from decoder: Decoder) throws {
        var value = ConverterOperationOptions()
        let container = try decoder.container(keyedBy: ConverterCodingKey.self)
        value.operation = try container.value(ConversionOperation.self, for: "operation", default: value.operation)
        value.targetFormat = try container.decodeIfPresent(ConverterFormat.self, forKey: ConverterCodingKey("targetFormat"))
        value.advancedMode = try container.value(Bool.self, for: "advancedMode", default: value.advancedMode)
        value.quality = try container.value(ConverterQualityProfile.self, for: "quality", default: value.quality)
        value.conflictPolicy = try container.value(ConverterConflictPolicy.self, for: "conflictPolicy", default: value.conflictPolicy)
        value.filenameStyle = try container.value(ConverterFilenameStyle.self, for: "filenameStyle", default: value.filenameStyle)
        value.preserveMetadata = try container.value(Bool.self, for: "preserveMetadata", default: value.preserveMetadata)
        value.preserveDates = try container.value(Bool.self, for: "preserveDates", default: value.preserveDates)
        value.avoidUpscaling = try container.value(Bool.self, for: "avoidUpscaling", default: value.avoidUpscaling)
        value.preferRemuxWhenPossible = try container.value(Bool.self, for: "preferRemuxWhenPossible", default: value.preferRemuxWhenPossible)
        value.frameFormat = try container.value(ConverterFrameFormat.self, for: "frameFormat", default: value.frameFormat)
        value.automaticHighBitDepthFrames = try container.value(Bool.self, for: "automaticHighBitDepthFrames", default: value.automaticHighBitDepthFrames)
        value.createFrameTimingCSV = try container.value(Bool.self, for: "createFrameTimingCSV", default: value.createFrameTimingCSV)
        value.audioVideoBackground = try container.value(ConverterAudioVideoBackground.self, for: "audioVideoBackground", default: value.audioVideoBackground)
        value.audioVideoImageURL = try container.decodeIfPresent(URL.self, forKey: ConverterCodingKey("audioVideoImageURL"))
        value.audioVideoCanvas = try container.value(ConverterVideoCanvas.self, for: "audioVideoCanvas", default: value.audioVideoCanvas)
        value.audioVideoWidth = try container.value(Int.self, for: "audioVideoWidth", default: value.audioVideoWidth)
        value.audioVideoHeight = try container.value(Int.self, for: "audioVideoHeight", default: value.audioVideoHeight)
        value.audioVideoFPS = try container.value(Int.self, for: "audioVideoFPS", default: value.audioVideoFPS)
        value.audioVideoFit = try container.value(ConverterImageFit.self, for: "audioVideoFit", default: value.audioVideoFit)
        value.recompressZIPResults = try container.value(Bool.self, for: "recompressZIPResults", default: value.recompressZIPResults)
        value.pdfRasterDPI = try container.value(Int.self, for: "pdfRasterDPI", default: value.pdfRasterDPI)
        value.imageResizeMode = try container.value(ConverterImageResizeMode.self, for: "imageResizeMode", default: value.imageResizeMode)
        value.imageResizePercentage = try container.value(Int.self, for: "imageResizePercentage", default: value.imageResizePercentage)
        value.imageMaximumWidth = try container.value(Int.self, for: "imageMaximumWidth", default: value.imageMaximumWidth)
        value.imageMaximumHeight = try container.value(Int.self, for: "imageMaximumHeight", default: value.imageMaximumHeight)
        value.imageMaintainAspectRatio = try container.value(Bool.self, for: "imageMaintainAspectRatio", default: value.imageMaintainAspectRatio)
        value.audioBitrate = try container.value(ConverterAudioBitrate.self, for: "audioBitrate", default: value.audioBitrate)
        value.audioSampleRate = try container.value(ConverterAudioSampleRate.self, for: "audioSampleRate", default: value.audioSampleRate)
        value.audioChannels = try container.value(ConverterAudioChannels.self, for: "audioChannels", default: value.audioChannels)
        value.normalizeAudio = try container.value(Bool.self, for: "normalizeAudio", default: value.normalizeAudio)
        value.preserveCoverArt = try container.value(Bool.self, for: "preserveCoverArt", default: value.preserveCoverArt)
        value.videoCodec = try container.value(ConverterVideoCodec.self, for: "videoCodec", default: value.videoCodec)
        value.videoResolution = try container.value(ConverterVideoResolution.self, for: "videoResolution", default: value.videoResolution)
        value.videoWidth = try container.value(Int.self, for: "videoWidth", default: value.videoWidth)
        value.videoHeight = try container.value(Int.self, for: "videoHeight", default: value.videoHeight)
        value.videoFrameRate = try container.value(ConverterVideoFrameRate.self, for: "videoFrameRate", default: value.videoFrameRate)
        value.videoAudioMode = try container.value(ConverterVideoAudioMode.self, for: "videoAudioMode", default: value.videoAudioMode)
        value.preserveSubtitles = try container.value(Bool.self, for: "preserveSubtitles", default: value.preserveSubtitles)
        value.preserveChapters = try container.value(Bool.self, for: "preserveChapters", default: value.preserveChapters)
        value.metadataPolicy = try container.value(ConverterMetadataPolicy.self, for: "metadataPolicy", default: value.metadataPolicy)
        value.outputFolderMode = try container.value(ConverterOutputFolderMode.self, for: "outputFolderMode", default: value.outputFolderMode)
        value.outputSubfolderName = try container.value(String.self, for: "outputSubfolderName", default: value.outputSubfolderName)
        value.filenamePrefix = try container.value(String.self, for: "filenamePrefix", default: value.filenamePrefix)
        value.filenameSuffix = try container.value(String.self, for: "filenameSuffix", default: value.filenameSuffix)
        value.filenameSeparator = try container.value(String.self, for: "filenameSeparator", default: value.filenameSeparator)
        value.zipStructureMode = try container.value(ConverterZIPStructureMode.self, for: "zipStructureMode", default: value.zipStructureMode)
        value.parallelismMode = try container.value(ConverterParallelismMode.self, for: "parallelismMode", default: value.parallelismMode)
        value.manualParallelism = try container.value(Int.self, for: "manualParallelism", default: value.manualParallelism)
        value.accelerationMode = try container.value(ConverterAccelerationMode.self, for: "accelerationMode", default: value.accelerationMode)
        value.saveOutputPathsInHistory = try container.value(Bool.self, for: "saveOutputPathsInHistory", default: value.saveOutputPathsInHistory)
        value.selectedAudioStreamIndex = try container.decodeIfPresent(Int.self, forKey: ConverterCodingKey("selectedAudioStreamIndex"))
        value.selectedSubtitleStreamIndex = try container.decodeIfPresent(Int.self, forKey: ConverterCodingKey("selectedSubtitleStreamIndex"))
        value.sequenceOrder = try container.value(ConverterSequenceOrder.self, for: "sequenceOrder", default: value.sequenceOrder)
        value.sequenceDurationPerImage = try container.value(Double.self, for: "sequenceDurationPerImage", default: value.sequenceDurationPerImage)
        value.animationLoopCount = try container.value(Int.self, for: "animationLoopCount", default: value.animationLoopCount)
        value.normalize()
        self = value
    }
}

public struct UniversalConverterPreset: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var options: ConverterOperationOptions
    public var isBuiltIn: Bool

    public init(id: UUID = UUID(), name: String, options: ConverterOperationOptions, isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        var sanitized = options
        sanitized.audioVideoImageURL = nil
        if sanitized.audioVideoBackground == .image { sanitized.audioVideoBackground = .black }
        sanitized.normalize()
        self.options = sanitized
        self.isBuiltIn = isBuiltIn
    }

    public static var defaults: [UniversalConverterPreset] {
        var image = ConverterOperationOptions()
        image.operation = .convert
        image.targetFormat = .png
        image.quality = .maximum

        var video = ConverterOperationOptions()
        video.operation = .convert
        video.targetFormat = .mp4
        video.quality = .maximum
        video.preferRemuxWhenPossible = false

        var frames = ConverterOperationOptions()
        frames.operation = .extractFrames
        frames.targetFormat = .png
        frames.frameFormat = .png
        frames.automaticHighBitDepthFrames = true
        frames.createFrameTimingCSV = true

        var audio = ConverterOperationOptions()
        audio.operation = .convert
        audio.targetFormat = .mp3
        audio.quality = .maximum

        var document = ConverterOperationOptions()
        document.operation = .convert
        document.targetFormat = .pdf
        document.quality = .maximum

        return [
            .init(name: "Imagen PNG sin pérdida", options: image, isBuiltIn: true),
            .init(name: "Vídeo MP4 compatible", options: video, isBuiltIn: true),
            .init(name: "Todos los fotogramas en PNG", options: frames, isBuiltIn: true),
            .init(name: "Audio MP3 de alta calidad", options: audio, isBuiltIn: true),
            .init(name: "Documento a PDF", options: document, isBuiltIn: true)
        ]
    }
}

public enum ConverterSourceKind: String, Codable, Sendable, Hashable {
    case file
    case archiveEntry
}

public struct ConverterInputItem: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let kind: ConverterSourceKind
    public let sourceURL: URL
    public let archiveEntryPath: String?
    public let relativePath: String
    public let displayName: String
    public let size: Int64
    public let format: ConverterFormat
    public let detection: ConverterFormatDetection?
    public let fingerprint: FileFingerprint
    public let sourceRootName: String

    public init(
        id: UUID = UUID(),
        kind: ConverterSourceKind,
        sourceURL: URL,
        archiveEntryPath: String? = nil,
        relativePath: String,
        displayName: String,
        size: Int64,
        format: ConverterFormat,
        detection: ConverterFormatDetection? = nil,
        fingerprint: FileFingerprint,
        sourceRootName: String
    ) {
        self.id = id
        self.kind = kind
        self.sourceURL = sourceURL.standardizedFileURL
        self.archiveEntryPath = archiveEntryPath
        self.relativePath = relativePath
        self.displayName = displayName
        self.size = size
        self.format = format
        self.detection = detection
        self.fingerprint = fingerprint
        self.sourceRootName = sourceRootName
    }

    public var category: ConverterCategory { format.category }
    public var isFromArchive: Bool { kind == .archiveEntry }
}

public enum ConverterExecutionKind: String, Codable, Sendable, Equatable, Hashable {
    case copy
    case nativeImage
    case ffmpeg
    case nativePDFToImages
    case nativePDFToText
    case nativeImagesToPDF
    case pandoc
    case calibre
    case ghostscript
}

public struct ConversionPlanItem: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let sources: [ConverterInputItem]
    public let operation: ConversionOperation
    public let targetFormat: ConverterFormat
    public let executionKind: ConverterExecutionKind
    public let destinationRelativePath: String
    public let estimatedOutputBytes: Int64?
    public let warnings: [String]

    public init(
        id: UUID = UUID(),
        sources: [ConverterInputItem],
        operation: ConversionOperation,
        targetFormat: ConverterFormat,
        executionKind: ConverterExecutionKind,
        destinationRelativePath: String,
        estimatedOutputBytes: Int64?,
        warnings: [String] = []
    ) {
        self.id = id
        self.sources = sources
        self.operation = operation
        self.targetFormat = targetFormat
        self.executionKind = executionKind
        self.destinationRelativePath = destinationRelativePath
        self.estimatedOutputBytes = estimatedOutputBytes
        self.warnings = warnings
    }
}

public struct ConversionPlan: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let revision: UInt64
    public let createdAt: Date
    public let items: [ConversionPlanItem]
    public let outputFolder: URL
    public let options: ConverterOperationOptions
    public let warnings: [String]
    public let estimatedOutputBytes: Int64?
    public let availableOutputBytes: Int64?
    public let safetyMarginBytes: Int64?
    public let containsArchiveEntries: Bool

    public var estimatedRequiredWithMargin: Int64? {
        guard let estimatedOutputBytes else { return nil }
        return estimatedOutputBytes.addingReportingOverflow(safetyMarginBytes ?? 0).overflow
            ? Int64.max
            : estimatedOutputBytes + (safetyMarginBytes ?? 0)
    }

    public var mayHaveInsufficientSpace: Bool {
        guard let required = estimatedRequiredWithMargin, let availableOutputBytes else { return false }
        return required > availableOutputBytes
    }

    public init(
        id: UUID = UUID(),
        revision: UInt64,
        createdAt: Date = Date(),
        items: [ConversionPlanItem],
        outputFolder: URL,
        options: ConverterOperationOptions,
        warnings: [String],
        estimatedOutputBytes: Int64?,
        availableOutputBytes: Int64? = nil,
        safetyMarginBytes: Int64? = nil,
        containsArchiveEntries: Bool
    ) {
        self.id = id
        self.revision = revision
        self.createdAt = createdAt
        self.items = items
        self.outputFolder = outputFolder.standardizedFileURL
        self.options = options
        self.warnings = warnings
        self.estimatedOutputBytes = estimatedOutputBytes
        self.availableOutputBytes = availableOutputBytes
        self.safetyMarginBytes = safetyMarginBytes
        self.containsArchiveEntries = containsArchiveEntries
    }
}

public enum ConverterItemResultStatus: String, Codable, Sendable, Equatable {
    case completed
    case skipped
    case failed
    case cancelled
}

public struct ConverterItemResult: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let sourceNames: [String]
    public let status: ConverterItemResultStatus
    public let outputURLs: [URL]
    public let message: String?

    public init(
        id: UUID = UUID(),
        sourceNames: [String],
        status: ConverterItemResultStatus,
        outputURLs: [URL] = [],
        message: String? = nil
    ) {
        self.id = id
        self.sourceNames = sourceNames
        self.status = status
        self.outputURLs = outputURLs
        self.message = message
    }
}

public struct UniversalConverterResult: Codable, Sendable, Equatable {
    public let operationID: UUID
    public let startedAt: Date
    public let finishedAt: Date
    public let outputFolder: URL
    public let items: [ConverterItemResult]
    public let archiveURL: URL?

    public init(
        operationID: UUID,
        startedAt: Date,
        finishedAt: Date = Date(),
        outputFolder: URL,
        items: [ConverterItemResult],
        archiveURL: URL? = nil
    ) {
        self.operationID = operationID
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.outputFolder = outputFolder
        self.items = items
        self.archiveURL = archiveURL
    }

    public var completedCount: Int { items.filter { $0.status == .completed }.count }
    public var skippedCount: Int { items.filter { $0.status == .skipped }.count }
    public var failedCount: Int { items.filter { $0.status == .failed }.count }
    public var cancelledCount: Int { items.filter { $0.status == .cancelled }.count }
    public var generatedFiles: [URL] { items.flatMap(\.outputURLs) + (archiveURL.map { [$0] } ?? []) }
    public var duration: TimeInterval { finishedAt.timeIntervalSince(startedAt) }
}

public enum ConverterProgressItemStatus: String, Sendable, Equatable {
    case pending
    case running
    case completed
    case skipped
    case failed
    case cancelled
}

public struct ConverterProgressItem: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let sourceNames: [String]
    public let status: ConverterProgressItemStatus
    public let fraction: Double?
    public let phase: String
    public let message: String?

    public init(
        id: UUID,
        sourceNames: [String],
        status: ConverterProgressItemStatus,
        fraction: Double? = nil,
        phase: String,
        message: String? = nil
    ) {
        self.id = id
        self.sourceNames = sourceNames
        self.status = status
        self.fraction = fraction
        self.phase = phase
        self.message = message
    }
}

public struct ConverterProgressSnapshot: Sendable, Equatable {
    public let phase: String
    public let currentItem: String?
    public let completedItems: Int
    public let totalItems: Int
    public let itemFraction: Double?
    public let failedItems: Int
    public let skippedItems: Int
    public let cancelledItems: Int
    public let elapsed: TimeInterval
    public let estimatedRemaining: TimeInterval?
    public let itemStates: [ConverterProgressItem]

    public init(
        phase: String,
        currentItem: String?,
        completedItems: Int,
        totalItems: Int,
        itemFraction: Double? = nil,
        failedItems: Int = 0,
        skippedItems: Int = 0,
        cancelledItems: Int = 0,
        elapsed: TimeInterval = 0,
        estimatedRemaining: TimeInterval? = nil,
        itemStates: [ConverterProgressItem] = []
    ) {
        self.phase = phase
        self.currentItem = currentItem
        self.completedItems = completedItems
        self.totalItems = totalItems
        self.itemFraction = itemFraction
        self.failedItems = failedItems
        self.skippedItems = skippedItems
        self.cancelledItems = cancelledItems
        self.elapsed = max(elapsed, 0)
        self.estimatedRemaining = estimatedRemaining.map { max($0, 0) }
        self.itemStates = itemStates
    }

    public var overallFraction: Double? {
        guard totalItems > 0 else { return nil }
        let item = min(max(itemFraction ?? 0, 0), 1)
        return min(max((Double(completedItems + failedItems + skippedItems + cancelledItems) + item) / Double(totalItems), 0), 1)
    }
}

