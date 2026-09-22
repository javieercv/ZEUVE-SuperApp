import Foundation
import ZEUVECore

public let cleanerModuleIdentifier = "com.zeuve.cleaner"

public enum CleanerModuleDefinition {
    public static func manifest() throws -> ModuleManifest {
        guard let url = Bundle.module.url(forResource: "manifest", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let manifest = try JSONDecoder().decode(ModuleManifest.self, from: Data(contentsOf: url))
        try manifest.validate()
        return manifest
    }
}
