import Foundation
import ZEUVEEngines

public struct CalibreCommandBuilder: Sendable {
    public init() {}

    public func request(executable: URL, source: URL, target: ConverterFormat, destination: URL, options: ConverterOperationOptions) throws -> ExternalProcessRequest {
        guard [.epub, .mobi, .azw3, .fb2, .html, .txt, .pdf].contains(target) else {
            throw UniversalConverterError.incompatibleRecipe("Calibre no admite la salida \(target.displayName) en este módulo.")
        }
        var arguments = [source.path, destination.path]
        switch options.quality {
        case .low: arguments += ["--output-profile", "tablet"]
        case .medium: arguments += ["--output-profile", "generic_eink"]
        case .high, .maximum, .custom: arguments += ["--output-profile", "default"]
        }
        if options.metadataPolicy == .removeAll {
            arguments += ["--authors", "", "--title", source.deletingPathExtension().lastPathComponent]
        }
        return ExternalProcessRequest(
            executable: executable,
            arguments: arguments,
            environment: ["LANG": "es_ES.UTF-8", "LC_ALL": "es_ES.UTF-8"],
            workingDirectory: destination.deletingLastPathComponent()
        )
    }
}
