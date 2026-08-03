import Foundation
import ZEUVECore

public enum ChatAnalyzerModuleDefinition {
    public static func manifest() throws -> ModuleManifest {
        #if SWIFT_PACKAGE
        let url = Bundle.module.url(forResource: "manifest", withExtension: "json")
        #else
        let url = Bundle.main.url(forResource: "manifest", withExtension: "json")
        #endif
        guard let url else { throw ChatAnalyzerError.storageUnavailable("No se encuentra el manifiesto del módulo.") }
        let manifest = try JSONDecoder().decode(ModuleManifest.self, from: Data(contentsOf: url))
        try manifest.validate()
        return manifest
    }
}
