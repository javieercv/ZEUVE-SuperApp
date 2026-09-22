import Foundation
import ZEUVEStorage

public final class UniversalDownloadPresetService: @unchecked Sendable {
    public static let currentSchemaVersion = 3
    private let settings: SettingsRepository

    public init(settings: SettingsRepository) { self.settings = settings }

    public func load() throws -> [UniversalDownloadPreset] {
        let current = try settings.value(forKey: UniversalDownloaderStorageKeys.presets, as: [UniversalDownloadPreset].self)
        let legacy = current == nil ? try settings.value(forKey: UniversalDownloaderStorageKeys.Legacy.presets, as: [UniversalDownloadPreset].self) : nil
        guard let stored = current ?? legacy else {
            let defaults = Self.defaultPresets()
            try save(defaults)
            return defaults
        }
        let migrated = stored.compactMap(migrate)
        if current == nil { try save(migrated) }
        if migrated != stored { try save(migrated) }
        return migrated
    }

    public func save(_ presets: [UniversalDownloadPreset]) throws {
        guard presets.allSatisfy({ $0.schemaVersion == Self.currentSchemaVersion }) else {
            throw UniversalDownloaderError.analysisFailed("Existe un preset con un esquema no compatible.")
        }
        try settings.set(presets, forKey: UniversalDownloaderStorageKeys.presets)
    }

    public func restoreDefaults() throws -> [UniversalDownloadPreset] {
        let values = Self.defaultPresets()
        try save(values)
        return values
    }

    private func migrate(_ preset: UniversalDownloadPreset) -> UniversalDownloadPreset? {
        guard preset.schemaVersion <= Self.currentSchemaVersion else { return nil }
        var result = preset
        if result.schemaVersion < 3,
           result.name == "Mejor calidad compatible",
           result.settings.mode == .video,
           result.settings.maximumResolution == .best,
           [.automatic, .mp4].contains(result.settings.container),
           result.settings.exactVideoFormatID == nil,
           result.settings.exactAudioFormatID == nil {
            result.settings.mode = .original
            result.modifiedAt = Date()
        }
        result.schemaVersion = Self.currentSchemaVersion
        return result
    }

    public static func defaultPresets() -> [UniversalDownloadPreset] {
        var best = UniversalDownloadSettings()
        best.mode = .original
        var video1080 = best; video1080.mode = .video; video1080.maximumResolution = .p1080
        var video720 = best; video720.mode = .video; video720.maximumResolution = .p720
        var m4a = best; m4a.mode = .audio; m4a.audioOutput = .m4a
        var mp3 = best; mp3.mode = .audio; mp3.audioOutput = .mp3; mp3.mp3Bitrate = .kbps320
        var playlist = best; playlist.numberPlaylistItems = true; playlist.createPlaylistFolder = true; playlist.filenamePreset = .playlistIndexAndTitle
        var subtitles = video1080; subtitles.subtitles = .init(languages: ["es", "es-*"], includeAutomatic: true, embed: true, convertToSRT: false)
        return [
            .init(schemaVersion: currentSchemaVersion, name: "Mejor calidad compatible", settings: best, isFavorite: true),
            .init(schemaVersion: currentSchemaVersion, name: "Vídeo 1080p", settings: video1080),
            .init(schemaVersion: currentSchemaVersion, name: "Vídeo 720p", settings: video720),
            .init(schemaVersion: currentSchemaVersion, name: "Audio M4A", settings: m4a, isFavorite: true),
            .init(schemaVersion: currentSchemaVersion, name: "Audio MP3 320 kbps", settings: mp3),
            .init(schemaVersion: currentSchemaVersion, name: "Colección completa", settings: playlist),
            .init(schemaVersion: currentSchemaVersion, name: "Vídeo con subtítulos en español", settings: subtitles),
        ]
    }
}
