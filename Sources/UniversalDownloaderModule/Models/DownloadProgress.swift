import Foundation

public enum DownloadProgressPhase: String, Codable, Sendable, Equatable {
    case preparing
    case analyzing
    case connecting
    case downloading
    case merging
    case converting
    case embeddingMetadata
    case verifying
    case publishing
    case cleaning
}

public struct UniversalDownloadProgress: Codable, Sendable, Equatable {
    public let phase: DownloadProgressPhase
    public let currentItem: String?
    public let itemIndex: Int
    public let itemTotal: Int
    public let fraction: Double?
    public let downloadedBytes: Int64?
    public let totalBytes: Int64?
    public let speedBytesPerSecond: Double?
    public let estimatedSecondsRemaining: Double?
    public let completedItems: Int
    public let failedItems: Int
    public let skippedItems: Int

    public init(phase: DownloadProgressPhase, currentItem: String? = nil, itemIndex: Int = 0, itemTotal: Int = 0, fraction: Double? = nil, downloadedBytes: Int64? = nil, totalBytes: Int64? = nil, speedBytesPerSecond: Double? = nil, estimatedSecondsRemaining: Double? = nil, completedItems: Int = 0, failedItems: Int = 0, skippedItems: Int = 0) {
        self.phase = phase
        self.currentItem = currentItem
        self.itemIndex = itemIndex
        self.itemTotal = itemTotal
        self.fraction = fraction
        self.downloadedBytes = downloadedBytes
        self.totalBytes = totalBytes
        self.speedBytesPerSecond = speedBytesPerSecond
        self.estimatedSecondsRemaining = estimatedSecondsRemaining
        self.completedItems = completedItems
        self.failedItems = failedItems
        self.skippedItems = skippedItems
    }
}
