import Foundation
import ZEUVEStorage

public enum UniversalDownloaderStorageKeys {
    public static let preferences = "universalDownloader.preferences"
    public static let defaultSettings = "universalDownloader.defaultSettings"
    public static let downloadProfiles = "universalDownloader.downloadProfiles"
    public static let defaultAdvancedMode = "universalDownloader.defaultAdvancedMode"
    public static let presets = "universalDownloader.presets"
    public static let outputFolderBookmark = "universalDownloader.outputFolderBookmark"

    public enum Legacy {
        public static let defaultSettings = "youtube.defaultSettings"
        public static let defaultAdvancedMode = "youtube.defaultAdvancedMode"
        public static let presets = "youtubeDownloader.presets"
        public static let outputFolderBookmark = "youtubeDownloader.outputFolderBookmark"
    }
}

public struct UniversalDownloaderStoredConfiguration: Sendable, Equatable {
    public let preferences: UniversalDownloaderPreferences
    public let defaultSettings: UniversalDownloadSettings
    public let downloadProfiles: UniversalDownloadProfiles
    public let defaultAdvancedMode: Bool

    public init(
        preferences: UniversalDownloaderPreferences,
        defaultSettings: UniversalDownloadSettings,
        downloadProfiles: UniversalDownloadProfiles,
        defaultAdvancedMode: Bool
    ) {
        self.preferences = preferences
        self.defaultSettings = defaultSettings
        self.downloadProfiles = downloadProfiles
        self.defaultAdvancedMode = defaultAdvancedMode
    }
}

public final class UniversalDownloaderSettingsStore: @unchecked Sendable {
    private let settings: SettingsRepository

    public init(settings: SettingsRepository) {
        self.settings = settings
    }

    public func load() -> UniversalDownloaderStoredConfiguration {
        var preferences = (try? settings.value(
            forKey: UniversalDownloaderStorageKeys.preferences,
            as: UniversalDownloaderPreferences.self
        )) ?? UniversalDownloaderPreferences()
        if preferences.useOptionalBrowserFallback {
            preferences.useOptionalBrowserFallback = false
            try? settings.set(preferences, forKey: UniversalDownloaderStorageKeys.preferences)
        }

        let storedDefaults = (try? settings.value(
            forKey: UniversalDownloaderStorageKeys.defaultSettings,
            as: UniversalDownloadSettings.self
        )) ?? (try? settings.value(
            forKey: UniversalDownloaderStorageKeys.Legacy.defaultSettings,
            as: UniversalDownloadSettings.self
        ))
        let migratedDefaults = Self.migratedStoredDefaults(storedDefaults ?? UniversalDownloadSettings())
        if storedDefaults != nil {
            try? settings.set(migratedDefaults, forKey: UniversalDownloaderStorageKeys.defaultSettings)
        }

        let profiles: UniversalDownloadProfiles
        if var storedProfiles = try? settings.value(
            forKey: UniversalDownloaderStorageKeys.downloadProfiles,
            as: UniversalDownloadProfiles.self
        ) {
            let previousProfiles = storedProfiles
            storedProfiles.normalize()
            profiles = storedProfiles
            if storedProfiles != previousProfiles {
                try? settings.set(storedProfiles, forKey: UniversalDownloaderStorageKeys.downloadProfiles)
            }
        } else {
            profiles = UniversalDownloadProfiles.migrated(from: migratedDefaults)
            try? settings.set(profiles, forKey: UniversalDownloaderStorageKeys.downloadProfiles)
        }

        let storedAdvancedMode = (try? settings.value(
            forKey: UniversalDownloaderStorageKeys.defaultAdvancedMode,
            as: Bool.self
        )) ?? (try? settings.value(
            forKey: UniversalDownloaderStorageKeys.Legacy.defaultAdvancedMode,
            as: Bool.self
        ))
        let advancedMode = storedAdvancedMode ?? false
        if storedAdvancedMode != nil {
            try? settings.set(advancedMode, forKey: UniversalDownloaderStorageKeys.defaultAdvancedMode)
        }

        return UniversalDownloaderStoredConfiguration(
            preferences: preferences,
            defaultSettings: migratedDefaults,
            downloadProfiles: profiles,
            defaultAdvancedMode: advancedMode
        )
    }

    public func saveDefaults(_ defaults: UniversalDownloadSettings, advancedMode: Bool) throws {
        try settings.set(Self.normalizedDefaults(defaults), forKey: UniversalDownloaderStorageKeys.defaultSettings)
        try settings.set(advancedMode, forKey: UniversalDownloaderStorageKeys.defaultAdvancedMode)
    }

    public func savePreferences(_ preferences: UniversalDownloaderPreferences) throws {
        try settings.set(preferences, forKey: UniversalDownloaderStorageKeys.preferences)
    }

    public func saveProfiles(_ profiles: UniversalDownloadProfiles) throws {
        var normalized = profiles
        normalized.normalize()
        try settings.set(normalized, forKey: UniversalDownloaderStorageKeys.downloadProfiles)
    }

    public static func normalizedDefaults(_ value: UniversalDownloadSettings) -> UniversalDownloadSettings {
        var normalized = value
        normalized.exactVideoFormatID = nil
        normalized.exactAudioFormatID = nil
        return normalized
    }

    public static func migratedStoredDefaults(_ value: UniversalDownloadSettings) -> UniversalDownloadSettings {
        var normalized = normalizedDefaults(value)
        let legacyFactoryDefault = UniversalDownloadSettings(mode: .video)
        if normalized == legacyFactoryDefault {
            normalized.mode = .automatic
        }
        return normalized
    }
}
