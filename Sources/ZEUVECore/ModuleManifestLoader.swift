import Foundation

public enum ModuleManifestLoader {
    public static func load(
        from url: URL?,
        missingResourceError: @autoclosure () -> any Error
    ) throws -> ModuleManifest {
        guard let url else { throw missingResourceError() }
        let manifest = try JSONDecoder().decode(ModuleManifest.self, from: Data(contentsOf: url))
        try manifest.validate()
        return manifest
    }
}
