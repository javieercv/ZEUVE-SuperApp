import Foundation

public enum ModulePermission: String, Codable, CaseIterable, Sendable {
    case readUserSelectedFiles
    case writeUserSelectedFolder
    case persistentFolderAccess
    case networkAccess
    case executeBundledTools
    case webContent
    case browserCookies
    case clipboard
    case openExternalApplications
}

public enum ModuleCapability: String, Codable, CaseIterable, Sendable {
    case preview
    case progress
    case cancellation
    case history
    case presets
    case favorites
    case undo
    case dragAndDrop
    case diagnostics
}

public enum ModuleTechnology: String, Codable, Sendable {
    case swift
    case python
    case rust
    case executable
    case web
    case mixed
}

public enum ModuleExecutionMode: String, Codable, Sendable {
    case builtIn
    case isolatedProcess
}

public struct ModulePresentation: Codable, Sendable, Equatable {
    public let systemImage: String
    public let category: String
    public let order: Int

    public init(systemImage: String, category: String, order: Int) {
        self.systemImage = systemImage
        self.category = category
        self.order = order
    }
}

public struct ModuleManifest: Codable, Identifiable, Sendable, Equatable {
    public let schemaVersion: Int
    public let identifier: String
    public let name: String
    public let summary: String
    public let version: String
    public let minimumZEUVEVersion: String
    public let moduleAPI: String
    public let technology: ModuleTechnology
    public let executionMode: ModuleExecutionMode
    public let permissions: [ModulePermission]
    public let capabilities: [ModuleCapability]
    public let presentation: ModulePresentation

    public var id: String { identifier }

    public init(
        schemaVersion: Int = 1,
        identifier: String,
        name: String,
        summary: String,
        version: String,
        minimumZEUVEVersion: String,
        moduleAPI: String = "1.0",
        technology: ModuleTechnology,
        executionMode: ModuleExecutionMode,
        permissions: [ModulePermission],
        capabilities: [ModuleCapability],
        presentation: ModulePresentation
    ) {
        self.schemaVersion = schemaVersion
        self.identifier = identifier
        self.name = name
        self.summary = summary
        self.version = version
        self.minimumZEUVEVersion = minimumZEUVEVersion
        self.moduleAPI = moduleAPI
        self.technology = technology
        self.executionMode = executionMode
        self.permissions = permissions
        self.capabilities = capabilities
        self.presentation = presentation
    }

    public func validate() throws {
        guard schemaVersion == 1 else { throw ModuleManifestError.unsupportedSchema(schemaVersion) }
        guard identifier.range(of: #"^[a-zA-Z0-9]+([.-][a-zA-Z0-9]+)+$"#, options: .regularExpression) != nil else {
            throw ModuleManifestError.invalidIdentifier(identifier)
        }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ModuleManifestError.emptyName
        }
        guard Self.isSemanticVersion(version), Self.isSemanticVersion(minimumZEUVEVersion) else {
            throw ModuleManifestError.invalidVersion
        }
        guard moduleAPI == "1.0" else { throw ModuleManifestError.unsupportedModuleAPI(moduleAPI) }
    }

    private static func isSemanticVersion(_ value: String) -> Bool {
        value.range(of: #"^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$"#, options: .regularExpression) != nil
    }
}

public enum ModuleManifestError: LocalizedError, Equatable {
    case unsupportedSchema(Int)
    case invalidIdentifier(String)
    case emptyName
    case invalidVersion
    case unsupportedModuleAPI(String)
    case duplicateIdentifier(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let value): return "Versión de manifiesto no compatible: \(value)."
        case .invalidIdentifier(let value): return "El identificador del módulo no es válido: \(value)."
        case .emptyName: return "El módulo debe tener un nombre."
        case .invalidVersion: return "La versión del módulo no utiliza el formato MAJOR.MINOR.PATCH."
        case .unsupportedModuleAPI(let value): return "La versión de la API de módulos no es compatible: \(value)."
        case .duplicateIdentifier(let value): return "Ya existe un módulo con el identificador \(value)."
        }
    }
}

public actor ModuleRegistry {
    private var manifests: [String: ModuleManifest] = [:]

    public init() {}

    public func register(_ manifest: ModuleManifest) throws {
        try manifest.validate()
        guard manifests[manifest.identifier] == nil else {
            throw ModuleManifestError.duplicateIdentifier(manifest.identifier)
        }
        manifests[manifest.identifier] = manifest
    }

    public func replace(_ manifest: ModuleManifest) throws {
        try manifest.validate()
        manifests[manifest.identifier] = manifest
    }

    public func manifest(identifier: String) -> ModuleManifest? {
        manifests[identifier]
    }

    public func all() -> [ModuleManifest] {
        manifests.values.sorted {
            if $0.presentation.order == $1.presentation.order { return $0.name < $1.name }
            return $0.presentation.order < $1.presentation.order
        }
    }
}
