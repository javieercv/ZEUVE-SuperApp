import Foundation
import ZEUVECore

public enum EngineUpdateChannel: String, Codable, Sendable, CaseIterable, Identifiable {
    case stable
    case experimental
    public var id: String { rawValue }

    public var spanishName: String {
        switch self {
        case .stable: return "Estable"
        case .experimental: return "Experimental / nightly"
        }
    }
}

public struct InstalledEngineOverride: Codable, Sendable, Equatable, Identifiable {
    public let engineName: String
    public let version: String
    public let executableName: String
    public let sha256: String
    public let installedAt: Date
    public let channel: EngineUpdateChannel

    public var id: String { engineName }
}

public enum EngineOverrideError: LocalizedError, Equatable {
    case invalidName
    case invalidVersion
    case sourceMissing
    case sourceNotRegular
    case sourceNotExecutable
    case unsafeDestination
    case hashMismatch
    case activeRecordInvalid

    public var errorDescription: String? {
        switch self {
        case .invalidName: return "El nombre del motor no es válido."
        case .invalidVersion: return "La versión del motor no es válida."
        case .sourceMissing: return "No se encuentra el ejecutable seleccionado."
        case .sourceNotRegular: return "El elemento seleccionado no es un archivo ejecutable normal."
        case .sourceNotExecutable: return "El archivo seleccionado no tiene permiso de ejecución."
        case .unsafeDestination: return "La ubicación del motor no es segura."
        case .hashMismatch: return "El archivo no coincide con el SHA-256 esperado."
        case .activeRecordInvalid: return "El registro del motor activo está dañado."
        }
    }
}

/// Conserva las versiones incluidas con la aplicación y almacena actualizaciones o motores
/// personalizados en Application Support. Nunca modifica Resources/Engines.
public struct EngineOverrideManager: Sendable {
    public static let updateWarning = "Actualizar o sustituir un motor puede cambiar su comportamiento, introducir incompatibilidades o provocar que algunas descargas dejen de funcionar. ZEUVE conservará la versión incluida con la aplicación para que puedas restaurarla."
    public static let experimentalWarning = "Las versiones experimentales o nightly pueden contener cambios sin probar, dejar de ser compatibles o producir resultados inesperados."

    private let fileManagerBox: SendableFileManager
    private var fileManager: FileManager { fileManagerBox.fileManager }
    private let rootOverride: URL?

    public init(fileManager: FileManager = .default, root: URL? = nil) {
        fileManagerBox = SendableFileManager(fileManager)
        rootOverride = root
    }

    public func rootDirectory() throws -> URL {
        let root = try rootOverride ?? AppPaths.applicationSupport(fileManager: fileManager)
            .appendingPathComponent("Engines", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return root.standardizedFileURL
    }

    public func activeOverrides() throws -> [InstalledEngineOverride] {
        let file = try activeFile()
        guard fileManager.fileExists(atPath: file.path) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([InstalledEngineOverride].self, from: Data(contentsOf: file))
    }

    public func activeExecutable(named engineName: String) throws -> URL? {
        guard let record = try activeOverrides().first(where: { $0.engineName == engineName }) else { return nil }
        let root = try rootDirectory().resolvingSymlinksInPath().standardizedFileURL
        let candidate = root
            .appendingPathComponent(record.engineName, isDirectory: true)
            .appendingPathComponent(record.version, isDirectory: true)
            .appendingPathComponent(record.executableName, isDirectory: false)
            .resolvingSymlinksInPath().standardizedFileURL
        let prefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard candidate.path.hasPrefix(prefix) else { throw EngineOverrideError.activeRecordInvalid }
        guard fileManager.isExecutableFile(atPath: candidate.path) else { return nil }
        guard (try? SHA256.hexDigest(fileAt: candidate)) == record.sha256 else { return nil }
        return candidate
    }

    @discardableResult
    public func installLocalExecutable(
        named engineName: String,
        version: String,
        source: URL,
        channel: EngineUpdateChannel,
        expectedSHA256: String? = nil
    ) throws -> InstalledEngineOverride {
        guard Self.safeComponent(engineName) else { throw EngineOverrideError.invalidName }
        guard Self.safeComponent(version) else { throw EngineOverrideError.invalidVersion }
        guard fileManager.fileExists(atPath: source.path) else { throw EngineOverrideError.sourceMissing }
        let values = try source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else { throw EngineOverrideError.sourceNotRegular }
        guard fileManager.isExecutableFile(atPath: source.path) else { throw EngineOverrideError.sourceNotExecutable }
        let sourceHash = try SHA256.hexDigest(fileAt: source)
        if let expectedSHA256, sourceHash.lowercased() != expectedSHA256.lowercased() { throw EngineOverrideError.hashMismatch }

        let root = try rootDirectory()
        let versionFolder = root
            .appendingPathComponent(engineName, isDirectory: true)
            .appendingPathComponent(version, isDirectory: true)
        try fileManager.createDirectory(at: versionFolder, withIntermediateDirectories: true)
        let destination = versionFolder.appendingPathComponent(source.lastPathComponent, isDirectory: false)
        let rootResolved = root.resolvingSymlinksInPath().standardizedFileURL
        let destinationParent = versionFolder.resolvingSymlinksInPath().standardizedFileURL
        let prefix = rootResolved.path.hasSuffix("/") ? rootResolved.path : rootResolved.path + "/"
        guard destinationParent.path.hasPrefix(prefix) else { throw EngineOverrideError.unsafeDestination }

        let temporary = versionFolder.appendingPathComponent(".install-\(UUID().uuidString)")
        try fileManager.copyItem(at: source, to: temporary)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: temporary.path)
        if fileManager.fileExists(atPath: destination.path) { try fileManager.removeItem(at: destination) }
        try fileManager.moveItem(at: temporary, to: destination)
        guard try SHA256.hexDigest(fileAt: destination) == sourceHash else {
            try? fileManager.removeItem(at: destination)
            throw EngineOverrideError.hashMismatch
        }

        let record = InstalledEngineOverride(
            engineName: engineName,
            version: version,
            executableName: destination.lastPathComponent,
            sha256: sourceHash,
            installedAt: Date(),
            channel: channel
        )
        var valuesByName = Dictionary(uniqueKeysWithValues: try activeOverrides().map { ($0.engineName, $0) })
        valuesByName[engineName] = record
        try save(Array(valuesByName.values).sorted { $0.engineName < $1.engineName })
        return record
    }

    public func restoreBundled(named engineName: String) throws {
        var values = try activeOverrides()
        values.removeAll { $0.engineName == engineName }
        try save(values)
    }

    public func removeInstalledVersions(named engineName: String) throws {
        try restoreBundled(named: engineName)
        guard Self.safeComponent(engineName) else { throw EngineOverrideError.invalidName }
        let folder = try rootDirectory().appendingPathComponent(engineName, isDirectory: true)
        if fileManager.fileExists(atPath: folder.path) { try fileManager.removeItem(at: folder) }
    }

    private func activeFile() throws -> URL {
        try rootDirectory().appendingPathComponent("active.json", isDirectory: false)
    }

    private func save(_ records: [InstalledEngineOverride]) throws {
        let data = try JSONEncoder.zeuve.encode(records)
        let destination = try activeFile()
        let temporary = destination.deletingLastPathComponent().appendingPathComponent(".active-\(UUID().uuidString).json")
        try data.write(to: temporary, options: .atomic)
        if fileManager.fileExists(atPath: destination.path) { try fileManager.removeItem(at: destination) }
        try fileManager.moveItem(at: temporary, to: destination)
    }

    private static func safeComponent(_ value: String) -> Bool {
        !value.isEmpty
            && value != "."
            && value != ".."
            && !value.contains("/")
            && !value.contains("\\")
            && value.range(of: "^[A-Za-z0-9._+-]+$", options: .regularExpression) != nil
    }
}

private final class SendableFileManager: @unchecked Sendable {
    let fileManager: FileManager

    init(_ fileManager: FileManager) {
        self.fileManager = fileManager
    }
}

private extension JSONEncoder {
    static var zeuve: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
