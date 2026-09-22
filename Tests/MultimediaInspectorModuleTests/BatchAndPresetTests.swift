import Foundation
import Testing
import ZEUVEEngines
import ZEUVEStorage
@testable import MultimediaInspectorModule

@Test func batchConfigurationNormalizesUserControlledBounds() {
    var configuration = MultimediaBatchConfiguration(
        analyzeSignal: true,
        analyzeLoudness: true,
        exportSpectrogram: true,
        reportFormat: .json,
        spectrogramWindow: .hann,
        spectrogramFFTSize: 123,
        spectrogramDynamicRange: -500 ... 99,
        spectrogramMaximumColumns: 99_999,
        spectrogramFrequencyScale: .linear,
        spectrogramChannel: .mix,
        spectrogramExportWidth: 12,
        spectrogramExportHeight: 99_999,
        signalSilenceThresholdDBFS: -500,
        signalMinimumSilenceDuration: 500,
        signalClippingThresholdDBFS: -99,
        signalMinimumConsecutiveClippedSamples: 999
    )
    configuration.normalize()
    #expect(configuration.spectrogramFFTSize == 4096)
    #expect(configuration.spectrogramDynamicRange.lowerBound == -180)
    #expect(configuration.spectrogramDynamicRange.upperBound == 12)
    #expect(configuration.spectrogramMaximumColumns == 8192)
    #expect(configuration.spectrogramExportWidth == 320)
    #expect(configuration.spectrogramExportHeight == 4096)
    #expect(configuration.signalSilenceThresholdDBFS == -120)
    #expect(configuration.signalMinimumSilenceDuration == 30)
    #expect(configuration.signalClippingThresholdDBFS == -6)
    #expect(configuration.signalMinimumConsecutiveClippedSamples == 64)
}

@Test func defaultBatchPresetsHaveStableIdentifiersAndExpectedJobs() {
    let first = MultimediaInspectorBatchPresetStore.defaultPresets()
    let second = MultimediaInspectorBatchPresetStore.defaultPresets()
    #expect(first.count == 4)
    #expect(first.map(\.id) == second.map(\.id))
    #expect(first[0].id == MultimediaInspectorBatchPresetStore.quickInspectionPresetID)
    #expect(first[1].id == MultimediaInspectorBatchPresetStore.technicalReportPresetID)
    #expect(first[2].id == MultimediaInspectorBatchPresetStore.completeAudioAnalysisPresetID)
    #expect(first[3].id == MultimediaInspectorBatchPresetStore.spectrogramsPresetID)
    #expect(first[0].configuration.reportFormat == nil)
    #expect(first[1].configuration.reportFormat == .markdown)
    #expect(first[2].configuration.analyzeSignal)
    #expect(first[2].configuration.analyzeLoudness)
    #expect(first[2].configuration.reportFormat == .json)
    #expect(first[3].configuration.exportSpectrogram)
}

@Test func batchPresetsPersistWithoutPathsOrSelectedFiles() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ZEUVE-BatchPresets-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storage = try StorageContainer(databaseURL: directory.appendingPathComponent("settings.sqlite"))
    let store = MultimediaInspectorBatchPresetStore(repository: storage.settings)
    var presets = store.load()
    #expect(presets.count == 4)
    presets[0].name = "Mi inspección"
    presets[0].configuration.analyzeLoudness = true
    try store.save(presets)
    let reloaded = store.load()
    #expect(reloaded[0].name == "Mi inspección")
    #expect(reloaded[0].configuration.analyzeLoudness)
    let data = try JSONEncoder().encode(reloaded)
    let text = String(decoding: data, as: UTF8.self)
    #expect(!text.localizedCaseInsensitiveContains("path"))
    #expect(!text.localizedCaseInsensitiveContains("outputDirectory"))
    #expect(!text.localizedCaseInsensitiveContains("fileName"))
}

@Test func batchOutputPolicyUsesPredictableNamesAndConservativeEstimate() {
    let policy = MultimediaBatchOutputPolicy()
    let input = URL(fileURLWithPath: "/tmp/Mi vídeo.mkv")
    let output = URL(fileURLWithPath: "/tmp/resultados", isDirectory: true)
    #expect(policy.reportURL(for: input, format: .json, directory: output).lastPathComponent == "Mi vídeo_informe.json")
    #expect(policy.spectrogramURL(for: input, directory: output).lastPathComponent == "Mi vídeo_espectrograma.png")
    var configuration = MultimediaBatchConfiguration()
    configuration.exportSpectrogram = true
    configuration.reportFormat = .markdown
    configuration.spectrogramExportWidth = 1000
    configuration.spectrogramExportHeight = 500
    let estimated = policy.estimatedOutputBytes(fileCount: 3, configuration: configuration)
    #expect(estimated >= 3 * 1000 * 500 * 4)
}

@Test func technicalReportSectionsCanDisableDetailedAreasWithoutLosingIdentity() throws {
    let inspection = try MediaInspectionParser.decode(Data(#"{"streams":[{"index":0,"codec_type":"audio","codec_name":"pcm_s16le","tags":{"title":"Privado"}}],"chapters":[{"id":0,"start_time":"0","end_time":"1","tags":{"title":"Capítulo"}}],"format":{"filename":"/Users/private/audio.wav","format_name":"wav","duration":"1","tags":{"artist":"Autor"}}}"#.utf8))
    let context = MultimediaTechnicalReportContext(
        fileName: "audio.wav",
        inspection: inspection,
        timing: AudioTimingAnalyzer().analyze(inspection),
        loudness: [],
        signal: []
    )
    let sections = MultimediaTechnicalReportSections(
        includeGlobalMetadata: false,
        includeStreams: false,
        includeChapters: false,
        includeTiming: false,
        includeLoudness: false,
        includeSignalAnalysis: false
    )
    let data = try MultimediaTechnicalReportExporter().data(context: context, format: .json, sections: sections)
    let text = String(decoding: data, as: UTF8.self)
    #expect(text.contains("audio.wav"))
    #expect(text.contains("\"schemaVersion\" : 3"))
    #expect(text.contains("\"streams\" : ["))
    #expect(!text.contains("Privado"))
    #expect(!text.contains("Capítulo"))
    #expect(!text.contains("Autor"))
    #expect(!text.contains("/Users/private"))
}

@Test func batchHistoryPayloadContainsOnlyAggregateCounts() throws {
    let payload = MultimediaInspectorHistoryPayload(
        kind: "batch-analysis",
        container: nil,
        audioTracks: 0,
        subtitleTracks: 0,
        convertedSubtitleTracks: 0,
        durationSeconds: 12.5,
        batchTotal: 100,
        batchCompleted: 92,
        batchWarnings: 3,
        batchSkipped: 2,
        batchFailed: 3,
        batchCancelled: 0,
        reportsGenerated: 87,
        spectrogramsGenerated: 42
    )
    let text = String(decoding: try JSONEncoder().encode(payload), as: UTF8.self)
    #expect(text.contains("\"batchTotal\":100"))
    #expect(text.contains("\"batchFailed\":3"))
    #expect(!text.localizedCaseInsensitiveContains("fileName"))
    #expect(!text.localizedCaseInsensitiveContains("path"))
    #expect(!text.localizedCaseInsensitiveContains("preset"))
}

@Test func favoritesPersistReusableConfigurationsWithoutMediaPaths() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ZEUVE-InspectorFavorites-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storage = try StorageContainer(databaseURL: directory.appendingPathComponent("settings.sqlite"))
    let store = MultimediaInspectorFavoritesStore(repository: storage.settings)
    let referenced = UUID()
    let saved = try store.setFavorite(kind: .structuralRuleSet, referencedID: referenced, displayName: "Limpieza de idiomas", favorite: true)
    #expect(saved.count == 1)
    #expect(store.load().first?.referencedID == referenced)
    let encoded = try JSONEncoder().encode(store.load())
    let text = String(decoding: encoded, as: UTF8.self)
    #expect(!text.contains("/Users/"))
    #expect(!text.localizedCaseInsensitiveContains("path"))
}

@Test func structuralRuleSetsPersistSemanticsWithoutSelectedFiles() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ZEUVE-InspectorRules-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storage = try StorageContainer(databaseURL: directory.appendingPathComponent("settings.sqlite"))
    let store = MultimediaInspectorRuleSetStore(repository: storage.settings)
    let rule = MultimediaBatchStructuralRule(
        name: "Quitar audio inglés",
        conditions: [.init(kind: .audio, field: .language, match: .equals, value: "eng")],
        action: .remove
    )
    try store.save([.init(name: "Audio", rules: [rule])])
    let loaded = store.load()
    #expect(loaded.count == 1)
    #expect(loaded[0].rules.first?.conditions.first?.value == "eng")
    let text = String(decoding: try JSONEncoder().encode(loaded), as: UTF8.self)
    #expect(!text.localizedCaseInsensitiveContains("filename"))
    #expect(!text.localizedCaseInsensitiveContains("outputdirectory"))
}
