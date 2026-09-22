import Foundation
import Testing
import ZEUVECore
@testable import MultimediaInspectorModule

@Test func signalAnalysisDetectsStereoSilenceOnlyWhenAllChannelsAreQuiet() throws {
    let configuration = AudioSignalAnalysisConfiguration(
        silenceThresholdDBFS: -60,
        minimumSilenceDuration: 0.05,
        clippingThresholdDBFS: -0.1,
        minimumConsecutiveClippedSamples: 3
    )
    let accumulator = try AudioSignalAnalysisAccumulator(
        sampleRate: 1_000,
        channels: 2,
        configuration: configuration,
        silenceWindowDuration: 0.01
    )

    var samples: [Float] = []
    for frame in 0..<100 {
        let left: Float = frame >= 20 && frame < 80 ? 0 : 0.2
        let right: Float = frame >= 20 && frame < 80 ? 0 : 0.2
        samples += [left, right]
    }
    accumulator.consume(samples)
    let result = accumulator.finish(sourceID: "stereo")

    #expect(result.silenceSegmentCount == 1)
    #expect(abs((result.silenceSegments.first?.startTime ?? -1) - 0.02) < 0.000_1)
    #expect(abs((result.silenceSegments.first?.endTime ?? -1) - 0.08) < 0.000_1)
    #expect(abs(result.totalSilenceDuration - 0.06) < 0.000_1)

    let oneChannelActive = try AudioSignalAnalysisAccumulator(
        sampleRate: 1_000,
        channels: 2,
        configuration: configuration,
        silenceWindowDuration: 0.01
    )
    oneChannelActive.consume(Array(repeating: [Float(0), Float(0.05)], count: 100).flatMap { $0 })
    #expect(oneChannelActive.finish(sourceID: "no-cancellation").silenceSegmentCount == 0)
}

@Test func signalAnalysisRequiresConsecutiveNearFullScaleSamplesAndGroupsNearbyRuns() throws {
    let configuration = AudioSignalAnalysisConfiguration(
        silenceThresholdDBFS: -60,
        minimumSilenceDuration: 0.05,
        clippingThresholdDBFS: -0.1,
        minimumConsecutiveClippedSamples: 3
    )
    let accumulator = try AudioSignalAnalysisAccumulator(
        sampleRate: 1_000,
        channels: 1,
        configuration: configuration,
        clippingMergeGap: 0.02
    )
    var samples = [Float](repeating: 0.2, count: 140)
    samples[10] = 1; samples[11] = 1; samples[12] = 1
    samples[20] = 0.999; samples[21] = 0.999; samples[22] = 0.999
    samples[60] = 1; samples[61] = 0.2; samples[62] = 1 // no son consecutivas
    samples[100] = 1; samples[101] = 1; samples[102] = 1
    accumulator.consume(samples)

    let result = accumulator.finish(sourceID: "clip")
    #expect(result.clippingEventCount == 2)
    #expect(result.clippingEvents[0].sampleCount == 6)
    #expect(result.clippingEvents[0].channelIndex == 0)
    #expect(result.clippingEvents[0].peakDBFS >= -0.001)
    #expect(result.clippingEvents[1].startTime >= 0.1)
}

@Test func signalAnalysisDoesNotCallStrongButSubThresholdAudioClipping() throws {
    let configuration = AudioSignalAnalysisConfiguration(
        silenceThresholdDBFS: -60,
        minimumSilenceDuration: 0.05,
        clippingThresholdDBFS: -0.1,
        minimumConsecutiveClippedSamples: 3
    )
    let accumulator = try AudioSignalAnalysisAccumulator(
        sampleRate: 48_000,
        channels: 1,
        configuration: configuration
    )
    accumulator.consume([Float](repeating: 0.98, count: 4_800))
    let result = accumulator.finish(sourceID: "strong")
    #expect(result.clippingEventCount == 0)
    #expect(result.silenceSegmentCount == 0)
}

@Test func signalAnalysisKeepsInterleavedFramesAcrossPCMChunks() throws {
    let configuration = AudioSignalAnalysisConfiguration(
        silenceThresholdDBFS: -60,
        minimumSilenceDuration: 0.05,
        clippingThresholdDBFS: -0.1,
        minimumConsecutiveClippedSamples: 3
    )
    let accumulator = try AudioSignalAnalysisAccumulator(
        sampleRate: 100,
        channels: 2,
        configuration: configuration,
        silenceWindowDuration: 0.01
    )
    let frames = Array(repeating: [Float(0), Float(0)], count: 10).flatMap { $0 }
    accumulator.consume(Array(frames.prefix(3)))
    accumulator.consume(Array(frames.dropFirst(3).prefix(8)))
    accumulator.consume(Array(frames.dropFirst(11)))
    let result = accumulator.finish(sourceID: "chunks")
    #expect(abs(result.durationAnalyzed - 0.1) < 0.000_1)
    #expect(result.silenceSegmentCount == 1)
}

@Test func signalAnalysisCapsMarkerStorageWithoutLosingTotalCount() throws {
    let configuration = AudioSignalAnalysisConfiguration(
        silenceThresholdDBFS: -60,
        minimumSilenceDuration: 0.05,
        clippingThresholdDBFS: -0.1,
        minimumConsecutiveClippedSamples: 2
    )
    let accumulator = try AudioSignalAnalysisAccumulator(
        sampleRate: 100,
        channels: 1,
        configuration: configuration,
        clippingMergeGap: 0,
        maximumClippingEvents: 2
    )
    var samples = [Float](repeating: 0.2, count: 80)
    for start in [0, 20, 40] {
        samples[start] = 1
        samples[start + 1] = 1
    }
    accumulator.consume(samples)
    let result = accumulator.finish(sourceID: "bounded")
    #expect(result.clippingEvents.count == 2)
    #expect(result.omittedClippingEvents == 1)
    #expect(result.clippingEventCount == 3)
}

@Test func signalAnalysisPreferencesDecodeOldPayloadWithSafeDefaults() throws {
    let legacy = Data(#"{"previewVolume":0.75,"previewSkipSeconds":10}"#.utf8)
    let preferences = try JSONDecoder().decode(MultimediaInspectorPreferences.self, from: legacy)
    #expect(preferences.signalSilenceThresholdDBFS == -60)
    #expect(preferences.signalMinimumSilenceDuration == 0.5)
    #expect(preferences.signalClippingThresholdDBFS == -0.1)
    #expect(preferences.signalMinimumConsecutiveClippedSamples == 3)
}

@Test func signalAnalysisCommandKeepsFullPCMAndSelectedStream() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try Data([0]).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    let source = MultimediaAudioPreviewSource(
        url: url,
        fingerprint: try FileFingerprint.read(from: url),
        streamIndex: 4,
        sampleRate: 48_000,
        channels: 2,
        duration: 1,
        title: "Audio"
    )
    let arguments = FFmpegSignalAnalysisCommandBuilder().arguments(source: source)
    #expect(arguments.contains("0:4"))
    #expect(arguments.contains("pcm_f32le"))
    #expect(arguments.contains("pipe:1"))
    #expect(!arguments.contains("-ar"))
    #expect(!arguments.contains("-ac"))
}
