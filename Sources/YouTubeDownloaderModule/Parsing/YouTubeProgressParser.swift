import Foundation

public struct YouTubeProgressParser: Sendable {
    public init() {}

    public func parse(line: String, itemIndex: Int, itemTotal: Int, title: String, completed: Int, failed: Int, skipped: Int) -> YouTubeDownloadProgress? {
        guard line.hasPrefix("ZEUVE_PROGRESS|") else {
            if line.localizedCaseInsensitiveContains("Merging formats") {
                return base(.merging, itemIndex, itemTotal, title, completed, failed, skipped)
            }
            if line.localizedCaseInsensitiveContains("ExtractAudio") || line.localizedCaseInsensitiveContains("Convert") {
                return base(.converting, itemIndex, itemTotal, title, completed, failed, skipped)
            }
            return nil
        }
        let values = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard values.count >= 7 else { return nil }
        return YouTubeDownloadProgress(
            phase: .downloading,
            currentItem: title,
            itemIndex: itemIndex,
            itemTotal: itemTotal,
            fraction: parseFraction(values[1]),
            downloadedBytes: parseInt64(values[2]),
            totalBytes: parseInt64(values[3]) ?? parseInt64(values[4]),
            speedBytesPerSecond: parseDouble(values[5]),
            estimatedSecondsRemaining: parseDouble(values[6]),
            completedItems: completed,
            failedItems: failed,
            skippedItems: skipped
        )
    }

    private func base(_ phase: YouTubeProgressPhase, _ index: Int, _ total: Int, _ title: String, _ completed: Int, _ failed: Int, _ skipped: Int) -> YouTubeDownloadProgress {
        .init(phase: phase, currentItem: title, itemIndex: index, itemTotal: total, completedItems: completed, failedItems: failed, skippedItems: skipped)
    }

    private func parseFraction(_ value: String) -> Double? {
        let normalized = value.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
        guard let number = Double(normalized) else { return nil }
        return min(max(number / 100, 0), 1)
    }
    private func parseInt64(_ value: String) -> Int64? { Int64(value.trimmingCharacters(in: .whitespaces)) }
    private func parseDouble(_ value: String) -> Double? { Double(value.trimmingCharacters(in: .whitespaces)) }
}
