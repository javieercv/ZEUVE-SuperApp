import Foundation
import ZEUVEStorage

public enum MultimediaInspectorStorageKeys {
    public static let preferences = "multimediaInspector.preferences"
    public static let batchPresets = "multimediaInspector.batchPresets.v1"
    public static let ruleSets = "multimediaInspector.ruleSets.v1"
    public static let favorites = "multimediaInspector.favorites.v1"
}

public final class MultimediaInspectorSettingsStore: @unchecked Sendable {
    private let repository: SettingsRepository?

    public init(repository: SettingsRepository?) {
        self.repository = repository
    }

    public func load() -> MultimediaInspectorPreferences {
        var value = (try? repository?.value(
            forKey: MultimediaInspectorStorageKeys.preferences,
            as: MultimediaInspectorPreferences.self
        )) ?? MultimediaInspectorPreferences.defaults
        value.normalize()
        return value
    }

    public func save(_ preferences: MultimediaInspectorPreferences) throws {
        var normalized = preferences
        normalized.normalize()
        try repository?.set(normalized, forKey: MultimediaInspectorStorageKeys.preferences)
    }

    public func restoreDefaults() throws -> MultimediaInspectorPreferences {
        let defaults = MultimediaInspectorPreferences.defaults
        try repository?.set(defaults, forKey: MultimediaInspectorStorageKeys.preferences)
        return defaults
    }
}
