import Foundation
import ZEUVEStorage

public struct ConverterBookmarkResolution: Sendable, Equatable {
    public let url: URL
    public let isStale: Bool
    public init(url: URL, isStale: Bool) { self.url = url; self.isStale = isStale }
}

public protocol ConverterFolderBookmarkCodec: Sendable {
    func makeBookmark(for url: URL) throws -> Data
    func resolveBookmark(_ data: Data) throws -> ConverterBookmarkResolution
}

public struct SystemConverterFolderBookmarkCodec: ConverterFolderBookmarkCodec {
    public init() {}

    public func makeBookmark(for url: URL) throws -> Data {
        #if os(macOS)
        return try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        #else
        return Data(url.standardizedFileURL.path.utf8)
        #endif
    }

    public func resolveBookmark(_ data: Data) throws -> ConverterBookmarkResolution {
        #if os(macOS)
        var stale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
        return .init(url: url.standardizedFileURL, isStale: stale)
        #else
        guard let path = String(data: data, encoding: .utf8) else { throw UniversalConverterError.outputFolderMissing }
        return .init(url: URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL, isStale: false)
        #endif
    }
}

public final class ConverterOutputBookmarkStore: @unchecked Sendable {
    private let settings: SettingsRepository
    private let codec: any ConverterFolderBookmarkCodec
    private let key: String

    public init(
        settings: SettingsRepository,
        key: String = "universalConverter.outputFolderBookmark.v1",
        codec: any ConverterFolderBookmarkCodec = SystemConverterFolderBookmarkCodec()
    ) {
        self.settings = settings
        self.key = key
        self.codec = codec
    }

    public func save(_ url: URL) throws {
        let valid = try Self.validate(url)
        try settings.set(try codec.makeBookmark(for: valid), forKey: key)
    }

    public func resolve() throws -> URL? {
        guard let data = try settings.value(forKey: key, as: Data.self) else { return nil }
        do {
            let resolution = try codec.resolveBookmark(data)
            let valid = try Self.validate(resolution.url)
            if resolution.isStale { try save(valid) }
            return valid
        } catch {
            try? settings.removeValue(forKey: key)
            return nil
        }
    }

    public func clear() throws { try settings.removeValue(forKey: key) }

    public static func validate(_ url: URL, fileManager: FileManager = .default) throws -> URL {
        let standardized = url.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard standardized.isFileURL,
              fileManager.fileExists(atPath: standardized.path, isDirectory: &isDirectory),
              isDirectory.boolValue,
              fileManager.isWritableFile(atPath: standardized.path) else {
            throw UniversalConverterError.outputFolderMissing
        }
        return standardized
    }
}

public struct ConverterSecurityScopedResourceAccess: Sendable {
    private let url: URL?
    private let active: Bool

    public init(_ url: URL?) {
        self.url = url
        #if os(macOS)
        active = url?.startAccessingSecurityScopedResource() ?? false
        #else
        active = false
        #endif
    }

    public func stop() {
        #if os(macOS)
        if active { url?.stopAccessingSecurityScopedResource() }
        #endif
    }
}
