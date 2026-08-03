import Foundation
import ZEUVEStorage

public final class YouTubePresetService: @unchecked Sendable {
    public static let currentSchemaVersion = 2
    private let settings: SettingsRepository
    private let key = "youtubeDownloader.presets"

    public init(settings: SettingsRepository) { self.settings = settings }

    public func load() throws -> [YouTubePreset] {
        guard let stored = try settings.value(forKey: key, as: [YouTubePreset].self) else {
            let defaults = Self.defaultPresets()
            try save(defaults)
            return defaults
        }
        let migrated = stored.compactMap(migrate)
        if migrated != stored { try save(migrated) }
        return migrated
    }

    public func save(_ presets: [YouTubePreset]) throws {
        guard presets.allSatisfy({ $0.schemaVersion == Self.currentSchemaVersion }) else {
            throw YouTubeDownloaderError.analysisFailed("Existe un preset con un esquema no compatible.")
        }
        try settings.set(presets, forKey: key)
    }

    public func restoreDefaults() throws -> [YouTubePreset] {
        let values = Self.defaultPresets()
        try save(values)
        return values
    }

    private func migrate(_ preset: YouTubePreset) -> YouTubePreset? {
        guard preset.schemaVersion <= Self.currentSchemaVersion else { return nil }
        var result = preset
        result.schemaVersion = Self.currentSchemaVersion
        return result
    }

    public static func defaultPresets() -> [YouTubePreset] {
        let best = YouTubeDownloadSettings()
        var video1080 = best; video1080.maximumResolution = .p1080
        var video720 = best; video720.maximumResolution = .p720
        var m4a = best; m4a.mode = .audio; m4a.audioOutput = .m4a
        var mp3 = best; mp3.mode = .audio; mp3.audioOutput = .mp3; mp3.mp3Bitrate = .kbps320
        var playlist = best; playlist.numberPlaylistItems = true; playlist.createPlaylistFolder = true; playlist.filenamePreset = .playlistIndexAndTitle
        var subtitles = video1080; subtitles.subtitles = .init(languages: ["es", "es-*"], includeAutomatic: true, embed: true, convertToSRT: false)
        return [
            .init(name: "Mejor calidad compatible", settings: best, isFavorite: true),
            .init(name: "Vídeo 1080p", settings: video1080),
            .init(name: "Vídeo 720p", settings: video720),
            .init(name: "Audio M4A", settings: m4a, isFavorite: true),
            .init(name: "Audio MP3 320 kbps", settings: mp3),
            .init(name: "Lista de reproducción completa", settings: playlist),
            .init(name: "Vídeo con subtítulos en español", settings: subtitles),
        ]
    }
}
