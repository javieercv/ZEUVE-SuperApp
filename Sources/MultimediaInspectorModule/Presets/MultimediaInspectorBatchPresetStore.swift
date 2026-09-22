import Foundation
import ZEUVEStorage

public final class MultimediaInspectorBatchPresetStore: @unchecked Sendable {
    public static let currentSchemaVersion = 1
    private let repository: SettingsRepository?

    public init(repository: SettingsRepository?) {
        self.repository = repository
    }

    public func load() -> [MultimediaInspectorBatchPreset] {
        guard let repository else { return Self.defaultPresets() }
        do {
            guard let stored = try repository.value(
                forKey: MultimediaInspectorStorageKeys.batchPresets,
                as: [MultimediaInspectorBatchPreset].self
            ) else {
                let defaults = Self.defaultPresets()
                try save(defaults)
                return defaults
            }
            let normalized = stored.compactMap(Self.normalizePreset)
            if normalized.isEmpty {
                let defaults = Self.defaultPresets()
                try save(defaults)
                return defaults
            }
            if normalized != stored { try save(normalized) }
            return normalized
        } catch {
            return Self.defaultPresets()
        }
    }

    public func save(_ presets: [MultimediaInspectorBatchPreset]) throws {
        let normalized = presets.compactMap(Self.normalizePreset)
        guard normalized.count == presets.count else {
            throw MultimediaInspectorError.invalidInput
        }
        try repository?.set(normalized, forKey: MultimediaInspectorStorageKeys.batchPresets)
    }

    public func restoreDefaults() throws -> [MultimediaInspectorBatchPreset] {
        let defaults = Self.defaultPresets()
        try save(defaults)
        return defaults
    }

    public static let quickInspectionPresetID = UUID(uuidString: "1E5B4F56-58DD-4A8A-9011-000000000001")!
    public static let technicalReportPresetID = UUID(uuidString: "1E5B4F56-58DD-4A8A-9011-000000000002")!
    public static let completeAudioAnalysisPresetID = UUID(uuidString: "1E5B4F56-58DD-4A8A-9011-000000000003")!
    public static let spectrogramsPresetID = UUID(uuidString: "1E5B4F56-58DD-4A8A-9011-000000000004")!

    public static func defaultPresets() -> [MultimediaInspectorBatchPreset] {
        let preferences = MultimediaInspectorPreferences.defaults
        let base = preferences.batchConfigurationDefaults
        var quick = base
        quick.analyzeSignal = false
        quick.analyzeLoudness = false
        quick.exportSpectrogram = false
        quick.reportFormat = nil

        var report = base
        report.analyzeSignal = false
        report.analyzeLoudness = false
        report.exportSpectrogram = false
        report.reportFormat = .markdown

        var audio = base
        audio.analyzeSignal = true
        audio.analyzeLoudness = true
        audio.exportSpectrogram = false
        audio.reportFormat = .json

        var spectra = base
        spectra.analyzeSignal = false
        spectra.analyzeLoudness = false
        spectra.exportSpectrogram = true
        spectra.reportFormat = nil

        return [
            .init(id: quickInspectionPresetID, schemaVersion: currentSchemaVersion, name: "Inspección rápida", configuration: quick),
            .init(id: technicalReportPresetID, schemaVersion: currentSchemaVersion, name: "Informe técnico", configuration: report),
            .init(id: completeAudioAnalysisPresetID, schemaVersion: currentSchemaVersion, name: "Análisis de audio completo", configuration: audio),
            .init(id: spectrogramsPresetID, schemaVersion: currentSchemaVersion, name: "Espectrogramas", configuration: spectra),
        ]
    }

    private static func normalizePreset(_ preset: MultimediaInspectorBatchPreset) -> MultimediaInspectorBatchPreset? {
        guard preset.schemaVersion <= currentSchemaVersion else { return nil }
        let name = preset.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        var result = preset
        result.schemaVersion = currentSchemaVersion
        result.name = name
        result.configuration.normalize()
        return result
    }
}
