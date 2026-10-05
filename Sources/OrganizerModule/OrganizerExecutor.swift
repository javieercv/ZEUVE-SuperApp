import Foundation
#if SWIFT_PACKAGE
import ZEUVECore
#endif

public struct OrganizerExecutor {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func execute(
        plan: OrganizerPlan,
        selectedIDs: Set<UUID>? = nil,
        progress: OrganizerProgressHandler? = nil
    ) throws -> OrganizerExecutionResult {
        let selected = plan.selectedOperations(selectedIDs)
        let startedAt = Date()
        try preflight(selected, baseFolder: plan.baseFolder)

        var createdDirectories = Set<URL>()
        var completed: [OrganizerExecutionItem] = []

        do {
            for (index, operation) in selected.enumerated() {
                try Task.checkCancellation()
                guard operation.sourceFingerprint.matches(operation.source, fileManager: fileManager) else {
                    throw OrganizerError.planInvalidated(operation.source.lastPathComponent)
                }
                guard !fileManager.fileExists(atPath: operation.destination.path) else {
                    throw OrganizerError.destinationAppeared(operation.destination.lastPathComponent)
                }
                try validateDestination(operation.destination, baseFolder: plan.baseFolder)

                try createDirectoryTree(
                    operation.destination.deletingLastPathComponent(),
                    baseFolder: plan.baseFolder,
                    created: &createdDirectories
                )
                try fileManager.moveItem(at: operation.source, to: operation.destination)
                let fingerprint = try FileFingerprint.read(from: operation.destination, fileManager: fileManager)
                completed.append(
                    OrganizerExecutionItem(
                        source: operation.source,
                        destination: operation.destination,
                        destinationFingerprint: fingerprint
                    )
                )
                progress?(
                    OperationProgress(
                        completed: index + 1,
                        total: selected.count,
                        phase: "Organizando archivos",
                        currentItem: operation.source.lastPathComponent
                    )
                )
            }
        } catch {
            rollback(completed)
            removeEmptyDirectories(createdDirectories)
            throw error
        }

        return OrganizerExecutionResult(
            operationID: UUID(),
            baseFolder: plan.baseFolder,
            moved: completed.count,
            skipped: max(plan.operations.count - selected.count, 0),
            renamed: selected.filter { $0.conflict }.count,
            createdDirectories: createdDirectories.sorted { $0.pathComponents.count < $1.pathComponents.count },
            operations: completed,
            startedAt: startedAt,
            finishedAt: Date()
        )
    }

    private func preflight(_ operations: [OrganizerMoveOperation], baseFolder: URL) throws {
        for operation in operations {
            try Task.checkCancellation()
            try validateDestination(operation.destination, baseFolder: baseFolder)
            guard fileManager.fileExists(atPath: operation.source.path) else {
                throw OrganizerError.planInvalidated(operation.source.lastPathComponent)
            }
            guard operation.sourceFingerprint.matches(operation.source, fileManager: fileManager) else {
                throw OrganizerError.planInvalidated(operation.source.lastPathComponent)
            }
            guard !fileManager.fileExists(atPath: operation.destination.path) else {
                throw OrganizerError.destinationAppeared(operation.destination.lastPathComponent)
            }
        }
    }

    private func validateDestination(_ destination: URL, baseFolder: URL) throws {
        let base = baseFolder.standardizedFileURL
        var cursor = destination.standardizedFileURL
        guard cursor.path.hasPrefix(base.path + "/") else { throw OrganizerError.planInvalidated(destination.lastPathComponent) }
        while true {
            // lstat mediante resourceValues también detecta enlaces colgantes.
            if let values = try? cursor.resourceValues(forKeys: [.isSymbolicLinkKey]), values.isSymbolicLink == true {
                throw OrganizerError.planInvalidated(destination.lastPathComponent)
            }
            if cursor == base { break }
            cursor.deleteLastPathComponent()
        }
        guard base.resolvingSymlinksInPath() == base else { throw OrganizerError.planInvalidated(destination.lastPathComponent) }
    }

    private func createDirectoryTree(_ directory: URL, baseFolder: URL, created: inout Set<URL>) throws {
        var missing: [URL] = []
        var cursor = directory.standardizedFileURL
        let base = baseFolder.standardizedFileURL
        while cursor.path != base.path && cursor.path.hasPrefix(base.path + "/") {
            if fileManager.fileExists(atPath: cursor.path) { break }
            missing.append(cursor)
            let parent = cursor.deletingLastPathComponent()
            if parent.path == cursor.path { break }
            cursor = parent
        }
        for folder in missing.reversed() {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: false)
            created.insert(folder)
        }
    }

    private func rollback(_ completed: [OrganizerExecutionItem]) {
        for item in completed.reversed() {
            guard fileManager.fileExists(atPath: item.destination.path),
                  !fileManager.fileExists(atPath: item.source.path) else { continue }
            try? fileManager.createDirectory(
                at: item.source.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? fileManager.moveItem(at: item.destination, to: item.source)
        }
    }

    private func removeEmptyDirectories(_ directories: Set<URL>) {
        for directory in directories.sorted(by: { $0.pathComponents.count > $1.pathComponents.count }) {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: directory.path), contents.isEmpty else { continue }
            try? fileManager.removeItem(at: directory)
        }
    }
}
