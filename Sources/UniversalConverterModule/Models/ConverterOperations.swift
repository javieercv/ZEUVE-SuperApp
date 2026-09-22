import Foundation
import ZEUVECore

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
