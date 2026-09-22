import Foundation
import Testing
@testable import MultimediaInspectorModule

private func sine(_ frequency: Double, sampleRate: Double, count: Int, amplitude: Double = 1) -> [Float] {
    (0..<count).map { Float(amplitude * sin(2 * Double.pi * frequency * Double($0) / sampleRate)) }
}

@Test(arguments: [(440.0, 44100.0), (1000.0, 48000.0), (10000.0, 48000.0), (1000.0, 96000.0)])
func fftPeaksNearSyntheticTone(_ item: (Double, Double)) throws {
    let n = 4096, (frequency, sr) = item
    let db = try SpectrogramFFTProcessor().analyze(samples: sine(frequency, sampleRate: sr, count: n), sampleRate: sr, window: .hann, dynamicRange: .init(minimumDB: -140, maximumDB: 0))
    let bin = try #require(db.enumerated().max(by: { $0.element < $1.element })?.offset)
    let measured = Double(bin) * sr / Double(n)
    #expect(abs(measured - frequency) <= sr / Double(n))
}

@Test(arguments: SpectrogramWindowFunction.allCases)
func standardWindowsProduceFiniteSpectra(_ window: SpectrogramWindowFunction) throws {
    let samples = sine(1000, sampleRate: 48000, count: 1024)
    let values = try SpectrogramFFTProcessor().analyze(samples: samples, sampleRate: 48000, window: window, dynamicRange: .init(minimumDB: -120, maximumDB: 0))
    #expect(values.count == 513)
    #expect(values.allSatisfy { $0.isFinite })
    #expect(values.allSatisfy { (-120...0).contains($0) })
}

@Test func lowAmplitudeToneHasExpectedRelativeDB() throws {
    let values = try SpectrogramFFTProcessor().analyze(samples: sine(1500, sampleRate: 48000, count: 4096, amplitude: 0.1), sampleRate: 48000, window: .hann, dynamicRange: .init(minimumDB: -120, maximumDB: 0))
    let peak = try #require(values.max())
    #expect(abs(peak - (-20)) < 1.0)
}

@Test func accumulatorSeparatesStereoChannelsAndHandlesIncompleteBlock() throws {
    let url = URL(fileURLWithPath: "/tmp/test.wav")
    let n = 512, sr = 8192.0
    var interleaved = [Float](); interleaved.reserveCapacity(n * 2)
    let left = sine(512, sampleRate: sr, count: n), right = sine(2048, sampleRate: sr, count: n)
    for i in 0..<n { interleaved.append(left[i]); interleaved.append(right[i]) }

    let leftRequest = SpectrogramAnalysisRequest(url: url, streamIndex: 0, sampleRate: sr, channels: 2, channelSelection: .channel(0), fftSize: n, maximumColumns: 100)
    let rightRequest = SpectrogramAnalysisRequest(url: url, streamIndex: 0, sampleRate: sr, channels: 2, channelSelection: .channel(1), fftSize: n, maximumColumns: 100)
    let la = try SpectrogramAccumulator(request: leftRequest), ra = try SpectrogramAccumulator(request: rightRequest)
    la.consume(Array(interleaved.prefix(333))); la.consume(Array(interleaved.dropFirst(333)))
    ra.consume(interleaved)
    let l = la.finish(), r = ra.finish()
    let lPeak = try #require(l.columns.first?.decibels.enumerated().max(by: { $0.element < $1.element })?.offset)
    let rPeak = try #require(r.columns.first?.decibels.enumerated().max(by: { $0.element < $1.element })?.offset)
    #expect(abs(l.frequency(forBin: lPeak) - 512) <= l.binWidth)
    #expect(abs(r.frequency(forBin: rPeak) - 2048) <= r.binWidth)

    let incomplete = try SpectrogramAccumulator(request: .init(url: url, streamIndex: 0, sampleRate: sr, channels: 1, fftSize: n))
    incomplete.consume(Array(left.prefix(100)))
    #expect(incomplete.finish().columns.count == 1)
}

@Test func accumulatorMixesMultichannelWithoutUnboundedColumns() throws {
    let request = SpectrogramAnalysisRequest(url: URL(fileURLWithPath: "/tmp/multi.wav"), streamIndex: 0, sampleRate: 8000, channels: 4, channelSelection: .mix, fftSize: 256, maximumColumns: 64)
    let accumulator = try SpectrogramAccumulator(request: request)
    let frame = [Float](repeating: 0.25, count: 4)
    for _ in 0..<5000 { accumulator.consume(frame) }
    let result = accumulator.finish()
    #expect(result.columns.count <= 128)
    #expect(result.nyquist == 4000)
}

@Test func fftRejectsNonPowerOfTwo() {
    #expect(throws: MultimediaInspectorError.self) {
        _ = try SpectrogramFFTProcessor().analyze(samples: [Float](repeating: 0, count: 1000), sampleRate: 48000, window: .hann, dynamicRange: .init())
    }
}


private final class ThreadSafeSampleCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func add(_ count: Int) { lock.withLock { value += count } }
    var count: Int { lock.withLock { value } }
}

private func makeStreamingPCMHelper() throws -> (executable: URL, directory: URL) {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("zeuve-pcm-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let source = root.appendingPathComponent("fake_ffmpeg.c")
    let executable = root.appendingPathComponent("fake_ffmpeg")
    let program = #"""
#include <stdio.h>
#include <unistd.h>

int main(void) {
    float block[512];
    for (int i = 0; i < 512; ++i) { block[i] = (float)(i % 32) / 32.0f; }
    for (;;) {
        if (fwrite(block, sizeof(float), 512, stdout) != 512) { return 0; }
        fflush(stdout);
        usleep(10000);
    }
}
"""#
    try program.write(to: source, atomically: true, encoding: .utf8)
    let compiler = Process()
    compiler.executableURL = URL(fileURLWithPath: "/usr/bin/cc")
    compiler.arguments = [source.path, "-O2", "-o", executable.path]
    try compiler.run()
    compiler.waitUntilExit()
    guard compiler.terminationStatus == 0 else {
        throw NSError(domain: "SpectrogramMathTests", code: Int(compiler.terminationStatus))
    }
    return (executable, root)
}

@Test func pcmDecoderStreamsIncrementallyAndCancelsTheActiveProcess() async throws {
    let helper = try makeStreamingPCMHelper()
    defer { try? FileManager.default.removeItem(at: helper.directory) }
    let input = helper.directory.appendingPathComponent("audio.media")
    try Data("x".utf8).write(to: input)
    let decoder = FFmpegPCMDecoder()
    let request = SpectrogramAnalysisRequest(
        url: input,
        streamIndex: 0,
        sampleRate: 48_000,
        channels: 2,
        channelSelection: .mix,
        fftSize: 1024,
        maximumColumns: 128
    )
    let receivedSamples = ThreadSafeSampleCounter()
    let task = Task {
        try await decoder.decode(ffmpeg: helper.executable, request: request) { values in
            receivedSamples.add(values.count)
        }
    }
    for _ in 0..<100 where receivedSamples.count == 0 {
        try await Task.sleep(for: .milliseconds(10))
    }
    #expect(receivedSamples.count > 0)
    await decoder.cancel()
    do {
        try await task.value
        Issue.record("La decodificación PCM cancelada no debe completar como éxito")
    } catch {
        #expect(error is CancellationError)
    }
}

@Test func renderMappingUsesTheSameMathematicalScaleForLinearAndLogarithmicViews() {
    let nyquist = 24_000.0
    #expect(abs(SpectrogramRenderMapping.frequency(normalizedFromBottom: 0.5, nyquist: nyquist, scale: .linear) - 12_000) < 0.001)
    let logarithmicMid = SpectrogramRenderMapping.frequency(normalizedFromBottom: 0.5, nyquist: nyquist, scale: .logarithmic)
    #expect(abs(logarithmicMid - sqrt(20 * nyquist)) < 0.001)
    #expect(logarithmicMid < 12_000)
}

@Test func rasterizerRespectsFrequencyScaleAndProducesDifferentRows() throws {
    let bins = (0..<9).map { Float($0) * 10 - 80 }
    let result = SpectrogramResult(
        sampleRate: 16_000,
        fftSize: 16,
        startTime: 0,
        endTime: 1,
        dynamicRange: .init(minimumDB: -80, maximumDB: 0),
        columns: [.init(time: 0.5, decibels: bins)]
    )
    let rasterizer = SpectrogramRasterizer()
    let linear = try rasterizer.rasterize(result, frequencyScale: .linear, width: 1, height: 9)
    let logarithmic = try rasterizer.rasterize(result, frequencyScale: .logarithmic, width: 1, height: 9)
    #expect(linear.rgba8 != logarithmic.rgba8)
    #expect(linear.rgba8.count == 36)
    #expect(logarithmic.rgba8.count == 36)
}

@Test func powerMixDoesNotCancelOppositePhaseStereoChannels() throws {
    let sampleRate = 8_192.0
    let fftSize = 512
    let tone = sine(1_024, sampleRate: sampleRate, count: fftSize)
    var interleaved: [Float] = []
    interleaved.reserveCapacity(fftSize * 2)
    for value in tone {
        interleaved.append(value)
        interleaved.append(-value)
    }
    let accumulator = try SpectrogramAccumulator(request: .init(
        url: URL(fileURLWithPath: "/tmp/antiphase.wav"),
        streamIndex: 0,
        sampleRate: sampleRate,
        channels: 2,
        channelSelection: .mix,
        fftSize: fftSize,
        dynamicRange: .init(minimumDB: -120, maximumDB: 0),
        duration: Double(fftSize) / sampleRate,
        maximumColumns: 64
    ))
    accumulator.consume(interleaved)
    let result = accumulator.finish()
    let peak = try #require(result.columns.first?.decibels.max())
    #expect(peak > -3)
}

@Test func knownDurationKeepsColumnsWithinConfiguredLimit() throws {
    let maximumColumns = 64
    let request = SpectrogramAnalysisRequest(
        url: URL(fileURLWithPath: "/tmp/long.wav"),
        streamIndex: 0,
        sampleRate: 8_000,
        channels: 1,
        fftSize: 256,
        duration: 10,
        maximumColumns: maximumColumns
    )
    let accumulator = try SpectrogramAccumulator(request: request)
    accumulator.consume(sine(440, sampleRate: 8_000, count: 80_000))
    let result = accumulator.finish()
    #expect(result.columns.count <= maximumColumns)
    #expect(result.endTime == 10)
}
