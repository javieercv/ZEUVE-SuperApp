import Foundation

/// Mapea la escala de frecuencia de forma idéntica para la vista y la exportación.
public enum SpectrogramRenderMapping {
    public static let logarithmicMinimumFrequency = 20.0

    public static func frequency(
        normalizedFromBottom normalized: Double,
        nyquist: Double,
        scale: SpectrogramFrequencyScale
    ) -> Double {
        let fraction = min(max(normalized, 0), 1)
        guard nyquist > 0 else { return 0 }
        switch scale {
        case .linear:
            return fraction * nyquist
        case .logarithmic:
            let minimum = logarithmicMinimumFrequency
            guard nyquist > minimum else { return fraction * nyquist }
            return minimum * pow(nyquist / minimum, fraction)
        }
    }

    public static func normalizedFromBottom(
        frequency: Double,
        nyquist: Double,
        scale: SpectrogramFrequencyScale
    ) -> Double {
        guard nyquist > 0 else { return 0 }
        let value = min(max(frequency, 0), nyquist)
        switch scale {
        case .linear:
            return value / nyquist
        case .logarithmic:
            let minimum = logarithmicMinimumFrequency
            guard nyquist > minimum, value > 0 else { return 0 }
            return min(max(log(value / minimum) / log(nyquist / minimum), 0), 1)
        }
    }

    public static func binIndex(
        rowFromTop: Int,
        height: Int,
        binCount: Int,
        nyquist: Double,
        scale: SpectrogramFrequencyScale
    ) -> Int {
        guard height > 0, binCount > 0 else { return 0 }
        let denominator = Double(max(height - 1, 1))
        let fromBottom = Double(max(height - 1 - rowFromTop, 0)) / denominator
        let frequency = frequency(normalizedFromBottom: fromBottom, nyquist: nyquist, scale: scale)
        guard nyquist > 0 else { return 0 }
        return min(binCount - 1, max(0, Int((frequency / nyquist) * Double(binCount - 1))))
    }

    public static func rowBinIndices(
        height: Int,
        binCount: Int,
        nyquist: Double,
        scale: SpectrogramFrequencyScale
    ) -> [Int] {
        guard height > 0 else { return [] }
        return (0..<height).map {
            binIndex(rowFromTop: $0, height: height, binCount: binCount, nyquist: nyquist, scale: scale)
        }
    }
}
