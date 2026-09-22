import Foundation
import ZEUVECore

public enum InstagramFollowersModuleDefinition {
    public static func manifest() throws -> ModuleManifest {
        #if SWIFT_PACKAGE
        let url = Bundle.module.url(forResource: "manifest", withExtension: "json")
        #else
        let url = Bundle.main.url(forResource: "manifest", withExtension: "json")
        #endif
        return try ModuleManifestLoader.load(from: url, missingResourceError: InstagramFollowersError.invalidManifest)
    }
}
