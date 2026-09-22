import Foundation

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
