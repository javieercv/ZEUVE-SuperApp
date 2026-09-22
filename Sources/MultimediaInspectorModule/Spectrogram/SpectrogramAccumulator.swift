import Foundation
#if canImport(Accelerate)
import Accelerate
#endif

/// Todos los buffers y diagnósticos se protegen con el mismo lock. Ningún buffer escapa mutable.
final class SpectrogramAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private let request: SpectrogramAnalysisRequest
    let plan: SpectrogramAnalysisPlanner
    private let analyzer: SpectrogramFFTAnalyzer
    private var buffers: [[Float]]
    private var remainder: [Float] = []
    private var framesConsumed: Int64 = 0
    private var windowIndex = 0
    private var windowStart: Int64 = 0
    private var filled = 0
    private var power: [Float]
    private var spectraInColumn = 0
    private var currentColumn = 0
    private var timeSum = 0.0
    private var windowCount = 0
    private var columns: [SpectrogramColumn] = []
    private var cancelled = false
    private var completed = false
    private var fftCount = 0
    private var lastProgress = 0.0
    private let onProgress: @Sendable (Double) -> Void

    init(request: SpectrogramAnalysisRequest, onProgress: @escaping @Sendable (Double) -> Void = { _ in }) throws {
        self.request = request
        self.plan = try SpectrogramAnalysisPlanner(request: request)
        self.analyzer = try SpectrogramFFTAnalyzer(fftSize: request.fftSize, window: request.window, dynamicRange: request.dynamicRange)
        let count: Int
        switch request.channelSelection {
        case .mix: count = request.channels
        case .channel(let index):
            guard (0..<request.channels).contains(index) else { throw MultimediaInspectorError.invalidInput }
            count = 1
        }
        self.buffers = (0..<count).map { _ in [Float](repeating: 0, count: request.fftSize) }
        self.power = [Float](repeating: 0, count: request.fftSize / 2 + 1)
        self.onProgress = onProgress
        self.windowStart = plan.windows?.first?.startFrame ?? 0
        columns.reserveCapacity(plan.columnLimit)
    }

    var diagnostics: SpectrogramDiagnostics {
        lock.withLock { .init(fftExecutions: fftCount, pcmFrames: framesConsumed, columns: columns.count,
                              processedChannels: buffers.count, decodedDuration: Double(framesConsumed) / request.sampleRate) }
    }
    func cancel() { lock.withLock { cancelled = true } }

    func consume(_ values: [Float]) {
        lock.withLock {
            guard !cancelled, !completed, !values.isEmpty else { return }
            values.withUnsafeBufferPointer { input in
                var offset = 0
                if !remainder.isEmpty {
                    let take = min(request.channels - remainder.count, input.count)
                    remainder.append(contentsOf: input.prefix(take)); offset += take
                    if remainder.count == request.channels {
                        remainder.withUnsafeBufferPointer { consumeFrames($0, count: 1) }
                        remainder.removeAll(keepingCapacity: true)
                    }
                }
                let frames = (input.count - offset) / request.channels
                if frames > 0 {
                    consumeFrames(UnsafeBufferPointer(rebasing: input[offset..<(offset + frames * request.channels)]), count: frames)
                    offset += frames * request.channels
                }
                if offset < input.count { remainder.append(contentsOf: input[offset...]) }
            }
            if let total = plan.expectedFrames {
                let progress = min(Double(framesConsumed) / Double(total) * 0.95, 0.95)
                if progress - lastProgress >= 0.01 { lastProgress = progress; onProgress(progress) }
            }
        }
    }

    private func consumeFrames(_ input: UnsafeBufferPointer<Float>, count: Int) {
        let blockStart = framesConsumed
        framesConsumed += Int64(count)
        while windowIsAvailable {
            let needed = windowStart + Int64(filled)
            let sourceFrame = max(needed - blockStart, 0)
            guard sourceFrame < count else { break }
            let take = min(request.fftSize - filled, count - Int(sourceFrame))
            for channel in buffers.indices {
                let sourceChannel: Int
                switch request.channelSelection { case .mix: sourceChannel = channel; case .channel(let selected): sourceChannel = selected }
                let source = input.baseAddress! + Int(sourceFrame) * request.channels + sourceChannel
                buffers[channel].withUnsafeMutableBufferPointer { destination in
                    #if canImport(Accelerate)
                    var unity: Float = 1
                    vDSP_vsmul(source, vDSP_Stride(request.channels), &unity, destination.baseAddress! + filled, 1, vDSP_Length(take))
                    #else
                    for index in 0..<take { destination[filled + index] = source[index * request.channels] }
                    #endif
                }
            }
            filled += take
            if filled == request.fftSize { processWindow(); advanceWindow() }
            else { break }
        }
    }

    private var windowIsAvailable: Bool { plan.windows.map { windowIndex < $0.count } ?? true }

    private func advanceWindow() {
        let oldStart = windowStart
        windowIndex += 1
        windowStart = plan.windows.flatMap { windowIndex < $0.count ? $0[windowIndex].startFrame : nil }
            ?? (oldStart + plan.hop)
        let shift = Int(min(windowStart - oldStart, Int64(request.fftSize)))
        filled = max(request.fftSize - shift, 0)
        if filled > 0 {
            for channel in buffers.indices {
                buffers[channel].withUnsafeMutableBufferPointer { buffer in
                    _ = memmove(buffer.baseAddress!, buffer.baseAddress! + shift, filled * MemoryLayout<Float>.stride)
                }
            }
        }
    }

    private func processWindow() {
        let bucket = plan.windows?[windowIndex].column ?? windowIndex
        if spectraInColumn > 0, bucket != currentColumn { flushColumn() }
        currentColumn = bucket
        analyzePowerMix()
        timeSum += Double(windowStart + plan.hop) / request.sampleRate + request.startTime
        windowCount += 1
    }

    /// Potencia por canal: no existe promedio PCM ni cancelación entre canales antífase.
    private func analyzePowerMix() {
        for buffer in buffers {
            let spectrum = analyzer.analyzePower(buffer)
            #if canImport(Accelerate)
            vDSP_vadd(power, 1, spectrum, 1, &power, 1, vDSP_Length(power.count))
            #else
            for bin in power.indices { power[bin] += spectrum[bin] }
            #endif
            spectraInColumn += 1
            fftCount += 1
        }
    }

    private func flushColumn() {
        guard spectraInColumn > 0 else { return }
        // El rango visual no destruye contenido débil del modelo: cambiarlo no requiere FFT.
        let divisor = Float(spectraInColumn)
        let db = power.map { 10 * log10f(max($0 / divisor, 1e-20)) }
        columns.append(.init(time: timeSum / Double(windowCount), decibels: db))
        power.withUnsafeMutableBufferPointer { $0.initialize(repeating: 0) }
        spectraInColumn = 0; windowCount = 0; timeSum = 0
        if plan.windows == nil, columns.count > plan.columnLimit { compactUnknownDuration() }
    }

    private func compactUnknownDuration() {
        var compacted: [SpectrogramColumn] = []
        for index in stride(from: 0, to: columns.count, by: 2) {
            guard index + 1 < columns.count else { compacted.append(columns[index]); break }
            let left = columns[index], right = columns[index + 1]
            let db = zip(left.decibels, right.decibels).map { 10 * log10f(max((powf(10, $0 / 10) + powf(10, $1 / 10)) / 2, 1e-20)) }
            compacted.append(.init(time: (left.time + right.time) / 2, decibels: db))
        }
        columns = compacted
    }

    func finish() -> SpectrogramResult {
        lock.withLock {
            if !completed, !cancelled {
                if filled > 0, windowIsAvailable, windowStart < framesConsumed {
                    for channel in buffers.indices {
                        for index in filled..<request.fftSize { buffers[channel][index] = 0 }
                    }
                    processWindow()
                }
                flushColumn()
            }
            completed = true
            if cancelled { columns.removeAll() }
            remainder.removeAll(); filled = 0
            return .init(sampleRate: request.sampleRate, fftSize: request.fftSize, startTime: request.startTime,
                         endTime: request.startTime + Double(framesConsumed) / request.sampleRate,
                         dynamicRange: request.dynamicRange, columns: columns)
        }
    }
}
