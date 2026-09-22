import Foundation

public enum AppPaths {
    public static func applicationSupport(fileManager: FileManager = .default) throws -> URL {
        if let override = ProcessInfo.processInfo.environment["ZEUVE_DATA_DIR"], !override.isEmpty {
            let url = URL(fileURLWithPath: override, isDirectory: true)
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }
        #if os(macOS)
        let root = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        #else
        let root = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share", isDirectory: true)
        #endif
        let directory = root.appendingPathComponent("ZEUVE", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    public static func logs(fileManager: FileManager = .default) throws -> URL {
        let url = try applicationSupport(fileManager: fileManager).appendingPathComponent("Logs", isDirectory: true)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
