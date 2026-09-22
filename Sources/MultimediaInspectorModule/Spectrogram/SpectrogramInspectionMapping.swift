import Foundation

public extension SpectrogramResult {
    func nearestColumn(to time: TimeInterval) -> SpectrogramColumn? {
        guard !columns.isEmpty else { return nil }
        var low = 0
        var high = columns.count - 1
        while low < high {
            let mid = (low + high) / 2
            if columns[mid].time < time { low = mid + 1 } else { high = mid }
        }
        if low == 0 { return columns[0] }
        let before = columns[low - 1]
        let after = columns[low]
        return abs(before.time - time) <= abs(after.time - time) ? before : after
    }

    func approximateDecibels(time: TimeInterval, frequency: Double) -> Float? {
        guard let column = nearestColumn(to: time), !column.decibels.isEmpty else { return nil }
        let bin = min(column.decibels.count - 1, max(0, Int((frequency / max(binWidth, .leastNonzeroMagnitude)).rounded())))
        return column.decibels[bin]
    }
}

public enum SpectrogramAxisTicks {
    public static func times(start: TimeInterval, end: TimeInterval, targetCount: Int = 5) -> [TimeInterval] {
        guard end > start else { return [start] }
        let count = max(2, targetCount)
        return (0..<count).map { start + Double($0) / Double(count - 1) * (end - start) }
    }

    public static func frequencies(nyquist: Double, scale: SpectrogramFrequencyScale, targetCount: Int = 6) -> [Double] {
        guard nyquist > 0 else { return [0] }
        switch scale {
        case .linear:
            let count = max(2, targetCount)
            return (0..<count).map { Double($0) / Double(count - 1) * nyquist }
        case .logarithmic:
            let candidates: [Double] = [20, 50, 100, 200, 500, 1_000, 2_000, 5_000, 10_000, 20_000, 50_000, 100_000]
            var values = candidates.filter { $0 <= nyquist }
            if values.last != nyquist { values.append(nyquist) }
            guard values.count > targetCount, targetCount > 1 else { return values }
            return (0..<targetCount).map { index in
                values[Int((Double(index) / Double(targetCount - 1) * Double(values.count - 1)).rounded())]
            }.reduce(into: []) { result, value in
                if result.last != value { result.append(value) }
            }
        }
    }
}
