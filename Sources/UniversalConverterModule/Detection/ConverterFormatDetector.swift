import Foundation
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

public struct ConverterFormatDetector: Sendable {
    private static let unsupportedOfficeExtensions: Set<String> = [
        "doc", "docx", "xls", "xlsx", "ppt", "pptx", "odt", "ods", "odp", "rtf"
    ]

    public init() {}

    public func detect(url: URL, maximumSampleBytes: Int = 256 * 1_024) throws -> ConverterFormat {
        try detectDetailed(url: url, maximumSampleBytes: maximumSampleBytes).detectedFormat
    }

    public func detectDetailed(url: URL, maximumSampleBytes: Int = 256 * 1_024) throws -> ConverterFormatDetection {
        if Self.unsupportedOfficeExtensions.contains(url.pathExtension.lowercased()) {
            return unsupportedOfficeDetection(filename: url.lastPathComponent)
        }
        let extensionFormat = ConverterFormat.from(pathExtension: url.pathExtension)
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let sample = try handle.read(upToCount: maximumSampleBytes) ?? Data()
        var contentFormat = detectContent(sample: sample, extensionHint: extensionFormat)
        var evidence: [ConverterDetectionEvidence] = []
        if contentFormat != .unknown { evidence.append(.signature) }

        if contentFormat == .zip {
            if let containerFormat = try? detectZIPContainer(url: url) {
                contentFormat = containerFormat
                evidence = [.signature, .containerStructure]
            }
        }

        let typeInfo = uniformTypeInfo(for: url)
        if typeInfo.uti != nil { evidence.append(.uniformType) }
        if typeInfo.mime != nil { evidence.append(.mime) }

        let resolved: ConverterFormat
        let confidence: ConverterDetectionConfidence
        if contentFormat != .unknown {
            resolved = contentFormat
            confidence = evidence.contains(.containerStructure) ? .certain : .high
        } else if extensionFormat != .unknown {
            resolved = extensionFormat
            evidence.append(.extensionValue)
            confidence = .low
        } else {
            resolved = .unknown
            confidence = .unknown
        }

        let warning: String?
        if extensionFormat != .unknown, resolved != .unknown, extensionFormat != resolved {
            warning = "La extensión indica \(extensionFormat.displayName), pero el contenido se ha detectado como \(resolved.displayName). Se utilizará el formato real."
        } else if confidence == .low {
            warning = "No se ha podido confirmar el formato mediante el contenido; solo coincide la extensión."
        } else {
            warning = nil
        }

        return ConverterFormatDetection(
            extensionFormat: extensionFormat,
            detectedFormat: resolved,
            confidence: confidence,
            evidence: Array(Set(evidence)),
            uniformTypeIdentifier: typeInfo.uti,
            mimeType: typeInfo.mime,
            warning: warning
        )
    }

    public func detect(sample: Data, filename: String) -> ConverterFormat {
        detectDetailed(sample: sample, filename: filename).detectedFormat
    }

    public func detectDetailed(sample: Data, filename: String) -> ConverterFormatDetection {
        if Self.unsupportedOfficeExtensions.contains(URL(fileURLWithPath: filename).pathExtension.lowercased()) {
            return unsupportedOfficeDetection(filename: filename)
        }
        let extensionFormat = ConverterFormat.from(pathExtension: URL(fileURLWithPath: filename).pathExtension)
        let content = detectContent(sample: sample, extensionHint: extensionFormat)
        let resolved = content == .unknown ? extensionFormat : content
        let confidence: ConverterDetectionConfidence = content == .unknown ? (resolved == .unknown ? .unknown : .low) : .high
        let warning: String?
        if extensionFormat != .unknown, content != .unknown, extensionFormat != content {
            warning = "La extensión indica \(extensionFormat.displayName), pero el contenido se ha detectado como \(content.displayName)."
        } else if confidence == .low {
            warning = "No se ha podido confirmar el formato mediante la muestra; solo coincide la extensión."
        } else { warning = nil }
        return .init(
            extensionFormat: extensionFormat,
            detectedFormat: resolved,
            confidence: confidence,
            evidence: content == .unknown ? [.extensionValue] : [.signature],
            mimeType: mimeType(for: resolved),
            warning: warning
        )
    }

    private func detectContent(sample: Data, extensionHint: ConverterFormat) -> ConverterFormat {
        guard !sample.isEmpty else { return .unknown }
        let bytes = [UInt8](sample.prefix(512))

        if starts(bytes, Array("%!PS-Adobe".utf8)), sample.range(of: Data("EPSF".utf8)) != nil { return .eps }
        if starts(bytes, [0x25, 0x50, 0x44, 0x46, 0x2D]) { return .pdf }
        if starts(bytes, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
            return sample.range(of: Data("acTL".utf8)) == nil ? .png : .apng
        }
        if starts(bytes, [0xFF, 0xD8, 0xFF]) { return .jpeg }
        if starts(bytes, Array("GIF87a".utf8)) || starts(bytes, Array("GIF89a".utf8)) { return .gif }
        if starts(bytes, [0x49, 0x49, 0x2A, 0x00]) || starts(bytes, [0x4D, 0x4D, 0x00, 0x2A]) { return .tiff }
        if starts(bytes, [0x42, 0x4D]) { return .bmp }
        if starts(bytes, Array("fLaC".utf8)) { return .flac }
        if starts(bytes, Array("OggS".utf8)) {
            if sample.range(of: Data("OpusHead".utf8)) != nil { return .opus }
            return .ogg
        }
        if starts(bytes, Array("ID3".utf8)) || isMPEGAudioFrame(bytes) { return .mp3 }
        if isAACFrame(bytes) { return .aac }
        if bytes.count >= 12,
           String(decoding: bytes[0..<4], as: UTF8.self) == "RIFF" {
            let kind = String(decoding: bytes[8..<12], as: UTF8.self)
            if kind == "WAVE" { return .wav }
            if kind == "WEBP" { return .webp }
            if kind == "AVI " { return .avi }
        }
        if starts(bytes, [0x1A, 0x45, 0xDF, 0xA3]) {
            return String(data: sample, encoding: .isoLatin1)?.lowercased().contains("webm") != true ? .mkv : .webm
        }
        if starts(bytes, [0x50, 0x4B, 0x03, 0x04]) || starts(bytes, [0x50, 0x4B, 0x05, 0x06]) { return .zip }
        if bytes.count >= 12, String(decoding: bytes[4..<8], as: UTF8.self) == "ftyp" {
            let brand = String(decoding: bytes[8..<min(bytes.count, 64)], as: UTF8.self).lowercased()
            if ["heic", "heix", "hevc", "mif1", "msf1"].contains(where: brand.contains) { return .heic }
            if brand.contains("m4a") || brand.contains("m4b") { return .m4a }
            if brand.contains("qt") { return .mov }
            return .mp4
        }
        if sample.count >= 68, String(data: sample.subdata(in: 60..<68), encoding: .ascii) == "BOOKMOBI" { return .mobi }

        guard let text = String(data: sample.prefix(64 * 1_024), encoding: .utf8) else { return .unknown }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        if lower.contains("<fictionbook") { return .fb2 }
        if lower.hasPrefix("<!doctype html") || lower.hasPrefix("<html") || lower.contains("<body") { return .html }
        if lower.hasPrefix("<?xml"), lower.contains("<svg") || lower.hasPrefix("<svg") { return .svg }
        if lower.hasPrefix("<svg") { return .svg }
        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
            if (try? JSONSerialization.jsonObject(with: Data(trimmed.utf8))) != nil { return .json }
        }
        if lower.hasPrefix("<?xml") || (lower.hasPrefix("<") && lower.contains(">")) { return .xml }
        if looksLikeCSV(trimmed) { return .csv }
        if looksLikeMarkdown(trimmed) { return .markdown }
        return trimmed.isEmpty ? .unknown : .txt
    }

    private func detectZIPContainer(url: URL) throws -> ConverterFormat {
        let reader = ConverterArchiveReader(url: url)
        let catalog = try reader.catalog()
        let paths = Set(catalog.entries.map { $0.path.lowercased() })
        if paths.contains("meta-inf/container.xml") {
            if let mimetype = try? reader.readPrefix(path: "mimetype", maximumBytes: 256),
               String(data: mimetype, encoding: .utf8)?.contains("application/epub+zip") == true { return .epub }
        }
        if let mimetype = try? reader.readPrefix(path: "mimetype", maximumBytes: 256),
           let value = String(data: mimetype, encoding: .utf8)?.lowercased(),
           value.contains("application/epub+zip") { return .epub }
        return .zip
    }

    private func uniformTypeInfo(for url: URL) -> (uti: String?, mime: String?) {
        #if canImport(UniformTypeIdentifiers)
        if let type = UTType(filenameExtension: url.pathExtension) {
            return (type.identifier, type.preferredMIMEType)
        }
        #endif
        let format = ConverterFormat.from(pathExtension: url.pathExtension)
        return (nil, mimeType(for: format))
    }

    private func mimeType(for format: ConverterFormat) -> String? {
        switch format {
        case .png: return "image/png"; case .jpeg: return "image/jpeg"; case .gif: return "image/gif"
        case .webp: return "image/webp"; case .svg: return "image/svg+xml"; case .pdf: return "application/pdf"
        case .mp3: return "audio/mpeg"; case .m4a: return "audio/mp4"; case .wav: return "audio/wav"
        case .mp4: return "video/mp4"; case .mov: return "video/quicktime"; case .mkv: return "video/x-matroska"; case .webm: return "video/webm"
        case .epub: return "application/epub+zip"; case .zip: return "application/zip"
        case .txt, .markdown: return "text/plain"; case .html: return "text/html"; case .csv: return "text/csv"; case .json: return "application/json"; case .xml, .fb2: return "application/xml"
        default: return nil
        }
    }

    private func unsupportedOfficeDetection(filename: String) -> ConverterFormatDetection {
        ConverterFormatDetection(
            extensionFormat: .unknown,
            detectedFormat: .unknown,
            confidence: .unknown,
            evidence: [.extensionValue],
            warning: "\(filename): los formatos ofimáticos no son compatibles con el Conversor."
        )
    }

    private func starts(_ bytes: [UInt8], _ prefix: [UInt8]) -> Bool {
        bytes.count >= prefix.count && Array(bytes.prefix(prefix.count)) == prefix
    }
    private func isMPEGAudioFrame(_ bytes: [UInt8]) -> Bool { bytes.count >= 2 && bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0 }
    private func isAACFrame(_ bytes: [UInt8]) -> Bool { bytes.count >= 2 && bytes[0] == 0xFF && (bytes[1] & 0xF6) == 0xF0 }
    private func looksLikeCSV(_ text: String) -> Bool {
        let lines = text.split(whereSeparator: \.isNewline).prefix(6)
        guard lines.count >= 2 else { return false }
        for separator in [",", ";", "\t"] {
            let counts = lines.map { $0.filter { String($0) == separator }.count }
            if let first = counts.first, first > 0, counts.allSatisfy({ $0 == first }) { return true }
        }
        return false
    }
    private func looksLikeMarkdown(_ text: String) -> Bool {
        let lines = text.split(whereSeparator: \.isNewline).prefix(40)
        let markers = lines.filter { line in
            let value = line.trimmingCharacters(in: .whitespaces)
            return value.hasPrefix("#") || value.hasPrefix("- ") || value.hasPrefix("* ") || value.hasPrefix("> ") || value.contains("](") || value.hasPrefix("```")
        }
        return markers.count >= 2
    }
}
