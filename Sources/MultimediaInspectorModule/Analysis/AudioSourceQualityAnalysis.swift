import Foundation
import ZEUVECore

public enum AudioLossySourceIndication: String, Codable, Sendable, CaseIterable {
    case noClearIndications, mild, moderate, strong, insufficientEvidence

    public var displayName: String {
        switch self {
        case .noClearIndications: return "Sin indicios claros"
        case .mild: return "Indicios leves"
        case .moderate: return "Indicios moderados"
        case .strong: return "Indicios fuertes"
        case .insufficientEvidence: return "Evidencia insuficiente"
        }
    }
}

public struct AudioQualityEvidence: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let title: String
    public let detail: String
    public let weight: Double
    public init(id: UUID = UUID(), title: String, detail: String, weight: Double) {
        self.id = id; self.title = title; self.detail = detail; self.weight = min(max(weight, 0), 1)
    }
}

public struct SpectralAnomaly: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let start: TimeInterval
    public let end: TimeInterval
    public let severity: Double
    public let title: String
    public let detail: String
    public init(id: UUID = UUID(), start: TimeInterval, end: TimeInterval, severity: Double, title: String, detail: String) {
        self.id = id; self.start = start; self.end = end; self.severity = min(max(severity, 0), 1); self.title = title; self.detail = detail
    }
}

public struct AudioSourceQualityAnalysis: Codable, Sendable, Equatable {
    public let indication: AudioLossySourceIndication
    public let confidence: Double
    public let analyzedDuration: TimeInterval
    public let activeWindowCount: Int
    public let discardedWindowCount: Int
    public let spectralRolloffHz: Double?
    public let effectiveBandwidthHz: Double?
    public let persistentCutoffCandidateHz: Double?
    public let highBandEnergyRatio: Double?
    public let evidence: [AudioQualityEvidence]
    public let totalAnomalyCount: Int
    public let anomalies: [SpectralAnomaly]
    public let anomaliesWereTruncated: Bool

    public init(
        indication: AudioLossySourceIndication,
        confidence: Double,
        analyzedDuration: TimeInterval,
        activeWindowCount: Int = 0,
        discardedWindowCount: Int = 0,
        spectralRolloffHz: Double? = nil,
        effectiveBandwidthHz: Double?,
        persistentCutoffCandidateHz: Double? = nil,
        highBandEnergyRatio: Double?,
        evidence: [AudioQualityEvidence],
        totalAnomalyCount: Int? = nil,
        anomalies: [SpectralAnomaly],
        anomaliesWereTruncated: Bool? = nil
    ) {
        self.indication = indication
        self.confidence = min(max(confidence, 0), 1)
        self.analyzedDuration = analyzedDuration
        self.activeWindowCount = max(activeWindowCount, 0)
        self.discardedWindowCount = max(discardedWindowCount, 0)
        self.spectralRolloffHz = spectralRolloffHz
        self.effectiveBandwidthHz = effectiveBandwidthHz
        self.persistentCutoffCandidateHz = persistentCutoffCandidateHz
        self.highBandEnergyRatio = highBandEnergyRatio
        self.evidence = evidence
        self.totalAnomalyCount = max(totalAnomalyCount ?? anomalies.count, anomalies.count)
        self.anomalies = anomalies
        self.anomaliesWereTruncated = anomaliesWereTruncated ?? ((totalAnomalyCount ?? anomalies.count) > anomalies.count)
    }
}

public struct AudioSourceQualityRequest: Sendable, Equatable {
    public let url: URL
    public let fingerprint: FileFingerprint
    public let streamIndex: Int
    public let sampleRate: Double
    public let channels: Int
    public let duration: TimeInterval?
    public let codec: String

    public init(url: URL, fingerprint: FileFingerprint, streamIndex: Int, sampleRate: Double, channels: Int, duration: TimeInterval?, codec: String) {
        self.url = url.standardizedFileURL; self.fingerprint = fingerprint; self.streamIndex = streamIndex; self.sampleRate = sampleRate; self.channels = channels; self.duration = duration; self.codec = codec
    }
}
