import Foundation

public struct YouTubeClassifiedError: Sendable, Equatable {
    public let userMessage: String
    public let technicalReference: String
}

public struct YouTubeErrorClassifier: Sendable {
    public init() {}
    public func classify(stderr: String) -> YouTubeClassifiedError {
        let lower = stderr.lowercased()
        let message: String
        if lower.contains("private video") { message = "El vídeo es privado." }
        else if lower.contains("video unavailable") { message = "El vídeo no está disponible." }
        else if lower.contains("sign in") || lower.contains("login") { message = "YouTube requiere iniciar sesión. Puedes seleccionar un archivo cookies.txt autorizado." }
        else if lower.contains("geo") || lower.contains("country") { message = "El contenido parece estar restringido por región." }
        else if lower.contains("drm") { message = "El contenido utiliza DRM y ZEUVE no intenta eludirlo." }
        else if lower.contains("network") || lower.contains("timed out") { message = "No se ha podido completar la conexión con YouTube." }
        else { message = "yt-dlp no ha podido completar la operación." }
        return .init(userMessage: message, technicalReference: String(SHA256Digest.short(stderr)))
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
