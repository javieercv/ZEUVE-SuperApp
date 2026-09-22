import Foundation

extension ChatAnalytics {
    public static func search(_ timeline: [NormalizedMessage], filter: ChatFilter, options: ChatSearchOptions) -> ChatSearchResult {
        let index = searchIndex(timeline, filter: filter, options: options)
        return searchResult(timeline, index: index, options: options)
    }

    public static func searchIndex(
        _ timeline: [NormalizedMessage],
        filter: ChatFilter,
        options: ChatSearchOptions,
        textIndex: ChatSearchTextIndex? = nil,
        cancellation: @Sendable () -> Bool = { false }
    ) -> ChatSearchIndex {
        let query = options.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, let matcher = SearchMatcher(query: query, options: options) else { return .empty }
        let calendar = self.calendar
        var hits: [ChatSearchHit] = []
        var totalOccurrences = 0
        var participantCounts: [String: Int] = [:]
        var platformCounts: [ChatPlatform: Int] = [:]
        hits.reserveCapacity(min(timeline.count / 20, 10_000))

        for (index, message) in timeline.enumerated() where filter.includes(message, calendar: calendar) {
            if index.isMultiple(of: 512), cancellation() { return .empty }
            let occurrences: Int
            if let textIndex, textIndex.messageCount == timeline.count,
               let cached = matcher.matchCount(in: textIndex, messageIndex: index) {
                occurrences = cached
            } else {
                occurrences = matcher.matchCount(in: message.text)
            }
            guard occurrences > 0 else { continue }
            hits.append(.init(messageIndex: index, occurrenceCount: occurrences))
            totalOccurrences += occurrences
            participantCounts[message.author, default: 0] += 1
            platformCounts[message.platform, default: 0] += 1
        }
        return ChatSearchIndex(
            hits: hits,
            totalOccurrences: totalOccurrences,
            participantCounts: participantCounts,
            platformCounts: platformCounts
        )
    }

    public static func searchResult(_ timeline: [NormalizedMessage], index: ChatSearchIndex, options: ChatSearchOptions) -> ChatSearchResult {
        let pageSize = max(options.pageSize, 1)
        let start = min(max(options.page, 0) * pageSize, index.hits.count)
        let end = min(start + pageSize, index.hits.count)
        let matches = index.hits[start..<end].map { hit -> ChatSearchMatch in
            let messageIndex = hit.messageIndex
            let beforeRange = max(0, messageIndex - options.contextMessages)..<messageIndex
            let afterRange = min(messageIndex + 1, timeline.count)..<min(timeline.count, messageIndex + 1 + options.contextMessages)
            let before = timeline[beforeRange].filter {
                timeline[messageIndex].timestamp.timeIntervalSince($0.timestamp) <= options.maximumContextGap
            }
            let after = timeline[afterRange].filter {
                $0.timestamp.timeIntervalSince(timeline[messageIndex].timestamp) <= options.maximumContextGap
            }
            return ChatSearchMatch(
                message: timeline[messageIndex],
                occurrenceCount: hit.occurrenceCount,
                before: Array(before),
                after: Array(after)
            )
        }
        return ChatSearchResult(
            totalMessages: index.hits.count,
            totalOccurrences: index.totalOccurrences,
            matches: matches,
            participantCounts: index.participantCounts,
            platformCounts: index.platformCounts
        )
    }

    private struct SearchMatcher {
        private let regexes: [NSRegularExpression]
        private let requiresAll: Bool
        private let exactPhrase: Bool
        private let ignoreCase: Bool
        private let ignoreDiacritics: Bool

        init?(query: String, options: ChatSearchOptions) {
            self.ignoreCase = options.ignoreCase
            self.ignoreDiacritics = options.ignoreDiacritics
            let normalized = ChatSearchTextNormalizer.transform(query, ignoreCase: options.ignoreCase, ignoreDiacritics: options.ignoreDiacritics)
            let terms: [String]
            switch options.mode {
            case .exactPhrase:
                terms = [normalized]
                requiresAll = false
                exactPhrase = true
            case .allWords:
                terms = ChatTokenizer.words(in: normalized, includeStopWords: true)
                requiresAll = true
                exactPhrase = false
            case .anyWord:
                terms = ChatTokenizer.words(in: normalized, includeStopWords: true)
                requiresAll = false
                exactPhrase = false
            }
            guard !terms.isEmpty else { return nil }
            do {
                regexes = try terms.map { term in
                    let escaped = NSRegularExpression.escapedPattern(for: term)
                    let pattern = options.wholeWords ? "(?<![\\p{L}\\p{N}_])\(escaped)(?![\\p{L}\\p{N}_])" : escaped
                    return try NSRegularExpression(pattern: pattern)
                }
            } catch {
                return nil
            }
        }

        func matchCount(in text: String) -> Int {
            let haystack = ChatSearchTextNormalizer.transform(text, ignoreCase: ignoreCase, ignoreDiacritics: ignoreDiacritics)
            let range = NSRange(haystack.startIndex..., in: haystack)
            let values = regexes.map { $0.numberOfMatches(in: haystack, range: range) }
            if exactPhrase { return values.first ?? 0 }
            if requiresAll && values.contains(0) { return 0 }
            return values.reduce(0, +)
        }

        func matchCount(in textIndex: ChatSearchTextIndex, messageIndex: Int) -> Int? {
            guard let values = textIndex.matchCounts(regexes: regexes, messageIndex: messageIndex) else { return nil }
            if exactPhrase { return values.first ?? 0 }
            if requiresAll && values.contains(0) { return 0 }
            return values.reduce(0, +)
        }
    }
}
