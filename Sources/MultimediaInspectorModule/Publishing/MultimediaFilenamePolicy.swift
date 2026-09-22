import Foundation

public struct MultimediaFilenamePolicy: Sendable {
    public init() {}
    public func suggestedName(original: URL, container: EditableMediaContainer, suffix: String) -> String {
        original.deletingPathExtension().lastPathComponent + suffix + "." + container.fileExtension
    }
    public func conflictFreeURL(_ proposed: URL, protectedPaths: Set<String>, fileManager: FileManager = .default) throws -> URL {
        var candidate = proposed.standardizedFileURL
        var number = 2
        while fileManager.fileExists(atPath: candidate.path) || protectedPaths.contains(Self.canonical(candidate)) {
            let base = proposed.deletingPathExtension().lastPathComponent
            candidate = proposed.deletingLastPathComponent().appendingPathComponent("\(base) \(number).\(proposed.pathExtension)")
            number += 1
            if number > 10_000 { throw MultimediaInspectorError.invalidOutput("no se ha encontrado un nombre de salida libre") }
        }
        return candidate
    }
    public static func canonical(_ url: URL) -> String { url.standardizedFileURL.resolvingSymlinksInPath().path }
}
