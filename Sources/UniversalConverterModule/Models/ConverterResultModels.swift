import Foundation
import ZEUVECore

public enum ConverterItemResultStatus: String, Codable, Sendable, Equatable {
    case completed
    case skipped
    case failed
    case cancelled
}

public struct ConverterItemResult: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let sourceNames: [String]
    public let status: ConverterItemResultStatus
    public let outputURLs: [URL]
    public let message: String?

    public init(
        id: UUID = UUID(),
        sourceNames: [String],
        status: ConverterItemResultStatus,
        outputURLs: [URL] = [],
        message: String? = nil
    ) {
        self.id = id
        self.sourceNames = sourceNames
        self.status = status
        self.outputURLs = outputURLs
        self.message = message
    }
}

public struct UniversalConverterResult: Codable, Sendable, Equatable {
    public let operationID: UUID
    public let startedAt: Date
    public let finishedAt: Date
    public let outputFolder: URL
    public let items: [ConverterItemResult]
    public let archiveURL: URL?

    public init(
        operationID: UUID,
        startedAt: Date,
        finishedAt: Date = Date(),
        outputFolder: URL,
        items: [ConverterItemResult],
        archiveURL: URL? = nil
    ) {
        self.operationID = operationID
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.outputFolder = outputFolder
        self.items = items
        self.archiveURL = archiveURL
    }

    public var completedCount: Int { items.filter { $0.status == .completed }.count }
    public var skippedCount: Int { items.filter { $0.status == .skipped }.count }
    public var failedCount: Int { items.filter { $0.status == .failed }.count }
    public var cancelledCount: Int { items.filter { $0.status == .cancelled }.count }
    public var generatedFiles: [URL] { items.flatMap(\.outputURLs) + (archiveURL.map { [$0] } ?? []) }
    public var duration: TimeInterval { finishedAt.timeIntervalSince(startedAt) }
}
