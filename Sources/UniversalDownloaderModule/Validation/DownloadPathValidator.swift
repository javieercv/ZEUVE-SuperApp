import Foundation

public enum DownloadPathValidator {
    public static func validateOutputFolder(_ url: URL, fileManager: FileManager = .default) throws -> URL {
        let standardized = url.standardizedFileURL
        guard standardized.isFileURL, standardized.path.hasPrefix("/") else {
            throw UniversalDownloaderError.outputFolderUnavailable
        }
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: standardized.path, isDirectory: &isDirectory), isDirectory.boolValue,
              fileManager.isWritableFile(atPath: standardized.path) else {
            throw UniversalDownloaderError.outputFolderUnavailable
        }
        return standardized
    }

    public static func validateCookiesFile(_ url: URL?, fileManager: FileManager = .default) throws -> URL? {
        guard let url else { return nil }
        let standardized = url.standardizedFileURL
        guard standardized.isFileURL,
              standardized.lastPathComponent.lowercased().hasSuffix(".txt"),
              fileManager.fileExists(atPath: standardized.path),
              fileManager.isReadableFile(atPath: standardized.path),
              let data = fileManager.contents(atPath: standardized.path) else {
            throw UniversalDownloaderError.cookiesFileUnavailable
        }
        _ = try NetscapeCookieFile.parse(data)
        return standardized
    }

    public static func validateProxy(_ proxy: String?) throws -> String? {
        guard let proxy = proxy?.trimmingCharacters(in: .whitespacesAndNewlines), !proxy.isEmpty else { return nil }
        guard let components = URLComponents(string: proxy),
              let scheme = components.scheme?.lowercased(), ["http", "https", "socks5", "socks5h"].contains(scheme),
              components.host != nil else { throw UniversalDownloaderError.invalidProxy }
        return proxy
    }
}
