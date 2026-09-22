import Foundation

public struct YTDLPAdaptiveFragmentPolicy: Sendable, Equatable {
    public init() {}

    public func levels(startingAt value: Int) -> [Int] {
        let start = max(1, min(value, 16))
        let standard = [16, 8, 4, 1].filter { $0 <= start }
        return standard.isEmpty ? [1] : standard
    }

    public func shouldReduce(after stderr: String) -> Bool {
        let value = stderr.lowercased()
        let signals = [
            "too many requests",
            "http error 429",
            "fragment",
            "timed out",
            "timeout",
            "connection reset",
            "temporarily unavailable",
            "unable to download video data",
        ]
        return signals.contains { value.contains($0) }
    }
}
