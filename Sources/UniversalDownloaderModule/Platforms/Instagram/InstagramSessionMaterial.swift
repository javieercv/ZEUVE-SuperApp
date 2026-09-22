import Foundation

public enum InstagramSessionMaterialError: LocalizedError, Equatable {
    case empty
    case unsupportedFormat
    case unsafeCookieName

    public var errorDescription: String? {
        switch self {
        case .empty: return "Pega una cabecera Cookie o el contenido de un archivo cookies.txt."
        case .unsupportedFormat: return "El texto no parece una cabecera Cookie ni un archivo cookies.txt válido."
        case .unsafeCookieName: return "La sesión contiene un nombre de cookie no válido."
        }
    }
}

public enum InstagramSessionMaterial {
    /// Crea un archivo temporal con permisos 0600. El llamador debe eliminarlo al terminar.
    public static func writeSecureTemporaryFile(
        text: String,
        operationID: UUID = UUID(),
        fileManager: FileManager = .default
    ) throws -> URL {
        let normalized = try normalize(text)
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("ZEUVE", isDirectory: true)
            .appendingPathComponent("instagram-session-\(operationID.uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let file = root.appendingPathComponent("session.txt", isDirectory: false)
        try Data(normalized.utf8).write(to: file, options: [.atomic])
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        return file
    }

    /// Convierte una cabecera Cookie pegada a un cookies.txt Netscape compatible con gallery-dl y yt-dlp.
    public static func writeSecureNetscapeTemporaryFile(
        text: String,
        operationID: UUID = UUID(),
        fileManager: FileManager = .default
    ) throws -> URL {
        let normalized = try normalize(text)
        let netscape = try netscapeText(fromNormalized: normalized)
        let file = try makeSecureTemporaryDestination(
            operationID: operationID,
            filename: "cookies.txt",
            fileManager: fileManager
        )
        try Data(netscape.utf8).write(to: file, options: [.atomic])
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        return file
    }

    /// Reserva una ruta temporal privada para una exportación de cookies desde navegador.
    public static func makeSecureTemporaryDestination(
        operationID: UUID = UUID(),
        filename: String = "cookies.txt",
        fileManager: FileManager = .default
    ) throws -> URL {
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("ZEUVE", isDirectory: true)
            .appendingPathComponent("instagram-session-\(operationID.uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        return root.appendingPathComponent(filename, isDirectory: false)
    }

    public static func secureExistingTemporaryFile(_ file: URL, fileManager: FileManager = .default) throws {
        guard fileManager.fileExists(atPath: file.path) else { throw InstagramSessionMaterialError.empty }
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        _ = try NetscapeCookieFile.parse(Data(contentsOf: file))
    }

    public static func normalize(_ text: String) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw InstagramSessionMaterialError.empty }
        if trimmed.contains("# Netscape HTTP Cookie File") || trimmed.contains("# HTTP Cookie File") {
            _ = try NetscapeCookieFile.parse(Data(trimmed.utf8))
            return trimmed + (trimmed.hasSuffix("\n") ? "" : "\n")
        }
        let raw = trimmed.lowercased().hasPrefix("cookie:")
            ? String(trimmed.dropFirst(trimmed.firstIndex(of: ":")!.utf16Offset(in: trimmed) + 1)).trimmingCharacters(in: .whitespaces)
            : trimmed
        let pairs = raw.split(separator: ";", omittingEmptySubsequences: true)
        guard !pairs.isEmpty else { throw InstagramSessionMaterialError.unsupportedFormat }
        var normalizedPairs: [String] = []
        for pair in pairs {
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { throw InstagramSessionMaterialError.unsupportedFormat }
            let name = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard name.range(of: "^[A-Za-z0-9_.$-]+$", options: .regularExpression) != nil else {
                throw InstagramSessionMaterialError.unsafeCookieName
            }
            normalizedPairs.append("\(name)=\(value)")
        }
        guard normalizedPairs.contains(where: { $0.hasPrefix("sessionid=") }) else {
            throw InstagramSessionMaterialError.unsupportedFormat
        }
        return "Cookie: " + normalizedPairs.joined(separator: "; ") + "\n"
    }

    private static func netscapeText(fromNormalized normalized: String) throws -> String {
        if normalized.contains("# Netscape HTTP Cookie File") || normalized.contains("# HTTP Cookie File") {
            return normalized.hasSuffix("\n") ? normalized : normalized + "\n"
        }
        let raw = normalized.lowercased().hasPrefix("cookie:")
            ? String(normalized.dropFirst(normalized.firstIndex(of: ":")!.utf16Offset(in: normalized) + 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            : normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        var lines = ["# Netscape HTTP Cookie File", "# Generated locally by ZEUVE from an explicitly supplied Instagram session."]
        for pair in raw.split(separator: ";", omittingEmptySubsequences: true) {
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { throw InstagramSessionMaterialError.unsupportedFormat }
            let name = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            lines.append(".instagram.com\tTRUE\t/\tTRUE\t0\t\(name)\t\(value)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    public static func removeTemporaryFile(_ file: URL, fileManager: FileManager = .default) {
        let parent = file.deletingLastPathComponent()
        try? fileManager.removeItem(at: parent)
    }
}
