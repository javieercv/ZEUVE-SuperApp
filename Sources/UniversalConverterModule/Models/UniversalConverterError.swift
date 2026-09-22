import Foundation

public enum UniversalConverterError: LocalizedError, Equatable {
    case unavailable(String)
    case invalidManifest
    case noInput
    case unsupportedFormat(String)
    case incompatibleCategory(String)
    case incompatibleRecipe(String)
    case incompatibleSettings(String)
    case outputFolderMissing
    case unsafePath(String)
    case archiveDamaged(String)
    case archiveEncrypted
    case archivePasswordRequired
    case archivePasswordIncorrect
    case passwordRequired(String)
    case passwordIncorrect(String)
    case archiveLimit(String)
    case corruptFile(String)
    case sourceChanged(String)
    case sourceMissing(String)
    case outputConflict(String)
    case overwriteNotConfirmed
    case insufficientDiskSpace(required: Int64, available: Int64)
    case engineUnavailable(String)
    case dependencyMissing(String)
    case codecUnavailable(String)
    case permissionDenied(String)
    case processFailed(String)
    case invalidResult(String)
    case unsupportedPlatform(String)
    case internalFailure(String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .unavailable(let message): return message
        case .invalidManifest: return "No se ha podido cargar el manifiesto del Conversor universal."
        case .noInput: return "Añade al menos un archivo compatible."
        case .unsupportedFormat(let name): return "El formato de «\(name)» no es compatible con esta operación."
        case .incompatibleCategory(let message): return "Las categorías seleccionadas no son compatibles: \(message)"
        case .incompatibleRecipe(let message): return message
        case .incompatibleSettings(let message): return "Los ajustes elegidos no son compatibles: \(message)"
        case .outputFolderMissing: return "Selecciona una carpeta de salida válida y con permiso de escritura."
        case .unsafePath(let path): return "Se ha rechazado una ruta no segura: \(path)."
        case .archiveDamaged(let detail): return "No se puede leer el ZIP: \(detail)."
        case .archiveEncrypted: return "El ZIP está cifrado y no puede abrirse con la configuración actual."
        case .archivePasswordRequired: return "El ZIP está cifrado. Introduce su contraseña para inspeccionarlo y convertirlo."
        case .archivePasswordIncorrect: return "La contraseña del ZIP no es correcta o el método de cifrado no es compatible."
        case .passwordRequired(let kind): return "El archivo de \(kind) está protegido. Introduce su contraseña para continuar."
        case .passwordIncorrect(let kind): return "La contraseña del archivo de \(kind) no es correcta o su protección no es compatible."
        case .archiveLimit(let detail): return "El ZIP se ha rechazado por seguridad: \(detail)."
        case .corruptFile(let name): return "«\(name)» está dañado o su contenido no puede leerse de forma fiable."
        case .sourceChanged(let name): return "«\(name)» ha cambiado desde que se preparó la vista previa. Vuelve a analizarlo."
        case .sourceMissing(let name): return "Ya no se encuentra «\(name)»."
        case .outputConflict(let name): return "Ya existe un resultado llamado «\(name)»."
        case .overwriteNotConfirmed: return "El reemplazo no se ha confirmado expresamente."
        case .insufficientDiskSpace(let required, let available):
            return "No hay espacio suficiente. Se estiman \(ByteCountFormatter.string(fromByteCount: required, countStyle: .file)) y hay \(ByteCountFormatter.string(fromByteCount: available, countStyle: .file)) disponibles."
        case .engineUnavailable(let name): return "El motor \(name) no está disponible o no ha superado el diagnóstico."
        case .dependencyMissing(let name): return "Falta la dependencia local \(name). Revisa Ajustes > Conversor > Diagnóstico."
        case .codecUnavailable(let name): return "El códec solicitado no está disponible: \(name)"
        case .permissionDenied(let path): return "No hay permiso para leer o escribir en «\(path)»."
        case .processFailed(let detail): return "La conversión no ha podido completarse: \(detail)."
        case .invalidResult(let detail): return "El resultado generado no es válido: \(detail)."
        case .unsupportedPlatform(let detail): return "Esta operación requiere macOS: \(detail)."
        case .internalFailure(let detail): return "Se ha producido un fallo interno del Conversor: \(detail)."
        case .cancelled: return "La conversión se ha cancelado."
        }
    }
}
