import Foundation

public enum MultimediaInspectorError: LocalizedError, Equatable, Sendable {
    case invalidInput
    case unsupportedFile
    case inspectionFailed
    case ffprobeUnavailable
    case ffmpegUnavailable
    case notEditable(String)
    case incompatibleContainer(String)
    case requiresTranscode(String)
    case subtitleConversionAuthorizationRequired(String, String)
    case subtitleNotConvertible(String)
    case invalidChapter(String)
    case invalidAttachment(String)
    case unsupportedMetadata(String)
    case attachmentExtractionFailed(String)
    case inputMissing(String)
    case inputChanged(String)
    case originalChanged
    case outputMatchesOriginal
    case insufficientDiskSpace(required: Int64, available: Int64)
    case permissionDenied
    case cancelled
    case processFailed
    case invalidOutput(String)
    case validationFailed(String)
    case exportUnavailable
    case previewUnavailable

    public var errorDescription: String? {
        switch self {
        case .invalidInput: return "Selecciona un archivo local válido."
        case .unsupportedFile: return "FFprobe no ha podido reconocer este archivo como contenido multimedia compatible."
        case .inspectionFailed: return "No se ha podido completar la inspección técnica del archivo."
        case .ffprobeUnavailable: return "FFprobe no está disponible. Revisa los motores de ZEUVE."
        case .ffmpegUnavailable: return "FFmpeg no está disponible. Revisa los motores de ZEUVE."
        case .notEditable(let reason): return "Este archivo se puede inspeccionar, pero no editar: \(reason)"
        case .incompatibleContainer(let reason): return "La combinación de pistas no es compatible con el contenedor: \(reason)"
        case .requiresTranscode(let reason): return "La operación requeriría recodificar vídeo o audio (\(reason)). Utiliza el Conversor universal."
        case .subtitleConversionAuthorizationRequired(let from, let to): return "El subtítulo debe convertirse de \(from) a \(to). Autoriza expresamente esa conversión para continuar."
        case .subtitleNotConvertible(let codec): return "El subtítulo \(codec) no puede convertirse de forma auxiliar segura en Inspector multimedia."
        case .invalidChapter(let reason): return "El capítulo no es válido: \(reason)."
        case .invalidAttachment(let reason): return "El adjunto no es válido: \(reason)."
        case .unsupportedMetadata(let reason): return "El metadato no se puede escribir de forma segura: \(reason)."
        case .attachmentExtractionFailed(let reason): return "No se ha podido extraer el adjunto: \(reason)."
        case .inputMissing(let name): return "La entrada «\(name)» ya no existe."
        case .inputChanged(let name): return "La entrada «\(name)» ha cambiado desde que se inspeccionó. Vuelve a analizarla."
        case .originalChanged: return "El archivo original ha cambiado desde que se inspeccionó. Vuelve a abrirlo."
        case .outputMatchesOriginal: return "El resultado no puede utilizar la misma ruta ni el mismo archivo que el original."
        case .insufficientDiskSpace(let required, let available): return "No hay espacio suficiente. Se necesitan aproximadamente \(required) bytes y hay \(available) bytes disponibles."
        case .permissionDenied: return "ZEUVE no tiene permisos para escribir en la carpeta seleccionada."
        case .cancelled: return "La operación se ha cancelado."
        case .processFailed: return "FFmpeg no ha podido generar el resultado."
        case .invalidOutput(let reason): return "El resultado no es válido: \(reason)"
        case .validationFailed(let reason): return "La validación final ha fallado: \(reason)"
        case .exportUnavailable: return "La exportación PNG no está disponible en este entorno."
        case .previewUnavailable: return "La previsualización de audio no está disponible en este entorno."
        }
    }
}
