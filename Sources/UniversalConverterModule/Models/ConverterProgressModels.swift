import Foundation
import ZEUVECore

public enum ConverterProgressItemStatus: String, Sendable, Equatable {
    case pending
    case running
    case completed
    case skipped
    case failed
    case cancelled
}

public struct ConverterProgressItem: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let sourceNames: [String]
    public let status: ConverterProgressItemStatus
    public let fraction: Double?
    public let phase: String
    public let message: String?

    public init(
        id: UUID,
        sourceNames: [String],
        status: ConverterProgressItemStatus,
        fraction: Double? = nil,
        phase: String,
        message: String? = nil
    ) {
        self.id = id
        self.sourceNames = sourceNames
        self.status = status
        self.fraction = fraction
        self.phase = phase
        self.message = message
    }
}

public struct ConverterProgressSnapshot: Sendable, Equatable {
    public let phase: String
    public let currentItem: String?
    public let completedItems: Int
    public let totalItems: Int
    public let itemFraction: Double?
    public let failedItems: Int
    public let skippedItems: Int
    public let cancelledItems: Int
    public let elapsed: TimeInterval
    public let estimatedRemaining: TimeInterval?
    public let itemStates: [ConverterProgressItem]

    public init(
        phase: String,
        currentItem: String?,
        completedItems: Int,
        totalItems: Int,
        itemFraction: Double? = nil,
        failedItems: Int = 0,
        skippedItems: Int = 0,
        cancelledItems: Int = 0,
        elapsed: TimeInterval = 0,
        estimatedRemaining: TimeInterval? = nil,
        itemStates: [ConverterProgressItem] = []
    ) {
        self.phase = phase
        self.currentItem = currentItem
        self.completedItems = completedItems
        self.totalItems = totalItems
        self.itemFraction = itemFraction
        self.failedItems = failedItems
        self.skippedItems = skippedItems
        self.cancelledItems = cancelledItems
        self.elapsed = max(elapsed, 0)
        self.estimatedRemaining = estimatedRemaining.map { max($0, 0) }
        self.itemStates = itemStates
    }

    public var overallFraction: Double? {
        guard totalItems > 0 else { return nil }
        let item = min(max(itemFraction ?? 0, 0), 1)
        return min(max((Double(completedItems + failedItems + skippedItems + cancelledItems) + item) / Double(totalItems), 0), 1)
    }
}
