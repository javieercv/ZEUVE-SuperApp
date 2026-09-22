import Foundation
#if os(macOS)
import Darwin
#endif

public struct DownloadOriginMetadataCommandBuilder: Sendable {
    public init() {}

    public func arguments(
        input: URL,
        output: URL,
        origin: DownloadPageOrigin,
        includeDownloadDate: Bool,
        generatedAt: Date = Date()
    ) -> [String] {
        let sourceURL = UniversalURLNormalizer.provenanceURL(origin.pageURL).absoluteString
        var details = ["Origen: \(sourceURL)", "Dominio: \(origin.domain)"]
        if let identifier = origin.pageIdentifier, !identifier.isEmpty {
            details.append("ID de página: \(identifier)")
        }
        let readable = details.joined(separator: "\n")

        var arguments = [
            "-hide_banner", "-loglevel", "error", "-nostdin", "-y",
            "-i", input.path,
            "-map", "0",
            "-map_metadata", "0",
            "-c", "copy",
            "-metadata", "source=\(sourceURL)",
            "-metadata", "website=\(sourceURL)",
            "-metadata", "comment=\(readable)",
            "-metadata", "description=\(readable)",
            "-metadata", "zeuve_source_domain=\(origin.domain)",
        ]
        if let identifier = origin.pageIdentifier, !identifier.isEmpty {
            arguments += ["-metadata", "zeuve_source_page_id=\(identifier)"]
        }
        if includeDownloadDate {
            arguments += ["-metadata", "date=\(ISO8601DateFormatter().string(from: generatedAt))"]
        }
        if ["mp4", "mov", "m4v", "m4a"].contains(output.pathExtension.lowercased()) {
            arguments += ["-movflags", "use_metadata_tags"]
        }
        arguments.append(output.path)
        return arguments
    }

    public func verificationArguments(file: URL) -> [String] {
        [
            "-v", "error",
            "-show_entries", "format=duration:format_tags=source,website,comment,description,zeuve_source_domain,zeuve_source_page_id,date",
            "-of", "json",
            file.path,
        ]
    }
}

public enum MacOSWhereFromWriter {
    public static func apply(originURL: URL, to file: URL) throws {
        let cleanURL = UniversalURLNormalizer.provenanceURL(originURL).absoluteString
        #if os(macOS)
        let propertyList = try PropertyListSerialization.data(
            fromPropertyList: [cleanURL],
            format: .binary,
            options: 0
        )
        let result = file.path.withCString { path in
            "com.apple.metadata:kMDItemWhereFroms".withCString { name in
                propertyList.withUnsafeBytes { bytes in
                    setxattr(path, name, bytes.baseAddress, bytes.count, 0, 0)
                }
            }
        }
        guard result == 0 else {
            throw NSError(
                domain: "com.zeuve.universal-downloader.where-from",
                code: Int(errno),
                userInfo: [NSLocalizedDescriptionKey: "macOS no ha permitido guardar el atributo «De dónde»."]
            )
        }
        #else
        throw NSError(
            domain: "com.zeuve.universal-downloader.where-from",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "El atributo «De dónde» solo está disponible en macOS."]
        )
        #endif
    }
}
