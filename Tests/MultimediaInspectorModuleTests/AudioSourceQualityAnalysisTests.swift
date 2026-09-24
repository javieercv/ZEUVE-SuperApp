import Foundation
import Testing
@testable import MultimediaInspectorModule

private let qualitySampleRate = 48_000.0

private func deterministicNoise(seconds: Double) -> [Float] {
    let count = Int(qualitySampleRate * seconds)
    var state: UInt64 = 0x1234_5678_9ABC_DEF0
    return (0 ..< count).map { _ in
        state = state &* 6_364_136_223_846_793_005 &+ 1
        let value = Double((state >> 32) & 0xFFFF_FFFF) / Double(UInt32.max)
        return Float((value * 2 - 1) * 0.65)
    }
}

private func lowPass(_ input: [Float], cutoff: Double, taps: Int = 129) -> [Float] {
    let middle = (taps - 1) / 2
    let normalizedCutoff = cutoff / qualitySampleRate
    var kernel = (0 ..< taps).map { index -> Double in
        let offset = Double(index - middle)
        let sinc = offset == 0
            ? 2 * normalizedCutoff
            : sin(2 * Double.pi * normalizedCutoff * offset) / (Double.pi * offset)
        let window = 0.5 - 0.5 * cos(2 * Double.pi * Double(index) / Double(taps - 1))
        return sinc * window
    }
    let sum = kernel.reduce(0, +)
    kernel = kernel.map { $0 / sum }
    var output = [Float](repeating: 0, count: input.count)
    for index in input.indices {
        var value = 0.0
        let lower = max(0, index - middle)
        let upper = min(input.count - 1, index + middle)
        for sourceIndex in lower ... upper {
            value += Double(input[sourceIndex]) * kernel[sourceIndex - index + middle]
        }
        output[index] = Float(value)
    }
    return output
}

private func normalized(_ input: [Float], peak: Float = 0.75) -> [Float] {
    let maximum = input.map(abs).max() ?? 0
    guard maximum > 0 else { return input }
    let scale = peak / maximum
    return input.map { $0 * scale }
}

private func analyzeQuality(_ samples: [Float], expectedDuration: Double? = nil) throws -> AudioSourceQualityAnalysis {
    let accumulator = try AudioSourceQualityAccumulator(
        sampleRate: qualitySampleRate,
        expectedDuration: expectedDuration ?? (Double(samples.count) / qualitySampleRate)
    )
    accumulator.append(samples)
    return accumulator.finish()
}

@Test func sourceQualityTreatsSilenceAndPureToneAsInsufficientEvidence() throws {
    let silence = try analyzeQuality([Float](repeating: 0, count: Int(qualitySampleRate)))
    let tone = (0 ..< Int(qualitySampleRate * 2)).map { index in
        Float(sin(2 * Double.pi * 1_000 * Double(index) / qualitySampleRate) * 0.7)
    }
    let tonal = try analyzeQuality(tone)

    #expect(silence.indication == .insufficientEvidence)
    #expect(silence.activeWindowCount == 0)
    #expect(tonal.indication == .insufficientEvidence)
    #expect(tonal.persistentCutoffCandidateHz == nil)
}

@Test func sourceQualitySeparatesRolloffFromEffectiveFullBandContent() throws {
    let result = try analyzeQuality(deterministicNoise(seconds: 2.5))
    #expect((result.effectiveBandwidthHz ?? 0) > 18_000)
    #expect(result.persistentCutoffCandidateHz == nil)
    #expect(result.spectralRolloffHz != nil)
    #expect(result.indication == .noClearIndications)
}

@Test func sourceQualityFindsKnownPersistentLowPassRegion() throws {
    let signal = normalized(lowPass(deterministicNoise(seconds: 3), cutoff: 9_000))
    let result = try analyzeQuality(signal)
    let bandwidth = try #require(result.effectiveBandwidthHz)
    let cutoff = try #require(result.persistentCutoffCandidateHz)

    #expect(bandwidth > 7_000 && bandwidth < 11_500)
    #expect(cutoff > 7_000 && cutoff < 11_500)
    #expect(result.indication == .moderate || result.indication == .strong)
}

@Test func sourceQualityDoesNotConfuseBassDominanceWithLowBandwidth() throws {
    let noise = deterministicNoise(seconds: 2.5)
    let bass = lowPass(noise, cutoff: 4_000)
    let combined = normalized(zip(bass, noise).map { $0.0 * 0.95 + $0.1 * 0.02 })
    let result = try analyzeQuality(combined)

    #expect((result.effectiveBandwidthHz ?? 0) > 17_000)
    #expect(result.persistentCutoffCandidateHz == nil)
}

@Test func sourceQualityIgnoresAnIsolatedSpectralGap() throws {
    let noise = deterministicNoise(seconds: 2.5)
    let belowGap = lowPass(noise, cutoff: 7_000)
    let belowUpperEdge = lowPass(noise, cutoff: 13_000)
    let aboveGap = zip(noise, belowUpperEdge).map { $0.0 - $0.1 }
    let signal = normalized(zip(belowGap, aboveGap).map { $0.0 + $0.1 })
    let result = try analyzeQuality(signal)

    #expect((result.effectiveBandwidthHz ?? 0) > 17_000)
    #expect(result.persistentCutoffCandidateHz == nil)
}

@Test func sourceQualityConfidenceRequiresCoverageOfALongFile() throws {
    let samples = deterministicNoise(seconds: 5)
    let result = try analyzeQuality(samples, expectedDuration: 300)
    #expect(result.confidence < 0.50)
}

@Test func sourceQualityAggregationKeepsBeginningMiddleAndEndInfluence() throws {
    let noise = deterministicNoise(seconds: 3)
    let low = lowPass(noise, cutoff: 7_000)
    let oneSecond = Int(qualitySampleRate)
    let signal = Array(low[0 ..< oneSecond])
        + Array(noise[oneSecond ..< oneSecond * 2])
        + Array(low[oneSecond * 2 ..< oneSecond * 3])
    let result = try analyzeQuality(normalized(signal))
    #expect((result.effectiveBandwidthHz ?? 0) > 17_000)
}

@Test func anomalyAccumulatorGroupsAdjacentWindowsAndReportsTruncation() {
    let grouped = SpectralAnomalyAccumulator(maximumRetained: 256, groupingGap: 0.12)
    grouped.record(start: 1, end: 1.08, severity: 0.5)
    grouped.record(start: 1.09, end: 1.17, severity: 0.8)
    let groupedResult = grouped.finish()
    #expect(groupedResult.total == 1)
    #expect(groupedResult.retained.count == 1)

    let many = SpectralAnomalyAccumulator(maximumRetained: 256, groupingGap: 0.01)
    for index in 0 ..< 300 {
        let start = Double(index) * 0.1
        many.record(start: start, end: start + 0.02, severity: Double(index % 10) / 10)
    }
    let result = many.finish()
    #expect(result.total == 300)
    #expect(result.retained.count == 256)
    #expect(result.truncated)
}
