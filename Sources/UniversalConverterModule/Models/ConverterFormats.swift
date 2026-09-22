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
