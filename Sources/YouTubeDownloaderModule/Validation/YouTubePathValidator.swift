import Foundation

public enum YouTubePathValidator {
    public static func validateOutputFolder(_ url: URL, fileManager: FileManager = .default) throws -> URL {
        let standardized = url.standardizedFileURL
        guard standardized.isFileURL, standardized.path.hasPrefix("/") else {
            throw YouTubeDownloaderError.outputFolderUnavailable
        }
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: standardized.path, isDirectory: &isDirectory), isDirectory.boolValue,
              fileManager.isWritableFile(atPath: standardized.path) else {
            throw YouTubeDownloaderError.outputFolderUnavailable
        }
        return standardized
    }

    public static func validateCookiesFile(_ url: URL?, fileManager: FileManager = .default) throws -> URL? {
        guard let url else { return nil }
        let standardized = url.standardizedFileURL
        guard standardized.isFileURL,
              standardized.lastPathComponent.lowercased().hasSuffix(".txt"),
              fileManager.fileExists(atPath: standardized.path),
              fileManager.isReadableFile(atPath: standardized.path) else {
            throw YouTubeDownloaderError.cookiesFileUnavailable
        }
        return standardized
    }

    public static func validateProxy(_ proxy: String?) throws -> String? {
        guard let proxy = proxy?.trimmingCharacters(in: .whitespacesAndNewlines), !proxy.isEmpty else { return nil }
        guard let components = URLComponents(string: proxy),
              let scheme = components.scheme?.lowercased(), ["http", "https", "socks5", "socks5h"].contains(scheme),
              components.host != nil else { throw YouTubeDownloaderError.invalidProxy }
        return proxy
    }
}
