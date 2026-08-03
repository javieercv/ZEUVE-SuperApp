import Foundation

public struct YouTubeFilenamePolicy: Sendable {
    public init() {}

    public func sanitize(_ raw: String, maximumUTF8Bytes: Int = 180) throws -> String {
        var value = raw.precomposedStringWithCanonicalMapping
        value = String(value.unicodeScalars.map { scalar in
            if scalar.value < 32 || scalar.value == 127 { return " " }
            return CharacterSet(charactersIn: "/:").contains(scalar) ? "-" : String(scalar)
        }.joined())
        value = value.replacingOccurrences(of: "..", with: ".")
        value = value.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        while value.hasPrefix(".") { value.removeFirst() }
        value = value.replacingOccurrences(of: "\\", with: "-")
        guard !value.isEmpty, value != ".", value != "..", !value.contains("/") else { throw YouTubeDownloaderError.unsafeOutputName }
        while value.utf8.count > maximumUTF8Bytes, !value.isEmpty { value.removeLast() }
        value = value.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        guard !value.isEmpty else { throw YouTubeDownloaderError.unsafeOutputName }
        return value
    }

    public func automaticRename(for desired: URL, fileManager: FileManager = .default) throws -> URL {
        guard fileManager.fileExists(atPath: desired.path) else { return desired }
        let directory = desired.deletingLastPathComponent()
        let ext = desired.pathExtension
        let base = desired.deletingPathExtension().lastPathComponent
        for index in 2...10_000 {
            let name = ext.isEmpty ? "\(base) (\(index))" : "\(base) (\(index)).\(ext)"
            let candidate = directory.appendingPathComponent(name)
            if !fileManager.fileExists(atPath: candidate.path) { return candidate }
        }
        throw YouTubeDownloaderError.unsafeOutputName
    }
}
