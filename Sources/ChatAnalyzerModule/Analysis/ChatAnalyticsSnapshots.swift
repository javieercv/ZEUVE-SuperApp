import Foundation

extension ChatAnalytics {
    public static func participantsSnapshot(
        _ messages: [NormalizedMessage],
        settings: ChatAnalyzerSettings,
        includeDetails: Bool = false,
        cancellation: @Sendable () -> Bool = { false }
    ) -> ChatParticipantsAnalyticsSnapshot {
        let statistics = participants(messages, settings: settings, cancellation: cancellation)
        guard includeDetails else { return ChatParticipantsAnalyticsSnapshot(statistics: statistics) }
        var details: [String: ParticipantDetailAnalyticsSnapshot] = [:]
        let grouped = Dictionary(grouping: messages.filter { !$0.isSystem }, by: \.author)
        for statistic in statistics {
            let participantMessages = grouped[statistic.name, default: []]
            details[statistic.name] = participantDetail(
                name: statistic.name,
                messages: participantMessages,
                includeStopWords: settings.includeStopWords,
                cancellation: cancellation
            )
        }
        return ChatParticipantsAnalyticsSnapshot(statistics: statistics, details: details)
    }

    public static func participantDetail(
        name: String,
        messages: [NormalizedMessage],
        includeStopWords: Bool,
        cancellation: @Sendable () -> Bool = { false }
    ) -> ParticipantDetailAnalyticsSnapshot {
        ParticipantDetailAnalyticsSnapshot(
            name: name,
            messages: messages,
            words: words(messages, includeStopWords: includeStopWords, limit: 10, cancellation: cancellation),
            bigrams: bigrams(messages, includeStopWords: includeStopWords, limit: 10, cancellation: cancellation),
            emojis: emojis(messages, limit: 10, cancellation: cancellation),
            monthlySeries: timeSeries(messages, granularity: .month, cancellation: cancellation).filter { $0.platform == nil },
            hourly: hourly(messages, cancellation: cancellation),
            weekdays: weekdays(messages, cancellation: cancellation),
            platformCounts: Dictionary(grouping: messages, by: \.platform).mapValues(\.count),
            longestMessage: messages.max { $0.text.count < $1.text.count }
        )
    }

    public static func wordsSnapshot(
        _ messages: [NormalizedMessage],
        participantNames: [String],
        includeStopWords: Bool,
        cancellation: @Sendable () -> Bool = { false }
    ) -> ChatWordsAnalyticsSnapshot {
        var overallWords: [String: Int] = [:]
        var overallBigrams: [String: Int] = [:]
        var overallEmojis: [String: Int] = [:]
        var participantWords: [String: [String: Int]] = [:]
        var participantEmojis: [String: [String: Int]] = [:]
        var contentCounts: [ChatContentType: Int] = [:]

        for (messageIndex, message) in messages.enumerated() {
            if messageIndex.isMultiple(of: 512), cancellation() { return .empty }
            contentCounts[message.contentType, default: 0] += 1

            let tokens = ChatTokenizer.words(in: message.text, includeStopWords: true)
            for token in tokens where includeStopWords || !ChatTokenizer.stopWords.contains(token) {
                overallWords[token, default: 0] += 1
                if !message.isSystem {
                    participantWords[message.author, default: [:]][token, default: 0] += 1
                }
            }
            if tokens.count >= 2 {
                for index in 0..<(tokens.count - 1) {
                    let first = tokens[index]
                    let second = tokens[index + 1]
                    if !includeStopWords && ChatTokenizer.stopWords.contains(first) && ChatTokenizer.stopWords.contains(second) { continue }
                    overallBigrams["\(first) \(second)", default: 0] += 1
                }
            }

            for emoji in ChatTokenizer.emojis(in: message.text) {
                overallEmojis[emoji, default: 0] += 1
                if !message.isSystem {
                    participantEmojis[message.author, default: [:]][emoji, default: 0] += 1
                }
            }
        }

        let participantValues = participantNames.compactMap { name -> ParticipantFrequencyAnalyticsSnapshot? in
            let wordCounts = participantWords[name, default: [:]]
            let emojiCounts = participantEmojis[name, default: [:]]
            guard !wordCounts.isEmpty || !emojiCounts.isEmpty else { return nil }
            return ParticipantFrequencyAnalyticsSnapshot(
                name: name,
                words: frequency(wordCounts, limit: 5),
                emojis: frequency(emojiCounts, limit: 5)
            )
        }
        return ChatWordsAnalyticsSnapshot(
            words: frequency(overallWords, limit: 50),
            bigrams: frequency(overallBigrams.filter { $0.value >= 2 }, limit: 50),
            emojis: frequency(overallEmojis, limit: 50),
            participants: participantValues,
            contentCounts: contentCounts
        )
    }

    public static func conversationSnapshot(
        allMessages: [NormalizedMessage],
        filteredMessages: [NormalizedMessage],
        settings: ChatAnalyzerSettings,
        cancellation: @Sendable () -> Bool = { false }
    ) -> ChatConversationAnalyticsSnapshot {
        let source = settings.conversationFilterStrategy == .afterFiltering ? filteredMessages : allMessages
        let conversations = conversations(
            source,
            threshold: TimeInterval(settings.conversationThresholdMinutes * 60),
            cancellation: cancellation
        )
        let responses = responseTimes(
            conversations: conversations.conversations,
            maximumWindow: settings.responseWindowMinutes == 0
                ? nil
                : TimeInterval(settings.responseWindowMinutes * 60),
            cancellation: cancellation
        )
        return ChatConversationAnalyticsSnapshot(conversations: conversations, responses: responses)
    }

    public static func comparisonSnapshot(
        names: [String],
        filteredMessages: [NormalizedMessage],
        conversations: ConversationStatistics,
        responses: ResponseStatistics,
        settings: ChatAnalyzerSettings,
        granularity: TimeGranularity,
        cancellation: @Sendable () -> Bool = { false }
    ) -> ChatComparisonAnalyticsSnapshot {
        let selectedNames = Array(Set(names)).filter { !$0.isEmpty }
        let personalTotal = filteredMessages.lazy.filter { !$0.isSystem }.count
        let grouped = Dictionary(grouping: filteredMessages.filter { !$0.isSystem && selectedNames.contains($0.author) }, by: \.author)
        let responseGroups = Dictionary(grouping: responses.samples, by: \.participant)
        var values: [String: ParticipantComparisonAnalyticsSnapshot] = [:]

        for name in selectedNames {
            if cancellation() { return .empty }
            let participantMessages = grouped[name, default: []]
            let responseValues = responseGroups[name, default: []].map(\.delay).sorted()
            values[name] = ParticipantComparisonAnalyticsSnapshot(
                name: name,
                statistics: participant(name: name, messages: participantMessages, total: personalTotal, settings: settings, cancellation: cancellation),
                initiatedConversations: conversations.conversations.lazy.filter { $0.initiator == name }.count,
                unansweredConversations: conversations.conversations.lazy.filter { $0.initiator == name && $0.participants.count <= 1 }.count,
                finishedConversations: conversations.conversations.lazy.filter { $0.lastParticipant == name }.count,
                responseAverage: responseValues.isEmpty ? nil : responseValues.reduce(0, +) / Double(responseValues.count),
                responseMedian: responseValues.isEmpty ? nil : median(responseValues),
                platformCounts: Dictionary(grouping: participantMessages, by: \.platform).mapValues(\.count),
                series: timeSeries(participantMessages, granularity: granularity, cancellation: cancellation).filter { $0.platform == nil },
                hourly: hourly(participantMessages, cancellation: cancellation),
                weekdays: weekdays(participantMessages, cancellation: cancellation)
            )
        }
        return ChatComparisonAnalyticsSnapshot(participants: values)
    }
}
