import Foundation
import Testing
@testable import MultimediaInspectorModule

private func planningRequest(duration: Double? = 7200, fftSize: Int = 4096, channels: Int = 2, columns: Int = 1800) -> SpectrogramAnalysisRequest {
    .init(url: URL(fileURLWithPath: "/tmp/spectral-test.wav"), streamIndex: 0, sampleRate: 48000,
          channels: channels, fftSize: fftSize, duration: duration, maximumColumns: columns)
}

@Test(arguments: [1.0, 170, 1500, 7200, 720000])
func analysisBudgetIsBoundedByResolution(_ duration: Double) throws {
    let plan = try SpectrogramAnalysisPlanner(request: planningRequest(duration: duration))
    let windows = try #require(plan.windows)
    #expect(windows.count <= plan.columnLimit * SpectrogramAnalysisPlanner.windowsPerColumn)
    #expect(zip(windows, windows.dropFirst()).allSatisfy { $0.startFrame < $1.startFrame })
    #expect(windows.allSatisfy { $0.startFrame >= 0 && $0.column < plan.columnLimit })
}

@Test func shortAudioRetainsEveryHalfOverlappingWindow() throws {
    let plan = try SpectrogramAnalysisPlanner(request: planningRequest(duration: 1))
    let windows = try #require(plan.windows)
    #expect(windows.count == (48000 - 4096) / 2048 + 2)
    #expect(zip(windows, windows.dropFirst()).allSatisfy { $1.startFrame - $0.startFrame == 2048 })
}

@Test func sparseWindowsCoverEveryTemporalStratum() throws {
    let plan = try SpectrogramAnalysisPlanner(request: planningRequest())
    let windows = try #require(plan.windows)
    let grouped = Dictionary(grouping: windows, by: \.column)
    #expect(grouped.count == plan.columnLimit)
    for group in grouped.values {
        #expect(group.count == SpectrogramAnalysisPlanner.windowsPerColumn)
        #expect(group.last!.startFrame - group.first!.startFrame > Int64(48000 * 2))
    }
}

@Test(arguments: [256, 1024, 4096, 8192, 16384, 32768])
func largeFFTModelHasIndependentMemoryBudget(_ fftSize: Int) throws {
    let plan = try SpectrogramAnalysisPlanner(request: planningRequest(fftSize: fftSize, channels: 8, columns: Int.max))
    #expect(plan.columnLimit * (fftSize / 2 + 1) * 4 <= SpectrogramAnalysisPlanner.maximumModelBytes)
    #expect(plan.windows!.count <= plan.columnLimit * SpectrogramAnalysisPlanner.windowsPerColumn)
}

@Test func plannerRejectsInvalidAndOverflowingInputs() {
    for duration in [Double.nan, Double.infinity, -1, 0, Double.greatestFiniteMagnitude] {
        #expect(throws: MultimediaInspectorError.self) { _ = try SpectrogramAnalysisPlanner(request: planningRequest(duration: duration)) }
    }
    #expect(throws: MultimediaInspectorError.self) { _ = try SpectrogramAnalysisPlanner(request: planningRequest(channels: 65)) }
    #expect(throws: MultimediaInspectorError.self) { _ = try SpectrogramAnalysisPlanner(request: planningRequest(columns: 0)) }
}

@Test func accumulatorSkipsPCMWithoutAddingFFTsAndHonorsTinyColumnLimit() throws {
    let request = SpectrogramAnalysisRequest(url: URL(fileURLWithPath: "/tmp/sparse.wav"), streamIndex: 0,
        sampleRate: 8000, channels: 2, fftSize: 256, duration: 30, maximumColumns: 4)
    let accumulator = try SpectrogramAccumulator(request: request)
    let chunk = [Float](repeating: 0, count: 1600)
    for _ in 0..<300 { accumulator.consume(chunk) }
    let result = accumulator.finish(), stats = accumulator.diagnostics
    #expect(result.columns.count == 4)
    #expect(stats.fftExecutions <= 4 * SpectrogramAnalysisPlanner.windowsPerColumn * 2)
    #expect(stats.pcmFrames == 240000)
    #expect(stats.decodedDuration == 30)
    #expect(result.columns.flatMap(\.decibels).allSatisfy { $0.isFinite && $0 <= -120 })
}

@Test func cancellingAccumulatorDiscardsPartialWorkAndStopsDSP() throws {
    let accumulator = try SpectrogramAccumulator(request: planningRequest(duration: 10))
    accumulator.consume([Float](repeating: 0.2, count: 10000))
    accumulator.cancel()
    let count = accumulator.diagnostics.fftExecutions
    accumulator.consume([Float](repeating: 1, count: 100000))
    #expect(accumulator.diagnostics.fftExecutions == count)
    #expect(accumulator.finish().columns.isEmpty)
}

private final class Samples: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Float] = []
    func append(_ values: [Float]) { lock.withLock { storage.append(contentsOf: values) } }
    var values: [Float] { lock.withLock { storage } }
}

@Test(arguments: [1, 2, 3, 5, 7, 16383, 16384])
func PCMByteDecoderHandlesUnalignedChunksAndBitPatterns(_ chunkSize: Int) {
    let expected: [Float] = [0, -0.0, 0.25, -1, 1e-18, Float.greatestFiniteMagnitude] + (0..<100).map { Float($0) / 100 }
    var bytes = Data()
    for value in expected { var bits = value.bitPattern.littleEndian; withUnsafeBytes(of: &bits) { bytes.append(contentsOf: $0) } }
    let captured = Samples()
    let decoder = Float32LEStreamDecoder { captured.append($0) }
    for index in stride(from: 0, to: bytes.count, by: chunkSize) { decoder.append(bytes.subdata(in: index..<min(index + chunkSize, bytes.count))) }
    decoder.append(Data([1, 2, 3])); decoder.finish()
    #expect(captured.values.map(\.bitPattern) == expected.map(\.bitPattern))
}

@Test func multichannelChunkBoundariesPreservePowerAndSelectedChannel() throws {
    let frames = 4096
    let mono = (0..<frames).map { Float(sin(2 * Double.pi * 1000 * Double($0) / 48000)) }
    var interleaved: [Float] = []
    for value in mono { interleaved.append(contentsOf: [value, -value, value, -value, value, -value, value, -value]) }
    let request = planningRequest(duration: Double(frames) / 48000, channels: 8)
    let whole = try SpectrogramAccumulator(request: request)
    let chunks = try SpectrogramAccumulator(request: request)
    whole.consume(interleaved)
    for start in stride(from: 0, to: interleaved.count, by: 333) { chunks.consume(Array(interleaved[start..<min(start + 333, interleaved.count)])) }
    let a = whole.finish(), b = chunks.finish()
    #expect(a.columns == b.columns)
    #expect(a.columns[0].decibels.max()! > -3) // Incluye el último hop completado con ceros.
    var selected = request; selected.channelSelection = .channel(7)
    let single = try SpectrogramAccumulator(request: selected); single.consume(interleaved)
    let selectedResult = single.finish()
    #expect(selectedResult.columns.count == a.columns.count)
    for (left, right) in zip(selectedResult.columns, a.columns) {
        #expect(zip(left.decibels, right.decibels).allSatisfy { abs($0 - $1) < 0.0001 })
    }
    #expect(single.diagnostics.fftExecutions * 8 == whole.diagnostics.fftExecutions)
}

@Test func visualRangeAndZoomDoNotDestroyWeakSpectralData() throws {
    let accumulator = try SpectrogramAccumulator(request: planningRequest(duration: 0.1, channels: 1))
    let values = (0..<4800).map { Float(1e-7 * sin(2 * Double.pi * 1000 * Double($0) / 48000)) }
    accumulator.consume(values)
    let result = accumulator.finish(), count = accumulator.diagnostics.fftExecutions
    let wide = result.displaying(dynamicRange: .init(minimumDB: -160))
    #expect(wide.columns == result.columns)
    #expect(wide.columns[0].decibels.max()! < -130)
    #expect(wide.columns[0].decibels.max()! > -150)
    let zoom = wide.cropped(start: 0, duration: 0.05)
    #expect(zoom.endTime == 0.05)
    #expect(accumulator.diagnostics.fftExecutions == count)
}

@Test func DCAndNyquistUseSingleSidedEdgeNormalization() throws {
    let processor = SpectrogramFFTProcessor()
    let dc = try processor.analyze(samples: [Float](repeating: 1, count: 1024), sampleRate: 48000, window: .hann, dynamicRange: .init(minimumDB: -160, maximumDB: 20))
    let nyquist = try processor.analyze(samples: (0..<1024).map { $0.isMultiple(of: 2) ? Float(1) : -1 }, sampleRate: 48000, window: .hann, dynamicRange: .init(minimumDB: -160, maximumDB: 20))
    #expect(abs(dc[0]) < 0.001)
    #expect(abs(nyquist[512]) < 0.001)
}
