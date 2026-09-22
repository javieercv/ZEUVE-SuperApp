import Foundation

/// Presupuesto interno: no depende de SwiftUI ni crece con la duración del archivo.
struct SpectrogramAnalysisPlanner: Sendable {
    static let windowsPerColumn = 8
    static let maximumModelBytes = 64 * 1_024 * 1_024
    static let maximumColumns = 1_800

    struct Window: Sendable, Equatable {
        let startFrame: Int64
        let column: Int
    }
    let windows: [Window]?
    let columnLimit: Int
    let expectedFrames: Int64?
    let hop: Int64

    init(request: SpectrogramAnalysisRequest) throws {
        guard request.sampleRate.isFinite, request.sampleRate > 0,
              request.channels > 0, request.channels <= 64,
              request.fftSize >= 2, request.fftSize <= 32768,
              request.fftSize.nonzeroBitCount == 1,
              request.startTime.isFinite, request.startTime >= 0,
              request.maximumColumns > 0,
              request.dynamicRange.minimumDB.isFinite, request.dynamicRange.maximumDB.isFinite,
              request.dynamicRange.minimumDB < request.dynamicRange.maximumDB else {
            throw MultimediaInspectorError.invalidInput
        }
        hop = Int64(request.fftSize / 2)
        let memoryLimit = Self.maximumModelBytes / ((request.fftSize / 2 + 1) * MemoryLayout<Float>.stride)
        let limit = min(request.maximumColumns, Self.maximumColumns, memoryLimit)
        guard let duration = request.duration else {
            columnLimit = limit; expectedFrames = nil; windows = nil; return
        }
        let frameEstimate = duration * request.sampleRate
        guard duration.isFinite, duration > 0, frameEstimate.isFinite,
              frameEstimate < Double(Int64.max / 2) else { throw MultimediaInspectorError.invalidInput }
        let frames = max(Int64(frameEstimate.rounded(.up)), 1)
        expectedFrames = frames
        let denseCount = frames < request.fftSize ? 1 : (frames - Int64(request.fftSize)) / hop + 2
        columnLimit = min(limit, Int(min(denseCount, Int64(limit))))
        let columnLimit = self.columnLimit
        let hop = self.hop
        if denseCount <= Int64(columnLimit * Self.windowsPerColumn) {
            windows = (0..<Int(denseCount)).map { index in
                let start = Int64(index) * hop
                let column = min(columnLimit - 1, Int(Double(start + hop) / Double(frames) * Double(columnLimit)))
                return Window(startFrame: start, column: column)
            }
        } else {
            var planned: [Window] = []
            planned.reserveCapacity(columnLimit * Self.windowsPerColumn)
            for column in 0..<columnLimit {
                for slot in 0..<Self.windowsPerColumn {
                    // Estratos distribuidos por el intervalo completo, no una única muestra central.
                    let fraction = (Double(column) + (Double(slot) + 0.5) / Double(Self.windowsPerColumn)) / Double(columnLimit)
                    let start = min(max(Int64(fraction * Double(frames)) - hop, 0), max(frames - Int64(request.fftSize), 0))
                    if planned.last?.startFrame != start { planned.append(.init(startFrame: start, column: column)) }
                }
            }
            windows = planned
        }
    }
}
