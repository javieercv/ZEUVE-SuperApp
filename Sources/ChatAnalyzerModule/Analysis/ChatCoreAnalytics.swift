import Foundation

extension ChatAnalytics {
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
}
