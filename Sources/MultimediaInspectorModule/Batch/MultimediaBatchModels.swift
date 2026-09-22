import Foundation
import ZEUVECore

public enum MultimediaBatchItemStatus: String, Codable, Sendable, Equatable, CaseIterable {
    case queued
    case waiting
    case inspecting
    case analyzingSignal
    case analyzingLoudness
    case generatingSpectrogram
    case exporting
    case completed
    case completedWithWarning
    case skipped
    case failed
    case cancelled

    public var displayName: String {
        switch self {
        case .queued: return "En espera"
        case .waiting: return "Esperando"
        case .inspecting: return "Inspeccionando"
        case .analyzingSignal: return "Analizando señal"
        case .analyzingLoudness: return "Analizando sonoridad"
        case .generatingSpectrogram: return "Generando espectrograma"
        case .exporting: return "Exportando"
        case .completed: return "Completado"
        case .completedWithWarning: return "Completado con aviso"
        case .skipped: return "Omitido"
        case .failed: return "Fallido"
        case .cancelled: return "Cancelado"
        }
    }

    public var isTerminal: Bool {
        switch self {
        case .completed, .completedWithWarning, .skipped, .failed, .cancelled: return true
        default: return false
        }
    }
}

public struct MultimediaTechnicalReportSections: Codable, Sendable, Equatable {
    public var includeGlobalMetadata: Bool
    public var includeStreams: Bool
    public var includeVideoDetails: Bool
    public var includeArtwork: Bool
    public var includeChapters: Bool
    public var includeTiming: Bool
    public var includeLoudness: Bool
    public var includeSignalAnalysis: Bool
    public var includeAdvancedAudioAnalysis: Bool
    public var includeOCRSummary: Bool
    public var includeStructuralEditSummary: Bool

    public init(
        includeGlobalMetadata: Bool = true,
        includeStreams: Bool = true,
        includeVideoDetails: Bool = true,
        includeArtwork: Bool = true,
        includeChapters: Bool = true,
        includeTiming: Bool = true,
        includeLoudness: Bool = true,
        includeSignalAnalysis: Bool = true,
        includeAdvancedAudioAnalysis: Bool = true,
        includeOCRSummary: Bool = true,
        includeStructuralEditSummary: Bool = true
    ) {
        self.includeGlobalMetadata = includeGlobalMetadata
        self.includeStreams = includeStreams
        self.includeVideoDetails = includeVideoDetails
        self.includeArtwork = includeArtwork
        self.includeChapters = includeChapters
        self.includeTiming = includeTiming
        self.includeLoudness = includeLoudness
        self.includeSignalAnalysis = includeSignalAnalysis
        self.includeAdvancedAudioAnalysis = includeAdvancedAudioAnalysis
        self.includeOCRSummary = includeOCRSummary
        self.includeStructuralEditSummary = includeStructuralEditSummary
    }

    private enum CodingKeys: String, CodingKey {
        case includeGlobalMetadata, includeStreams, includeVideoDetails, includeArtwork, includeChapters
        case includeTiming, includeLoudness, includeSignalAnalysis, includeAdvancedAudioAnalysis
        case includeOCRSummary, includeStructuralEditSummary
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        includeGlobalMetadata = try container.decodeIfPresent(Bool.self, forKey: .includeGlobalMetadata) ?? true
        includeStreams = try container.decodeIfPresent(Bool.self, forKey: .includeStreams) ?? true
        includeVideoDetails = try container.decodeIfPresent(Bool.self, forKey: .includeVideoDetails) ?? true
        includeArtwork = try container.decodeIfPresent(Bool.self, forKey: .includeArtwork) ?? true
        includeChapters = try container.decodeIfPresent(Bool.self, forKey: .includeChapters) ?? true
        includeTiming = try container.decodeIfPresent(Bool.self, forKey: .includeTiming) ?? true
        includeLoudness = try container.decodeIfPresent(Bool.self, forKey: .includeLoudness) ?? true
        includeSignalAnalysis = try container.decodeIfPresent(Bool.self, forKey: .includeSignalAnalysis) ?? true
        includeAdvancedAudioAnalysis = try container.decodeIfPresent(Bool.self, forKey: .includeAdvancedAudioAnalysis) ?? true
        includeOCRSummary = try container.decodeIfPresent(Bool.self, forKey: .includeOCRSummary) ?? true
        includeStructuralEditSummary = try container.decodeIfPresent(Bool.self, forKey: .includeStructuralEditSummary) ?? true
    }

    public static let all = MultimediaTechnicalReportSections()
}

public struct MultimediaBatchConfiguration: Codable, Sendable, Equatable {
    public var analyzeSignal: Bool
    public var analyzeLoudness: Bool
    public var exportSpectrogram: Bool
    public var reportFormat: MultimediaTechnicalReportFormat?
    public var reportSections: MultimediaTechnicalReportSections
    public var spectrogramWindow: SpectrogramWindowFunction
    public var spectrogramFFTSize: Int
    public var spectrogramDynamicRange: ClosedRange<Float>
    public var spectrogramMaximumColumns: Int
    public var spectrogramFrequencyScale: SpectrogramFrequencyScale
    public var spectrogramChannel: SpectrogramInitialChannel
    public var spectrogramExportWidth: Int
    public var spectrogramExportHeight: Int
    public var signalSilenceThresholdDBFS: Double
    public var signalMinimumSilenceDuration: Double
    public var signalClippingThresholdDBFS: Double
    public var signalMinimumConsecutiveClippedSamples: Int

    public init(
        analyzeSignal: Bool = false,
        analyzeLoudness: Bool = false,
        exportSpectrogram: Bool = false,
        reportFormat: MultimediaTechnicalReportFormat? = nil,
        reportSections: MultimediaTechnicalReportSections = .all,
        spectrogramWindow: SpectrogramWindowFunction = .hann,
        spectrogramFFTSize: Int = 4096,
        spectrogramDynamicRange: ClosedRange<Float> = -120 ... 0,
        spectrogramMaximumColumns: Int = 1800,
        spectrogramFrequencyScale: SpectrogramFrequencyScale = .linear,
        spectrogramChannel: SpectrogramInitialChannel = .mix,
        spectrogramExportWidth: Int = 1600,
        spectrogramExportHeight: Int = 900,
        signalSilenceThresholdDBFS: Double = -60,
        signalMinimumSilenceDuration: Double = 0.5,
        signalClippingThresholdDBFS: Double = -0.1,
        signalMinimumConsecutiveClippedSamples: Int = 3
    ) {
        self.analyzeSignal = analyzeSignal
        self.analyzeLoudness = analyzeLoudness
        self.exportSpectrogram = exportSpectrogram
        self.reportFormat = reportFormat
        self.reportSections = reportSections
        self.spectrogramWindow = spectrogramWindow
        self.spectrogramFFTSize = spectrogramFFTSize
        self.spectrogramDynamicRange = spectrogramDynamicRange
        self.spectrogramMaximumColumns = spectrogramMaximumColumns
        self.spectrogramFrequencyScale = spectrogramFrequencyScale
        self.spectrogramChannel = spectrogramChannel
        self.spectrogramExportWidth = spectrogramExportWidth
        self.spectrogramExportHeight = spectrogramExportHeight
        self.signalSilenceThresholdDBFS = signalSilenceThresholdDBFS
        self.signalMinimumSilenceDuration = signalMinimumSilenceDuration
        self.signalClippingThresholdDBFS = signalClippingThresholdDBFS
        self.signalMinimumConsecutiveClippedSamples = signalMinimumConsecutiveClippedSamples
        normalize()
    }

    public mutating func normalize() {
        let allowed = MultimediaInspectorPreferences.defaultAllowedFFTSizes
        if !allowed.contains(spectrogramFFTSize) { spectrogramFFTSize = 4096 }
        let lower = min(max(spectrogramDynamicRange.lowerBound, -180), -20)
        let upper = min(max(spectrogramDynamicRange.upperBound, lower + 1), 12)
        spectrogramDynamicRange = lower ... upper
        spectrogramMaximumColumns = min(max(spectrogramMaximumColumns, 256), 8192)
        spectrogramExportWidth = min(max(spectrogramExportWidth, 320), 4096)
        spectrogramExportHeight = min(max(spectrogramExportHeight, 180), 4096)
        signalSilenceThresholdDBFS = min(max(signalSilenceThresholdDBFS.isFinite ? signalSilenceThresholdDBFS : -60, -120), -10)
        signalMinimumSilenceDuration = min(max(signalMinimumSilenceDuration.isFinite ? signalMinimumSilenceDuration : 0.5, 0.05), 30)
        signalClippingThresholdDBFS = min(max(signalClippingThresholdDBFS.isFinite ? signalClippingThresholdDBFS : -0.1, -6), 0)
        signalMinimumConsecutiveClippedSamples = min(max(signalMinimumConsecutiveClippedSamples, 2), 64)
    }
}

public struct MultimediaInspectorBatchPreset: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public var schemaVersion: Int
    public var name: String
    public var configuration: MultimediaBatchConfiguration
    public var modifiedAt: Date

    public init(
        id: UUID = UUID(),
        schemaVersion: Int = 1,
        name: String,
        configuration: MultimediaBatchConfiguration,
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.name = name
        self.configuration = configuration
        self.modifiedAt = modifiedAt
    }
}

public struct MultimediaBatchInspectionSummary: Sendable, Equatable {
    public let container: String?
    public let durationSeconds: TimeInterval?
    public let videoStreams: Int
    public let audioStreams: Int
    public let subtitleStreams: Int

    public init(container: String?, durationSeconds: TimeInterval?, videoStreams: Int, audioStreams: Int, subtitleStreams: Int) {
        self.container = container
        self.durationSeconds = durationSeconds
        self.videoStreams = videoStreams
        self.audioStreams = audioStreams
        self.subtitleStreams = subtitleStreams
    }
}

public struct MultimediaBatchItem: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let url: URL
    public let fingerprint: FileFingerprint
    public var status: MultimediaBatchItemStatus
    public var phase: String?
    public var warning: String?
    public var error: String?
    public var summary: MultimediaBatchInspectionSummary?
    public var generatedOutputs: [URL]

    public init(id: UUID = UUID(), url: URL, fingerprint: FileFingerprint) {
        self.id = id
        self.url = url.standardizedFileURL
        self.fingerprint = fingerprint
        self.status = .queued
        self.phase = nil
        self.warning = nil
        self.error = nil
        self.summary = nil
        self.generatedOutputs = []
    }
}

public struct MultimediaBatchItemResult: Sendable {
    public let summary: MultimediaBatchInspectionSummary
    public let warning: String?
    public let generatedOutputs: [URL]

    public init(summary: MultimediaBatchInspectionSummary, warning: String?, generatedOutputs: [URL]) {
        self.summary = summary
        self.warning = warning
        self.generatedOutputs = generatedOutputs
    }
}

public struct MultimediaBatchRunSummary: Sendable, Equatable {
    public let total: Int
    public let completed: Int
    public let warnings: Int
    public let skipped: Int
    public let failed: Int
    public let cancelled: Int
    public let reportsGenerated: Int
    public let spectrogramsGenerated: Int
    public let durationSeconds: TimeInterval

    public init(total: Int, completed: Int, warnings: Int, skipped: Int, failed: Int, cancelled: Int, reportsGenerated: Int, spectrogramsGenerated: Int, durationSeconds: TimeInterval) {
        self.total = total
        self.completed = completed
        self.warnings = warnings
        self.skipped = skipped
        self.failed = failed
        self.cancelled = cancelled
        self.reportsGenerated = reportsGenerated
        self.spectrogramsGenerated = spectrogramsGenerated
        self.durationSeconds = durationSeconds
    }
}

public enum MultimediaBatchProcessOutcome: Sendable {
    case completed(MultimediaBatchItemResult)
    case skipped(MultimediaBatchInspectionSummary, reason: String)
}
