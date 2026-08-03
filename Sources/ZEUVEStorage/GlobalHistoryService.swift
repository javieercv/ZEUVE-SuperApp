import Foundation
import ZEUVECore

public struct GlobalHistoryEntry: Sendable, Equatable, Identifiable {
    public let record: OperationHistoryRecord
    public let moduleName: String
    public let moduleIcon: String
    public let presentation: ModuleHistoryPresentation
    public var id: UUID { record.id }
}

public final class GlobalHistoryService: @unchecked Sendable {
    private let repository: HistoryRepository
    public init(repository: HistoryRepository) { self.repository = repository }

    public func entries(
        manifests: [ModuleManifest],
        presenters: [any ModuleHistoryPresenter],
        moduleID: String? = nil,
        limit: Int = 500
    ) throws -> [GlobalHistoryEntry] {
        let manifestByID = Dictionary(uniqueKeysWithValues: manifests.map { ($0.identifier, $0) })
        let presenterByID = Dictionary(uniqueKeysWithValues: presenters.map { ($0.moduleID, $0) })
        return try repository.records(moduleID: moduleID, limit: limit).map { record in
            let manifest = manifestByID[record.moduleID]
            let presenter = presenterByID[record.moduleID] ?? GenericModuleHistoryPresenter(moduleID: record.moduleID)
            return GlobalHistoryEntry(
                record: record,
                moduleName: manifest?.name ?? record.moduleID,
                moduleIcon: manifest?.presentation.systemImage ?? "puzzlepiece.extension",
                presentation: presenter.presentation(for: record)
            )
        }
    }
}
