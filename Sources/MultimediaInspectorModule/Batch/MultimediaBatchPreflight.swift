import Foundation
import ZEUVECore
import ZEUVEEngines
import ZEUVEOperations

public enum MultimediaBatchPreflightClassification: String, Codable, Sendable, CaseIterable {
    case applicable, applicableWithWarnings, incompatible, noChanges
}

public struct MultimediaBatchPreflightItem: Sendable, Identifiable {
    public let id: UUID
    public let url: URL
    public let fingerprint: FileFingerprint
    public let classification: MultimediaBatchPreflightClassification
    public let appliedRules: [String]
    public let warnings: [String]
    public let errorMessage: String?
    public let plan: MediaEditPlan?

    public init(id: UUID = UUID(), url: URL, fingerprint: FileFingerprint, classification: MultimediaBatchPreflightClassification, appliedRules: [String], warnings: [String], errorMessage: String?, plan: MediaEditPlan?) {
        self.id = id; self.url = url; self.fingerprint = fingerprint; self.classification = classification; self.appliedRules = appliedRules; self.warnings = warnings; self.errorMessage = errorMessage; self.plan = plan
    }
}

public actor MultimediaBatchPreflightService {
    private let inspector: MediaInspectionService
    private let ruleEngine: MultimediaBatchRuleEngine
    private let coordinator: OperationCoordinator?
    public init(inspector: MediaInspectionService = .init(), ruleEngine: MultimediaBatchRuleEngine = .init(), coordinator: OperationCoordinator? = nil) {
        self.inspector = inspector; self.ruleEngine = ruleEngine; self.coordinator = coordinator
    }

    public func prepare(files: [MultimediaBatchDiscoveredFile], ruleSet: MultimediaBatchRuleSet, ffprobe: URL, preferences: MultimediaInspectorPreferences) async -> [MultimediaBatchPreflightItem] {
        let operationID: UUID?
        if let coordinator { operationID = try? await coordinator.begin(moduleID: multimediaInspectorModuleIdentifier, name: "Preflight de edición por lotes") } else { operationID = nil }
        defer { if let operationID, let coordinator { Task { try? await coordinator.finish(id: operationID) } } }
        var results: [MultimediaBatchPreflightItem] = []
        results.reserveCapacity(files.count)
        for (ordinal, file) in files.enumerated() {
            if Task.isCancelled { break }
            if let operationID, let coordinator { try? await coordinator.update(id: operationID, progress: .init(completed: ordinal, total: max(files.count, 1), phase: "Analizando planes")) }
            do {
                guard file.fingerprint.matches(file.url) else { throw MultimediaInspectorError.originalChanged }
                let inspection = try await inspector.inspect(url: file.url, ffprobe: ffprobe, useCache: false)
                guard let container = EditableMediaContainer.detect(from: inspection, url: file.url) else {
                    results.append(.init(url: file.url, fingerprint: file.fingerprint, classification: .incompatible, appliedRules: [], warnings: [], errorMessage: "El contenedor no admite edición estructural segura.", plan: nil)); continue
                }
                let originalDraft = try MediaEditDraft(originalURL: file.url, originalFingerprint: file.fingerprint, inspection: inspection, container: container)
                let application = ruleEngine.apply(ruleSet, to: originalDraft)
                if application.draft == originalDraft {
                    results.append(.init(url: file.url, fingerprint: file.fingerprint, classification: .noChanges, appliedRules: [], warnings: application.warnings, errorMessage: nil, plan: nil)); continue
                }
                let plan = try MediaEditPlanner(preferences: preferences).plan(from: application.draft)
                let warnings = application.warnings + plan.warnings
                results.append(.init(url: file.url, fingerprint: file.fingerprint, classification: warnings.isEmpty ? .applicable : .applicableWithWarnings, appliedRules: application.appliedRuleNames, warnings: warnings, errorMessage: nil, plan: plan))
            } catch {
                results.append(.init(url: file.url, fingerprint: file.fingerprint, classification: .incompatible, appliedRules: [], warnings: [], errorMessage: (error as? LocalizedError)?.errorDescription ?? "No se ha podido preparar el archivo.", plan: nil))
            }
        }
        return results
    }
}
