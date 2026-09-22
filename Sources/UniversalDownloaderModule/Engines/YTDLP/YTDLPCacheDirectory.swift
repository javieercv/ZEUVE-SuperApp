import Foundation

enum YTDLPCacheDirectory {
    static func prepare(
        fileManager: FileManager = .default,
        baseDirectory: URL? = nil
    ) throws -> URL {
        guard let base = baseDirectory ?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        var directory = base
            .appendingPathComponent("ZEUVE", isDirectory: true)
            .appendingPathComponent("yt-dlp", isDirectory: true)
            .standardizedFileURL
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? directory.setResourceValues(values)
        return directory
    }
}
