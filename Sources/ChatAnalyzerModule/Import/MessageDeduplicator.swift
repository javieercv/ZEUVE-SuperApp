import Foundation

public enum MessageDeduplicator {
    public static func deduplicate(_ messages: [NormalizedMessage]) -> (messages: [NormalizedMessage], removed: Int) {
        var exact = Set<String>()
        var conservative = Set<String>()
        var output: [NormalizedMessage] = []
        for message in messages {
            if !exact.insert(message.id).inserted { continue }
            let key = ChatStableID.make([
                message.platform.rawValue, message.conversationID, message.author,
                String(message.timestamp.timeIntervalSince1970), message.text, message.contentType.rawValue,
                message.attachment?.path ?? "", message.sourceFile, String(message.sourcePosition)
            ])
            guard conservative.insert(key).inserted else { continue }
            output.append(message)
        }
        return (output, messages.count - output.count)
    }
}
