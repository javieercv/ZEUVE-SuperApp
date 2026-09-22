import Foundation

public enum EngineArchitecture: String, Codable, Sendable, CaseIterable {
    case arm64
    case universal

    public var spanishName: String {
        switch self {
        case .arm64: return "Apple Silicon (ARM64)"
        case .universal: return "Universal (ARM64 e Intel)"
        }
    }
}

public enum EngineRequirement: String, Codable, Sendable {
    case required
    case optional
}

public struct EngineDescriptor: Codable, Sendable, Equatable, Identifiable {
    public let name: String
    public let executable: String
    public let relativePath: String
    public let version: String
    public let architecture: EngineArchitecture
    public let sha256: String
    public let source: String
    public let licenseFile: String
    public let purpose: String
    public let diagnosticArguments: [String]
    public let size: Int64
    public let requirement: EngineRequirement

    public var id: String { name }

    public init(
        name: String,
        executable: String,
        relativePath: String,
        version: String,
        architecture: EngineArchitecture,
        sha256: String,
        source: String,
        licenseFile: String,
        purpose: String,
        diagnosticArguments: [String],
        size: Int64,
        requirement: EngineRequirement
    ) {
        self.name = name
        self.executable = executable
        self.relativePath = relativePath
        self.version = version
        self.architecture = architecture
        self.sha256 = sha256.lowercased()
        self.source = source
        self.licenseFile = licenseFile
        self.purpose = purpose
        self.diagnosticArguments = diagnosticArguments
        self.size = size
        self.requirement = requirement
    }
}

public struct EngineManifest: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let engines: [EngineDescriptor]

    public init(schemaVersion: Int = 1, engines: [EngineDescriptor]) {
        self.schemaVersion = schemaVersion
        self.engines = engines
    }

    public func validate() throws {
        guard schemaVersion == 1 else { throw EngineRegistryError.unsupportedManifestSchema(schemaVersion) }
        var names = Set<String>()
        for engine in engines {
            guard names.insert(engine.name).inserted else { throw EngineRegistryError.duplicateEngine(engine.name) }
            guard !engine.name.isEmpty,
                  !engine.executable.isEmpty,
                  !engine.relativePath.isEmpty,
                  !engine.version.isEmpty,
                  engine.sha256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil,
                  engine.size >= 0 else {
                throw EngineRegistryError.invalidDescriptor(engine.name)
            }
            guard Self.isSafeRelativePath(engine.relativePath),
                  Self.isSafeRelativePath(engine.licenseFile) else {
                throw EngineRegistryError.invalidDescriptor(engine.name)
            }
        }
    }

    private static func isSafeRelativePath(_ value: String) -> Bool {
        guard !value.isEmpty, !value.hasPrefix("/"), !value.hasPrefix("~") else { return false }
        let components = value.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.isEmpty else { return false }
        return components.allSatisfy { component in
            !component.isEmpty && component != "." && component != ".." && !component.contains("\\")
        }
    }
}

public enum EngineDiagnosticState: String, Codable, Sendable, Equatable {
    case ready
    case missing
    case hashMismatch
    case wrongArchitecture
    case notExecutable
    case versionMismatch
    case launchFailed
    case missingDynamicDependency
    case invalidManifest
    case unsupportedPlatform
}

public struct EngineDiagnostic: Codable, Sendable, Equatable, Identifiable {
    public let descriptor: EngineDescriptor
    public let state: EngineDiagnosticState
    public let message: String
    public let detectedVersion: String?
    public let dynamicDependencies: [String]
    public let technicalDetails: [String]

    public var id: String { descriptor.name }
    public var isReady: Bool { state == .ready }

    public init(
        descriptor: EngineDescriptor,
        state: EngineDiagnosticState,
        message: String,
        detectedVersion: String? = nil,
        dynamicDependencies: [String] = [],
        technicalDetails: [String] = []
    ) {
        self.descriptor = descriptor
        self.state = state
        self.message = message
        self.detectedVersion = detectedVersion
        self.dynamicDependencies = dynamicDependencies
        self.technicalDetails = technicalDetails
    }

    private enum CodingKeys: String, CodingKey {
        case descriptor
        case state
        case message
        case detectedVersion
        case dynamicDependencies
        case technicalDetails
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        descriptor = try container.decode(EngineDescriptor.self, forKey: .descriptor)
        state = try container.decode(EngineDiagnosticState.self, forKey: .state)
        message = try container.decode(String.self, forKey: .message)
        detectedVersion = try container.decodeIfPresent(String.self, forKey: .detectedVersion)
        dynamicDependencies = try container.decodeIfPresent([String].self, forKey: .dynamicDependencies) ?? []
        technicalDetails = try container.decodeIfPresent([String].self, forKey: .technicalDetails) ?? []
    }
}

public enum EngineRegistryError: LocalizedError, Equatable {
    case manifestMissing
    case unsupportedManifestSchema(Int)
    case duplicateEngine(String)
    case invalidDescriptor(String)
    case unknownEngine(String)
    case unsafePath(String)
    case missingEngine(String)
    case requiredEnginesUnavailable([String])

    public var errorDescription: String? {
        switch self {
        case .manifestMissing: return "No se encuentra el manifiesto de motores incluidos."
        case .unsupportedManifestSchema(let value): return "El esquema del manifiesto de motores no es compatible: \(value)."
        case .duplicateEngine(let name): return "El motor \(name) aparece duplicado en el manifiesto."
        case .invalidDescriptor(let name): return "La descripción del motor \(name) no es válida."
        case .unknownEngine(let name): return "El motor \(name) no está registrado."
        case .unsafePath(let path): return "La ruta del motor no es segura: \(path)."
        case .missingEngine(let name): return "No se encuentra el motor obligatorio \(name)."
        case .requiredEnginesUnavailable(let names): return "No están disponibles los motores obligatorios: \(names.joined(separator: ", "))."
        }
    }
}
