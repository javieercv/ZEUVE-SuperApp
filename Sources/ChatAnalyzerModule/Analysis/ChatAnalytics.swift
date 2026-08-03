import Foundation

public struct ChatFilter: Sendable, Equatable {
    public var startDate: Date?
    public var endDate: Date?
    public var participants: Set<String>
    public var platforms: Set<ChatPlatform>
    public var contentTypes: Set<ChatContentType>
    public var weekdays: Set<Int>
    public var startHour: Int?
    public var endHour: Int?

    public init(startDate: Date? = nil, endDate: Date? = nil, participants: Set<String> = [], platforms: Set<ChatPlatform> = [], contentTypes: Set<ChatContentType> = [], weekdays: Set<Int> = [], startHour: Int? = nil, endHour: Int? = nil) {
        self.startDate = startDate; self.endDate = endDate; self.participants = participants
        self.platforms = platforms; self.contentTypes = contentTypes; self.weekdays = weekdays
        self.startHour = startHour; self.endHour = endHour
    }

    public var activeCount: Int {
        [startDate != nil || endDate != nil, !participants.isEmpty, !platforms.isEmpty, !contentTypes.isEmpty, !weekdays.isEmpty, startHour != nil || endHour != nil].filter { $0 }.count
    }

    public func includes(_ message: NormalizedMessage, calendar: Calendar = ChatAnalytics.calendar) -> Bool {
        if let startDate, message.timestamp < startDate { return false }
        if let endDate, message.timestamp > endDate { return false }
        if !participants.isEmpty && !participants.contains(message.author) { return false }
        if !platforms.isEmpty && !platforms.contains(message.platform) { return false }
        if !contentTypes.isEmpty && !contentTypes.contains(message.contentType) { return false }
        let needsWeekday = !weekdays.isEmpty
        let needsHour = startHour != nil || endHour != nil
        guard needsWeekday || needsHour else { return true }
        let components = calendar.dateComponents([.weekday, .hour], from: message.timestamp)
        if needsWeekday, let weekday = components.weekday, !weekdays.contains(weekday) { return false }
        if let startHour, let endHour, let hour = components.hour {
            if startHour <= endHour {
                if hour < startHour || hour > endHour { return false }
            } else if hour < startHour && hour > endHour { return false }
        } else if let startHour, let hour = components.hour, hour < startHour { return false }
        else if let endHour, let hour = components.hour, hour > endHour { return false }
        return true
    }
}

public enum TimeGranularity: String, Codable, CaseIterable, Sendable, Identifiable {
    case day, week, month, year
    public var id: String { rawValue }
    public var displayName: String {
        switch self { case .day: return "Día"; case .week: return "Semana"; case .month: return "Mes"; case .year: return "Año" }
    }
}

public struct ChatSummaryStatistics: Sendable, Equatable {
    public let totalMessages: Int
    public let includedMessages: Int
    public let participants: Int
    public let activeDays: Int
    public let firstMessage: Date?
    public let lastMessage: Date?
    public let mostActiveDay: Date?
    public let mostActiveHour: Int?
    public let mostActiveWeekday: Int?
    public let whatsappMessages: Int
    public let instagramMessages: Int
    public let averagePerActiveDay: Double
    public let contentCounts: [ChatContentType: Int]
}

public struct TimeSeriesPoint: Sendable, Equatable, Identifiable {
    public let date: Date
    public let platform: ChatPlatform?
    public let count: Int
    public var id: String { "\(date.timeIntervalSince1970)-\(platform?.rawValue ?? "total")" }
}

public struct ParticipantStatistics: Sendable, Equatable, Identifiable {
    public let name: String
    public let messages: Int
    public let percentage: Double
    public let words: Int
    public let averageWords: Double
    public let medianWords: Double
    public let averageLength: Double
    public let activeDays: Int
    public let messagesPerActiveDay: Double
    public let firstMessage: Date?
    public let lastMessage: Date?
    public let platforms: Set<ChatPlatform>
    public let questions: Int
    public let links: Int
    public let multimedia: Int
    public let uppercaseMessages: Int
    public let emojis: Int
    public let contentCounts: [ChatContentType: Int]
    public var id: String { name }
}

public struct FrequencyItem: Sendable, Equatable, Identifiable {
    public let value: String
    public let count: Int
    public var id: String { value }
}

public struct HeatmapCell: Sendable, Equatable, Identifiable {
    public let weekday: Int
    public let hour: Int
    public let count: Int
    public var id: String { "\(weekday)-\(hour)" }
}

public struct ChatConversation: Sendable, Equatable, Identifiable {
    public let id: Int
    public let start: Date
    public let end: Date
    public let messages: [NormalizedMessage]
    public let participants: Set<String>
    public let initiator: String
    public let lastParticipant: String
    public var duration: TimeInterval { end.timeIntervalSince(start) }
    public var platforms: Set<ChatPlatform> { Set(messages.map(\.platform)) }
    public var isSingleParticipant: Bool { participants.count == 1 }
}

public struct ConversationStatistics: Sendable, Equatable {
    public let conversations: [ChatConversation]
    public let averageDuration: TimeInterval
    public let medianDuration: TimeInterval
    public let averageMessages: Double
    public let singleParticipantCount: Int
    public let unansweredCount: Int
}

public struct ResponseSample: Sendable, Equatable, Identifiable {
    public let id: String
    public let participant: String
    public let previousParticipant: String
    public let delay: TimeInterval
    public let timestamp: Date
}

public struct ResponseStatistics: Sendable, Equatable {
    public let samples: [ResponseSample]
    public let average: TimeInterval?
    public let median: TimeInterval?
    public let fastest: TimeInterval?
    public let slowest: TimeInterval?
    public let percentile25: TimeInterval?
    public let percentile75: TimeInterval?
}

public enum SearchMode: String, CaseIterable, Sendable, Identifiable {
    case exactPhrase, allWords, anyWord
    public var id: String { rawValue }
    public var displayName: String {
        switch self { case .exactPhrase: return "Frase exacta"; case .allWords: return "Todas las palabras"; case .anyWord: return "Cualquiera de las palabras" }
    }
}

public struct ChatSearchOptions: Sendable, Equatable {
    public var query = ""
    public var mode: SearchMode = .exactPhrase
    public var ignoreCase = true
    public var wholeWords = false
    public var ignoreDiacritics = true
    public var contextMessages = 1
    public var pageSize = 25
    public var page = 0
    public var maximumContextGap: TimeInterval = 6 * 3_600
    public init() {}
}

public struct ChatSearchMatch: Sendable, Equatable, Identifiable {
    public let message: NormalizedMessage
    public let occurrenceCount: Int
    public let before: [NormalizedMessage]
    public let after: [NormalizedMessage]
    public var id: String { message.id }
}

public struct ChatSearchResult: Sendable, Equatable {
    public let totalMessages: Int
    public let totalOccurrences: Int
    public let matches: [ChatSearchMatch]
    public let participantCounts: [String: Int]
    public let platformCounts: [ChatPlatform: Int]
}

public enum ChatAnalytics {
    public static let calendar: Calendar = {
        var value = Calendar(identifier: .gregorian)
        value.locale = Locale(identifier: "es_ES")
        value.timeZone = TimeZone(identifier: "Europe/Madrid") ?? .current
        return value
    }()

    public static func filtered(
        _ messages: [NormalizedMessage],
        by filter: ChatFilter,
        cancellation: @Sendable () -> Bool = { false }
    ) -> [NormalizedMessage] {
        guard filter.activeCount > 0 else { return messages }
        let calendar = self.calendar
        var result: [NormalizedMessage] = []
        result.reserveCapacity(messages.count)
        for (index, message) in messages.enumerated() {
            if index.isMultiple(of: 1_024), cancellation() { return [] }
            if filter.includes(message, calendar: calendar) { result.append(message) }
        }
        return result
    }

    public static func applyingIdentityMap(
        _ identityMap: [String: String],
        to messages: [NormalizedMessage],
        cancellation: @Sendable () -> Bool = { false }
    ) -> [NormalizedMessage] {
        guard !identityMap.isEmpty else { return messages }
        var result: [NormalizedMessage] = []
        result.reserveCapacity(messages.count)
        for (index, message) in messages.enumerated() {
            if index.isMultiple(of: 1_024), cancellation() { return [] }
            guard let merged = identityMap[message.originalAuthor], merged != message.author else {
                result.append(message)
                continue
            }
            result.append(NormalizedMessage(
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
            ))
        }
        return result
    }

    public static func participantNames(_ messages: [NormalizedMessage]) -> [String] {
        var counts: [String: Int] = [:]
        for message in messages where !message.isSystem {
            counts[message.author, default: 0] += 1
        }
        return counts.keys.sorted {
            let left = counts[$0, default: 0]
            let right = counts[$1, default: 0]
            return left == right ? $0 < $1 : left > right
        }
    }

    public static func coreSnapshot(
        messages baseMessages: [NormalizedMessage],
        identityMap: [String: String],
        filter: ChatFilter,
        cancellation: @Sendable () -> Bool = { false }
    ) -> ChatCoreAnalyticsSnapshot {
        let messages = applyingIdentityMap(identityMap, to: baseMessages, cancellation: cancellation)
        guard !cancellation() else { return .empty }
        let filteredMessages = filtered(messages, by: filter, cancellation: cancellation)
        return ChatCoreAnalyticsSnapshot(
            messages: messages,
            filteredMessages: filteredMessages,
            participantNames: participantNames(messages),
            summary: summary(all: messages, included: filteredMessages, cancellation: cancellation)
        )
    }

    public static func summary(
        all: [NormalizedMessage],
        included: [NormalizedMessage],
        cancellation: @Sendable () -> Bool = { false }
    ) -> ChatSummaryStatistics {
        let calendar = self.calendar
        var dayCounts: [Date: Int] = [:]
        var hourCounts = Array(repeating: 0, count: 24)
        var weekdayCounts = Array(repeating: 0, count: 8)
        var participants: Set<String> = []
        var contentCounts: [ChatContentType: Int] = [:]
        var whatsappMessages = 0
        var instagramMessages = 0

        for (index, message) in included.enumerated() {
            if index.isMultiple(of: 1_024), cancellation() { return .empty }
            dayCounts[calendar.startOfDay(for: message.timestamp), default: 0] += 1
            hourCounts[calendar.component(.hour, from: message.timestamp)] += 1
            weekdayCounts[calendar.component(.weekday, from: message.timestamp)] += 1
            if !message.isSystem { participants.insert(message.author) }
            contentCounts[message.contentType, default: 0] += 1
            if message.platform == .whatsapp { whatsappMessages += 1 }
            else { instagramMessages += 1 }
        }

        let mostActiveHour = hourCounts.indices.max { hourCounts[$0] < hourCounts[$1] }
        let mostActiveWeekday = (1...7).max { weekdayCounts[$0] < weekdayCounts[$1] }
        return ChatSummaryStatistics(
            totalMessages: all.count,
            includedMessages: included.count,
            participants: participants.count,
            activeDays: dayCounts.count,
            firstMessage: included.first?.timestamp,
            lastMessage: included.last?.timestamp,
            mostActiveDay: dayCounts.max { $0.value < $1.value }?.key,
            mostActiveHour: mostActiveHour.flatMap { hourCounts[$0] > 0 ? $0 : nil },
            mostActiveWeekday: mostActiveWeekday.flatMap { weekdayCounts[$0] > 0 ? $0 : nil },
            whatsappMessages: whatsappMessages,
            instagramMessages: instagramMessages,
            averagePerActiveDay: dayCounts.isEmpty ? 0 : Double(included.count) / Double(dayCounts.count),
            contentCounts: contentCounts
        )
    }

    public static func timeSeries(
        _ messages: [NormalizedMessage],
        granularity: TimeGranularity,
        cancellation: @Sendable () -> Bool = { false }
    ) -> [TimeSeriesPoint] {
        let calendar = self.calendar
        func bucket(_ date: Date) -> Date {
            switch granularity {
            case .day: return calendar.startOfDay(for: date)
            case .week: return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
            case .month: return calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
            case .year: return calendar.date(from: calendar.dateComponents([.year], from: date)) ?? date
            }
        }

        var counts: [Date: (total: Int, whatsapp: Int, instagram: Int)] = [:]
        counts.reserveCapacity(min(messages.count, 4_096))
        for (index, message) in messages.enumerated() {
            if index.isMultiple(of: 1_024), cancellation() { return [] }
            let date = bucket(message.timestamp)
            var value = counts[date] ?? (0, 0, 0)
            value.total += 1
            if message.platform == .whatsapp { value.whatsapp += 1 }
            else { value.instagram += 1 }
            counts[date] = value
        }

        var result: [TimeSeriesPoint] = []
        result.reserveCapacity(counts.count * 3)
        for (date, value) in counts {
            result.append(.init(date: date, platform: nil, count: value.total))
            if value.whatsapp > 0 { result.append(.init(date: date, platform: .whatsapp, count: value.whatsapp)) }
            if value.instagram > 0 { result.append(.init(date: date, platform: .instagram, count: value.instagram)) }
        }
        return result.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            return ($0.platform?.rawValue ?? "") < ($1.platform?.rawValue ?? "")
        }
    }

    public static func hourly(
        _ messages: [NormalizedMessage],
        cancellation: @Sendable () -> Bool = { false }
    ) -> [Int] {
        let calendar = self.calendar
        var values = Array(repeating: 0, count: 24)
        for (index, message) in messages.enumerated() {
            if index.isMultiple(of: 1_024), cancellation() { return Array(repeating: 0, count: 24) }
            values[calendar.component(.hour, from: message.timestamp)] += 1
        }
        return values
    }

    public static func weekdays(
        _ messages: [NormalizedMessage],
        cancellation: @Sendable () -> Bool = { false }
    ) -> [Int] {
        let calendar = self.calendar
        var values = Array(repeating: 0, count: 7)
        for (index, message) in messages.enumerated() {
            if index.isMultiple(of: 1_024), cancellation() { return Array(repeating: 0, count: 7) }
            values[calendar.component(.weekday, from: message.timestamp) - 1] += 1
        }
        return values
    }

    public static func heatmap(
        _ messages: [NormalizedMessage],
        cancellation: @Sendable () -> Bool = { false }
    ) -> [HeatmapCell] {
        let calendar = self.calendar
        var values = Array(repeating: 0, count: 7 * 24)
        for (index, message) in messages.enumerated() {
            if index.isMultiple(of: 1_024), cancellation() { return [] }
            let weekday = calendar.component(.weekday, from: message.timestamp)
            let hour = calendar.component(.hour, from: message.timestamp)
            values[(weekday - 1) * 24 + hour] += 1
        }
        return (1...7).flatMap { day in
            (0..<24).map { hour in
                .init(weekday: day, hour: hour, count: values[(day - 1) * 24 + hour])
            }
        }
    }

    public static func activitySnapshot(
        _ messages: [NormalizedMessage],
        granularity: TimeGranularity,
        cancellation: @Sendable () -> Bool = { false }
    ) -> ChatActivityAnalyticsSnapshot {
        let calendar = self.calendar
        func bucket(_ date: Date) -> Date {
            switch granularity {
            case .day: return calendar.startOfDay(for: date)
            case .week: return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
            case .month: return calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
            case .year: return calendar.date(from: calendar.dateComponents([.year], from: date)) ?? date
            }
        }

        var temporal: [Date: (total: Int, whatsapp: Int, instagram: Int)] = [:]
        var hourlyValues = Array(repeating: 0, count: 24)
        var weekdayValues = Array(repeating: 0, count: 7)
        var heatmapValues = Array(repeating: 0, count: 7 * 24)
        temporal.reserveCapacity(min(messages.count, 4_096))

        for (index, message) in messages.enumerated() {
            if index.isMultiple(of: 1_024), cancellation() { return .empty }
            let date = bucket(message.timestamp)
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

        let heatmapCells = (1...7).flatMap { day in
            (0..<24).map { hour in
                HeatmapCell(weekday: day, hour: hour, count: heatmapValues[(day - 1) * 24 + hour])
            }
        }
        return ChatActivityAnalyticsSnapshot(
            series: series,
            hourly: hourlyValues,
            weekdays: weekdayValues,
            heatmap: heatmapCells
        )
    }

    public static func participants(
        _ messages: [NormalizedMessage],
        settings: ChatAnalyzerSettings,
        cancellation: @Sendable () -> Bool = { false }
    ) -> [ParticipantStatistics] {
        let personal = messages.filter { !$0.isSystem }
        let grouped = Dictionary(grouping: personal, by: \.author)
        var values: [ParticipantStatistics] = []
        values.reserveCapacity(grouped.count)
        for (name, items) in grouped {
            if cancellation() { return [] }
            values.append(participant(name: name, messages: items, total: personal.count, settings: settings, cancellation: cancellation))
        }
        return values.sorted { $0.messages == $1.messages ? $0.name < $1.name : $0.messages > $1.messages }
    }

    public static func participant(
        name: String,
        messages: [NormalizedMessage],
        total: Int? = nil,
        settings: ChatAnalyzerSettings,
        cancellation: @Sendable () -> Bool = { false }
    ) -> ParticipantStatistics {
        let calendar = self.calendar
        var wordsPerMessage: [Double] = []
        wordsPerMessage.reserveCapacity(messages.count)
        var wordTotal = 0
        var characterTotal = 0
        var days: Set<Date> = []
        var platforms: Set<ChatPlatform> = []
        var questions = 0
        var links = 0
        var multimedia = 0
        var uppercaseMessages = 0
        var emojiTotal = 0
        var contentCounts: [ChatContentType: Int] = [:]

        for (index, message) in messages.enumerated() {
            if index.isMultiple(of: 512), cancellation() { break }
            let wordCount = ChatTokenizer.words(in: message.text, includeStopWords: true).count
            wordsPerMessage.append(Double(wordCount))
            wordTotal += wordCount
            characterTotal += message.text.count
            days.insert(calendar.startOfDay(for: message.timestamp))
            platforms.insert(message.platform)
            if message.text.contains("?") { questions += 1 }
            if ChatContentClassifier.containsURL(message.text) { links += 1 }
            if isMultimedia(message, settings: settings) { multimedia += 1 }
            if isUppercase(message.text) { uppercaseMessages += 1 }
            emojiTotal += ChatTokenizer.emojiCount(in: message.text)
            contentCounts[message.contentType, default: 0] += 1
        }

        let denominator = total ?? messages.count
        return ParticipantStatistics(
            name: name,
            messages: messages.count,
            percentage: denominator == 0 ? 0 : Double(messages.count) / Double(denominator) * 100,
            words: wordTotal,
            averageWords: messages.isEmpty ? 0 : Double(wordTotal) / Double(messages.count),
            medianWords: median(wordsPerMessage),
            averageLength: messages.isEmpty ? 0 : Double(characterTotal) / Double(messages.count),
            activeDays: days.count,
            messagesPerActiveDay: days.isEmpty ? 0 : Double(messages.count) / Double(days.count),
            firstMessage: messages.first?.timestamp,
            lastMessage: messages.last?.timestamp,
            platforms: platforms,
            questions: questions,
            links: links,
            multimedia: multimedia,
            uppercaseMessages: uppercaseMessages,
            emojis: emojiTotal,
            contentCounts: contentCounts
        )
    }

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

    public static func conversations(
        _ messages: [NormalizedMessage],
        threshold: TimeInterval,
        cancellation: @Sendable () -> Bool = { false }
    ) -> ConversationStatistics {
        let sorted = chronologicallyOrdered(messages)
        guard let first = sorted.first else { return .init(conversations: [], averageDuration: 0, medianDuration: 0, averageMessages: 0, singleParticipantCount: 0, unansweredCount: 0) }
        var groups: [[NormalizedMessage]] = [[first]]
        for (index, message) in sorted.dropFirst().enumerated() {
            if index.isMultiple(of: 1_024), cancellation() { return .empty }
            let previous = groups[groups.count - 1].last!
            if message.timestamp.timeIntervalSince(previous.timestamp) > threshold { groups.append([message]) }
            else { groups[groups.count - 1].append(message) }
        }
        let conversations = groups.enumerated().map { index, values in
            ChatConversation(id: index, start: values.first!.timestamp, end: values.last!.timestamp, messages: values, participants: Set(values.filter { !$0.isSystem }.map(\.author)), initiator: values.first(where: { !$0.isSystem })?.author ?? "Sistema", lastParticipant: values.last(where: { !$0.isSystem })?.author ?? "Sistema")
        }
        let durations = conversations.map(\.duration)
        let unanswered = conversations.filter { $0.participants.count <= 1 }.count
        return .init(conversations: conversations, averageDuration: durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count), medianDuration: median(durations), averageMessages: conversations.isEmpty ? 0 : Double(conversations.reduce(0) { $0 + $1.messages.count }) / Double(conversations.count), singleParticipantCount: conversations.filter(\.isSingleParticipant).count, unansweredCount: unanswered)
    }

    public static func responseTimes(
        conversations: [ChatConversation],
        maximumWindow: TimeInterval?,
        cancellation: @Sendable () -> Bool = { false }
    ) -> ResponseStatistics {
        var samples: [ResponseSample] = []
        for (conversationIndex, conversation) in conversations.enumerated() {
            if conversationIndex.isMultiple(of: 128), cancellation() { return .empty }
            let messages = chronologicallyOrdered(conversation.messages.filter { !$0.isSystem })
            guard !messages.isEmpty else { continue }
            var turns: [(author: String, start: Date, end: Date)] = []
            for message in messages {
                if let last = turns.last, last.author == message.author { turns[turns.count - 1].end = message.timestamp }
                else { turns.append((message.author, message.timestamp, message.timestamp)) }
            }
            for index in 1..<turns.count {
                let delay = turns[index].start.timeIntervalSince(turns[index - 1].end)
                guard delay >= 0, maximumWindow.map({ delay <= $0 }) ?? true else { continue }
                samples.append(.init(id: "\(conversation.id)-\(index)", participant: turns[index].author, previousParticipant: turns[index - 1].author, delay: delay, timestamp: turns[index].start))
            }
        }
        let values = samples.map(\.delay).sorted()
        return .init(samples: samples, average: values.isEmpty ? nil : values.reduce(0, +) / Double(values.count), median: values.isEmpty ? nil : median(values), fastest: values.first, slowest: values.last, percentile25: percentile(values, 0.25), percentile75: percentile(values, 0.75))
    }

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

    private static func chronologicallyOrdered(_ messages: [NormalizedMessage]) -> [NormalizedMessage] {
        guard messages.count > 1 else { return messages }
        for index in 1..<messages.count where messages[index].timestamp < messages[index - 1].timestamp {
            return messages.sorted {
                if $0.timestamp != $1.timestamp { return $0.timestamp < $1.timestamp }
                return $0.sourcePosition < $1.sourcePosition
            }
        }
        return messages
    }

    private static func frequency(_ counts: [String: Int], limit: Int) -> [FrequencyItem] {
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

    private static func isUppercase(_ text: String) -> Bool {
        let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        return letters.count >= 2 && letters.allSatisfy { String($0) == String($0).uppercased() }
    }

    private static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted(); let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    private static func percentile(_ values: [Double], _ p: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let position = p * Double(values.count - 1); let lower = Int(position.rounded(.down)); let upper = Int(position.rounded(.up))
        if lower == upper { return values[lower] }
        return values[lower] + (values[upper] - values[lower]) * (position - Double(lower))
    }
}

public enum ChatTokenizer {
    public static let stopWords: Set<String> = ["a", "al", "algo", "como", "con", "de", "del", "el", "ella", "en", "es", "esta", "este", "ha", "la", "las", "lo", "los", "me", "mi", "no", "o", "para", "pero", "por", "que", "se", "si", "sin", "su", "te", "tu", "un", "una", "y", "ya", "the", "and", "of", "to", "in", "is", "it", "you", "for", "on", "with"]
    private static let urlRegex = ChatRegularExpression(#"(?i)\b(?:https?://|www\.)\S+"#)
    private static let wordRegex = ChatRegularExpression(#"[\p{L}\p{M}\p{N}]+(?:['’][\p{L}\p{M}]+)?"#)

    public static func words(in text: String, includeStopWords: Bool) -> [String] {
        let fullRange = NSRange(text.startIndex..., in: text)
        let withoutURLs = urlRegex.value.stringByReplacingMatches(in: text, range: fullRange, withTemplate: " ")
        return wordRegex.value.matches(in: withoutURLs, range: NSRange(withoutURLs.startIndex..., in: withoutURLs)).compactMap { match in
            Range(match.range, in: withoutURLs).map { String(withoutURLs[$0]).lowercased() }
        }.filter { includeStopWords || !stopWords.contains($0) }
    }

    public static func emojis(in text: String) -> [String] {
        text.filter(isEmoji).map(String.init)
    }

    public static func emojiCount(in text: String) -> Int {
        text.lazy.filter(isEmoji).count
    }

    private static func isEmoji(_ character: Character) -> Bool {
        character.unicodeScalars.contains {
            $0.properties.isEmojiPresentation || ($0.properties.isEmoji && $0.value > 0x238C)
        }
    }
}
