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
    public let messageCount: Int
    public let participants: Set<String>
    public let initiator: String
    public let lastParticipant: String
    private let compactPlatforms: Set<ChatPlatform>?
    public var duration: TimeInterval { end.timeIntervalSince(start) }
    public var platforms: Set<ChatPlatform> { compactPlatforms ?? Set(messages.map(\.platform)) }
    public var isSingleParticipant: Bool { participants.count == 1 }

    public init(
        id: Int,
        start: Date,
        end: Date,
        messages: [NormalizedMessage],
        participants: Set<String>,
        initiator: String,
        lastParticipant: String
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.messages = messages
        self.messageCount = messages.count
        self.participants = participants
        self.initiator = initiator
        self.lastParticipant = lastParticipant
        self.compactPlatforms = nil
    }

    /// Representación compacta usada por las analíticas respaldadas por SQLite. Solo se
    /// conservan en memoria las conversaciones que la UI necesita mostrar (por ejemplo, top 10).
    public init(
        id: Int,
        start: Date,
        end: Date,
        messageCount: Int,
        participants: Set<String>,
        initiator: String,
        lastParticipant: String,
        platforms: Set<ChatPlatform>
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.messages = []
        self.messageCount = messageCount
        self.participants = participants
        self.initiator = initiator
        self.lastParticipant = lastParticipant
        self.compactPlatforms = platforms
    }
}

public struct ConversationParticipantStatistics: Sendable, Equatable {
    public let initiated: Int
    public let finished: Int
    public let unanswered: Int
    public let initiatedAverageDuration: TimeInterval?
    public let initiatedAverageMessages: Double?

    public init(
        initiated: Int,
        finished: Int,
        unanswered: Int,
        initiatedAverageDuration: TimeInterval?,
        initiatedAverageMessages: Double?
    ) {
        self.initiated = initiated
        self.finished = finished
        self.unanswered = unanswered
        self.initiatedAverageDuration = initiatedAverageDuration
        self.initiatedAverageMessages = initiatedAverageMessages
    }
}

public struct ConversationStatistics: Sendable, Equatable {
    public let conversations: [ChatConversation]
    public let totalCount: Int
    public let averageDuration: TimeInterval
    public let medianDuration: TimeInterval
    public let averageMessages: Double
    public let singleParticipantCount: Int
    public let unansweredCount: Int
    public let maximumMessageCount: Int
    public let maximumDuration: TimeInterval?
    public let startHourCounts: [Int]
    public let startWeekdayCounts: [Int]
    public let participantStatistics: [String: ConversationParticipantStatistics]

    public init(
        conversations: [ChatConversation],
        averageDuration: TimeInterval,
        medianDuration: TimeInterval,
        averageMessages: Double,
        singleParticipantCount: Int,
        unansweredCount: Int
    ) {
        self.conversations = conversations
        self.totalCount = conversations.count
        self.averageDuration = averageDuration
        self.medianDuration = medianDuration
        self.averageMessages = averageMessages
        self.singleParticipantCount = singleParticipantCount
        self.unansweredCount = unansweredCount
        self.maximumMessageCount = conversations.map(\.messageCount).max() ?? 0
        self.maximumDuration = conversations.map(\.duration).max()

        var hours = Array(repeating: 0, count: 24)
        var weekdays = Array(repeating: 0, count: 7)
        var participantValues: [String: (initiated: Int, finished: Int, unanswered: Int, duration: Double, messages: Int)] = [:]
        let calendar = ChatAnalytics.calendar
        for conversation in conversations {
            hours[calendar.component(.hour, from: conversation.start)] += 1
            weekdays[calendar.component(.weekday, from: conversation.start) - 1] += 1
            var initiator = participantValues[conversation.initiator] ?? (0, 0, 0, 0, 0)
            initiator.initiated += 1
            if conversation.participants.count <= 1 { initiator.unanswered += 1 }
            initiator.duration += conversation.duration
            initiator.messages += conversation.messageCount
            participantValues[conversation.initiator] = initiator

            var finisher = participantValues[conversation.lastParticipant] ?? (0, 0, 0, 0, 0)
            finisher.finished += 1
            participantValues[conversation.lastParticipant] = finisher
        }
        self.startHourCounts = hours
        self.startWeekdayCounts = weekdays
        self.participantStatistics = participantValues.mapValues { value in
            ConversationParticipantStatistics(
                initiated: value.initiated,
                finished: value.finished,
                unanswered: value.unanswered,
                initiatedAverageDuration: value.initiated == 0 ? nil : value.duration / Double(value.initiated),
                initiatedAverageMessages: value.initiated == 0 ? nil : Double(value.messages) / Double(value.initiated)
            )
        }
    }

    public init(
        conversations: [ChatConversation] = [],
        totalCount: Int,
        averageDuration: TimeInterval,
        medianDuration: TimeInterval,
        averageMessages: Double,
        singleParticipantCount: Int,
        unansweredCount: Int,
        maximumMessageCount: Int,
        maximumDuration: TimeInterval?,
        startHourCounts: [Int],
        startWeekdayCounts: [Int],
        participantStatistics: [String: ConversationParticipantStatistics]
    ) {
        self.conversations = conversations
        self.totalCount = totalCount
        self.averageDuration = averageDuration
        self.medianDuration = medianDuration
        self.averageMessages = averageMessages
        self.singleParticipantCount = singleParticipantCount
        self.unansweredCount = unansweredCount
        self.maximumMessageCount = maximumMessageCount
        self.maximumDuration = maximumDuration
        self.startHourCounts = startHourCounts
        self.startWeekdayCounts = startWeekdayCounts
        self.participantStatistics = participantStatistics
    }
}

public struct ResponseSample: Sendable, Equatable, Identifiable {
    public let id: String
    public let participant: String
    public let previousParticipant: String
    public let delay: TimeInterval
    public let timestamp: Date
}

public struct ResponseParticipantStatistics: Sendable, Equatable {
    public let count: Int
    public let average: TimeInterval?
    public let median: TimeInterval?
    public let fastest: TimeInterval?
    public let slowest: TimeInterval?
    public let underFiveMinutes: Int
    public let underOneHour: Int
    public let underTwentyFourHours: Int

    public init(
        count: Int,
        average: TimeInterval?,
        median: TimeInterval?,
        fastest: TimeInterval?,
        slowest: TimeInterval?,
        underFiveMinutes: Int,
        underOneHour: Int,
        underTwentyFourHours: Int
    ) {
        self.count = count
        self.average = average
        self.median = median
        self.fastest = fastest
        self.slowest = slowest
        self.underFiveMinutes = underFiveMinutes
        self.underOneHour = underOneHour
        self.underTwentyFourHours = underTwentyFourHours
    }
}

public struct ResponseDistributionItem: Sendable, Equatable, Identifiable {
    public let label: String
    public let count: Int
    public var id: String { label }
    public init(label: String, count: Int) { self.label = label; self.count = count }
}

public struct ResponseStatistics: Sendable, Equatable {
    public let samples: [ResponseSample]
    public let sampleCount: Int
    public let average: TimeInterval?
    public let median: TimeInterval?
    public let fastest: TimeInterval?
    public let slowest: TimeInterval?
    public let percentile25: TimeInterval?
    public let percentile75: TimeInterval?
    public let participants: [String: ResponseParticipantStatistics]
    public let distribution: [ResponseDistributionItem]

    public init(
        samples: [ResponseSample],
        average: TimeInterval?,
        median: TimeInterval?,
        fastest: TimeInterval?,
        slowest: TimeInterval?,
        percentile25: TimeInterval?,
        percentile75: TimeInterval?
    ) {
        self.samples = samples
        self.sampleCount = samples.count
        self.average = average
        self.median = median
        self.fastest = fastest
        self.slowest = slowest
        self.percentile25 = percentile25
        self.percentile75 = percentile75

        let grouped = Dictionary(grouping: samples, by: \.participant)
        self.participants = grouped.mapValues { values in
            let delays = values.map(\.delay).sorted()
            return ResponseParticipantStatistics(
                count: delays.count,
                average: delays.isEmpty ? nil : delays.reduce(0, +) / Double(delays.count),
                median: delays.isEmpty ? nil : ChatAnalytics.median(delays),
                fastest: delays.first,
                slowest: delays.last,
                underFiveMinutes: delays.lazy.filter { $0 < 300 }.count,
                underOneHour: delays.lazy.filter { $0 < 3_600 }.count,
                underTwentyFourHours: delays.lazy.filter { $0 < 86_400 }.count
            )
        }
        self.distribution = Self.makeDistribution(samples.lazy.map(\.delay))
    }

    public init(
        samples: [ResponseSample] = [],
        sampleCount: Int,
        average: TimeInterval?,
        median: TimeInterval?,
        fastest: TimeInterval?,
        slowest: TimeInterval?,
        percentile25: TimeInterval?,
        percentile75: TimeInterval?,
        participants: [String: ResponseParticipantStatistics],
        distribution: [ResponseDistributionItem]
    ) {
        self.samples = samples
        self.sampleCount = sampleCount
        self.average = average
        self.median = median
        self.fastest = fastest
        self.slowest = slowest
        self.percentile25 = percentile25
        self.percentile75 = percentile75
        self.participants = participants
        self.distribution = distribution
    }

    private static func makeDistribution<S: Sequence>(_ delays: S) -> [ResponseDistributionItem] where S.Element == TimeInterval {
        let limits: [(String, TimeInterval)] = [
            ("<1 min", 60),
            ("<5 min", 300),
            ("<15 min", 900),
            ("<1 h", 3_600),
            ("<6 h", 21_600),
            ("<24 h", 86_400),
            ("≥24 h", .infinity),
        ]
        var counts = Array(repeating: 0, count: limits.count)
        for delay in delays {
            if let index = limits.firstIndex(where: { delay < $0.1 }) { counts[index] += 1 }
        }
        return limits.enumerated().map { index, item in
            ResponseDistributionItem(label: item.0, count: counts[index])
        }
    }
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
