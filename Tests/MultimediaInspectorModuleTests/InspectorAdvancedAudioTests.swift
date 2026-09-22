import Foundation
import Testing
import ZEUVECore
import ZEUVEEngines
import ZEUVEStorage
@testable import MultimediaInspectorModule

@Test func waveformKeepsRealPositiveAndNegativeEnvelope() throws {
    let accumulator = try MultimediaWaveformAccumulator(sampleRate: 10, channels: 1, channelSelection: .channel(0), duration: 1, maximumBuckets: 128)
    accumulator.consume(interleaved: [0.8, 0.4, -0.2, -0.7, 0.1, -0.3, 0.6, -0.1, 0.2, -0.5])
    let result = accumulator.finish(sourceID: "test")
    let nonSilent = result.buckets.filter { $0.maximum > 0 || $0.minimum < 0 }
    #expect(!nonSilent.isEmpty)
    #expect(nonSilent.contains { abs($0.maximum) != abs($0.minimum) })
    #expect(nonSilent.allSatisfy { $0.minimum <= 0 && $0.maximum >= 0 })
}

@Test func waveformMixPreservesOppositePhasePeaks() throws {
    let accumulator = try MultimediaWaveformAccumulator(sampleRate: 4, channels: 2, channelSelection: .mix, duration: 1, maximumBuckets: 64)
    accumulator.consume(interleaved: [0.9, -0.9, 0.7, -0.7, -0.8, 0.8, 0.4, -0.4])
    let result = accumulator.finish(sourceID: "mix")
    let peak = result.buckets.max { $0.maximum < $1.maximum }
    let trough = result.buckets.min { $0.minimum < $1.minimum }
    #expect((peak?.maximum ?? 0) >= 0.89)
    #expect((trough?.minimum ?? 0) <= -0.89)
    #expect(result.buckets.contains { $0.rms > 0.5 })
}

@Test func waveformSelectedChannelDoesNotUseOtherChannels() throws {
    let accumulator = try MultimediaWaveformAccumulator(sampleRate: 2, channels: 2, channelSelection: .channel(1), duration: 1, maximumBuckets: 64)
    accumulator.consume(interleaved: [1.0, 0.2, -1.0, -0.3])
    let result = accumulator.finish(sourceID: "right")
    #expect(result.buckets.map(\.maximum).max() ?? 0 <= 0.21)
    #expect(result.buckets.map(\.minimum).min() ?? 0 >= -0.31)
}

@Test func waveformSamplerKeepsEnvelopeAndBoundsVisualDensity() {
    let source = (0..<1000).map { index in
        MultimediaWaveformBucket(
            minimum: index == 501 ? -1 : -0.1,
            maximum: index == 502 ? 0.95 : 0.2,
            rms: 0.12
        )
    }
    let samples = MultimediaWaveformRenderSampler.samples(from: source, targetCount: 100)
    #expect(samples.count == 100)
    #expect(samples.contains { $0.minimum == -1 })
    #expect(samples.contains { $0.maximum == 0.95 })
}

@Test func waveformUnknownDurationNeverExceedsMaximumBuckets() throws {
    let accumulator = try MultimediaWaveformAccumulator(sampleRate: 48_000, channels: 2, channelSelection: .mix, duration: nil, maximumBuckets: 256)
    let block = Array(repeating: Float(0.25), count: 2 * 64 * 800)
    accumulator.consume(interleaved: block)
    #expect(accumulator.finish(sourceID: "bounded").buckets.count <= 256)
}

@Test func waveformUnknownDurationKeepsTemporalPositionAfterStreamingCompaction() throws {
    let framesPerInitialBucket = 64
    let initialBucketCount = 192
    let totalFrames = framesPerInitialBucket * initialBucketCount
    var samples = Array(repeating: Float(0), count: totalFrames)
    samples[(totalFrames * 3) / 4] = 1

    let accumulator = try MultimediaWaveformAccumulator(
        sampleRate: 48_000,
        channels: 1,
        channelSelection: .channel(0),
        duration: nil,
        maximumBuckets: 64
    )
    accumulator.consume(interleaved: samples)
    let result = accumulator.finish(sourceID: "temporal-position")
    let peakIndex = try #require(result.buckets.indices.max {
        result.buckets[$0].maximum < result.buckets[$1].maximum
    })
    let fraction = (Double(peakIndex) + 0.5) / Double(result.buckets.count)

    #expect(result.buckets.count <= 64)
    #expect(fraction > 0.70)
    #expect(fraction < 0.80)
}

@Test func inspectorPreferencesDecodeOlderPayloadAndNormalizeNewFields() throws {
    let legacy = #"{"defaultWindow":"hann","defaultFFTSize":4096,"allowedFFTSizes":[1024,4096],"defaultDynamicRange":[-120,0],"spectrogramMaximumColumns":1800,"defaultFrequencyScale":"linear","defaultChannel":"mix","outputSuffix":"_editado","initialTab":"summary","detailLevel":"useful","preserveMetadata":true}"#
    let value = try JSONDecoder().decode(MultimediaInspectorPreferences.self, from: Data(legacy.utf8))
    #expect(value.waveformStyle == .balanced)
    #expect(value.waveformRepresentation == .peaks)
    #expect(value.previewSkipSeconds == 15)
    #expect(value.previewVolume == 1)
    #expect(value.signalSilenceThresholdDBFS == -60)
    #expect(value.signalMinimumSilenceDuration == 0.5)
    #expect(value.signalClippingThresholdDBFS == -0.1)
    #expect(value.signalMinimumConsecutiveClippedSamples == 3)
}

@Test func inspectorPreferencesPersistThroughSettingsRepository() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ZEUVE-InspectorSettings-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storage = try StorageContainer(databaseURL: directory.appendingPathComponent("settings.sqlite"))
    let store = MultimediaInspectorSettingsStore(repository: storage.settings)
    var preferences = MultimediaInspectorPreferences.defaults
    preferences.waveformStyle = .detailed
    preferences.waveformRepresentation = .peaksAndEnergy
    preferences.waveformShowsCenterGuide = true
    preferences.previewSkipSeconds = 30
    preferences.previewVolume = 0.42
    preferences.signalSilenceThresholdDBFS = -55
    preferences.signalMinimumSilenceDuration = 0.8
    preferences.signalClippingThresholdDBFS = -0.3
    preferences.signalMinimumConsecutiveClippedSamples = 5
    try store.save(preferences)
    let loaded = store.load()
    #expect(loaded.waveformStyle == .detailed)
    #expect(loaded.waveformRepresentation == .peaksAndEnergy)
    #expect(loaded.waveformShowsCenterGuide)
    #expect(loaded.previewSkipSeconds == 30)
    #expect(abs(loaded.previewVolume - 0.42) < 0.001)
    #expect(loaded.signalSilenceThresholdDBFS == -55)
    #expect(abs(loaded.signalMinimumSilenceDuration - 0.8) < 0.001)
    #expect(abs(loaded.signalClippingThresholdDBFS - -0.3) < 0.001)
    #expect(loaded.signalMinimumConsecutiveClippedSamples == 5)
}

@Test func loudnessParserReadsFinalEBUR128AndSamplePeakValues() throws {
    let lines = [
        "[Parsed_ebur128_0 @ 0x1] t: 12.300 TARGET:-23 LUFS",
        "    I:         -16.8 LUFS",
        "    LRA:         5.2 LU",
        "    Peak:       -1.2 dBFS",
        "[Parsed_astats_1 @ 0x2] Peak level dB: -1.35",
    ]
    let result = try #require(AudioLoudnessParser().parse(lines: lines, sourceID: "audio", fallbackDuration: 15))
    #expect(result.integratedLUFS == -16.8)
    #expect(result.loudnessRangeLU == 5.2)
    #expect(result.truePeakDBTP == -1.2)
    #expect(result.samplePeakDBFS == -1.35)
    #expect(result.durationAnalyzed == 12.3)
}

@Test func loudnessCommandUsesExactStreamAndSeparatedArguments() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("loudness-\(UUID().uuidString).mkv")
    try Data([1, 2, 3]).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    let source = MultimediaAudioPreviewSource(url: url, fingerprint: try FileFingerprint.read(from: url), streamIndex: 7, sampleRate: 48_000, channels: 2, duration: 20, title: "Audio")
    let arguments = FFmpegLoudnessCommandBuilder().arguments(source: source)
    #expect(arguments.contains("0:7"))
    #expect(arguments.contains(where: { $0.contains("ebur128=peak=true") }))
    #expect(!arguments.contains("/bin/sh"))
}

@Test func audioTimingReportsTechnicalOffsetsWithoutJudgement() throws {
    let result = try MediaInspectionParser.decode(Data(#"{"streams":[{"index":0,"codec_type":"video","codec_name":"h264","start_time":"0.100","duration":"10.000"},{"index":1,"codec_type":"audio","codec_name":"aac","start_time":"0.180","duration":"9.950","tags":{"language":"spa"}},{"index":2,"codec_type":"audio","codec_name":"aac","start_time":"0.050","duration":"10.100"}],"format":{"duration":"10.000","start_time":"0.000"}}"#.utf8))
    let timing = AudioTimingAnalyzer().analyze(result)
    #expect(timing.referenceLabel == "Vídeo principal")
    #expect(abs((timing.entries.first(where: { $0.streamIndex == 1 })?.offsetFromReference ?? 0) - 0.08) < 0.000_001)
    #expect(abs((timing.entries.first(where: { $0.streamIndex == 2 })?.offsetFromReference ?? 0) + 0.05) < 0.000_001)
}

@Test func technicalReportDoesNotExportSourcePathFingerprintOrInternalSourceID() throws {
    let result = try MediaInspectionParser.decode(Data(#"{"streams":[{"index":1,"codec_type":"audio","codec_name":"aac","start_time":"0","duration":"10"}],"format":{"filename":"/Users/private/Movie.mkv","format_name":"matroska","duration":"10"}}"#.utf8))
    let timing = AudioTimingAnalyzer().analyze(result)
    let loudness = AudioLoudnessResult(sourceID: "PRIVATE-INTERNAL-ID", integratedLUFS: -18, loudnessRangeLU: 4, truePeakDBTP: -1, samplePeakDBFS: -1.2, durationAnalyzed: 10)
    let context = MultimediaTechnicalReportContext(fileName: "Movie.mkv", inspection: result, timing: timing, loudness: [.init(label: "Audio", result: loudness)])
    let data = try MultimediaTechnicalReportExporter().data(context: context, format: .json)
    let text = String(decoding: data, as: UTF8.self)
    #expect(text.contains("Movie.mkv"))
    #expect(!text.contains("/Users/private"))
    #expect(!text.contains("PRIVATE-INTERNAL-ID"))
    #expect(!text.localizedCaseInsensitiveContains("fingerprint"))
}

@Test func audioTimelineZoomCentersAroundPlaybackAndClampsAtEdges() {
    let centered = AudioTimelineViewport.full.zoomed(by: 0.5, around: 90, totalDuration: 120)
    #expect(centered.duration == 60)
    #expect(centered.start == 60)
    #expect(centered.visibleRange(totalDuration: 120) == AudioTimelineVisibleRange(start: 60, end: 120))

    let beginning = AudioTimelineViewport.full.zoomed(by: 0.5, around: 5, totalDuration: 120)
    #expect(beginning.start == 0)
    #expect(beginning.visibleRange(totalDuration: 120).end == 60)
}

@Test func audioTimelinePanMovesHalfAWindowAndNeverLeavesDuration() {
    let viewport = AudioTimelineViewport(start: 20, duration: 40)
    let forward = viewport.panned(byFraction: 0.5, totalDuration: 100)
    #expect(forward.visibleRange(totalDuration: 100) == AudioTimelineVisibleRange(start: 40, end: 80))

    let clamped = forward.panned(byFraction: 10, totalDuration: 100)
    #expect(clamped.visibleRange(totalDuration: 100) == AudioTimelineVisibleRange(start: 60, end: 100))
}

@Test func audioTimelineZoomOutReturnsToFullView() {
    let viewport = AudioTimelineViewport(start: 25, duration: 50)
    let full = viewport.zoomed(by: 2, around: 50, totalDuration: 100)
    #expect(full.isFull)
    #expect(full.visibleRange(totalDuration: 100) == AudioTimelineVisibleRange(start: 0, end: 100))
}

@Test func waveformSamplerUsesOnlyVisibleTimelineWindow() {
    let buckets = (0..<100).map { index in
        MultimediaWaveformBucket(
            minimum: index == 75 ? -1 : -0.1,
            maximum: index == 25 ? 0.9 : 0.1,
            rms: 0.1
        )
    }
    let result = MultimediaWaveformResult(sourceID: "windowed", duration: 100, buckets: buckets)
    let rightHalf = MultimediaWaveformRenderSampler.samples(
        from: result,
        visibleRange: AudioTimelineVisibleRange(start: 50, end: 100),
        targetCount: 25
    )
    #expect(rightHalf.contains { $0.minimum == -1 })
    #expect(!rightHalf.contains { $0.maximum == 0.9 })
}

@Test func waveformEnvelopeSupportsBoundedHighResolutionTimeline() throws {
    let accumulator = try MultimediaWaveformAccumulator(
        sampleRate: 1,
        channels: 1,
        channelSelection: .channel(0),
        duration: 7_200,
        maximumBuckets: 65_536
    )
    let result = accumulator.finish(sourceID: "high-resolution")
    #expect(result.buckets.count == 65_536)
}

@Test func loudnessParserBuildsTemporalTimelineFromSameEBUR128Pass() throws {
    let lines = [
        "[Parsed_ebur128_0 @ 0x1] t: 0.400 TARGET:-23 LUFS M: -18.0 S: -20.0 I: -21.0 LUFS LRA: 0.1 LU",
        "[Parsed_ebur128_0 @ 0x1] t: 0.500 TARGET:-23 LUFS M: -16.0 S: -19.0 I: -20.5 LUFS LRA: 0.2 LU",
        "    I:         -17.2 LUFS",
        "    LRA:         4.3 LU",
        "    Peak:       -0.8 dBFS",
        "[Parsed_astats_1 @ 0x2] Peak level dB: -1.0",
    ]
    let result = try #require(AudioLoudnessParser().parse(lines: lines, sourceID: "timeline", fallbackDuration: 1))
    let timeline = try #require(result.timeline)
    #expect(timeline.samples.count == 2)
    #expect(timeline.samples[0].time == 0.4)
    #expect(timeline.samples[0].momentaryLUFS == -18)
    #expect(timeline.samples[0].shortTermLUFS == -20)
    #expect(timeline.samples[1].integratedLUFS == -20.5)
    #expect(timeline.shortTermMinimumLUFS == -20)
    #expect(timeline.shortTermMaximumLUFS == -19)
    #expect(timeline.shortTermAverageLUFS == -19.5)
    #expect(result.integratedLUFS == -17.2)
}

@Test func loudnessTimelineCompactionIsBoundedAndPreservesExtremes() throws {
    let accumulator = AudioLoudnessTimelineAccumulator(maximumSamples: 32)
    for index in 0..<500 {
        let value = index == 123 ? -60.0 : (index == 321 ? -5.0 : -20.0)
        accumulator.append(time: Double(index) / 10, momentary: value + 1, shortTerm: value, integrated: -18)
    }
    let timeline = try #require(accumulator.finish(duration: 50))
    #expect(timeline.samples.count <= 32)
    #expect(timeline.shortTermMinimumLUFS == -60)
    #expect(timeline.shortTermMaximumLUFS == -5)
    #expect(timeline.nearestSample(to: 20) != nil)
}

@Test func comparisonMetricsCombineTechnicalLoudnessAndSignalData() throws {
    let inspection = try MediaInspectionParser.decode(Data(#"{"streams":[{"index":1,"codec_type":"audio","codec_name":"aac","bit_rate":"256000","sample_rate":"48000","channels":2,"channel_layout":"stereo","duration":"10"}],"format":{"duration":"10"}}"#.utf8))
    let stream = try #require(inspection.audioStreams.first)
    let track = try #require(MediaEditableTrack.from(stream: stream, kind: .audio))
    let loudness = AudioLoudnessResult(sourceID: "internal", integratedLUFS: -18, loudnessRangeLU: 5, truePeakDBTP: -1, samplePeakDBFS: -1.2, durationAnalyzed: 10)
    let signal = AudioSignalAnalysisResult(sourceID: "internal", durationAnalyzed: 10, silenceSegments: [.init(startTime: 1, endTime: 2)], clippingEvents: [.init(startTime: 3, endTime: 3.01, channelIndex: 0, peakDBFS: -0.05, sampleCount: 4)])
    let metrics = AudioTrackComparisonMetrics(track: track, stream: stream, loudness: loudness, signal: signal)
    #expect(metrics.codec == "AAC")
    #expect(metrics.bitRate == 256_000)
    #expect(metrics.sampleRate == 48_000)
    #expect(metrics.channels == 2)
    #expect(metrics.integratedLUFS == -18)
    #expect(metrics.silenceSegmentCount == 1)
    #expect(metrics.clippingEventCount == 1)
}

@Test func technicalReportSchemaThreeIncludesSignalAndLoudnessTimelineWithoutPrivateIDs() throws {
    let inspection = try MediaInspectionParser.decode(Data(#"{"streams":[{"index":1,"codec_type":"audio","codec_name":"aac","duration":"10"}],"format":{"filename":"/Users/private/source.mkv","format_name":"matroska","duration":"10"}}"#.utf8))
    let timing = AudioTimingAnalyzer().analyze(inspection)
    let timeline = AudioLoudnessTimeline(samples: [
        .init(time: 0.4, momentaryLUFS: -18, shortTermLUFS: -20, integratedLUFS: -21),
        .init(time: 0.5, momentaryLUFS: -17, shortTermLUFS: -19, integratedLUFS: -20.5),
    ], durationAnalyzed: 10)
    let loudness = AudioLoudnessResult(sourceID: "PRIVATE-LOUDNESS-ID", integratedLUFS: -18, loudnessRangeLU: 5, truePeakDBTP: -1, samplePeakDBFS: -1.2, durationAnalyzed: 10, timeline: timeline)
    let signal = AudioSignalAnalysisResult(sourceID: "PRIVATE-SIGNAL-ID", durationAnalyzed: 10, silenceSegments: [.init(startTime: 1, endTime: 2)], clippingEvents: [])
    let context = MultimediaTechnicalReportContext(
        fileName: "source.mkv",
        inspection: inspection,
        timing: timing,
        loudness: [.init(label: "Audio", result: loudness)],
        signal: [.init(label: "Audio", result: signal)]
    )
    let data = try MultimediaTechnicalReportExporter().data(context: context, format: .json)
    let text = String(decoding: data, as: UTF8.self)
    #expect(text.contains("\"schemaVersion\" : 3"))
    #expect(text.contains("shortTermLUFS"))
    #expect(text.contains("silenceSegments"))
    #expect(!text.contains("PRIVATE-LOUDNESS-ID"))
    #expect(!text.contains("PRIVATE-SIGNAL-ID"))
    #expect(!text.contains("/Users/private"))
}

@Test func loudnessTimelineTreatsNegativeInfinityAsMissingInsteadOfInventingValues() throws {
    let lines = [
        "[Parsed_ebur128_0 @ 0x1] t: 0.100 TARGET:-23 LUFS M: -inf S: -inf I: -inf LUFS LRA: 0.0 LU",
        "[Parsed_ebur128_0 @ 0x1] t: 0.200 TARGET:-23 LUFS M: -30.0 S: -inf I: -40.0 LUFS LRA: 0.0 LU",
        "    I:         -25.0 LUFS",
        "    LRA:         2.0 LU",
    ]
    let result = try #require(AudioLoudnessParser().parse(lines: lines, sourceID: "inf", fallbackDuration: 1))
    let timeline = try #require(result.timeline)
    #expect(timeline.samples.count == 1)
    #expect(timeline.samples[0].time == 0.2)
    #expect(timeline.samples[0].momentaryLUFS == -30)
    #expect(timeline.samples[0].shortTermLUFS == nil)
    #expect(timeline.samples[0].integratedLUFS == -40)
    #expect(result.integratedLUFS == -25)
}
