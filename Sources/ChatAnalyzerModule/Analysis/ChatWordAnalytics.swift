import Foundation

extension ChatAnalytics {
    public static func words(
        _ messages: [NormalizedMessage],
        includeStopWords: Bool,
        limit: Int = 100,
        cancellation: @Sendable () -> Bool = { false }
    ) -> [FrequencyItem] {
        var counts: [String: Int] = [:]
        for (index, message) in messages.enumerated() {
            if index.isMultiple(of: 512), cancellation() { return [] }
            for word in ChatTokenizer.words(in: message.text, includeStopWords: includeStopWords) {
                counts[word, default: 0] += 1
            }
        }
        return frequency(counts, limit: limit)
    }

    public static func bigrams(
        _ messages: [NormalizedMessage],
        includeStopWords: Bool,
        limit: Int = 100,
        cancellation: @Sendable () -> Bool = { false }
    ) -> [FrequencyItem] {
        var counts: [String: Int] = [:]
        for (messageIndex, message) in messages.enumerated() {
            if messageIndex.isMultiple(of: 512), cancellation() { return [] }
            let words = ChatTokenizer.words(in: message.text, includeStopWords: true)
            guard words.count >= 2 else { continue }
            for index in 0..<(words.count - 1) {
                let first = words[index]
                let second = words[index + 1]
                if !includeStopWords && ChatTokenizer.stopWords.contains(first) && ChatTokenizer.stopWords.contains(second) { continue }
                counts["\(first) \(second)", default: 0] += 1
            }
        }
        return frequency(counts.filter { $0.value >= 2 }, limit: limit)
    }

    public static func emojis(
        _ messages: [NormalizedMessage],
        limit: Int = 100,
        cancellation: @Sendable () -> Bool = { false }
    ) -> [FrequencyItem] {
        var counts: [String: Int] = [:]
        for (index, message) in messages.enumerated() {
            if index.isMultiple(of: 512), cancellation() { return [] }
            for emoji in ChatTokenizer.emojis(in: message.text) {
                counts[emoji, default: 0] += 1
            }
        }
        return frequency(counts, limit: limit)
    }
}
