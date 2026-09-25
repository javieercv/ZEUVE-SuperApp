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

    public func prepare(files: [MultimediaBatchDiscoveredFile], ruleSet: MultimediaBatchRuleSet, ffprobe: URL, preferences: MultimediaInspectorPreferences) async throws -> [MultimediaBatchPreflightItem] {
        let operationID: UUID?
        if let coordinator {
            operationID = try await coordinator.begin(moduleID: multimediaInspectorModuleIdentifier, name: "Preflight de edición por lotes")
        } else {
            operationID = nil
        }
        let cancellationObserver: Task<Void, Never>?
        if let operationID, let coordinator {
            let inspector = self.inspector
            cancellationObserver = Task {
                for await snapshot in await coordinator.snapshots() {
                    guard !Task.isCancelled else { return }
                    if snapshot?.id == operationID, snapshot?.status == .cancelling {
                        await inspector.cancel()
                        return
                    }
                }
            }
        } else {
            cancellationObserver = nil
        }

        do {
            var results: [MultimediaBatchPreflightItem] = []
            results.reserveCapacity(files.count)
            for (ordinal, file) in files.enumerated() {
                try await throwIfCancelled(operationID: operationID)
                if let operationID, let coordinator {
                    try await coordinator.update(id: operationID, progress: .init(completed: ordinal, total: max(files.count, 1), phase: "Analizando planes"))
                }
                do {
                    guard file.fingerprint.matches(file.url) else { throw MultimediaInspectorError.originalChanged }
                    let inspector = self.inspector
                    let inspection = try await withTaskCancellationHandler {
                        try await inspector.inspect(url: file.url, ffprobe: ffprobe, useCache: false)
                    } onCancel: {
                        Task { await inspector.cancel() }
                    }
                    try await throwIfCancelled(operationID: operationID)
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
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    try await throwIfCancelled(operationID: operationID)
                    results.append(.init(url: file.url, fingerprint: file.fingerprint, classification: .incompatible, appliedRules: [], warnings: [], errorMessage: (error as? LocalizedError)?.errorDescription ?? "No se ha podido preparar el archivo.", plan: nil))
                }
            }
            cancellationObserver?.cancel()
            if let operationID, let coordinator { try await coordinator.finish(id: operationID) }
            return results
        } catch {
            cancellationObserver?.cancel()
            if let operationID, let coordinator, await coordinator.current()?.id == operationID {
                try await coordinator.finish(id: operationID)
            }
            throw error
        }
    }

    private func throwIfCancelled(operationID: UUID?) async throws {
        try Task.checkCancellation()
        if let operationID, let coordinator, await coordinator.shouldCancel(id: operationID) {
            throw CancellationError()
        }
    }
}
