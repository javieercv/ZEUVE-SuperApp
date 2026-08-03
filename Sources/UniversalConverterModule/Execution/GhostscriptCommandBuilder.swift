import Foundation
import ZEUVEEngines

public struct GhostscriptCommandBuilder: Sendable {
    public init() {}

    public func request(
        executable: URL,
        source: URL,
        target: ConverterFormat,
        destination: URL,
        options: ConverterOperationOptions
    ) throws -> ExternalProcessRequest {
        var arguments = ["-dSAFER", "-dBATCH", "-dNOPAUSE", "-dQUIET", "-P-", "-I-"]
        switch target {
        case .pdf:
            arguments += ["-sDEVICE=pdfwrite", "-dCompatibilityLevel=1.7"]
        case .png:
            arguments += ["-sDEVICE=pngalpha", "-r\(options.pdfRasterDPI)", "-dTextAlphaBits=4", "-dGraphicsAlphaBits=4"]
        case .jpeg:
            arguments += ["-sDEVICE=jpeg", "-r\(options.pdfRasterDPI)", "-dJPEGQ=\(jpegQuality(options.quality))"]
        case .tiff:
            arguments += ["-sDEVICE=tiff24nc", "-r\(options.pdfRasterDPI)"]
        case .bmp:
            arguments += ["-sDEVICE=bmp16m", "-r\(options.pdfRasterDPI)"]
        default:
            throw UniversalConverterError.incompatibleRecipe("Ghostscript no admite la salida \(target.displayName) en este módulo.")
        }
        arguments += ["-sOutputFile=\(destination.path)", "-f", source.path]

        var environment = ["LANG": "es_ES.UTF-8", "LC_ALL": "es_ES.UTF-8"]
        let libraryPaths = ghostscriptLibraryPaths(executable: executable, fileManager: .default)
        if !libraryPaths.isEmpty {
            environment["GS_LIB"] = libraryPaths.map(\.path).joined(separator: ":")
        }

        return ExternalProcessRequest(
            executable: executable,
            arguments: arguments,
            environment: environment,
            workingDirectory: destination.deletingLastPathComponent()
        )
    }

    private func ghostscriptLibraryPaths(executable: URL, fileManager: FileManager) -> [URL] {
        let root = executable.deletingLastPathComponent().deletingLastPathComponent()
        let shareRoot = root.appendingPathComponent("share/ghostscript", isDirectory: true)
        guard let versions = try? fileManager.contentsOfDirectory(
            at: shareRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let versionRoot = versions
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedDescending }
            .first

        var candidates: [URL] = []
        if let versionRoot {
            candidates += [
                versionRoot.appendingPathComponent("Resource", isDirectory: true),
                versionRoot.appendingPathComponent("Resource/Init", isDirectory: true),
                versionRoot.appendingPathComponent("lib", isDirectory: true),
                versionRoot.appendingPathComponent("iccprofiles", isDirectory: true)
            ]
        }
        candidates += [
            shareRoot.appendingPathComponent("fonts", isDirectory: true),
            root.appendingPathComponent("lib/ghostscript", isDirectory: true)
        ]

        var seen = Set<String>()
        return candidates.filter { url in
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else { return false }
            return seen.insert(url.standardizedFileURL.path).inserted
        }
    }

    private func jpegQuality(_ quality: ConverterQualityProfile) -> Int {
        switch quality {
        case .low: return 70
        case .medium: return 82
        case .high: return 92
        case .maximum, .custom: return 100
        }
    }
}
