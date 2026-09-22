import Foundation
import ZEUVEStorage
import ZEUVECore

public final class DownloadOutputFolderBookmarkStore: @unchecked Sendable {
    private let settings: SettingsRepository
    private let codec: any FolderBookmarkCodec

    public init(settings: SettingsRepository, codec: any FolderBookmarkCodec = SystemFolderBookmarkCodec()) {
        self.settings = settings
        self.codec = codec
    }

    public func save(_ url: URL) throws {
        let valid = try DownloadPathValidator.validateOutputFolder(url)
        try settings.set(try codec.makeBookmark(for: valid), forKey: UniversalDownloaderStorageKeys.outputFolderBookmark)
    }

    public func resolve() throws -> URL? {
        let current = try settings.value(forKey: UniversalDownloaderStorageKeys.outputFolderBookmark, as: Data.self)
        let legacy = current == nil ? try settings.value(forKey: UniversalDownloaderStorageKeys.Legacy.outputFolderBookmark, as: Data.self) : nil
        guard let data = current ?? legacy else { return nil }
        if current == nil { try? settings.set(data, forKey: UniversalDownloaderStorageKeys.outputFolderBookmark) }
        do {
            let resolution = try codec.resolveBookmark(data)
            let valid = try DownloadPathValidator.validateOutputFolder(resolution.url)
            if resolution.isStale { try save(valid) }
            return valid
        } catch {
            // Un fallo de resolución puede ser temporal (permisos, volumen no montado, etc.).
            // Conservar el bookmark evita destruir una preferencia válida sin una acción del usuario.
            return nil
        }
    }

    public func clear() throws {
        try settings.removeValue(forKey: UniversalDownloaderStorageKeys.outputFolderBookmark)
        try settings.removeValue(forKey: UniversalDownloaderStorageKeys.Legacy.outputFolderBookmark)
    }
}
