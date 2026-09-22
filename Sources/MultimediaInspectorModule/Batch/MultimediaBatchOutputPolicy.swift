import Foundation

public struct MultimediaBatchOutputPolicy: Sendable {
    public init() {}

    public func reportURL(for input: URL, format: MultimediaTechnicalReportFormat, directory: URL) -> URL {
        directory.appendingPathComponent(input.deletingPathExtension().lastPathComponent + "_informe.\(format.rawValue)")
    }

    public func spectrogramURL(for input: URL, directory: URL) -> URL {
        directory.appendingPathComponent(input.deletingPathExtension().lastPathComponent + "_espectrograma.png")
    }

    public func estimatedOutputBytes(fileCount: Int, configuration: MultimediaBatchConfiguration) -> Int64 {
        var total: Int64 = 0
        if configuration.exportSpectrogram {
            let pixels = Int64(configuration.spectrogramExportWidth) * Int64(configuration.spectrogramExportHeight)
            total += Int64(fileCount) * max(pixels, 1) * 4
        }
        if configuration.reportFormat != nil {
            total += Int64(fileCount) * 512 * 1024
        }
        return max(total, 0)
    }
}
