import Foundation

public enum CleanerDeletionMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case trash, permanent
    public var id: String { rawValue }
}

public struct CleanerPreferences: Codable, Sendable, Equatable {
    public var deletionMode: CleanerDeletionMode
    public var safeSelectionEnabled: Bool
    public var scanCaches: Bool
    public var scanLogs: Bool
    public var scanXcode: Bool
    public var scanOldInstallers: Bool
    public var oldInstallerDays: Int
    public var additionalFolderBookmarks: [Data]

    public init(deletionMode: CleanerDeletionMode = .trash, safeSelectionEnabled: Bool = true, scanCaches: Bool = true, scanLogs: Bool = true, scanXcode: Bool = true, scanOldInstallers: Bool = true, oldInstallerDays: Int = 90, additionalFolderBookmarks: [Data] = []) {
        self.deletionMode = deletionMode; self.safeSelectionEnabled = safeSelectionEnabled; self.scanCaches = scanCaches; self.scanLogs = scanLogs; self.scanXcode = scanXcode; self.scanOldInstallers = scanOldInstallers; self.oldInstallerDays = max(1, oldInstallerDays); self.additionalFolderBookmarks = additionalFolderBookmarks
    }
    public static let `default` = CleanerPreferences()
}

public enum CleanerCoverage: String, Codable, Sendable { case complete, partial, noAccess, notAnalyzed }

public struct CleanerFileFingerprint: Codable, Sendable, Equatable {
    public let isDirectory: Bool
    public let isSymbolicLink: Bool
    public let logicalSize: Int64
    public let allocatedSize: Int64?
    public let modificationDate: Date?
    public let inode: UInt64?
    public init(isDirectory: Bool, isSymbolicLink: Bool, logicalSize: Int64, allocatedSize: Int64? = nil, modificationDate: Date? = nil, inode: UInt64? = nil) {
        self.isDirectory=isDirectory; self.isSymbolicLink=isSymbolicLink; self.logicalSize=logicalSize; self.allocatedSize=allocatedSize; self.modificationDate=modificationDate; self.inode=inode
    }
}

public enum CleanerApplicationAvailability: String, Codable, Sendable { case installed, missing, externalVolumeUnavailable }

public struct CleanerAppIdentity: Codable, Sendable, Equatable, Hashable {
    public let bundleID: String?
    public let name: String
    public let version: String?
    public let build: String?
    public let path: String
    public let volumePath: String?
    public let signingIdentifier: String?
    public let teamID: String?
    public let appGroups: [String]
    public let isSigned: Bool
    public init(bundleID: String?, name: String, version: String? = nil, build: String? = nil, path: String, volumePath: String? = nil, signingIdentifier: String? = nil, teamID: String? = nil, appGroups: [String] = [], isSigned: Bool = false) {
        self.bundleID=bundleID; self.name=name; self.version=version; self.build=build; self.path=path; self.volumePath=volumePath; self.signingIdentifier=signingIdentifier; self.teamID=teamID; self.appGroups=appGroups; self.isSigned=isSigned
    }
}

public struct CleanerAppInventoryItem: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var id: String { (identity.bundleID ?? "unsigned") + "|" + identity.path }
    public var identity: CleanerAppIdentity
    public var logicalSize: Int64?
    public var firstSeen: Date
    public var lastSeen: Date
    public var availability: CleanerApplicationAvailability
    public init(identity: CleanerAppIdentity, logicalSize: Int64? = nil, firstSeen: Date = Date(), lastSeen: Date = Date(), availability: CleanerApplicationAvailability = .installed) {
        self.identity=identity; self.logicalSize=logicalSize; self.firstSeen=firstSeen; self.lastSeen=lastSeen; self.availability=availability
    }
}

public enum CleanerEvidenceStrength: String, Codable, Sendable { case strong, complementary, heuristic }
public struct CleanerEvidence: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let strength: CleanerEvidenceStrength
    public let explanation: String
    public init(id: UUID = UUID(), strength: CleanerEvidenceStrength, explanation: String) { self.id=id; self.strength=strength; self.explanation=explanation }
}
public enum CleanerAssociationConfidence: String, Codable, Sendable { case high, medium, low }
public enum CleanerResidueStatus: String, Codable, Sendable { case probableResidue, possibleResidue, uncertainAssociation, notResidue, applicationUnavailable, keptByUser, regenerable }
public enum CleanerRemovalRisk: String, Codable, Sendable { case low, medium, high }

public enum CleanerCandidateCategory: String, Codable, Sendable, CaseIterable {
    case cache, log, preference, applicationSupport, container, groupContainer, savedState, applicationScript, launchItem, xcodeDerivedData, xcodeIndex, installer, application, other
    public var isRegenerable: Bool { [.cache,.log,.savedState,.xcodeDerivedData,.xcodeIndex].contains(self) }
    public var containsPersistentUserDataByDefault: Bool { [.preference,.applicationSupport,.container,.groupContainer,.applicationScript].contains(self) }
}

public struct CleanerCandidate: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let url: URL
    public let category: CleanerCandidateCategory
    public let associatedAppName: String?
    public let associatedBundleID: String?
    public let evidences: [CleanerEvidence]
    public let confidence: CleanerAssociationConfidence
    public let status: CleanerResidueStatus
    public let risk: CleanerRemovalRisk
    public let logicalSize: Int64?
    public let allocatedSize: Int64?
    public let containsPotentialUserData: Bool
    public let isShared: Bool
    public let requiresAdministrator: Bool
    public let applicationRunning: Bool
    public let consequence: String
    public var selected: Bool
    public let fingerprint: CleanerFileFingerprint?

    public init(id: UUID = UUID(), url: URL, category: CleanerCandidateCategory, associatedAppName: String? = nil, associatedBundleID: String? = nil, evidences: [CleanerEvidence], confidence: CleanerAssociationConfidence, status: CleanerResidueStatus, risk: CleanerRemovalRisk, logicalSize: Int64? = nil, allocatedSize: Int64? = nil, containsPotentialUserData: Bool = false, isShared: Bool = false, requiresAdministrator: Bool = false, applicationRunning: Bool = false, consequence: String, selected: Bool = false, fingerprint: CleanerFileFingerprint? = nil) {
        self.id=id; self.url=url; self.category=category; self.associatedAppName=associatedAppName; self.associatedBundleID=associatedBundleID; self.evidences=evidences; self.confidence=confidence; self.status=status; self.risk=risk; self.logicalSize=logicalSize; self.allocatedSize=allocatedSize; self.containsPotentialUserData=containsPotentialUserData; self.isShared=isShared; self.requiresAdministrator=requiresAdministrator; self.applicationRunning=applicationRunning; self.consequence=consequence; self.selected=selected; self.fingerprint=fingerprint
    }
    public var canBeSafelyPreselected: Bool {
        category.isRegenerable && confidence == .high && risk == .low && !containsPotentialUserData && !isShared && !requiresAdministrator && !applicationRunning && status != .applicationUnavailable && status != .keptByUser && status != .uncertainAssociation
    }
}

public struct CleanerRemovalPlan: Codable, Sendable, Equatable {
    public var candidates: [CleanerCandidate]
    public init(candidates: [CleanerCandidate]) { self.candidates=candidates }
    public var selectedCandidates: [CleanerCandidate] { candidates.filter(\.selected) }
    public var selectedLogicalBytes: Int64 { selectedCandidates.compactMap(\.logicalSize).reduce(0,+) }
}

public struct CleanerScanSummary: Codable, Sendable, Equatable {
    public let startedAt: Date; public let finishedAt: Date; public let coverage: CleanerCoverage
    public let scannedLogicalBytes: Int64; public let potentialRecoverableBytes: Int64; public let inaccessibleLocations: Int
    public let appCount: Int; public let candidateCount: Int
    public init(startedAt: Date, finishedAt: Date, coverage: CleanerCoverage, scannedLogicalBytes: Int64, potentialRecoverableBytes: Int64, inaccessibleLocations: Int, appCount: Int, candidateCount: Int) { self.startedAt=startedAt; self.finishedAt=finishedAt; self.coverage=coverage; self.scannedLogicalBytes=scannedLogicalBytes; self.potentialRecoverableBytes=potentialRecoverableBytes; self.inaccessibleLocations=inaccessibleLocations; self.appCount=appCount; self.candidateCount=candidateCount }
}

public struct CleanerStorageNode: Sendable, Equatable, Identifiable {
    public var id: String { url.path }
    public let url: URL; public let logicalSize: Int64; public let allocatedSize: Int64?; public let isDirectory: Bool; public let children: [CleanerStorageNode]
    public init(url: URL, logicalSize: Int64, allocatedSize: Int64?, isDirectory: Bool, children: [CleanerStorageNode] = []) { self.url=url; self.logicalSize=logicalSize; self.allocatedSize=allocatedSize; self.isDirectory=isDirectory; self.children=children }
}

public enum CleanerItemExecutionStatus: String, Codable, Sendable { case removed, skippedChanged, permissionDenied, failed, unavailable, restored, restoreConflict }
public struct CleanerItemExecutionResult: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID; public let sourcePath: String; public let trashPath: String?; public let status: CleanerItemExecutionStatus; public let message: String?
    public init(id: UUID = UUID(), sourcePath: String, trashPath: String? = nil, status: CleanerItemExecutionStatus, message: String? = nil) { self.id=id; self.sourcePath=sourcePath; self.trashPath=trashPath; self.status=status; self.message=message }
}
public struct CleanerExecutionSummary: Codable, Sendable, Equatable {
    public let results: [CleanerItemExecutionResult]; public let deletedLogicalBytes: Int64; public let deletionMode: CleanerDeletionMode
    public init(results: [CleanerItemExecutionResult], deletedLogicalBytes: Int64, deletionMode: CleanerDeletionMode) { self.results=results; self.deletedLogicalBytes=deletedLogicalBytes; self.deletionMode=deletionMode }
    public var removedCount: Int { results.filter { $0.status == .removed }.count }
    public var restoredCount: Int { results.filter { $0.status == .restored }.count }
    public var failedCount: Int { results.filter { $0.status == .failed }.count }
    public var skippedCount: Int { results.filter { [.skippedChanged,.permissionDenied,.unavailable,.restoreConflict].contains($0.status) }.count }
}

public struct CleanerUndoItem: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID; public let historyID: UUID; public let originalURL: URL; public let trashURL: URL; public let fingerprint: CleanerFileFingerprint
    public init(id: UUID = UUID(), historyID: UUID, originalURL: URL, trashURL: URL, fingerprint: CleanerFileFingerprint) { self.id=id; self.historyID=historyID; self.originalURL=originalURL; self.trashURL=trashURL; self.fingerprint=fingerprint }
}
