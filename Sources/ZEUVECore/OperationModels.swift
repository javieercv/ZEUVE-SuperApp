import Foundation

public enum OperationStatus: String, Codable, Sendable {
    case queued
    case running
    case cancelling
    case completed
    case cancelled
    case failed
    case undone
    case partiallyUndone
    case undoUnavailable
}

public struct OperationProgress: Codable, Sendable, Equatable {
    public let completed: Int
    public let total: Int?
    public let phase: String
    public let currentItem: String?

    public init(completed: Int, total: Int?, phase: String, currentItem: String? = nil) {
        self.completed = completed
        self.total = total
        self.phase = phase
        self.currentItem = currentItem
    }

    public var fraction: Double? {
        guard let total, total > 0 else { return nil }
        return min(max(Double(completed) / Double(total), 0), 1)
    }
}

public struct OperationSnapshot: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let moduleID: String
    public let name: String
    public let startedAt: Date
    public let status: OperationStatus
    public let progress: OperationProgress?

    public init(
        id: UUID,
        moduleID: String,
        name: String,
        startedAt: Date,
        status: OperationStatus,
        progress: OperationProgress?
    ) {
        self.id = id
        self.moduleID = moduleID
        self.name = name
        self.startedAt = startedAt
        self.status = status
        self.progress = progress
    }
}

public struct OperationHistoryRecord: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let moduleID: String
    public let kind: String
    public let baseFolder: String?
    public let createdAt: Date
    public var status: OperationStatus
    public var undoAvailable: Bool
    public let payload: Data

    public init(
        id: UUID = UUID(),
        moduleID: String,
        kind: String,
        baseFolder: String?,
        createdAt: Date = Date(),
        status: OperationStatus,
        undoAvailable: Bool,
        payload: Data
    ) {
        self.id = id
        self.moduleID = moduleID
        self.kind = kind
        self.baseFolder = baseFolder
        self.createdAt = createdAt
        self.status = status
        self.undoAvailable = undoAvailable
        self.payload = payload
    }
}
