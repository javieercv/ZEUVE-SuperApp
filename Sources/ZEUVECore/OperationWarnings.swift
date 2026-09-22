import Foundation

public struct ZEUVEHistoryPersistenceFailure: Sendable, Equatable {
    public let warning: String
    public let logMetadata: [String: String]

    public init(warning: String, logMetadata: [String: String]) {
        self.warning = warning
        self.logMetadata = logMetadata
    }
}

public enum ZEUVEHistoryPersistence {
    public static let warningMessage = "La operación ha finalizado correctamente, pero no se ha podido guardar en el historial."

    /// El historial es secundario al resultado principal. Esta función captura únicamente
    /// el fallo de persistencia y devuelve un aviso saneado; nunca convierte en fallida
    /// una operación principal que ya ha terminado correctamente.
    public static func attempt(_ save: () throws -> Void) -> ZEUVEHistoryPersistenceFailure? {
        do {
            try save()
            return nil
        } catch {
            return ZEUVEHistoryPersistenceFailure(
                warning: warningMessage,
                logMetadata: ["tipo_error": String(reflecting: type(of: error))]
            )
        }
    }
}
