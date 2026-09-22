import Foundation

public struct SpectrogramRaster: Sendable, Equatable {
    public let width: Int
    public let height: Int
    public let rgba8: [UInt8]

    public init(width: Int, height: Int, rgba8: [UInt8]) {
        self.width = width
        self.height = height
        self.rgba8 = rgba8
    }
}

public struct SpectrogramRasterizer: Sendable {
    public init() {}

    public func rasterize(
        _ result: SpectrogramResult,
        frequencyScale: SpectrogramFrequencyScale,
        width requestedWidth: Int,
        height requestedHeight: Int,
        shouldCancel: @Sendable () -> Bool = { false }
    ) throws -> SpectrogramRaster {
        let width = max(1, min(requestedWidth, 4096))
        let height = max(1, min(requestedHeight, 4096))
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard !result.columns.isEmpty else {
            for pixel in stride(from: 3, to: pixels.count, by: 4) { pixels[pixel] = 255 }
            return .init(width: width, height: height, rgba8: pixels)
        }

        let firstBinCount = result.columns.first(where: { !$0.decibels.isEmpty })?.decibels.count ?? 0
        guard firstBinCount > 0 else {
            for pixel in stride(from: 3, to: pixels.count, by: 4) { pixels[pixel] = 255 }
            return .init(width: width, height: height, rgba8: pixels)
        }

        let rowBins = SpectrogramRenderMapping.rowBinIndices(
            height: height,
            binCount: firstBinCount,
            nyquist: result.nyquist,
            scale: frequencyScale
        )
        var cursor = 0
        let columnIndices = (0..<width).map { x in
            let time = result.startTime + Double(x) / Double(max(width - 1, 1)) * (result.endTime - result.startTime)
            while cursor + 1 < result.columns.count,
                  abs(result.columns[cursor + 1].time - time) < abs(result.columns[cursor].time - time) { cursor += 1 }
            return cursor
        }
        let rangeSpan = max(result.dynamicRange.maximumDB - result.dynamicRange.minimumDB, 1)

        for x in 0..<width {
            if x % 32 == 0, shouldCancel() { throw MultimediaInspectorError.cancelled }
            let values = result.columns[columnIndices[x]].decibels
            guard !values.isEmpty else { continue }
            for row in 0..<height {
                let bin = min(values.count - 1, rowBins[row])
                let value = values[bin]
                let normalized = min(max((value - result.dynamicRange.minimumDB) / rangeSpan, 0), 1)
                let red = UInt8((normalized * 255).rounded())
                let green = UInt8((normalized * normalized * 255).rounded())
                let blue = UInt8(((1 - normalized) * 255).rounded())
                let offset = (row * width + x) * 4
                pixels[offset] = red
                pixels[offset + 1] = green
                pixels[offset + 2] = blue
                pixels[offset + 3] = 255
            }
        }
        return .init(width: width, height: height, rgba8: pixels)
    }
}
