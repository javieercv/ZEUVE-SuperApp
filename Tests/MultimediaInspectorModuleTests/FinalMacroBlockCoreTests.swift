import Foundation
import Testing
@testable import MultimediaInspectorModule
import ZEUVECore
import ZEUVEEngines

private func macroTempFile(ext: String = "mkv") throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("zeuve-macro-\(UUID().uuidString).\(ext)")
    try Data([1,2,3,4]).write(to: url)
    return url
}

private func inspection(_ json: String) throws -> MediaInspectionResult {
    try JSONDecoder().decode(MediaInspectionResult.self, from: Data(json.utf8))
}

@Test func videoTracksParticipateInDraftPlannerAndStreamCopyCommand() throws {
    let source = try macroTempFile(); defer { try? FileManager.default.removeItem(at: source) }
    let fp = try FileFingerprint.read(from: source)
    let result = try inspection(#"{"streams":[{"index":0,"codec_name":"h264","codec_type":"video","width":1920,"height":1080},{"index":1,"codec_name":"aac","codec_type":"audio"}]}"#)
    var draft = try MediaEditDraft(originalURL: source, originalFingerprint: fp, inspection: result, container: .mkv)
    #expect(draft.videoTracks.count == 1)
    draft.videoTracks[0].title = "Vídeo principal"
    let plan = try MediaEditPlanner().plan(from: draft)
    #expect(plan.videoTracks.count == 1)
    let command = try FFmpegMediaEditCommandBuilder().command(ffmpeg: URL(fileURLWithPath: "/tmp/ffmpeg"), plan: plan, outputURL: URL(fileURLWithPath: "/tmp/out.mkv"))
    #expect(command.request.arguments.contains("0:0"))
    #expect(command.request.arguments.contains("-c"))
    #expect(command.request.arguments.contains("copy"))
    #expect(!command.request.arguments.contains("libx264"))
}

@Test func videoPreviewBuilderCapsResolutionFPSAndUsesExactStream() throws {
    let file = try macroTempFile(ext: "mp4"); defer { try? FileManager.default.removeItem(at: file) }
    let fp = try FileFingerprint.read(from: file)
    let source = MultimediaVideoPreviewSource(url: file, fingerprint: fp, streamIndex: 4, codec: "hevc", width: 3840, height: 2160, frameRate: 60, duration: 100, title: "Vídeo")
    let prepared = try FFmpegVideoPreviewCommandBuilder().prepare(source: source, from: 12.5, limits: .init(maximumWidth: 1280, maximumHeight: 720, maximumFPS: 24, maximumBufferedFrames: 3), decoder: .software)
    #expect(prepared.outputWidth == 1280)
    #expect(prepared.outputHeight == 720)
    #expect(prepared.outputFPS == 24)
    #expect(prepared.arguments.contains("0:4"))
    #expect(prepared.arguments.contains("bgra"))
}

@Test func folderEnumeratorFiltersHiddenAndDoesNotFollowSymlinks() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("zeuve-folder-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try Data([1]).write(to: root.appendingPathComponent("a.mp4"))
    try Data([2]).write(to: root.appendingPathComponent(".hidden.mkv"))
    let sub = root.appendingPathComponent("sub", isDirectory: true); try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
    try Data([3]).write(to: sub.appendingPathComponent("b.wav"))
    try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("link.mp4"), withDestinationURL: root.appendingPathComponent("a.mp4"))
    let result = try MultimediaBatchFolderEnumerator().enumerate(folder: root, options: .init(includeSubfolders: true, maximumDepth: 4, includeHidden: false))
    #expect(result.files.map { $0.url.lastPathComponent }.sorted() == ["a.mp4", "b.wav"])
    #expect(result.ignoredSymlinks == 1)
}

@Test func semanticRuleUsesPropertiesInsteadOfTrackOrdinal() throws {
    let source = try macroTempFile(); defer { try? FileManager.default.removeItem(at: source) }
    let fp = try FileFingerprint.read(from: source)
    let result = try inspection(#"{"streams":[{"index":0,"codec_name":"h264","codec_type":"video"},{"index":1,"codec_name":"aac","codec_type":"audio","tags":{"language":"eng"}},{"index":2,"codec_name":"aac","codec_type":"audio","tags":{"language":"spa"}}]}"#)
    let draft = try MediaEditDraft(originalURL: source, originalFingerprint: fp, inspection: result, container: .mkv)
    let condition = MultimediaBatchRuleCondition(kind: .audio, field: .language, value: "eng")
    let set = MultimediaBatchRuleSet(name: "Limpieza", rules: [.init(name: "Quitar inglés", conditions: [condition], action: .remove)])
    let output = MultimediaBatchRuleEngine().apply(set, to: draft)
    #expect(output.draft.audioTracks.count == 1)
    #expect(output.draft.audioTracks[0].language == "spa")
}

@Test func ocrExporterProducesReviewableSRTWithoutSourcePath() {
    let draft = BitmapSubtitleOCRDraft(events: [
        .init(start: 1.2, end: 2.5, text: "Hola\nmundo", confidence: 0.9, needsReview: false),
        .init(start: 3, end: 4, text: "Descartado", confidence: 0.2, needsReview: true, included: false)
    ], sourceCodec: "hdmv_pgs_subtitle", sourceStreamIndex: 7, language: "es")
    let text = String(decoding: BitmapSubtitleOCRExporter().srtData(from: draft), as: UTF8.self)
    #expect(text.contains("00:00:01,199 --> 00:00:02,500") || text.contains("00:00:01,200 --> 00:00:02,500"))
    #expect(text.contains("Hola\nmundo"))
    #expect(!text.contains("Descartado"))
}

@Test func subtitlePreviewParsesSRTEventsLocally() async throws {
    let events = MultimediaSubtitlePreviewService.parseSRT("""
    1
    00:00:01,250 --> 00:00:03,000
    Hola\nmundo

    2
    00:00:04,000 --> 00:00:05,500
    Adiós
    """)
    #expect(events.count == 2)
    #expect(events[0].start == 1.25)
    #expect(events[0].text == "Hola\nmundo")
}

@Test func reportSchemaThreeAddsAdvancedOCRAndStructuralSummaryWithoutOCRTextOrPrivateIDs() throws {
    let source = try inspection(#"{"streams":[{"index":0,"codec_name":"hevc","codec_type":"video","width":1920,"height":1080,"disposition":{"default":1}},{"index":2,"codec_name":"hdmv_pgs_subtitle","codec_type":"subtitle","tags":{"language":"spa"}}],"format":{"filename":"/Users/private/source.mkv","format_name":"matroska","duration":"10"}}"#)
    let advanced = AudioSourceQualityAnalysis(
        indication: .moderate,
        confidence: 0.74,
        analyzedDuration: 10,
        effectiveBandwidthHz: 16_100,
        highBandEnergyRatio: 0.01,
        evidence: [.init(title: "Corte persistente", detail: "La energía cae de forma sostenida por encima de 16,1 kHz.", weight: 0.7)],
        anomalies: [.init(start: 2, end: 3, severity: 0.6, title: "Cambio espectral", detail: "Cambio localizado")]
    )
    let context = MultimediaTechnicalReportContext(
        fileName: "source.mkv",
        inspection: source,
        timing: AudioTimingAnalyzer().analyze(source),
        loudness: [],
        advancedAudio: [.init(label: "Audio", result: advanced)],
        ocrSummaries: [.init(streamIndex: 2, codec: "hdmv_pgs_subtitle", language: "spa", eventCount: 15, needsReviewCount: 2)],
        structuralEdit: .init(targetContainer: "mkv", videoStreams: 1, audioStreams: 1, subtitleStreams: 2, artworks: 0, warnings: 1)
    )
    let data = try MultimediaTechnicalReportExporter().data(context: context, format: .json)
    let text = String(decoding: data, as: UTF8.self)
    #expect(text.contains("\"schemaVersion\" : 3"))
    #expect(text.contains("Corte persistente"))
    #expect(text.contains("\"eventCount\" : 15"))
    #expect(text.contains("\"targetContainer\" : \"mkv\""))
    #expect(!text.contains("/Users/private"))
    #expect(!text.contains("Texto OCR privado"))
    #expect(!text.localizedCaseInsensitiveContains("fingerprint"))
}

@Test func oldPreferencesDecodeWithNewPreviewAndReportDefaults() throws {
    let old = #"{"defaultWindow":"hann","defaultFFTSize":4096,"allowedFFTSizes":[4096],"defaultDynamicRange":[-120,0],"spectrogramMaximumColumns":1800,"defaultFrequencyScale":"linear","defaultChannel":"mix","spectrogramExportWidth":1600,"spectrogramExportHeight":900,"outputSuffix":"_editado","initialTab":"summary","detailLevel":"useful","preserveMetadata":true,"waveformStyle":"balanced","waveformRepresentation":"peaks","waveformShowsCenterGuide":false,"showChapterMarkersOnWaveform":true,"showSignalOverlaysOnWaveform":true,"showSignalOverlaysOnSpectrogram":true,"showLoudnessTimeline":true,"previewVolume":1,"previewSkipSeconds":15,"previewTrackSwitchKeepsPosition":true,"previewTrackSwitchKeepsPlaybackState":true,"timelineZoomFactor":0.5,"timelinePanFraction":0.5,"signalSilenceThresholdDBFS":-60,"signalMinimumSilenceDuration":0.5,"signalClippingThresholdDBFS":-0.1,"signalMinimumConsecutiveClippedSamples":3,"automaticSpectrogramForSingleTrack":true,"automaticSignalAnalysisForSingleTrack":true,"automaticLoudnessForSingleTrack":true,"defaultReportFormat":"md"}"#
    let decoded = try JSONDecoder().decode(MultimediaInspectorPreferences.self, from: Data(old.utf8))
    #expect(decoded.subtitlePreviewFontSize == MultimediaInspectorPreferences.defaults.subtitlePreviewFontSize)
    #expect(decoded.videoPreviewLimits.maximumBufferedFrames == MultimediaInspectorPreferences.defaults.videoPreviewLimits.maximumBufferedFrames)
    #expect(decoded.reportSections.includeAdvancedAudioAnalysis)
}
