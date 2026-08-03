import Foundation

public struct EngineRegistry: Sendable {
    public let resourceRoot: URL
    public let manifest: EngineManifest

    public init(resourceRoot: URL, manifest: EngineManifest) throws {
        self.resourceRoot = resourceRoot.standardizedFileURL
        self.manifest = manifest
        try manifest.validate()
    }

    public init(resourceRoot: URL) throws {
        let manifestURL = resourceRoot.appendingPathComponent("engines.json", isDirectory: false)
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw EngineRegistryError.manifestMissing
        }
        let manifest = try JSONDecoder().decode(EngineManifest.self, from: Data(contentsOf: manifestURL))
        try self.init(resourceRoot: resourceRoot, manifest: manifest)
    }

    public static func bundled(bundle: Bundle = .main) throws -> EngineRegistry {
        guard let root = bundle.resourceURL?.appendingPathComponent("Engines", isDirectory: true) else {
            throw EngineRegistryError.manifestMissing
        }
        return try EngineRegistry(resourceRoot: root)
    }

    public func descriptor(named name: String) throws -> EngineDescriptor {
        guard let descriptor = manifest.engines.first(where: { $0.name == name }) else {
            throw EngineRegistryError.unknownEngine(name)
        }
        return descriptor
    }

    public func executableURL(named name: String) throws -> URL {
        let descriptor = try descriptor(named: name)
        let candidate = resourceRoot.appendingPathComponent(descriptor.relativePath).standardizedFileURL
        let root = resourceRoot.resolvingSymlinksInPath().standardizedFileURL
        let resolved = candidate.resolvingSymlinksInPath().standardizedFileURL
        let prefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard resolved.path.hasPrefix(prefix) else { throw EngineRegistryError.unsafePath(candidate.path) }
        return candidate
    }

    public func licenseURL(for descriptor: EngineDescriptor) throws -> URL {
        let candidate = resourceRoot.appendingPathComponent(descriptor.licenseFile).standardizedFileURL
        let root = resourceRoot.resolvingSymlinksInPath().standardizedFileURL
        let resolved = candidate.resolvingSymlinksInPath().standardizedFileURL
        let prefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard resolved.path.hasPrefix(prefix) else { throw EngineRegistryError.unsafePath(candidate.path) }
        return candidate
    }

    public func requiredEngineNames() -> [String] {
        manifest.engines.filter { $0.requirement == .required }.map(\.name)
    }
}
