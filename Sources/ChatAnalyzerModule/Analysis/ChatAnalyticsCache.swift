import Foundation

public struct ChatCoreAnalyticsSnapshot: Sendable, Equatable {
    public let messages: [NormalizedMessage]
    public let filteredMessages: [NormalizedMessage]
    public let participantNames: [String]
    public let summary: ChatSummaryStatistics

    public init(
        messages: [NormalizedMessage],
        filteredMessages: [NormalizedMessage],
        participantNames: [String],
        summary: ChatSummaryStatistics
    ) {
        self.messages = messages
        self.filteredMessages = filteredMessages
        self.participantNames = participantNames
        self.summary = summary
    }

    public static let empty = ChatCoreAnalyticsSnapshot(
        messages: [],
        filteredMessages: [],
        participantNames: [],
        summary: .empty
    )
}

public struct ChatActivityAnalyticsSnapshot: Sendable, Equatable {
    public let series: [TimeSeriesPoint]
    public let hourly: [Int]
    public let weekdays: [Int]
    public let heatmap: [HeatmapCell]

    public init(series: [TimeSeriesPoint], hourly: [Int], weekdays: [Int], heatmap: [HeatmapCell]) {
        self.series = series
        self.hourly = hourly
        self.weekdays = weekdays
        self.heatmap = heatmap
    }

    public static let empty = ChatActivityAnalyticsSnapshot(
        series: [],
        hourly: Array(repeating: 0, count: 24),
        weekdays: Array(repeating: 0, count: 7),
        heatmap: []
    )
}

public struct ParticipantDetailAnalyticsSnapshot: Sendable, Equatable {
    public let name: String
    public let messages: [NormalizedMessage]
    public let words: [FrequencyItem]
    public let bigrams: [FrequencyItem]
    public let emojis: [FrequencyItem]
    public let monthlySeries: [TimeSeriesPoint]
    public let hourly: [Int]
    public let weekdays: [Int]
    public let platformCounts: [ChatPlatform: Int]
    public let longestMessage: NormalizedMessage?

    public init(
        name: String,
        messages: [NormalizedMessage],
        words: [FrequencyItem],
        bigrams: [FrequencyItem],
        emojis: [FrequencyItem],
        monthlySeries: [TimeSeriesPoint],
        hourly: [Int],
        weekdays: [Int],
        platformCounts: [ChatPlatform: Int],
        longestMessage: NormalizedMessage?
    ) {
        self.name = name
        self.messages = messages
        self.words = words
        self.bigrams = bigrams
        self.emojis = emojis
        self.monthlySeries = monthlySeries
        self.hourly = hourly
        self.weekdays = weekdays
        self.platformCounts = platformCounts
        self.longestMessage = longestMessage
    }
}

public struct ChatParticipantsAnalyticsSnapshot: Sendable, Equatable {
    public let statistics: [ParticipantStatistics]
    public let details: [String: ParticipantDetailAnalyticsSnapshot]

    public init(statistics: [ParticipantStatistics], details: [String: ParticipantDetailAnalyticsSnapshot] = [:]) {
        self.statistics = statistics
        self.details = details
    }

    public static let empty = ChatParticipantsAnalyticsSnapshot(statistics: [])
}

public struct ParticipantFrequencyAnalyticsSnapshot: Sendable, Equatable, Identifiable {
    public let name: String
    public let words: [FrequencyItem]
    public let emojis: [FrequencyItem]
    public var id: String { name }

    public init(name: String, words: [FrequencyItem], emojis: [FrequencyItem]) {
        self.name = name
        self.words = words
        self.emojis = emojis
    }
}

public struct ChatWordsAnalyticsSnapshot: Sendable, Equatable {
    public let words: [FrequencyItem]
    public let bigrams: [FrequencyItem]
    public let emojis: [FrequencyItem]
    public let participants: [ParticipantFrequencyAnalyticsSnapshot]
    public let contentCounts: [ChatContentType: Int]

    public init(
        words: [FrequencyItem],
        bigrams: [FrequencyItem],
        emojis: [FrequencyItem],
        participants: [ParticipantFrequencyAnalyticsSnapshot],
        contentCounts: [ChatContentType: Int]
    ) {
        self.words = words
        self.bigrams = bigrams
        self.emojis = emojis
        self.participants = participants
        self.contentCounts = contentCounts
    }

    public static let empty = ChatWordsAnalyticsSnapshot(
        words: [],
        bigrams: [],
        emojis: [],
        participants: [],
        contentCounts: [:]
    )
}

public struct ChatConversationAnalyticsSnapshot: Sendable, Equatable {
    public let conversations: ConversationStatistics
    public let responses: ResponseStatistics
    public let topConversationsByMessages: [ChatConversation]
    public let topConversationsByDuration: [ChatConversation]

    public init(
        conversations: ConversationStatistics,
        responses: ResponseStatistics,
        topConversationsByMessages: [ChatConversation]? = nil,
        topConversationsByDuration: [ChatConversation]? = nil
    ) {
        self.conversations = conversations
        self.responses = responses
        self.topConversationsByMessages = topConversationsByMessages
            ?? Array(conversations.conversations.sorted { $0.messages.count > $1.messages.count }.prefix(10))
        self.topConversationsByDuration = topConversationsByDuration
            ?? Array(conversations.conversations.sorted { $0.duration > $1.duration }.prefix(10))
    }

    public static let empty = ChatConversationAnalyticsSnapshot(
        conversations: .empty,
        responses: .empty,
        topConversationsByMessages: [],
        topConversationsByDuration: []
    )
}

public struct ParticipantComparisonAnalyticsSnapshot: Sendable, Equatable, Identifiable {
    public let name: String
    public let statistics: ParticipantStatistics
    public let initiatedConversations: Int
    public let unansweredConversations: Int
    public let finishedConversations: Int
    public let responseAverage: TimeInterval?
    public let responseMedian: TimeInterval?
    public let platformCounts: [ChatPlatform: Int]
    public let series: [TimeSeriesPoint]
    public let hourly: [Int]
    public let weekdays: [Int]
    public var id: String { name }

    public init(
        name: String,
        statistics: ParticipantStatistics,
        initiatedConversations: Int,
        unansweredConversations: Int,
        finishedConversations: Int,
        responseAverage: TimeInterval?,
        responseMedian: TimeInterval?,
        platformCounts: [ChatPlatform: Int],
        series: [TimeSeriesPoint],
        hourly: [Int],
        weekdays: [Int]
    ) {
        self.name = name
        self.statistics = statistics
        self.initiatedConversations = initiatedConversations
        self.unansweredConversations = unansweredConversations
        self.finishedConversations = finishedConversations
        self.responseAverage = responseAverage
        self.responseMedian = responseMedian
        self.platformCounts = platformCounts
        self.series = series
        self.hourly = hourly
        self.weekdays = weekdays
    }
}

public struct ChatComparisonAnalyticsSnapshot: Sendable, Equatable {
    public let participants: [String: ParticipantComparisonAnalyticsSnapshot]

    public init(participants: [String: ParticipantComparisonAnalyticsSnapshot]) {
        self.participants = participants
    }

    public static let empty = ChatComparisonAnalyticsSnapshot(participants: [:])
}

public struct ChatSearchHit: Sendable, Equatable {
    public let messageIndex: Int
    public let occurrenceCount: Int

    public init(messageIndex: Int, occurrenceCount: Int) {
        self.messageIndex = messageIndex
        self.occurrenceCount = occurrenceCount
    }
}

public struct ChatSearchIndex: Sendable, Equatable {
    public let hits: [ChatSearchHit]
    public let totalOccurrences: Int
    public let participantCounts: [String: Int]
    public let platformCounts: [ChatPlatform: Int]

    public init(
        hits: [ChatSearchHit],
        totalOccurrences: Int,
        participantCounts: [String: Int],
        platformCounts: [ChatPlatform: Int]
    ) {
        self.hits = hits
        self.totalOccurrences = totalOccurrences
        self.participantCounts = participantCounts
        self.platformCounts = platformCounts
    }

    public static let empty = ChatSearchIndex(hits: [], totalOccurrences: 0, participantCounts: [:], platformCounts: [:])
}

public extension ChatSummaryStatistics {
    static let empty = ChatSummaryStatistics(
        totalMessages: 0,
        includedMessages: 0,
        participants: 0,
        activeDays: 0,
        firstMessage: nil,
        lastMessage: nil,
        mostActiveDay: nil,
        mostActiveHour: nil,
        mostActiveWeekday: nil,
        whatsappMessages: 0,
        instagramMessages: 0,
        averagePerActiveDay: 0,
        contentCounts: [:]
    )
}

public extension ConversationStatistics {
    static let empty = ConversationStatistics(
        conversations: [],
        averageDuration: 0,
        medianDuration: 0,
        averageMessages: 0,
        singleParticipantCount: 0,
        unansweredCount: 0
    )
}

public extension ResponseStatistics {
    static let empty = ResponseStatistics(
        samples: [],
        average: nil,
        median: nil,
        fastest: nil,
        slowest: nil,
        percentile25: nil,
        percentile75: nil
    )
}

public extension ChatSearchResult {
    static let empty = ChatSearchResult(
        totalMessages: 0,
        totalOccurrences: 0,
        matches: [],
        participantCounts: [:],
        platformCounts: [:]
    )
}
