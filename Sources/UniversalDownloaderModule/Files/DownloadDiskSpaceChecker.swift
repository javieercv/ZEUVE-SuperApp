import Foundation

public struct DownloadDiskSpaceChecker: Sendable {
    public init() {}

    public func availableBytes(at folder: URL) throws -> Int64 {
        #if os(macOS)
        let values = try folder.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
        ])
        return values.volumeAvailableCapacityForImportantUsage ?? Int64(values.volumeAvailableCapacity ?? 0)
        #else
        let values = try folder.resourceValues(forKeys: [.volumeAvailableCapacityKey])
        return Int64(values.volumeAvailableCapacity ?? 0)
        #endif
    }

    public func verify(estimatedBytes: Int64?, at folder: URL) throws {
        guard let estimatedBytes, estimatedBytes > 0 else { return }
        let available = try availableBytes(at: folder)
        let safetyMargin = max(Int64(100 * 1024 * 1024), estimatedBytes / 10)
        guard available >= estimatedBytes + safetyMargin else {
            throw UniversalDownloaderError.insufficientDiskSpace(
                required: estimatedBytes + safetyMargin,
                available: available
            )
        }
    }
}
