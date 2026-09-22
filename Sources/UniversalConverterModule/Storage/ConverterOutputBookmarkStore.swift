import Foundation
import ZEUVEStorage
import ZEUVECore

public final class ConverterOutputBookmarkStore: @unchecked Sendable {
    private let settings: SettingsRepository
    private let codec: any FolderBookmarkCodec
    private let key: String

    public init(
        settings: SettingsRepository,
        key: String = "universalConverter.outputFolderBookmark.v1",
        codec: any FolderBookmarkCodec = SystemFolderBookmarkCodec()
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
            // Resolver un bookmark puede fallar temporalmente. Solo `clear()` o un nuevo
            // `save(_:)` deben olvidar de forma permanente la carpeta recordada.
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
