import Foundation
import ZEUVECore

public enum UniversalConverterModuleDefinition {
    public static func manifest() throws -> ModuleManifest {
        #if SWIFT_PACKAGE
        let url = Bundle.module.url(forResource: "manifest", withExtension: "json")
        #else
        let url = Bundle.main.url(forResource: "manifest", withExtension: "json")
        #endif
        guard let url else { throw UniversalConverterError.invalidManifest }
        let manifest = try JSONDecoder().decode(ModuleManifest.self, from: Data(contentsOf: url))
        try manifest.validate()
        return manifest
    }
}
