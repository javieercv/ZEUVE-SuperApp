import Foundation

public enum MediaInspectionError: LocalizedError, Equatable, Sendable {
    case invalidInput
    case processFailed(exitCode: Int32)
    case outputTooLarge
    case emptyOutput
    case invalidOutput

    public var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "No se ha podido leer el archivo multimedia seleccionado."
        case .processFailed:
            return "FFprobe no ha podido analizar el archivo."
        case .outputTooLarge:
            return "FFprobe ha devuelto una cantidad de información inesperadamente grande."
        case .emptyOutput:
            return "FFprobe no ha devuelto información del archivo."
        case .invalidOutput:
            return "FFprobe ha devuelto información multimedia que no se ha podido interpretar."
        }
    }
}
