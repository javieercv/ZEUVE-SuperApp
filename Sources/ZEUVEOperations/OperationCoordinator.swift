import Foundation
#if SWIFT_PACKAGE
import ZEUVECore
#endif

public enum OperationCoordinatorError: LocalizedError, Equatable {
    case busy(OperationSnapshot)
    case operationNotActive(UUID)

    public var errorDescription: String? {
        switch self {
        case .busy(let operation):
            return "Ya hay una operación en curso: \(operation.name)."
        case .operationNotActive:
            return "La operación ya no está activa."
        }
    }
}

public actor OperationCoordinator {
    private var activeOperation: OperationSnapshot?
    private var cancellationRequested = false
    private var continuations: [UUID: AsyncStream<OperationSnapshot?>.Continuation] = [:]

    public init() {}

    public func begin(moduleID: String, name: String) throws -> UUID {
        if let activeOperation { throw OperationCoordinatorError.busy(activeOperation) }
        let id = UUID()
        activeOperation = OperationSnapshot(
            id: id,
            moduleID: moduleID,
            name: name,
            startedAt: Date(),
            status: .running,
            progress: nil
        )
        cancellationRequested = false
        publish()
        return id
    }

    public func update(id: UUID, progress: OperationProgress) throws {
        guard let activeOperation, activeOperation.id == id else {
            throw OperationCoordinatorError.operationNotActive(id)
        }
        self.activeOperation = OperationSnapshot(
            id: activeOperation.id,
            moduleID: activeOperation.moduleID,
            name: activeOperation.name,
            startedAt: activeOperation.startedAt,
            status: cancellationRequested ? .cancelling : .running,
            progress: progress
        )
        publish()
    }

    public func requestCancellation(id: UUID) throws {
        guard let activeOperation, activeOperation.id == id else {
            throw OperationCoordinatorError.operationNotActive(id)
        }
        cancellationRequested = true
        self.activeOperation = OperationSnapshot(
            id: activeOperation.id,
            moduleID: activeOperation.moduleID,
            name: activeOperation.name,
            startedAt: activeOperation.startedAt,
            status: .cancelling,
            progress: activeOperation.progress
        )
        publish()
    }

    public func shouldCancel(id: UUID) -> Bool {
        activeOperation?.id == id && cancellationRequested
    }

    public func finish(id: UUID) throws {
        guard activeOperation?.id == id else {
            throw OperationCoordinatorError.operationNotActive(id)
        }
        activeOperation = nil
        cancellationRequested = false
        publish()
    }

    public func current() -> OperationSnapshot? {
        activeOperation
    }

    public func snapshots() -> AsyncStream<OperationSnapshot?> {
        let key = UUID()
        return AsyncStream { continuation in
            continuations[key] = continuation
            continuation.yield(activeOperation)
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(key) }
            }
        }
    }

    private func removeContinuation(_ key: UUID) {
        continuations.removeValue(forKey: key)
    }

    private func publish() {
        for continuation in continuations.values {
            continuation.yield(activeOperation)
        }
    }
}
