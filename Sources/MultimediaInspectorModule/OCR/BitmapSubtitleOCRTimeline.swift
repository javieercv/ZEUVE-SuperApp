import Foundation

/// Un frame de borrado cierra el subtítulo; no es una fila vacía del borrador.
public struct BitmapSubtitleOCRFrame: Sendable, Equatable {
    public let timestamp: TimeInterval
    public let text: String
    public let confidence: Double
    public let isClear: Bool

    public init(timestamp: TimeInterval, text: String, confidence: Double, isClear: Bool) {
        self.timestamp = timestamp; self.text = text; self.confidence = confidence; self.isClear = isClear
    }
}

public struct BitmapSubtitleOCRTimeline: Sendable {
    public init() {}

    public func events(frames: [BitmapSubtitleOCRFrame], duration: TimeInterval?, threshold: Double) -> [BitmapSubtitleOCREvent] {
        let limit = duration.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        var events: [BitmapSubtitleOCREvent] = []
        var pending: BitmapSubtitleOCREvent?
        func finish(at timestamp: TimeInterval) {
            guard var event = pending else { return }
            event.end = min(timestamp, limit ?? timestamp)
            if event.end > event.start { events.append(event) }
            pending = nil
        }
        for frame in frames.filter({ $0.timestamp.isFinite && $0.timestamp >= 0 }).sorted(by: { $0.timestamp < $1.timestamp }) {
            if let limit, frame.timestamp >= limit { finish(at: limit); break }
            if frame.isClear { finish(at: frame.timestamp); continue }
            let text = frame.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if var active = pending, active.text == text, !text.isEmpty {
                active.confidence = min(active.confidence, frame.confidence)
                active.needsReview = active.needsReview || frame.confidence < threshold
                pending = active
                continue
            }
            finish(at: frame.timestamp)
            pending = .init(start: frame.timestamp, end: frame.timestamp, text: text, confidence: frame.confidence,
                            needsReview: text.isEmpty || frame.confidence < threshold)
        }
        if let active = pending { finish(at: limit ?? (active.start + 2)) }
        return events
    }
}
