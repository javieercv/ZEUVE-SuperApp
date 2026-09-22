import Foundation
import ZEUVEStorage

/// Analíticas de sesión que recorren `TemporaryChatStore` por lotes. Estas rutas son las usadas
/// por la aplicación real para evitar que una conversación completa vuelva a materializarse en RAM.
public enum ChatStoreAnalytics {
    private static let batchSize = 4_096

    public static func coreSnapshot(
        store: TemporaryChatStore,
        identityMap: [String: String],
        filter: ChatFilter,
        cancellation: @Sendable () -> Bool = { false }
    ) throws -> ChatStoreCoreAnalyticsSnapshot {
        let calendar = ChatAnalytics.calendar
        var totalMessages = 0
        var includedMessages = 0
        var firstTimelineMessage: Date?
        var lastTimelineMessage: Date?
        var participantCounts: [String: Int] = [:]
        var includedParticipants = Set<String>()
        var dayCounts: [Date: Int] = [:]
        var hourCounts = Array(repeating: 0, count: 24)
        var weekdayCounts = Array(repeating: 0, count: 8)
        var contentCounts: [ChatContentType: Int] = [:]
        var whatsappMessages = 0
        var instagramMessages = 0
        var firstMessage: Date?
        var lastMessage: Date?

        try store.forEachBatch(batchSize: batchSize, cancellation: cancellation) { batch in
            for raw in batch {
                try checkCancellation(cancellation)
                let message = applyingIdentityMap(identityMap, to: raw)
                totalMessages += 1
                if firstTimelineMessage == nil { firstTimelineMessage = message.timestamp }
                lastTimelineMessage = message.timestamp
                if !message.isSystem { participantCounts[message.author, default: 0] += 1 }
                guard filter.includes(message, calendar: calendar) else { continue }
                includedMessages += 1
                if firstMessage == nil { firstMessage = message.timestamp }
                lastMessage = message.timestamp
                let day = calendar.startOfDay(for: message.timestamp)
                dayCounts[day, default: 0] += 1
                hourCounts[calendar.component(.hour, from: message.timestamp)] += 1
                weekdayCounts[calendar.component(.weekday, from: message.timestamp)] += 1
                if !message.isSystem { includedParticipants.insert(message.author) }
                contentCounts[message.contentType, default: 0] += 1
                if message.platform == .whatsapp { whatsappMessages += 1 }
                else { instagramMessages += 1 }
            }
        }

        let mostActiveHour = hourCounts.indices.max { hourCounts[$0] < hourCounts[$1] }
        let mostActiveWeekday = (1...7).max { weekdayCounts[$0] < weekdayCounts[$1] }
        let participantNames = participantCounts.keys.sorted {
            let left = participantCounts[$0, default: 0]
            let right = participantCounts[$1, default: 0]
            return left == right ? $0 < $1 : left > right
        }
        let summary = ChatSummaryStatistics(
            totalMessages: totalMessages,
            includedMessages: includedMessages,
            participants: includedParticipants.count,
            activeDays: dayCounts.count,
            firstMessage: firstMessage,
            lastMessage: lastMessage,
            mostActiveDay: dayCounts.max { $0.value < $1.value }?.key,
            mostActiveHour: mostActiveHour.flatMap { hourCounts[$0] > 0 ? $0 : nil },
            mostActiveWeekday: mostActiveWeekday.flatMap { weekdayCounts[$0] > 0 ? $0 : nil },
            whatsappMessages: whatsappMessages,
            instagramMessages: instagramMessages,
            averagePerActiveDay: dayCounts.isEmpty ? 0 : Double(includedMessages) / Double(dayCounts.count),
            contentCounts: contentCounts
        )
        return ChatStoreCoreAnalyticsSnapshot(
            totalMessages: totalMessages,
            filteredMessageCount: includedMessages,
            participantNames: participantNames,
            firstTimelineMessage: firstTimelineMessage,
            lastTimelineMessage: lastTimelineMessage,
            summary: summary
        )
    }

    public static func activitySnapshot(
        store: TemporaryChatStore,
        identityMap: [String: String],
        filter: ChatFilter,
        granularity: TimeGranularity,
        cancellation: @Sendable () -> Bool = { false }
    ) throws -> ChatActivityAnalyticsSnapshot {
        let calendar = ChatAnalytics.calendar
        var temporal: [Date: (total: Int, whatsapp: Int, instagram: Int)] = [:]
        var hourlyValues = Array(repeating: 0, count: 24)
        var weekdayValues = Array(repeating: 0, count: 7)
        var heatmapValues = Array(repeating: 0, count: 7 * 24)

        try store.forEachBatch(batchSize: batchSize, cancellation: cancellation) { batch in
            for raw in batch {
                try checkCancellation(cancellation)
                let message = applyingIdentityMap(identityMap, to: raw)
                guard filter.includes(message, calendar: calendar) else { continue }
                let date = bucket(message.timestamp, granularity: granularity, calendar: calendar)
                var counts = temporal[date] ?? (0, 0, 0)
                counts.total += 1
                if message.platform == .whatsapp { counts.whatsapp += 1 }
                else { counts.instagram += 1 }
                temporal[date] = counts

                let hour = calendar.component(.hour, from: message.timestamp)
                let weekdayIndex = calendar.component(.weekday, from: message.timestamp) - 1
                hourlyValues[hour] += 1
                weekdayValues[weekdayIndex] += 1
                heatmapValues[weekdayIndex * 24 + hour] += 1
            }
        }

        var series: [TimeSeriesPoint] = []
        series.reserveCapacity(temporal.count * 3)
        for (date, counts) in temporal {
            series.append(.init(date: date, platform: nil, count: counts.total))
            if counts.whatsapp > 0 { series.append(.init(date: date, platform: .whatsapp, count: counts.whatsapp)) }
            if counts.instagram > 0 { series.append(.init(date: date, platform: .instagram, count: counts.instagram)) }
        }
        series.sort {
            if $0.date != $1.date { return $0.date < $1.date }
            return ($0.platform?.rawValue ?? "") < ($1.platform?.rawValue ?? "")
        }
        let heatmap = (1...7).flatMap { day in
            (0..<24).map { hour in
                HeatmapCell(weekday: day, hour: hour, count: heatmapValues[(day - 1) * 24 + hour])
            }
        }
        return ChatActivityAnalyticsSnapshot(series: series, hourly: hourlyValues, weekdays: weekdayValues, heatmap: heatmap)
    }

    public static func participantsSnapshot(
        store: TemporaryChatStore,
        identityMap: [String: String],
        filter: ChatFilter,
        settings: ChatAnalyzerSettings,
        cancellation: @Sendable () -> Bool = { false }
    ) throws -> ChatParticipantsAnalyticsSnapshot {
        let calendar = ChatAnalytics.calendar
        var totalPersonal = 0
        var accumulators: [String: ParticipantAccumulator] = [:]

        try store.forEachBatch(batchSize: batchSize, cancellation: cancellation) { batch in
            for raw in batch {
                try checkCancellation(cancellation)
                let message = applyingIdentityMap(identityMap, to: raw)
                guard filter.includes(message, calendar: calendar), !message.isSystem else { continue }
                totalPersonal += 1
                var accumulator = accumulators[message.author] ?? ParticipantAccumulator()
                accumulator.consume(message, settings: settings, calendar: calendar)
                accumulators[message.author] = accumulator
            }
        }

        var statistics: [ParticipantStatistics] = []
        statistics.reserveCapacity(accumulators.count)
        for (name, accumulator) in accumulators {
            statistics.append(accumulator.statistics(name: name, totalPersonal: totalPersonal))
        }
        statistics.sort {
            if $0.messages == $1.messages {
                return $0.name < $1.name
            }
            return $0.messages > $1.messages
        }
        return ChatParticipantsAnalyticsSnapshot(statistics: statistics)
    }

    public static func participantDetail(
        name: String,
        store: TemporaryChatStore,
        identityMap: [String: String],
        filter: ChatFilter,
        includeStopWords: Bool,
        cancellation: @Sendable () -> Bool = { false }
    ) throws -> ParticipantDetailAnalyticsSnapshot {
        let calendar = ChatAnalytics.calendar
        let scratch = try FrequencyScratch(baseDirectory: store.url.deletingLastPathComponent())
        var monthly: [Date: Int] = [:]
        var hourly = Array(repeating: 0, count: 24)
        var weekdays = Array(repeating: 0, count: 7)
        var platformCounts: [ChatPlatform: Int] = [:]
        var longestMessage: NormalizedMessage?

        try store.forEachBatch(batchSize: batchSize, cancellation: cancellation) { batch in
            var frequencies = FrequencyBatch()
            for raw in batch {
                try checkCancellation(cancellation)
                let message = applyingIdentityMap(identityMap, to: raw)
                guard !message.isSystem, message.author == name, filter.includes(message, calendar: calendar) else { continue }
                frequencies.consume(message, includeStopWords: includeStopWords, participant: nil, includeBigrams: true)
                let month = bucket(message.timestamp, granularity: .month, calendar: calendar)
                monthly[month, default: 0] += 1
                hourly[calendar.component(.hour, from: message.timestamp)] += 1
                weekdays[calendar.component(.weekday, from: message.timestamp) - 1] += 1
                platformCounts[message.platform, default: 0] += 1
                if longestMessage == nil || message.text.count > longestMessage!.text.count { longestMessage = message }
            }
            try scratch.merge(frequencies)
        }

        let monthlySeries = monthly.map { TimeSeriesPoint(date: $0.key, platform: nil, count: $0.value) }.sorted { $0.date < $1.date }
        return ParticipantDetailAnalyticsSnapshot(
            name: name,
            messages: [],
            words: try scratch.top(kind: .word, participant: nil, limit: 10),
            bigrams: try scratch.top(kind: .bigram, participant: nil, limit: 10, minimumCount: 2),
            emojis: try scratch.top(kind: .emoji, participant: nil, limit: 10),
            monthlySeries: monthlySeries,
            hourly: hourly,
            weekdays: weekdays,
            platformCounts: platformCounts,
            longestMessage: longestMessage
        )
    }

    public static func wordsSnapshot(
        store: TemporaryChatStore,
        identityMap: [String: String],
        filter: ChatFilter,
        participantNames: [String],
        includeStopWords: Bool,
        cancellation: @Sendable () -> Bool = { false }
    ) throws -> ChatWordsAnalyticsSnapshot {
        let calendar = ChatAnalytics.calendar
        let scratch = try FrequencyScratch(baseDirectory: store.url.deletingLastPathComponent())
        var contentCounts: [ChatContentType: Int] = [:]

        try store.forEachBatch(batchSize: batchSize, cancellation: cancellation) { batch in
            var frequencies = FrequencyBatch()
            for raw in batch {
                try checkCancellation(cancellation)
                let message = applyingIdentityMap(identityMap, to: raw)
                guard filter.includes(message, calendar: calendar) else { continue }
                contentCounts[message.contentType, default: 0] += 1
                frequencies.consume(
                    message,
                    includeStopWords: includeStopWords,
                    participant: message.isSystem ? nil : message.author,
                    includeBigrams: true
                )
            }
            try scratch.merge(frequencies)
        }

        var participantValues: [ParticipantFrequencyAnalyticsSnapshot] = []
        participantValues.reserveCapacity(participantNames.count)
        for name in participantNames {
            try checkCancellation(cancellation)
            let words = try scratch.top(kind: .participantWord, participant: name, limit: 5)
            let emojis = try scratch.top(kind: .participantEmoji, participant: name, limit: 5)
            if !words.isEmpty || !emojis.isEmpty {
                participantValues.append(.init(name: name, words: words, emojis: emojis))
            }
        }

        return ChatWordsAnalyticsSnapshot(
            words: try scratch.top(kind: .word, participant: nil, limit: 50),
            bigrams: try scratch.top(kind: .bigram, participant: nil, limit: 50, minimumCount: 2),
            emojis: try scratch.top(kind: .emoji, participant: nil, limit: 50),
            participants: participantValues,
            contentCounts: contentCounts
        )
    }

    public static func conversationSnapshot(
        store: TemporaryChatStore,
        identityMap: [String: String],
        filter: ChatFilter,
        settings: ChatAnalyzerSettings,
        cancellation: @Sendable () -> Bool = { false }
    ) throws -> ChatConversationAnalyticsSnapshot {
        let scratch = try ConversationScratch(baseDirectory: store.url.deletingLastPathComponent())
        let calendar = ChatAnalytics.calendar
        let threshold = TimeInterval(settings.conversationThresholdMinutes * 60)
        let maximumWindow: TimeInterval? = settings.responseWindowMinutes == 0
            ? nil
            : TimeInterval(settings.responseWindowMinutes * 60)
        let appliesFilter = settings.conversationFilterStrategy == .afterFiltering

        var builder: CompactConversationBuilder?
        var conversationCount = 0
        var totalDuration: Double = 0
        var totalMessages = 0
        var singleParticipantCount = 0
        var unansweredCount = 0
        var maximumMessageCount = 0
        var maximumDuration: TimeInterval?
        var startHourCounts = Array(repeating: 0, count: 24)
        var startWeekdayCounts = Array(repeating: 0, count: 7)
        var participantAccumulators: [String: ConversationParticipantAccumulator] = [:]
        var topMessages: [ChatConversation] = []
        var topDuration: [ChatConversation] = []
        var durationBuffer: [Double] = []
        var responseBuffer: [(String, Double)] = []

        func flushBuffers() throws {
            if !durationBuffer.isEmpty {
                try scratch.appendDurations(durationBuffer)
                durationBuffer.removeAll(keepingCapacity: true)
            }
            if !responseBuffer.isEmpty {
                try scratch.appendResponses(responseBuffer)
                responseBuffer.removeAll(keepingCapacity: true)
            }
        }

        func finalizeCurrent() throws {
            guard let current = builder else { return }
            let finalized = current.finish(id: conversationCount)
            conversationCount += 1
            let duration = finalized.duration
            totalDuration += duration
            totalMessages += finalized.messageCount
            durationBuffer.append(duration)
            if durationBuffer.count >= 1_024 { try flushBuffers() }
            if finalized.participants.count == 1 { singleParticipantCount += 1 }
            if finalized.participants.count <= 1 { unansweredCount += 1 }
            maximumMessageCount = max(maximumMessageCount, finalized.messageCount)
            maximumDuration = max(maximumDuration ?? duration, duration)
            startHourCounts[calendar.component(.hour, from: finalized.start)] += 1
            startWeekdayCounts[calendar.component(.weekday, from: finalized.start) - 1] += 1

            var initiator = participantAccumulators[finalized.initiator] ?? .init()
            initiator.initiated += 1
            if finalized.participants.count <= 1 { initiator.unanswered += 1 }
            initiator.initiatedDuration += duration
            initiator.initiatedMessages += finalized.messageCount
            participantAccumulators[finalized.initiator] = initiator

            var finisher = participantAccumulators[finalized.lastParticipant] ?? .init()
            finisher.finished += 1
            participantAccumulators[finalized.lastParticipant] = finisher

            insertTop(finalized, into: &topMessages, limit: 10) {
                if $0.messageCount != $1.messageCount { return $0.messageCount > $1.messageCount }
                return $0.id < $1.id
            }
            insertTop(finalized, into: &topDuration, limit: 10) {
                if $0.duration != $1.duration { return $0.duration > $1.duration }
                return $0.id < $1.id
            }
            builder = nil
        }

        try store.forEachBatch(batchSize: batchSize, cancellation: cancellation) { batch in
            for raw in batch {
                try checkCancellation(cancellation)
                let message = applyingIdentityMap(identityMap, to: raw)
                if appliesFilter && !filter.includes(message, calendar: calendar) { continue }
                if let current = builder, message.timestamp.timeIntervalSince(current.end) > threshold {
                    try finalizeCurrent()
                }
                if builder == nil {
                    builder = CompactConversationBuilder(first: message)
                } else if let response = builder?.append(message),
                          response.delay >= 0,
                          maximumWindow.map({ response.delay <= $0 }) ?? true {
                    responseBuffer.append((response.participant, response.delay))
                    if responseBuffer.count >= 2_048 { try flushBuffers() }
                }
            }
        }
        try finalizeCurrent()
        try flushBuffers()

        let medianDuration = try scratch.durationMedian() ?? 0
        let participantStatistics = participantAccumulators.mapValues { value in
            ConversationParticipantStatistics(
                initiated: value.initiated,
                finished: value.finished,
                unanswered: value.unanswered,
                initiatedAverageDuration: value.initiated == 0 ? nil : value.initiatedDuration / Double(value.initiated),
                initiatedAverageMessages: value.initiated == 0 ? nil : Double(value.initiatedMessages) / Double(value.initiated)
            )
        }
        let conversationStats = ConversationStatistics(
            totalCount: conversationCount,
            averageDuration: conversationCount == 0 ? 0 : totalDuration / Double(conversationCount),
            medianDuration: medianDuration,
            averageMessages: conversationCount == 0 ? 0 : Double(totalMessages) / Double(conversationCount),
            singleParticipantCount: singleParticipantCount,
            unansweredCount: unansweredCount,
            maximumMessageCount: maximumMessageCount,
            maximumDuration: maximumDuration,
            startHourCounts: startHourCounts,
            startWeekdayCounts: startWeekdayCounts,
            participantStatistics: participantStatistics
        )
        let responses = try scratch.responseStatistics()
        return ChatConversationAnalyticsSnapshot(
            conversations: conversationStats,
            responses: responses,
            topConversationsByMessages: topMessages,
            topConversationsByDuration: topDuration
        )
    }

    public static func comparisonSnapshot(
        names: [String],
        store: TemporaryChatStore,
        identityMap: [String: String],
        filter: ChatFilter,
        conversations: ChatConversationAnalyticsSnapshot,
        settings: ChatAnalyzerSettings,
        granularity: TimeGranularity,
        cancellation: @Sendable () -> Bool = { false }
    ) throws -> ChatComparisonAnalyticsSnapshot {
        let selectedNames = Array(Set(names)).filter { !$0.isEmpty }
        guard !selectedNames.isEmpty else { return .empty }
        let selectedSet = Set(selectedNames)
        let calendar = ChatAnalytics.calendar
        var totalPersonal = 0
        var participantAccumulators: [String: ParticipantAccumulator] = [:]
        var temporal: [String: [Date: Int]] = [:]
        var hourly: [String: [Int]] = [:]
        var weekdays: [String: [Int]] = [:]
        var platformCounts: [String: [ChatPlatform: Int]] = [:]

        try store.forEachBatch(batchSize: batchSize, cancellation: cancellation) { batch in
            for raw in batch {
                try checkCancellation(cancellation)
                let message = applyingIdentityMap(identityMap, to: raw)
                guard filter.includes(message, calendar: calendar), !message.isSystem else { continue }
                totalPersonal += 1
                guard selectedSet.contains(message.author) else { continue }
                var accumulator = participantAccumulators[message.author] ?? .init()
                accumulator.consume(message, settings: settings, calendar: calendar)
                participantAccumulators[message.author] = accumulator
                let date = bucket(message.timestamp, granularity: granularity, calendar: calendar)
                temporal[message.author, default: [:]][date, default: 0] += 1
                if hourly[message.author] == nil { hourly[message.author] = Array(repeating: 0, count: 24) }
                if weekdays[message.author] == nil { weekdays[message.author] = Array(repeating: 0, count: 7) }
                hourly[message.author]![calendar.component(.hour, from: message.timestamp)] += 1
                weekdays[message.author]![calendar.component(.weekday, from: message.timestamp) - 1] += 1
                platformCounts[message.author, default: [:]][message.platform, default: 0] += 1
            }
        }

        var values: [String: ParticipantComparisonAnalyticsSnapshot] = [:]
        for name in selectedNames {
            try checkCancellation(cancellation)
            let participant = participantAccumulators[name] ?? .init()
            let conversationParticipant = conversations.conversations.participantStatistics[name]
            let response = conversations.responses.participants[name]
            let series = (temporal[name] ?? [:]).map {
                TimeSeriesPoint(date: $0.key, platform: nil, count: $0.value)
            }.sorted { $0.date < $1.date }
            values[name] = ParticipantComparisonAnalyticsSnapshot(
                name: name,
                statistics: participant.statistics(name: name, totalPersonal: totalPersonal),
                initiatedConversations: conversationParticipant?.initiated ?? 0,
                unansweredConversations: conversationParticipant?.unanswered ?? 0,
                finishedConversations: conversationParticipant?.finished ?? 0,
                responseAverage: response?.average,
                responseMedian: response?.median,
                platformCounts: platformCounts[name] ?? [:],
                series: series,
                hourly: hourly[name] ?? Array(repeating: 0, count: 24),
                weekdays: weekdays[name] ?? Array(repeating: 0, count: 7)
            )
        }
        return ChatComparisonAnalyticsSnapshot(participants: values)
    }

    public static func searchResult(
        store: TemporaryChatStore,
        identityMap: [String: String],
        filter: ChatFilter,
        options: ChatSearchOptions,
        cancellation: @Sendable () -> Bool = { false }
    ) throws -> ChatSearchResult {
        let query = options.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, let matcher = StoreSearchMatcher(query: query, options: options) else { return .empty }
        let calendar = ChatAnalytics.calendar
        let pageSize = max(options.pageSize, 1)
        let pageStart = max(options.page, 0) * pageSize
        let pageEnd = pageStart + pageSize
        var matchedMessages = 0
        var totalOccurrences = 0
        var participantCounts: [String: Int] = [:]
        var platformCounts: [ChatPlatform: Int] = [:]
        var pageHits: [(index: Int, message: NormalizedMessage, occurrences: Int)] = []
        pageHits.reserveCapacity(pageSize)

        try store.forEachIndexedBatch(batchSize: batchSize, cancellation: cancellation) { offset, batch in
            for (localIndex, raw) in batch.enumerated() {
                try checkCancellation(cancellation)
                let message = applyingIdentityMap(identityMap, to: raw)
                guard filter.includes(message, calendar: calendar) else { continue }
                let occurrences = matcher.matchCount(in: message.text)
                guard occurrences > 0 else { continue }
                let ordinal = matchedMessages
                matchedMessages += 1
                totalOccurrences += occurrences
                participantCounts[message.author, default: 0] += 1
                platformCounts[message.platform, default: 0] += 1
                if ordinal >= pageStart && ordinal < pageEnd {
                    pageHits.append((offset + localIndex, message, occurrences))
                }
            }
        }

        var matches: [ChatSearchMatch] = []
        matches.reserveCapacity(pageHits.count)
        for hit in pageHits {
            try checkCancellation(cancellation)
            let context = max(options.contextMessages, 0)
            let start = max(0, hit.index - context)
            let end = min(try store.messageCount(), hit.index + context + 1)
            let rawContext = try store.messages(offset: start, limit: max(0, end - start))
            let mappedContext = rawContext.map { applyingIdentityMap(identityMap, to: $0) }
            let center = hit.index - start
            let before = mappedContext[..<max(0, center)].filter {
                hit.message.timestamp.timeIntervalSince($0.timestamp) <= options.maximumContextGap
            }
            let afterStart = min(center + 1, mappedContext.count)
            let after = mappedContext[afterStart...].filter {
                $0.timestamp.timeIntervalSince(hit.message.timestamp) <= options.maximumContextGap
            }
            matches.append(ChatSearchMatch(
                message: hit.message,
                occurrenceCount: hit.occurrences,
                before: Array(before),
                after: Array(after)
            ))
        }

        return ChatSearchResult(
            totalMessages: matchedMessages,
            totalOccurrences: totalOccurrences,
            matches: matches,
            participantCounts: participantCounts,
            platformCounts: platformCounts
        )
    }

    // MARK: - Helpers

    static func applyingIdentityMap(_ identityMap: [String: String], to message: NormalizedMessage) -> NormalizedMessage {
        guard let merged = identityMap[message.originalAuthor], merged != message.author else { return message }
        return NormalizedMessage(
            id: message.id,
            conversationID: message.conversationID,
            timestamp: message.timestamp,
            originalDateText: message.originalDateText,
            timeZoneStrategy: message.timeZoneStrategy,
            author: merged,
            originalAuthor: message.originalAuthor,
            text: message.text,
            platform: message.platform,
            contentType: message.contentType,
            sourceFile: message.sourceFile,
            sourcePage: message.sourcePage,
            sourcePosition: message.sourcePosition,
            category: message.category,
            isSystem: message.isSystem,
            hasUncertainDate: message.hasUncertainDate,
            attachment: message.attachment
        )
    }

    private static func checkCancellation(_ cancellation: @Sendable () -> Bool) throws {
        if cancellation() || Task.isCancelled { throw ChatAnalyzerError.cancelled }
    }

    private static func bucket(_ date: Date, granularity: TimeGranularity, calendar: Calendar) -> Date {
        switch granularity {
        case .day: return calendar.startOfDay(for: date)
        case .week: return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        case .month: return calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
        case .year: return calendar.date(from: calendar.dateComponents([.year], from: date)) ?? date
        }
    }

    private static func insertTop(
        _ conversation: ChatConversation,
        into values: inout [ChatConversation],
        limit: Int,
        areInIncreasingPriority: (ChatConversation, ChatConversation) -> Bool
    ) {
        values.append(conversation)
        values.sort(by: areInIncreasingPriority)
        if values.count > limit { values.removeLast(values.count - limit) }
    }
}

private struct ParticipantAccumulator {
    var messages = 0
    var wordTotal = 0
    var characterTotal = 0
    var wordHistogram: [Int: Int] = [:]
    var activeDays = Set<Date>()
    var platforms = Set<ChatPlatform>()
    var questions = 0
    var links = 0
    var multimedia = 0
    var uppercaseMessages = 0
    var emojiTotal = 0
    var contentCounts: [ChatContentType: Int] = [:]
    var firstMessage: Date?
    var lastMessage: Date?

    mutating func consume(_ message: NormalizedMessage, settings: ChatAnalyzerSettings, calendar: Calendar) {
        let wordCount = ChatTokenizer.words(in: message.text, includeStopWords: true).count
        messages += 1
        wordTotal += wordCount
        characterTotal += message.text.count
        wordHistogram[wordCount, default: 0] += 1
        activeDays.insert(calendar.startOfDay(for: message.timestamp))
        platforms.insert(message.platform)
        if message.text.contains("?") { questions += 1 }
        if ChatContentClassifier.containsURL(message.text) { links += 1 }
        if ChatAnalytics.isMultimedia(message, settings: settings) { multimedia += 1 }
        if ChatAnalytics.isUppercase(message.text) { uppercaseMessages += 1 }
        emojiTotal += ChatTokenizer.emojiCount(in: message.text)
        contentCounts[message.contentType, default: 0] += 1
        if firstMessage == nil { firstMessage = message.timestamp }
        lastMessage = message.timestamp
    }

    func statistics(name: String, totalPersonal: Int) -> ParticipantStatistics {
        ParticipantStatistics(
            name: name,
            messages: messages,
            percentage: totalPersonal == 0 ? 0 : Double(messages) / Double(totalPersonal) * 100,
            words: wordTotal,
            averageWords: messages == 0 ? 0 : Double(wordTotal) / Double(messages),
            medianWords: histogramMedian(wordHistogram, total: messages),
            averageLength: messages == 0 ? 0 : Double(characterTotal) / Double(messages),
            activeDays: activeDays.count,
            messagesPerActiveDay: activeDays.isEmpty ? 0 : Double(messages) / Double(activeDays.count),
            firstMessage: firstMessage,
            lastMessage: lastMessage,
            platforms: platforms,
            questions: questions,
            links: links,
            multimedia: multimedia,
            uppercaseMessages: uppercaseMessages,
            emojis: emojiTotal,
            contentCounts: contentCounts
        )
    }

    private func histogramMedian(_ histogram: [Int: Int], total: Int) -> Double {
        guard total > 0 else { return 0 }
        let firstTarget = (total - 1) / 2
        let secondTarget = total / 2
        var cumulative = 0
        var first: Int?
        var second: Int?
        for key in histogram.keys.sorted() {
            cumulative += histogram[key, default: 0]
            if first == nil, cumulative > firstTarget { first = key }
            if cumulative > secondTarget { second = key; break }
        }
        return Double((first ?? 0) + (second ?? first ?? 0)) / 2
    }
}

private enum FrequencyKind: String {
    case word
    case bigram
    case emoji
    case participantWord = "participant-word"
    case participantEmoji = "participant-emoji"
}

private struct FrequencyKey: Hashable {
    let kind: FrequencyKind
    let participant: String
    let value: String
}

private struct FrequencyBatch {
    var values: [FrequencyKey: Int] = [:]

    mutating func consume(
        _ message: NormalizedMessage,
        includeStopWords: Bool,
        participant: String?,
        includeBigrams: Bool
    ) {
        let tokens = ChatTokenizer.words(in: message.text, includeStopWords: true)
        for token in tokens where includeStopWords || !ChatTokenizer.stopWords.contains(token) {
            values[.init(kind: .word, participant: "", value: token), default: 0] += 1
            if let participant {
                values[.init(kind: .participantWord, participant: participant, value: token), default: 0] += 1
            }
        }
        if includeBigrams, tokens.count >= 2 {
            for index in 0..<(tokens.count - 1) {
                let first = tokens[index]
                let second = tokens[index + 1]
                if !includeStopWords && ChatTokenizer.stopWords.contains(first) && ChatTokenizer.stopWords.contains(second) { continue }
                values[.init(kind: .bigram, participant: "", value: "\(first) \(second)"), default: 0] += 1
            }
        }
        for emoji in ChatTokenizer.emojis(in: message.text) {
            values[.init(kind: .emoji, participant: "", value: emoji), default: 0] += 1
            if let participant {
                values[.init(kind: .participantEmoji, participant: participant, value: emoji), default: 0] += 1
            }
        }
    }
}

private final class FrequencyScratch {
    private var database: SQLiteDatabase?
    private let url: URL

    init(baseDirectory: URL) throws {
        url = baseDirectory.appendingPathComponent("analytics-frequency-\(UUID().uuidString).sqlite")
        let database = try SQLiteDatabase(url: url)
        try database.execute("""
            CREATE TABLE frequency(
                kind TEXT NOT NULL,
                participant TEXT NOT NULL,
                value TEXT NOT NULL,
                count INTEGER NOT NULL,
                PRIMARY KEY(kind, participant, value)
            )
            """)
        try database.execute("CREATE INDEX idx_frequency_lookup ON frequency(kind, participant, count DESC, value)")
        self.database = database
    }

    func merge(_ batch: FrequencyBatch) throws {
        guard !batch.values.isEmpty, let database else { return }
        let values = Array(batch.values)
        try database.transaction {
            try database.executeBatch(
                """
                INSERT INTO frequency(kind, participant, value, count)
                VALUES(?, ?, ?, ?)
                ON CONFLICT(kind, participant, value)
                DO UPDATE SET count = frequency.count + excluded.count
                """,
                rowCount: values.count
            ) { index in
                let item = values[index]
                return [
                    .text(item.key.kind.rawValue),
                    .text(item.key.participant),
                    .text(item.key.value),
                    .integer(Int64(item.value)),
                ]
            }
        }
    }

    func top(kind: FrequencyKind, participant: String?, limit: Int, minimumCount: Int = 1) throws -> [FrequencyItem] {
        guard let database, limit > 0 else { return [] }
        let rows = try database.query(
            """
            SELECT value, count
            FROM frequency
            WHERE kind = ? AND participant = ? AND count >= ?
            ORDER BY count DESC, value ASC
            LIMIT ?
            """,
            bindings: [
                .text(kind.rawValue),
                .text(participant ?? ""),
                .integer(Int64(minimumCount)),
                .integer(Int64(limit)),
            ]
        )
        return try rows.map { FrequencyItem(value: try $0.string("value"), count: Int(try $0.integer("count"))) }
    }

    deinit { cleanup() }

    private func cleanup() {
        database = nil
        let fm = FileManager.default
        try? fm.removeItem(at: url)
        try? fm.removeItem(at: URL(fileURLWithPath: url.path + "-wal"))
        try? fm.removeItem(at: URL(fileURLWithPath: url.path + "-shm"))
    }
}

private struct CompactResponse {
    let participant: String
    let delay: TimeInterval
}

private struct CompactConversationBuilder {
    let start: Date
    var end: Date
    var messageCount: Int
    var participants: Set<String>
    var initiator: String?
    var lastParticipant: String?
    var platforms: Set<ChatPlatform>
    private var activeTurnAuthor: String?
    private var activeTurnEnd: Date?

    init(first: NormalizedMessage) {
        start = first.timestamp
        end = first.timestamp
        messageCount = 1
        participants = first.isSystem ? [] : [first.author]
        initiator = first.isSystem ? nil : first.author
        lastParticipant = first.isSystem ? nil : first.author
        platforms = [first.platform]
        activeTurnAuthor = first.isSystem ? nil : first.author
        activeTurnEnd = first.isSystem ? nil : first.timestamp
    }

    mutating func append(_ message: NormalizedMessage) -> CompactResponse? {
        end = message.timestamp
        messageCount += 1
        platforms.insert(message.platform)
        guard !message.isSystem else { return nil }
        participants.insert(message.author)
        if initiator == nil { initiator = message.author }
        lastParticipant = message.author
        var response: CompactResponse?
        if let activeTurnAuthor, activeTurnAuthor != message.author, let activeTurnEnd {
            response = .init(participant: message.author, delay: message.timestamp.timeIntervalSince(activeTurnEnd))
        }
        activeTurnAuthor = message.author
        activeTurnEnd = message.timestamp
        return response
    }

    func finish(id: Int) -> ChatConversation {
        ChatConversation(
            id: id,
            start: start,
            end: end,
            messageCount: messageCount,
            participants: participants,
            initiator: initiator ?? "Sistema",
            lastParticipant: lastParticipant ?? "Sistema",
            platforms: platforms
        )
    }
}

private struct ConversationParticipantAccumulator {
    var initiated = 0
    var finished = 0
    var unanswered = 0
    var initiatedDuration: Double = 0
    var initiatedMessages = 0
}

private final class ConversationScratch {
    private var database: SQLiteDatabase?
    private let url: URL

    init(baseDirectory: URL) throws {
        url = baseDirectory.appendingPathComponent("analytics-conversation-\(UUID().uuidString).sqlite")
        let database = try SQLiteDatabase(url: url)
        try database.execute("CREATE TABLE durations(value REAL NOT NULL)")
        try database.execute("CREATE INDEX idx_durations_value ON durations(value)")
        try database.execute("CREATE TABLE responses(participant TEXT NOT NULL, value REAL NOT NULL)")
        try database.execute("CREATE INDEX idx_responses_value ON responses(value)")
        try database.execute("CREATE INDEX idx_responses_participant_value ON responses(participant, value)")
        self.database = database
    }

    func appendDurations(_ values: [Double]) throws {
        guard !values.isEmpty, let database else { return }
        try database.transaction {
            try database.executeBatch("INSERT INTO durations(value) VALUES(?)", rowCount: values.count) { [.real(values[$0])] }
        }
    }

    func appendResponses(_ values: [(String, Double)]) throws {
        guard !values.isEmpty, let database else { return }
        try database.transaction {
            try database.executeBatch("INSERT INTO responses(participant, value) VALUES(?, ?)", rowCount: values.count) {
                [.text(values[$0].0), .real(values[$0].1)]
            }
        }
    }

    func durationMedian() throws -> Double? {
        try percentile(table: "durations", participant: nil, p: 0.5)
    }

    func responseStatistics() throws -> ResponseStatistics {
        guard let database else { return .empty }
        let aggregate = try database.query("SELECT COUNT(*) AS count, AVG(value) AS average, MIN(value) AS fastest, MAX(value) AS slowest FROM responses").first ?? [:]
        let count = Int(integer(aggregate["count"]) ?? 0)
        let participantRows = try database.query("SELECT DISTINCT participant FROM responses ORDER BY participant")
        var participants: [String: ResponseParticipantStatistics] = [:]
        for row in participantRows {
            let participant = try row.string("participant")
            let stats = try database.query(
                """
                SELECT COUNT(*) AS count,
                       AVG(value) AS average,
                       MIN(value) AS fastest,
                       MAX(value) AS slowest,
                       SUM(CASE WHEN value < 300 THEN 1 ELSE 0 END) AS under5,
                       SUM(CASE WHEN value < 3600 THEN 1 ELSE 0 END) AS under1h,
                       SUM(CASE WHEN value < 86400 THEN 1 ELSE 0 END) AS under24h
                FROM responses WHERE participant = ?
                """,
                bindings: [.text(participant)]
            ).first ?? [:]
            let participantCount = Int(integer(stats["count"]) ?? 0)
            participants[participant] = ResponseParticipantStatistics(
                count: participantCount,
                average: double(stats["average"]),
                median: try percentile(table: "responses", participant: participant, p: 0.5),
                fastest: double(stats["fastest"]),
                slowest: double(stats["slowest"]),
                underFiveMinutes: Int(integer(stats["under5"]) ?? 0),
                underOneHour: Int(integer(stats["under1h"]) ?? 0),
                underTwentyFourHours: Int(integer(stats["under24h"]) ?? 0)
            )
        }
        let distributionSpecs: [(String, String)] = [
            ("<1 min", "value < 60"),
            ("<5 min", "value >= 60 AND value < 300"),
            ("<15 min", "value >= 300 AND value < 900"),
            ("<1 h", "value >= 900 AND value < 3600"),
            ("<6 h", "value >= 3600 AND value < 21600"),
            ("<24 h", "value >= 21600 AND value < 86400"),
            ("≥24 h", "value >= 86400"),
        ]
        var distribution: [ResponseDistributionItem] = []
        for spec in distributionSpecs {
            let row = try database.query("SELECT COUNT(*) AS count FROM responses WHERE \(spec.1)").first ?? [:]
            distribution.append(.init(label: spec.0, count: Int(integer(row["count"]) ?? 0)))
        }
        return ResponseStatistics(
            sampleCount: count,
            average: double(aggregate["average"]),
            median: try percentile(table: "responses", participant: nil, p: 0.5),
            fastest: double(aggregate["fastest"]),
            slowest: double(aggregate["slowest"]),
            percentile25: try percentile(table: "responses", participant: nil, p: 0.25),
            percentile75: try percentile(table: "responses", participant: nil, p: 0.75),
            participants: participants,
            distribution: distribution
        )
    }

    private func percentile(table: String, participant: String?, p: Double) throws -> Double? {
        guard let database else { return nil }
        let whereClause = participant == nil ? "" : " WHERE participant = ?"
        let bindings: [SQLiteValue] = participant.map { [.text($0)] } ?? []
        let countRow = try database.query("SELECT COUNT(*) AS count FROM \(table)\(whereClause)", bindings: bindings).first ?? [:]
        let count = Int(integer(countRow["count"]) ?? 0)
        guard count > 0 else { return nil }
        let position = p * Double(count - 1)
        let lower = Int(position.rounded(.down))
        let upper = Int(position.rounded(.up))
        let lowerValue = try orderedValue(table: table, participant: participant, offset: lower)
        guard lower != upper else { return lowerValue }
        let upperValue = try orderedValue(table: table, participant: participant, offset: upper)
        guard let lowerValue, let upperValue else { return lowerValue ?? upperValue }
        return lowerValue + (upperValue - lowerValue) * (position - Double(lower))
    }

    private func orderedValue(table: String, participant: String?, offset: Int) throws -> Double? {
        guard let database else { return nil }
        if let participant {
            let row = try database.query(
                "SELECT value FROM \(table) WHERE participant = ? ORDER BY value LIMIT 1 OFFSET ?",
                bindings: [.text(participant), .integer(Int64(offset))]
            ).first
            return row.flatMap { double($0["value"]) }
        }
        let row = try database.query(
            "SELECT value FROM \(table) ORDER BY value LIMIT 1 OFFSET ?",
            bindings: [.integer(Int64(offset))]
        ).first
        return row.flatMap { double($0["value"]) }
    }

    deinit {
        database = nil
        let fm = FileManager.default
        try? fm.removeItem(at: url)
        try? fm.removeItem(at: URL(fileURLWithPath: url.path + "-wal"))
        try? fm.removeItem(at: URL(fileURLWithPath: url.path + "-shm"))
    }

    private func integer(_ value: SQLiteValue?) -> Int64? {
        if case .integer(let value) = value { return value }
        return nil
    }

    private func double(_ value: SQLiteValue?) -> Double? {
        switch value {
        case .real(let value): return value
        case .integer(let value): return Double(value)
        default: return nil
        }
    }
}

private struct StoreSearchMatcher {
    private let regexes: [NSRegularExpression]
    private let requiresAll: Bool
    private let exactPhrase: Bool
    private let ignoreCase: Bool
    private let ignoreDiacritics: Bool

    init?(query: String, options: ChatSearchOptions) {
        ignoreCase = options.ignoreCase
        ignoreDiacritics = options.ignoreDiacritics
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
}
