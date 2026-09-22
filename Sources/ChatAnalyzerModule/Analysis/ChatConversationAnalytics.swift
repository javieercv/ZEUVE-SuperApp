import Foundation

extension ChatAnalytics {
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
}
