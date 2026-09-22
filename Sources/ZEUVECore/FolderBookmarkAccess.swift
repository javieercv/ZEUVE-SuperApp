import Foundation

public struct FolderBookmarkResolution: Sendable, Equatable {
    public let url: URL
    public let isStale: Bool

    public init(url: URL, isStale: Bool) {
        self.url = url
        self.isStale = isStale
    }
}

public enum FolderBookmarkError: Error, Sendable {
    case invalidBookmarkData
}

public protocol FolderBookmarkCodec: Sendable {
    func makeBookmark(for url: URL) throws -> Data
    func resolveBookmark(_ data: Data) throws -> FolderBookmarkResolution
}

public struct SystemFolderBookmarkCodec: FolderBookmarkCodec {
    public init() {}

    public func makeBookmark(for url: URL) throws -> Data {
        #if os(macOS)
        return try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        #else
        return Data(url.standardizedFileURL.path.utf8)
        #endif
    }

    public func resolveBookmark(_ data: Data) throws -> FolderBookmarkResolution {
        #if os(macOS)
        var stale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
        return FolderBookmarkResolution(url: url.standardizedFileURL, isStale: stale)
        #else
        guard let path = String(data: data, encoding: .utf8), !path.isEmpty else {
            throw FolderBookmarkError.invalidBookmarkData
        }
        return FolderBookmarkResolution(
            url: URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL,
            isStale: false
        )
        #endif
    }
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
