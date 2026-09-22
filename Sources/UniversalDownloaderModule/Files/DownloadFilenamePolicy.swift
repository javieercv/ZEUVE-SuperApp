import Foundation

public struct DownloadFilenamePolicy: Sendable {
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
        guard !value.isEmpty, value != ".", value != "..", !value.contains("/") else { throw UniversalDownloaderError.unsafeOutputName }
        while value.utf8.count > maximumUTF8Bytes, !value.isEmpty { value.removeLast() }
        value = value.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        guard !value.isEmpty else { throw UniversalDownloaderError.unsafeOutputName }
        return value
    }

    public func pageDiscoveredBaseNames(for titles: [String], detectedTitles: [String]? = nil) throws -> [String] {
        guard !titles.isEmpty else { return [] }
        let sanitized = try titles.map { try sanitize($0, maximumUTF8Bytes: 170) }
        let context = try (detectedTitles ?? titles).map { try sanitize($0, maximumUTF8Bytes: 170) }
        let useStripped = try pageSuffixBasesToStrip(in: context)
        let bases = try sanitized.map { value -> String in
            let parsed = try parsePageSuffix(value)
            if let stripped = parsed.stripped, useStripped.contains(stripped) { return stripped }
            return parsed.exact
        }
        let counts = Dictionary(grouping: bases, by: { $0 }).mapValues(\.count)
        var positions: [String: Int] = [:]
        return bases.map { base in
            guard (counts[base] ?? 0) > 1 else { return base }
            positions[base, default: 0] += 1
            return "\(base) (\(positions[base]!))"
        }
    }

    private func pageSuffixBasesToStrip(in values: [String]) throws -> Set<String> {
        let parsed = try values.map(parsePageSuffix)
        var strippedGroups: [String: [Int]] = [:]
        for (index, value) in parsed.enumerated() {
            if let stripped = value.stripped { strippedGroups[stripped, default: []].append(index) }
        }
        var result = Set<String>()
        for (base, indices) in strippedGroups where indices.count > 1 {
            let numbers = indices.compactMap { parsed[$0].number }
            let distinct = Set(numbers)
            let looksExtractorGenerated = distinct.count > 1 || (numbers.max() ?? Int.max) <= max(100, indices.count * 10)
            if looksExtractorGenerated { result.insert(base) }
        }
        return result
    }

    private func parsePageSuffix(_ value: String) throws -> (exact: String, stripped: String?, number: Int?) {
        let expression = try NSRegularExpression(pattern: #"^(.*?)[\s]+\(([0-9]+)\)$"#)
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = expression.firstMatch(in: value, range: range),
              let baseRange = Range(match.range(at: 1), in: value),
              let numberRange = Range(match.range(at: 2), in: value),
              let number = Int(value[numberRange]) else {
            return (value, nil, nil)
        }
        let base = String(value[baseRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (value, base.isEmpty ? nil : base, number)
    }

    public func escapedOutputTemplateLiteral(_ value: String) -> String {
        value.replacingOccurrences(of: "%", with: "%%")
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
        throw UniversalDownloaderError.unsafeOutputName
    }
}
