import Foundation
import ZEUVECore
import ZEUVEStorage

public struct UniversalConverterHistoryPayload: Codable, Sendable, Equatable {
    public let operation: String
    public let operationID: String
    public let inputCategories: [ConverterCategory]
    public let inputFormats: [ConverterFormat]
    public let targetFormat: ConverterFormat?
    public let inputCount: Int
    public let completed: Int
    public let skipped: Int
    public let failed: Int
    public let cancelled: Int
    public let generated: Int
    public let durationSeconds: Double
    public let quality: ConverterQualityProfile
    public let metadataPolicy: ConverterMetadataPolicy
    public let conflictPolicy: ConverterConflictPolicy
    public let filenameStyle: ConverterFilenameStyle
    public let filenamePrefix: String
    public let filenameSuffix: String
    public let engineKinds: [ConverterExecutionKind]
    public let recipe: ConverterOperationOptions
    public let warnings: [String]

    public init(result: UniversalConverterResult, plan: ConversionPlan) {
        operation = plan.options.operation.displayName
        operationID = plan.options.operation.rawValue
        inputCategories = Array(Set(plan.items.flatMap(\.sources).map(\.category))).sorted { $0.rawValue < $1.rawValue }
        inputFormats = Array(Set(plan.items.flatMap(\.sources).map(\.format))).sorted { $0.rawValue < $1.rawValue }
        targetFormat = plan.options.targetFormat
        inputCount = plan.items.flatMap(\.sources).count
        completed = result.completedCount
        skipped = result.skippedCount
        failed = result.failedCount
        cancelled = result.cancelledCount
        generated = result.generatedFiles.count
        durationSeconds = result.duration
        quality = plan.options.quality
        metadataPolicy = plan.options.metadataPolicy
        conflictPolicy = plan.options.conflictPolicy
        filenameStyle = plan.options.filenameStyle
        filenamePrefix = plan.options.filenamePrefix
        filenameSuffix = plan.options.filenameSuffix
        engineKinds = Array(Set(plan.items.map(\.executionKind))).sorted { $0.rawValue < $1.rawValue }
        var sanitized = plan.options
        sanitized.audioVideoImageURL = nil
        if sanitized.audioVideoBackground == .image { sanitized.audioVideoBackground = .black }
        recipe = sanitized
        warnings = Array(Set(plan.warnings + result.items.compactMap(\.message))).sorted()
    }
}

public final class UniversalConverterHistoryService: @unchecked Sendable {
    private let repository: HistoryRepository
    public init(repository: HistoryRepository) { self.repository = repository }

    @discardableResult
    public func save(_ result: UniversalConverterResult, plan: ConversionPlan) throws -> OperationHistoryRecord {
        let payload = UniversalConverterHistoryPayload(result: result, plan: plan)
        let status: OperationStatus = result.cancelledCount > 0 ? .cancelled : (result.failedCount > 0 && result.completedCount == 0 ? .failed : .completed)
        let record = OperationHistoryRecord(
            id: result.operationID,
            moduleID: universalConverterModuleIdentifier,
            kind: plan.options.operation.rawValue,
            baseFolder: plan.options.saveOutputPathsInHistory ? result.outputFolder.path : nil,
            createdAt: result.finishedAt,
            status: status,
            undoAvailable: false,
            payload: try JSONEncoder().encode(payload)
        )
        try repository.add(record)
        return record
    }
}

public struct UniversalConverterHistoryPresenter: ModuleHistoryPresenter {
    public let moduleID = universalConverterModuleIdentifier
    public init() {}

    public func presentation(for record: OperationHistoryRecord) -> ModuleHistoryPresentation {
        guard let payload = try? JSONDecoder().decode(UniversalConverterHistoryPayload.self, from: record.payload) else {
            return GenericModuleHistoryPresenter(moduleID: moduleID).presentation(for: record)
        }
        let sources = payload.inputFormats.map(\.displayName).joined(separator: ", ")
        let engines = payload.engineKinds.map(\.rawValue).joined(separator: ", ")
        return ModuleHistoryPresentation(
            title: payload.operation,
            subtitle: "\(payload.completed) correctos · \(payload.failed) fallidos · \(payload.skipped) omitidos",
            details: [
                sources.isEmpty ? nil : "Entradas: \(sources)",
                payload.targetFormat.map { "Salida: \($0.displayName)" },
                "Preajuste: \(payload.quality.displayName)",
                "Metadatos: \(payload.metadataPolicy.displayName)",
                engines.isEmpty ? nil : "Motores: \(engines)",
                "\(payload.generated) resultados",
                String(format: "Duración: %.1f s", payload.durationSeconds),
            ].compactMap { $0 },
            outputFolder: record.baseFolder.map { URL(fileURLWithPath: $0, isDirectory: true) }
        )
    }
}
