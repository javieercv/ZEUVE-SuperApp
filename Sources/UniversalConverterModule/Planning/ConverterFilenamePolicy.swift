import Foundation

public struct ConverterFilenamePolicy: Sendable {
    public init() {}

    public func sanitize(_ raw: String, maximumUTF8Bytes: Int = 180) throws -> String {
        var value = raw.precomposedStringWithCanonicalMapping
        value = String(value.unicodeScalars.map { scalar in
            if scalar.value < 32 || scalar.value == 127 { return " " }
            if CharacterSet(charactersIn: "/:\\").contains(scalar) { return "-" }
            return String(scalar)
        }.joined())
        value = value.replacingOccurrences(of: "..", with: ".")
        value = value.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        while value.hasPrefix(".") { value.removeFirst() }
        while value.utf8.count > maximumUTF8Bytes, !value.isEmpty { value.removeLast() }
        value = value.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        guard !value.isEmpty, value != ".", value != "..", !value.contains("/") else {
            throw UniversalConverterError.unsafePath(raw)
        }
        return value
    }

    public func convertedBaseName(
        for sourceBaseName: String,
        style: ConverterFilenameStyle,
        prefix: String = "ZEUVE - Converted - ",
        suffix: String = "",
        separator: String = " - "
    ) throws -> String {
        let source = try sanitize(sourceBaseName)
        switch style {
        case .prefix:
            return try sanitize(prefix + source + suffix)
        case .suffix:
            let actualSuffix = suffix.isEmpty ? "converted" : suffix
            return try sanitize(source + separator + actualSuffix)
        }
    }

    public func convertedFilename(
        sourceName: String,
        targetFormat: ConverterFormat,
        style: ConverterFilenameStyle,
        prefix: String = "ZEUVE - Converted - ",
        suffix: String = "",
        separator: String = " - "
    ) throws -> String {
        let sourceURL = URL(fileURLWithPath: sourceName)
        let base = sourceURL.deletingPathExtension().lastPathComponent
        return try convertedBaseName(for: base, style: style, prefix: prefix, suffix: suffix, separator: separator) + "." + targetFormat.fileExtension
    }

    public func safeRelativeDirectory(_ raw: String) throws -> String {
        let normalized = try ConverterSafePath.normalize(raw)
        guard !normalized.isEmpty else { return "" }
        return try normalized.split(separator: "/").map { try sanitize(String($0), maximumUTF8Bytes: 160) }.joined(separator: "/")
    }

    public func automaticRename(for desired: URL, fileManager: FileManager = .default) throws -> URL {
        guard fileManager.fileExists(atPath: desired.path) else { return desired }
        let directory = desired.deletingLastPathComponent()
        let ext = desired.pathExtension
        var base = desired.deletingPathExtension().lastPathComponent
        if !base.localizedCaseInsensitiveContains("converted") { base += " - converted" }
        for index in 1...10_000 {
            let numberedBase = index == 1 ? base : "\(base) \(index)"
            let name = ext.isEmpty ? numberedBase : "\(numberedBase).\(ext)"
            let candidate = directory.appendingPathComponent(name, isDirectory: false)
            if !fileManager.fileExists(atPath: candidate.path) { return candidate }
        }
        throw UniversalConverterError.outputConflict(desired.lastPathComponent)
    }
}
