import Foundation
import ZEUVECore

public enum BitmapSubtitleOCRRecognitionLevel: String, Codable, CaseIterable, Sendable, Identifiable {
    case fast, accurate
    public var id: String { rawValue }
    public var displayName: String { self == .fast ? "Rápido" : "Preciso" }
}

public struct BitmapSubtitleOCRRequest: Sendable, Equatable {
    public let url: URL
    public let fingerprint: FileFingerprint
    public let streamIndex: Int
    public let codec: String
    public let timeBase: String?
    public let duration: TimeInterval?
    public let language: String?

    public init(url: URL, fingerprint: FileFingerprint, streamIndex: Int, codec: String, timeBase: String?, duration: TimeInterval?, language: String?) {
        self.url = url.standardizedFileURL; self.fingerprint = fingerprint; self.streamIndex = streamIndex; self.codec = codec; self.timeBase = timeBase; self.duration = duration; self.language = language
    }
}

public struct BitmapSubtitleOCROptions: Codable, Sendable, Equatable {
    public var recognitionLevel: BitmapSubtitleOCRRecognitionLevel
    public var language: String?
    public var usesLanguageCorrection: Bool
    public var lowConfidenceThreshold: Double

    public init(recognitionLevel: BitmapSubtitleOCRRecognitionLevel = .accurate, language: String? = nil, usesLanguageCorrection: Bool = true, lowConfidenceThreshold: Double = 0.55) {
        self.recognitionLevel = recognitionLevel; self.language = language; self.usesLanguageCorrection = usesLanguageCorrection; self.lowConfidenceThreshold = lowConfidenceThreshold
        normalize()
    }
    public mutating func normalize() { lowConfidenceThreshold = min(max(lowConfidenceThreshold, 0.1), 0.95) }
}

public struct BitmapSubtitleOCREvent: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public var start: TimeInterval
    public var end: TimeInterval
    public var text: String
    public var confidence: Double
    public var needsReview: Bool
    public var included: Bool

    public init(id: UUID = UUID(), start: TimeInterval, end: TimeInterval, text: String, confidence: Double, needsReview: Bool, included: Bool = true) {
        self.id = id; self.start = start; self.end = end; self.text = text; self.confidence = min(max(confidence, 0), 1); self.needsReview = needsReview; self.included = included
    }
}

public struct BitmapSubtitleOCRDraft: Codable, Sendable, Equatable {
    public var events: [BitmapSubtitleOCREvent]
    public let sourceCodec: String
    public let sourceStreamIndex: Int
    public var language: String?

    public init(events: [BitmapSubtitleOCREvent], sourceCodec: String, sourceStreamIndex: Int, language: String?) {
        self.events = events; self.sourceCodec = sourceCodec; self.sourceStreamIndex = sourceStreamIndex; self.language = language
    }
}
