import Foundation

public enum DownloadItemResultStatus: String, Codable, Sendable, Equatable {
    case completed
    case skipped
    case failed
    case cancelled
}

public struct UniversalDownloadItemResult: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let canonicalID: String
    public let title: String
    public let status: DownloadItemResultStatus
    public let outputFiles: [URL]
    public let errorReference: String?
    public let userMessage: String?

    public init(id: UUID = UUID(), canonicalID: String, title: String, status: DownloadItemResultStatus, outputFiles: [URL] = [], errorReference: String? = nil, userMessage: String? = nil) {
        self.id = id
        self.canonicalID = canonicalID
        self.title = title
        self.status = status
        self.outputFiles = outputFiles
        self.errorReference = errorReference
        self.userMessage = userMessage
    }
}

public struct UniversalDownloadResult: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let startedAt: Date
    public let finishedAt: Date
    public let outputFolder: URL
    public let mode: DownloadMode
    public let formatSummary: String
    public let items: [UniversalDownloadItemResult]
    public let auxiliaryFiles: [URL]
    public let warnings: [String]
    public let wasCancelled: Bool

    public var completedCount: Int { items.filter { $0.status == .completed }.count }
    public var skippedCount: Int { items.filter { $0.status == .skipped }.count }
    public var failedCount: Int { items.filter { $0.status == .failed }.count }
    public var hasTotalFailure: Bool { !wasCancelled && completedCount == 0 && failedCount > 0 }

    public init(id: UUID, startedAt: Date, finishedAt: Date = Date(), outputFolder: URL, mode: DownloadMode, formatSummary: String, items: [UniversalDownloadItemResult], auxiliaryFiles: [URL] = [], warnings: [String] = [], wasCancelled: Bool) {
        self.id = id
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.outputFolder = outputFolder
        self.mode = mode
        self.formatSummary = formatSummary
        self.items = items
        self.auxiliaryFiles = auxiliaryFiles
        self.warnings = warnings
        self.wasCancelled = wasCancelled
    }
}
