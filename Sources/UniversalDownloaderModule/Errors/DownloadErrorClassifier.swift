import Foundation

public enum DownloadErrorCategory: String, Sendable, Equatable {
    case authenticationRequired
    case profileUnverified
    case unavailable
    case geoRestricted
    case drmProtected
    case network
    case extractionFailed
}

public struct ClassifiedDownloadError: Sendable, Equatable {
    public let category: DownloadErrorCategory
    public let userMessage: String
    public let technicalReference: String
}

public struct DownloadErrorClassifier: Sendable {
    public init() {}

    public func classify(stderr: String) -> ClassifiedDownloadError {
        let lower = stderr.lowercased()
        let category: DownloadErrorCategory
        let message: String

        if lower.contains("could not copy") && lower.contains("cookie")
            || lower.contains("failed to decrypt") && lower.contains("cookie")
            || lower.contains("cookie database") && lower.contains("permission") {
            category = .authenticationRequired
            message = "No se ha podido leer la sesión del navegador. Cierra el navegador, revisa los permisos de macOS o selecciona un archivo cookies.txt autorizado."
        } else if lower.contains("http error 403") || lower.contains("403: forbidden") {
            category = .network
            message = "El servidor multimedia ha rechazado temporalmente la transferencia. ZEUVE ya ha probado las rutas públicas disponibles; vuelve a analizar el enlace y reintenta la descarga."
        } else if lower.contains("po token") || lower.contains("missing pot") || lower.contains("sabr-only") {
            category = .extractionFailed
            message = "YouTube no ha entregado un formato público compatible con las rutas anónimas disponibles. Vuelve a analizar el enlace antes de reintentar."
        } else if lower.contains("terminó sin producir archivos") || lower.contains("no results for") {
            category = .extractionFailed
            message = "Los motores disponibles han terminado sin generar ningún archivo. Vuelve a analizar el enlace y reintenta; si continúa, abre los registros para consultar la referencia técnica."
        } else if lower.contains("private video") {
            category = .unavailable
            message = "El contenido es privado."
        } else if lower.contains("profile") && (
            lower.contains("does not exist")
                || lower.contains("seems to exist, but could not be loaded")
                || lower.contains("graphql query returned none")
        ) {
            category = .profileUnverified
            message = "Instagram no ha permitido comprobar el perfil. Este resultado no confirma que el perfil no exista; puede deberse a una sesión necesaria, una respuesta bloqueada o una limitación temporal."
        } else if lower.contains("video unavailable") {
            category = .unavailable
            message = "El contenido no está disponible."
        } else if lower.contains("you need to log in")
            || lower.contains("login required")
            || lower.contains("loginrequiredexception")
            || lower.contains("stories require authentication")
            || lower.contains("requires authentication")
            || lower.contains("authentication required")
            || lower.contains("challenge_required")
            || lower.contains("checkpoint")
            || lower.contains("sign in")
            || lower.contains("login") {
            category = .authenticationRequired
            message = "Instagram o el servicio de origen exige una sesión válida. Pega una sesión temporal o selecciona un archivo cookies.txt autorizado y vuelve a analizar el enlace."
        } else if lower.contains("geo") || lower.contains("country") {
            category = .geoRestricted
            message = "El contenido parece estar restringido por región."
        } else if lower.contains("drm") {
            category = .drmProtected
            message = "El contenido utiliza DRM y ZEUVE no intenta eludirlo."
        } else if lower.contains("network")
            || lower.contains("timed out")
            || lower.contains("too many requests")
            || lower.contains("429")
            || lower.contains("connection") {
            category = .network
            message = "No se ha podido completar la conexión con el servicio remoto."
        } else {
            category = .extractionFailed
            message = "No se ha podido extraer contenido multimedia compatible de la URL."
        }
        return .init(
            category: category,
            userMessage: message,
            technicalReference: String(SHA256Digest.short(stderr))
        )
    }
}

private enum SHA256Digest {
    static func short(_ value: String) -> String {
        // Referencia no reversible y estable para relacionar el resumen con el registro local.
        var hash: UInt64 = 1469598103934665603
        for byte in value.utf8 { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
        return String(format: "YT-%016llX", hash)
    }
}
