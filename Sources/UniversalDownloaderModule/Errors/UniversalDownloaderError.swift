import Foundation

public enum UniversalDownloaderError: LocalizedError, Equatable {
    case emptyInput
    case unsupportedScheme(String)
    case unsupportedHost(String)
    case malformedURL(String)
    case adultContentDisabled(String)
    case platformRequiresConcreteURL(String)
    case platformMismatch(expected: String, detected: String)
    case invalidInstagramUsername
    case privateProfileNeedsSession(String)
    case optionalEngineUnavailable(String)
    case liveContentUnsupported
    case missingVideoIdentifier
    case missingPlaylistIdentifier
    case invalidManifest
    case enginesUnavailable
    case analysisFailed(String)
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
        case .emptyInput: return "Introduce al menos un enlace válido."
        case .unsupportedScheme(let value): return "El esquema \(value) no está permitido. Utiliza HTTPS; HTTP solo puede habilitarse para la red local desde el modo avanzado."
        case .unsupportedHost(let value): return "El dominio \(value) pertenece a la red local. Activa expresamente el acceso local en el modo avanzado para utilizarlo."
        case .malformedURL(let value): return "El enlace no es válido: \(value)."
        case .adultContentDisabled(let domain): return "El dominio \(domain) contiene contenido para adultos. Para analizarlo, activa «Permitir contenido para adultos» en Ajustes > Descargador universal > Contenido."
        case .platformRequiresConcreteURL(let platform): return "Para \(platform) debes pegar el enlace concreto de la publicación, vídeo, foto, álbum o contenido que quieres descargar."
        case .platformMismatch(let expected, let detected): return "El enlace pertenece a \(detected), pero has seleccionado \(expected). Cambia la plataforma o utiliza detección automática."
        case .invalidInstagramUsername: return "El nombre de usuario de Instagram no es válido."
        case .privateProfileNeedsSession(let username): return "El perfil @\(username) es privado. Proporciona una sesión de Instagram que ya tenga permiso para verlo."
        case .optionalEngineUnavailable(let engine):
            if engine == "gallery-dl" || engine == "Catálogo de Instagram" {
                return "El motor \(engine) no está incluido o no ha superado el diagnóstico. Vuelve a preparar y compilar ZEUVE para incorporar los motores de Instagram."
            }
            return "El motor \(engine) no está instalado o no ha superado el diagnóstico."
        case .liveContentUnsupported: return "Las emisiones activas o programadas no se descargan. Las repeticiones publicadas como vídeos normales sí pueden analizarse."
        case .missingVideoIdentifier: return "El enlace no contiene un identificador de vídeo válido."
        case .missingPlaylistIdentifier: return "El enlace no contiene un identificador de lista de reproducción válido."
        case .invalidManifest: return "No se ha podido cargar el manifiesto del Descargador universal."
        case .enginesUnavailable: return "Falta uno o varios motores necesarios. Consulta Diagnóstico."
        case .analysisFailed(let message): return "No se ha podido analizar el enlace: \(message)"
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
