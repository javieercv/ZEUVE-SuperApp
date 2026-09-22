import Foundation

extension ChatAnalytics {
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
}
