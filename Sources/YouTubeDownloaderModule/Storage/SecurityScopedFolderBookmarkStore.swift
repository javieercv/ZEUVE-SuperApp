import Foundation
import ZEUVEStorage

public struct BookmarkResolution: Sendable, Equatable {
    public let url: URL
    public let isStale: Bool
    public init(url: URL, isStale: Bool) { self.url = url; self.isStale = isStale }
}

public protocol FolderBookmarkCodec: Sendable {
    func makeBookmark(for url: URL) throws -> Data
    func resolveBookmark(_ data: Data) throws -> BookmarkResolution
}

public struct SystemFolderBookmarkCodec: FolderBookmarkCodec {
    public init() {}
    public func makeBookmark(for url: URL) throws -> Data {
        #if os(macOS)
        return try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        #else
        return Data(url.path.utf8)
        #endif
    }
    public func resolveBookmark(_ data: Data) throws -> BookmarkResolution {
        #if os(macOS)
        var stale = false
        let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale)
        return .init(url: url, isStale: stale)
        #else
        guard let path = String(data: data, encoding: .utf8) else { throw YouTubeDownloaderError.outputFolderUnavailable }
        return .init(url: URL(fileURLWithPath: path, isDirectory: true), isStale: false)
        #endif
    }
}

public final class SecurityScopedFolderBookmarkStore: @unchecked Sendable {
    private let settings: SettingsRepository
    private let codec: any FolderBookmarkCodec
    private let key = "youtubeDownloader.outputFolderBookmark"

    public init(settings: SettingsRepository, codec: any FolderBookmarkCodec = SystemFolderBookmarkCodec()) {
        self.settings = settings
        self.codec = codec
    }

    public func save(_ url: URL) throws {
        let valid = try YouTubePathValidator.validateOutputFolder(url)
        try settings.set(try codec.makeBookmark(for: valid), forKey: key)
    }

    public func resolve() throws -> URL? {
        guard let data = try settings.value(forKey: key, as: Data.self) else { return nil }
        do {
            let resolution = try codec.resolveBookmark(data)
            let valid = try YouTubePathValidator.validateOutputFolder(resolution.url)
            if resolution.isStale { try save(valid) }
            return valid
        } catch {
            try? settings.removeValue(forKey: key)
            return nil
        }
    }

    public func clear() throws { try settings.removeValue(forKey: key) }
}

public struct SecurityScopedResourceAccess: Sendable {
    private let url: URL?
    private let active: Bool

    public init(_ url: URL?) {
        self.url = url
        #if os(macOS)
        self.active = url?.startAccessingSecurityScopedResource() ?? false
        #else
        self.active = false
        #endif
    }

    public func stop() {
        #if os(macOS)
        if active { url?.stopAccessingSecurityScopedResource() }
        #endif
    }
}
