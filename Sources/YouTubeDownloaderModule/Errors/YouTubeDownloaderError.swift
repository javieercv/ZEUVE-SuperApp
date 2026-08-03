import Foundation

public enum YouTubeDownloaderError: LocalizedError, Equatable {
    case emptyInput
    case unsupportedScheme(String)
    case unsupportedHost(String)
    case malformedURL(String)
    case missingVideoIdentifier
    case missingPlaylistIdentifier
    case enginesUnavailable
    case analysisFailed(String)
    case activeOrUpcomingLive
    case unavailableMedia(String)
    case outputFolderUnavailable
    case cookiesFileUnavailable
    case invalidProxy
    case insufficientDiskSpace(required: Int64, available: Int64)
    case unsafeOutputName
    case invalidTemporaryWorkspace
    case noPublishedFiles
    case overwriteNotConfirmed

    public var errorDescription: String? {
        switch self {
        case .emptyInput: return "Introduce al menos un enlace de YouTube."
        case .unsupportedScheme(let value): return "El esquema \(value) no está permitido. Utiliza un enlace HTTPS de YouTube."
        case .unsupportedHost(let value): return "El dominio \(value) no es compatible. En esta versión solo se admite YouTube."
        case .malformedURL(let value): return "El enlace no es válido: \(value)."
        case .missingVideoIdentifier: return "El enlace no contiene un identificador de vídeo válido."
        case .missingPlaylistIdentifier: return "El enlace no contiene un identificador de lista de reproducción válido."
        case .enginesUnavailable: return "Falta uno o varios motores necesarios. Consulta Diagnóstico."
        case .analysisFailed(let message): return "No se ha podido analizar el enlace: \(message)"
        case .activeOrUpcomingLive: return "Las emisiones activas o futuras no pueden descargarse en ZEUVE 0.4.0."
        case .unavailableMedia(let message): return "El contenido no está disponible: \(message)"
        case .outputFolderUnavailable: return "La carpeta de salida ya no está disponible. Selecciónala de nuevo."
        case .cookiesFileUnavailable: return "El archivo cookies.txt ya no está disponible. Selecciónalo de nuevo."
        case .invalidProxy: return "La configuración del proxy no es válida."
        case .insufficientDiskSpace(let required, let available): return "No hay espacio suficiente. Se estiman \(required) bytes y hay \(available) bytes disponibles."
        case .unsafeOutputName: return "El nombre de salida no es seguro."
        case .invalidTemporaryWorkspace: return "La carpeta temporal no pertenece a esta operación."
        case .noPublishedFiles: return "La operación terminó sin producir archivos válidos."
        case .overwriteNotConfirmed: return "El reemplazo de archivos requiere una confirmación explícita."
        }
    }
}
