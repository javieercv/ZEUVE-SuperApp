import Foundation
import ZEUVECore

public enum ConverterExecutionKind: String, Codable, Sendable, Equatable, Hashable {
    case copy
    case nativeImage
    case ffmpeg
    case nativePDFToImages
    case nativePDFToText
    case nativeImagesToPDF
    case pandoc
}

public struct ConversionPlanItem: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let sources: [ConverterInputItem]
    public let operation: ConversionOperation
    public let targetFormat: ConverterFormat
    public let executionKind: ConverterExecutionKind
    public let destinationRelativePath: String
    public let estimatedOutputBytes: Int64?
    public let warnings: [String]

    public init(
        id: UUID = UUID(),
        sources: [ConverterInputItem],
        operation: ConversionOperation,
        targetFormat: ConverterFormat,
        executionKind: ConverterExecutionKind,
        destinationRelativePath: String,
        estimatedOutputBytes: Int64?,
        warnings: [String] = []
    ) {
        self.id = id
        self.sources = sources
        self.operation = operation
        self.targetFormat = targetFormat
        self.executionKind = executionKind
        self.destinationRelativePath = destinationRelativePath
        self.estimatedOutputBytes = estimatedOutputBytes
        self.warnings = warnings
    }
}

public struct ConversionPlan: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let revision: UInt64
    public let createdAt: Date
    public let items: [ConversionPlanItem]
    public let outputFolder: URL
    public let options: ConverterOperationOptions
    public let warnings: [String]
    public let estimatedOutputBytes: Int64?
    public let availableOutputBytes: Int64?
    public let safetyMarginBytes: Int64?
    public let containsArchiveEntries: Bool

    public var estimatedRequiredWithMargin: Int64? {
        guard let estimatedOutputBytes else { return nil }
        return estimatedOutputBytes.addingReportingOverflow(safetyMarginBytes ?? 0).overflow
            ? Int64.max
            : estimatedOutputBytes + (safetyMarginBytes ?? 0)
    }

    public var mayHaveInsufficientSpace: Bool {
        guard let required = estimatedRequiredWithMargin, let availableOutputBytes else { return false }
        return required > availableOutputBytes
    }

    public init(
        id: UUID = UUID(),
        revision: UInt64,
        createdAt: Date = Date(),
        items: [ConversionPlanItem],
        outputFolder: URL,
        options: ConverterOperationOptions,
        warnings: [String],
        estimatedOutputBytes: Int64?,
        availableOutputBytes: Int64? = nil,
        safetyMarginBytes: Int64? = nil,
        containsArchiveEntries: Bool
    ) {
        self.id = id
        self.revision = revision
        self.createdAt = createdAt
        self.items = items
        self.outputFolder = outputFolder.standardizedFileURL
        self.options = options
        self.warnings = warnings
        self.estimatedOutputBytes = estimatedOutputBytes
        self.availableOutputBytes = availableOutputBytes
        self.safetyMarginBytes = safetyMarginBytes
        self.containsArchiveEntries = containsArchiveEntries
    }
}
