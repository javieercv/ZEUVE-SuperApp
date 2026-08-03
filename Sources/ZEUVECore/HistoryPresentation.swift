import Foundation

public struct ModuleHistoryPresentation: Sendable, Equatable {
    public let title: String
    public let subtitle: String
    public let details: [String]
    public let outputFolder: URL?

    public init(title: String, subtitle: String, details: [String] = [], outputFolder: URL? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.details = details
        self.outputFolder = outputFolder
    }
}

public protocol ModuleHistoryPresenter: Sendable {
    var moduleID: String { get }
    func presentation(for record: OperationHistoryRecord) -> ModuleHistoryPresentation
}

public struct GenericModuleHistoryPresenter: ModuleHistoryPresenter {
    public let moduleID: String
    public init(moduleID: String) { self.moduleID = moduleID }
    public func presentation(for record: OperationHistoryRecord) -> ModuleHistoryPresentation {
        ModuleHistoryPresentation(
            title: record.kind,
            subtitle: record.createdAt.formatted(date: .abbreviated, time: .shortened),
            outputFolder: record.baseFolder.map { URL(fileURLWithPath: $0, isDirectory: true) }
        )
    }
}
