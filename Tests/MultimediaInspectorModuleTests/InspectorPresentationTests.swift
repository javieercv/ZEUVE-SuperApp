import Foundation
import Testing
import ZEUVEEngines
import ZEUVECore
@testable import MultimediaInspectorModule

@Test func channelLayoutResolverUsesKnownStereoAndSafeFallback() {
    let stereo = AudioChannelLayoutResolver.channels(layout: "stereo", count: 2)
    #expect(stereo.map(\.shortName) == ["L", "R"])
    #expect(stereo.map(\.displayName) == ["Izquierdo", "Derecho"])

    let unknown = AudioChannelLayoutResolver.channels(layout: "mystery", count: 3)
    #expect(unknown.map(\.displayName) == ["Canal 1", "Canal 2", "Canal 3"])
}

@Test func channelLayoutResolverCoversCommon51And71Orders() {
    #expect(AudioChannelLayoutResolver.channels(layout: "5.1(side)", count: 6).map(\.shortName) == ["L", "R", "C", "LFE", "SL", "SR"])
    #expect(AudioChannelLayoutResolver.channels(layout: "7.1", count: 8).map(\.shortName) == ["L", "R", "C", "LFE", "BL", "BR", "SL", "SR"])
}

@Test func spectrogramAxisTicksRespectBoundsAndScale() {
    let times = SpectrogramAxisTicks.times(start: 10, end: 20, targetCount: 5)
    #expect(times.first == 10)
    #expect(times.last == 20)
    #expect(times.count == 5)

    let linear = SpectrogramAxisTicks.frequencies(nyquist: 24_000, scale: .linear, targetCount: 5)
    #expect(linear.first == 0)
    #expect(linear.last == 24_000)

    let logarithmic = SpectrogramAxisTicks.frequencies(nyquist: 24_000, scale: .logarithmic, targetCount: 6)
    #expect(logarithmic.allSatisfy { $0 > 0 && $0 <= 24_000 })
    #expect(logarithmic.last == 24_000)
}

@Test func spectrogramLookupReturnsNearestDBWithoutReanalysis() {
    let result = SpectrogramResult(
        sampleRate: 8_000,
        fftSize: 8,
        startTime: 0,
        endTime: 2,
        dynamicRange: .init(minimumDB: -100, maximumDB: 0),
        columns: [
            .init(time: 0, decibels: [-90, -80, -70, -60, -50]),
            .init(time: 2, decibels: [-40, -30, -20, -10, 0]),
        ]
    )
    #expect(result.approximateDecibels(time: 1.8, frequency: 2_000) == -20)
    #expect(result.nearestColumn(to: 0.1)?.time == 0)
}

@Test func technicalFormatterProducesReadableLocalSummaryAndStream() throws {
    let json = #"""
    {
      "streams":[{"index":1,"codec_name":"aac","codec_long_name":"AAC","codec_type":"audio","sample_rate":"48000","channels":2,"channel_layout":"stereo","disposition":{"default":1},"tags":{"language":"spa","title":"TVE"}}],
      "format":{"format_name":"matroska,webm","format_long_name":"Matroska / WebM","duration":"120","size":"1000"}
    }
    """#
    let result = try MediaInspectionParser.decode(Data(json.utf8))
    let formatter = MediaInspectionTextFormatter()
    let summary = formatter.summary(result)
    let stream = formatter.stream(try #require(result.audioStreams.first))
    #expect(summary.contains("Contenedor: Matroska / WebM"))
    #expect(summary.contains("Audio: 1 pista(s)"))
    #expect(stream.contains("Sample rate: 48000 Hz"))
    #expect(stream.contains("Idioma: spa"))
    #expect(stream.contains("Default: Sí"))
}

@Test func previewSourceIdentityIsStableAndContainsStream() {
    let url = URL(fileURLWithPath: "/tmp/audio.mkv")
    try? Data([1, 2, 3]).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    let fingerprint = try! FileFingerprint.read(from: url)
    let source = MultimediaAudioPreviewSource(
        url: url,
        fingerprint: fingerprint,
        streamIndex: 3,
        sampleRate: 48_000,
        channels: 2,
        duration: 10,
        channelLayout: "stereo",
        title: "Audio"
    )
    #expect(source.id.hasSuffix(":3"))
    #expect(source.sampleRate == 48_000)
}

@Test func previewCommandBuilderUsesExactStreamAndNoShell() throws {
    let url = URL(fileURLWithPath: "/tmp/preview-source.mkv")
    try Data([1, 2, 3]).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    let fingerprint = try FileFingerprint.read(from: url)
    let source = MultimediaAudioPreviewSource(
        url: url,
        fingerprint: fingerprint,
        streamIndex: 4,
        sampleRate: 44_100,
        channels: 6,
        duration: 120,
        channelLayout: "5.1(side)",
        title: "Pista"
    )
    let builder = FFmpegAudioPreviewCommandBuilder()
    let mix = try builder.arguments(source: source, from: 12.5, channelSelection: .mix)
    #expect(mix.contains("0:4"))
    #expect(mix.contains("2"))
    #expect(mix.contains("44100"))
    #expect(!mix.contains("/bin/sh"))
    #expect(!mix.contains("-c"))

    let channel = try builder.arguments(source: source, from: 0, channelSelection: .channel(3))
    #expect(channel.contains("pan=mono|c0=c3"))
    #expect(builder.outputChannelCount(source: source, channelSelection: .channel(3)) == 1)
}

@Test func previewCommandBuilderRejectsInvalidChannel() throws {
    let url = URL(fileURLWithPath: "/tmp/preview-invalid.mkv")
    try Data([1]).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    let source = MultimediaAudioPreviewSource(
        url: url,
        fingerprint: try FileFingerprint.read(from: url),
        streamIndex: 1,
        sampleRate: 48_000,
        channels: 2,
        duration: 1,
        title: "Audio"
    )
    #expect(throws: MultimediaInspectorError.self) {
        _ = try FFmpegAudioPreviewCommandBuilder().arguments(source: source, from: 0, channelSelection: .channel(2))
    }
}

@Test func previewCommandBuilderChangesExactMappedStreamWhenSwitchingTracks() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("preview-switch-\(UUID().uuidString).mkv")
    try Data([1, 2, 3, 4]).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    let fingerprint = try FileFingerprint.read(from: url)
    let first = MultimediaAudioPreviewSource(
        url: url,
        fingerprint: fingerprint,
        streamIndex: 1,
        sampleRate: 44_100,
        channels: 2,
        duration: 60,
        channelLayout: "stereo",
        title: "Pista A"
    )
    let second = MultimediaAudioPreviewSource(
        url: url,
        fingerprint: fingerprint,
        streamIndex: 4,
        sampleRate: 44_100,
        channels: 2,
        duration: 60,
        channelLayout: "stereo",
        title: "Pista B"
    )
    let builder = FFmpegAudioPreviewCommandBuilder()
    let firstArguments = try builder.arguments(source: first, from: 12.5, channelSelection: .mix)
    let secondArguments = try builder.arguments(source: second, from: 12.5, channelSelection: .mix)
    let firstMapIndex = try #require(firstArguments.firstIndex(of: "-map"))
    let secondMapIndex = try #require(secondArguments.firstIndex(of: "-map"))

    #expect(first.id != second.id)
    #expect(firstArguments[firstMapIndex + 1] == "0:1")
    #expect(secondArguments[secondMapIndex + 1] == "0:4")
    #expect(firstArguments.contains("12.500000"))
    #expect(secondArguments.contains("12.500000"))
}
