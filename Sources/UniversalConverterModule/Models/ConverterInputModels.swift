import Foundation
import ZEUVECore

public enum ConverterSourceKind: String, Codable, Sendable, Hashable {
    case file
    case archiveEntry
}

public struct ConverterInputItem: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let kind: ConverterSourceKind
    public let sourceURL: URL
    public let archiveEntryPath: String?
    public let relativePath: String
    public let displayName: String
    public let size: Int64
    public let format: ConverterFormat
    public let detection: ConverterFormatDetection?
    public let fingerprint: FileFingerprint
    public let sourceRootName: String

    public init(
        id: UUID = UUID(),
        kind: ConverterSourceKind,
        sourceURL: URL,
        archiveEntryPath: String? = nil,
        relativePath: String,
        displayName: String,
        size: Int64,
        format: ConverterFormat,
        detection: ConverterFormatDetection? = nil,
        fingerprint: FileFingerprint,
        sourceRootName: String
    ) {
        self.id = id
        self.kind = kind
        self.sourceURL = sourceURL.standardizedFileURL
        self.archiveEntryPath = archiveEntryPath
        self.relativePath = relativePath
        self.displayName = displayName
        self.size = size
        self.format = format
        self.detection = detection
        self.fingerprint = fingerprint
        self.sourceRootName = sourceRootName
    }

    public var category: ConverterCategory { format.category }
    public var isFromArchive: Bool { kind == .archiveEntry }
}
