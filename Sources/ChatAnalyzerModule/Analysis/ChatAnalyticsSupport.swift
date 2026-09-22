import Foundation

extension ChatAnalytics {
    static func chronologicallyOrdered(_ messages: [NormalizedMessage]) -> [NormalizedMessage] {
        guard messages.count > 1 else { return messages }
        for index in 1..<messages.count where messages[index].timestamp < messages[index - 1].timestamp {
            return messages.sorted {
                if $0.timestamp != $1.timestamp { return $0.timestamp < $1.timestamp }
                return $0.sourcePosition < $1.sourcePosition
            }
        }
        return messages
    }

    static func frequency(_ counts: [String: Int], limit: Int) -> [FrequencyItem] {
        counts.map { .init(value: $0.key, count: $0.value) }
            .sorted { $0.count == $1.count ? $0.value < $1.value : $0.count > $1.count }
            .prefix(limit).map { $0 }
    }

    public static func isMultimedia(_ message: NormalizedMessage, settings: ChatAnalyzerSettings) -> Bool {
        switch settings.multimediaDefinition {
        case .classic: return [.image, .video, .audio, .sticker].contains(message.contentType)
        case .configurable: return settings.configurableMultimediaTypes.contains(message.contentType)
        case .nonText: return ![.text, .system].contains(message.contentType)
        }
    }

    static func isUppercase(_ text: String) -> Bool {
        let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        return letters.count >= 2 && letters.allSatisfy { String($0) == String($0).uppercased() }
    }

    static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted(); let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    static func percentile(_ values: [Double], _ p: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let position = p * Double(values.count - 1); let lower = Int(position.rounded(.down)); let upper = Int(position.rounded(.up))
        if lower == upper { return values[lower] }
        return values[lower] + (values[upper] - values[lower]) * (position - Double(lower))
    }
}
