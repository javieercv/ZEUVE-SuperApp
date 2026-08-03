import Foundation
import ZEUVEEngines

public struct PandocCommandBuilder: Sendable {
    public init() {}

    public func request(executable: URL, source: URL, target: ConverterFormat, destination: URL, metadataPolicy: ConverterMetadataPolicy) throws -> ExternalProcessRequest {
        guard [.txt, .markdown, .html, .epub].contains(target) else {
            throw UniversalConverterError.incompatibleRecipe("Pandoc no admite la salida \(target.displayName) con los motores aprobados.")
        }
        var arguments = [source.path, "--standalone", "--output", destination.path]
        switch metadataPolicy {
        case .allCompatible:
            break
        case .essentialOnly:
            arguments += ["--metadata", "lang=es"]
        case .removeAll:
            arguments += ["--metadata", "title=", "--metadata", "author=", "--metadata", "date="]
        }
        return ExternalProcessRequest(
            executable: executable,
            arguments: arguments,
            environment: ["LANG": "es_ES.UTF-8", "LC_ALL": "es_ES.UTF-8"],
            workingDirectory: destination.deletingLastPathComponent()
        )
    }
}
