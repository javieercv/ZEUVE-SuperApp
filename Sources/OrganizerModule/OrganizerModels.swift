import Foundation
#if SWIFT_PACKAGE
import ZEUVECore
#endif

public let organizerModuleIdentifier = "com.zeuve.organizer"
public let organizerRelatedFolder = "Relacionados"
public let organizerNoExtensionFolder = "SIN_EXTENSION"

public enum OrganizationLevel: String, Codable, CaseIterable, Sendable, Hashable {
    case simple
    case detailed

    public var displayName: String {
        switch self {
        case .simple: return "Simple"
        case .detailed: return "Detallado"
        }
    }
}

public enum ConflictPolicy: String, Codable, CaseIterable, Sendable, Hashable {
    case rename
    case skip
    case resolve

    public var displayName: String {
        switch self {
        case .rename: return "Renombrar automáticamente"
        case .skip: return "Omitir"
        case .resolve: return "Revisar conflictos"
        }
    }
}

public struct ExtensionRule: Codable, Sendable, Equatable {
    public let category: String
    public let formatFolder: String

    public init(category: String, formatFolder: String) {
        self.category = category
        self.formatFolder = formatFolder
    }
}

public struct OrganizerOptions: Codable, Sendable, Equatable {
    public var recursive: Bool
    public var organizationLevel: OrganizationLevel
    public var keepRelated: Bool
    public var conflictPolicy: ConflictPolicy
    public var includeHidden: Bool
    public var customRules: [String: ExtensionRule]

    public init(
        recursive: Bool = false,
        organizationLevel: OrganizationLevel = .detailed,
        keepRelated: Bool = true,
        conflictPolicy: ConflictPolicy = .rename,
        includeHidden: Bool = false,
        customRules: [String: ExtensionRule] = [:]
    ) {
        self.recursive = recursive
        self.organizationLevel = organizationLevel
        self.keepRelated = keepRelated
        self.conflictPolicy = conflictPolicy
        self.includeHidden = includeHidden
        self.customRules = customRules
    }
}

public struct OrganizerIgnoredItem: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let url: URL
    public let reason: String

    public init(id: UUID = UUID(), url: URL, reason: String) {
        self.id = id
        self.url = url
        self.reason = reason
    }
}

public struct OrganizerMoveOperation: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let source: URL
    public let destination: URL
    public let reason: String
    public let category: String
    public let formatFolder: String
    public let groupKey: String?
    public let conflict: Bool
    public let sourceFingerprint: FileFingerprint

    public init(
        id: UUID = UUID(),
        source: URL,
        destination: URL,
        reason: String,
        category: String,
        formatFolder: String,
        groupKey: String?,
        conflict: Bool,
        sourceFingerprint: FileFingerprint
    ) {
        self.id = id
        self.source = source
        self.destination = destination
        self.reason = reason
        self.category = category
        self.formatFolder = formatFolder
        self.groupKey = groupKey
        self.conflict = conflict
        self.sourceFingerprint = sourceFingerprint
    }
}

public struct OrganizerPlanSummary: Codable, Sendable, Equatable {
    public let files: Int
    public let categories: [String: Int]
    public let formats: [String: [String: Int]]
    public let foldersToCreate: Int
    public let relatedGroups: Int
    public let conflicts: Int
    public let ignored: Int
    public let subfolders: Int
}

public struct OrganizerPlan: Codable, Sendable, Equatable {
    public let baseFolder: URL
    public let operations: [OrganizerMoveOperation]
    public let ignored: [OrganizerIgnoredItem]
    public let options: OrganizerOptions
    public let subfolderCount: Int
    public let generatedAt: Date

    public init(
        baseFolder: URL,
        operations: [OrganizerMoveOperation],
        ignored: [OrganizerIgnoredItem],
        options: OrganizerOptions,
        subfolderCount: Int,
        generatedAt: Date = Date()
    ) {
        self.baseFolder = baseFolder
        self.operations = operations
        self.ignored = ignored
        self.options = options
        self.subfolderCount = subfolderCount
        self.generatedAt = generatedAt
    }

    public func selectedOperations(_ selectedIDs: Set<UUID>? = nil) -> [OrganizerMoveOperation] {
        guard let selectedIDs else { return operations }
        return operations.filter { selectedIDs.contains($0.id) }
    }

    public func summary(selectedIDs: Set<UUID>? = nil, fileManager: FileManager = .default) -> OrganizerPlanSummary {
        let selected = selectedOperations(selectedIDs)
        var categories: [String: Int] = [:]
        var formats: [String: [String: Int]] = [:]
        var groups = Set<String>()
        var directories = Set<String>()
        for operation in selected {
            categories[operation.category, default: 0] += 1
            formats[operation.category, default: [:]][operation.formatFolder, default: 0] += 1
            if let groupKey = operation.groupKey { groups.insert(groupKey.lowercased()) }
            var parent = operation.destination.deletingLastPathComponent()
            while parent.path != baseFolder.path && parent.path.hasPrefix(baseFolder.path) {
                if !fileManager.fileExists(atPath: parent.path) { directories.insert(parent.standardizedFileURL.path) }
                let next = parent.deletingLastPathComponent()
                if next.path == parent.path { break }
                parent = next
            }
        }
        return OrganizerPlanSummary(
            files: selected.count,
            categories: categories,
            formats: formats,
            foldersToCreate: directories.count,
            relatedGroups: groups.count,
            conflicts: selected.filter(\.conflict).count,
            ignored: ignored.count,
            subfolders: subfolderCount
        )
    }
}

public struct OrganizerExecutionItem: Codable, Sendable, Equatable {
    public let source: URL
    public let destination: URL
    public let destinationFingerprint: FileFingerprint
}

public struct OrganizerExecutionResult: Codable, Sendable, Equatable {
    public let operationID: UUID
    public let baseFolder: URL
    public let moved: Int
    public let skipped: Int
    public let renamed: Int
    public let createdDirectories: [URL]
    public let operations: [OrganizerExecutionItem]
    public let startedAt: Date
    public let finishedAt: Date
}

public struct OrganizerUndoResult: Codable, Sendable, Equatable {
    public let restored: Int
    public let skipped: Int
    public let status: OperationStatus
    public let details: [String]
}

public struct OrganizerHistoryPayload: Codable, Sendable, Equatable {
    public let execution: OrganizerExecutionResult
    public let undoDetails: [String]

    public init(execution: OrganizerExecutionResult, undoDetails: [String] = []) {
        self.execution = execution
        self.undoDetails = undoDetails
    }
}

public enum OrganizerError: LocalizedError, Equatable {
    case folderDoesNotExist
    case selectionIsNotFolder
    case unsafeSystemLocation(String)
    case insufficientPermissions
    case planInvalidated(String)
    case destinationAppeared(String)
    case noHistoryRecord
    case undoUnavailable
    case invalidManifest

    public var errorDescription: String? {
        switch self {
        case .folderDoesNotExist: return "La carpeta seleccionada no existe."
        case .selectionIsNotFolder: return "La selección no es una carpeta."
        case .unsafeSystemLocation(let path): return "La ubicación del sistema no se puede organizar de forma segura: \(path)."
        case .insufficientPermissions: return "No hay permisos suficientes para leer y modificar esta carpeta."
        case .planInvalidated(let name): return "El archivo \(name) ha cambiado desde la vista previa. Vuelve a analizar la carpeta."
        case .destinationAppeared(let name): return "Ha aparecido un archivo en el destino previsto para \(name). No se ha sobrescrito nada."
        case .noHistoryRecord: return "No se encuentra la operación en el historial."
        case .undoUnavailable: return "Esta operación ya no se puede deshacer."
        case .invalidManifest: return "No se ha podido cargar el manifiesto del organizador."
        }
    }
}
