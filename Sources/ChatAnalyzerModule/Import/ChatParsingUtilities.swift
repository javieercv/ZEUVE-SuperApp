import Foundation

final class ChatRegularExpression: @unchecked Sendable {
    let value: NSRegularExpression

    init(_ pattern: String) {
        value = try! NSRegularExpression(pattern: pattern)
    }
}

enum ChatStableID {
    static func make(_ components: [String]) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in components.joined(separator: "\u{1F}").utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}

enum ChatTextDecoder {
    static func decode(_ data: Data) -> String? {
        if data.starts(with: [0xEF, 0xBB, 0xBF]) { return String(data: data.dropFirst(3), encoding: .utf8) }
        if let value = String(data: data, encoding: .utf8) { return value }
        if let value = String(data: data, encoding: .utf16) { return value }
        if let value = String(data: data, encoding: .isoLatin1) { return value }
        return nil
    }
}

enum ChatContentClassifier {
    private static let urlRegex = ChatRegularExpression(#"(?i)\b(?:https?://|www\.)\S+"#)
    static func classify(text: String, attachmentName: String? = nil, tagName: String? = nil) -> ChatContentType {
        let lower = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_ES"))
        let tag = tagName?.lowercased() ?? ""
        if let attachmentName, isStickerFilename(attachmentName) { return .sticker }
        if tag == "img" { return .image }
        if tag == "video" { return .video }
        if tag == "audio" { return .audio }
        if lower.contains("mensaje eliminado") || lower.contains("this message was deleted") || lower.contains("contenido no disponible") { return .deleted }
        if lower.contains("sticker omitid") || lower.contains("sticker omitted") { return .sticker }
        if lower.contains("imagen omitid") || lower.contains("image omitted") || lower.contains("foto omitid") { return .image }
        if lower.contains("video omitid") || lower.contains("video omitted") || lower.contains("gif omitid") { return .video }
        if lower.contains("audio omitid") || lower.contains("audio omitted") || lower.contains("nota de voz") { return .audio }
        if lower.contains("documento omitid") || lower.contains("document omitted") { return .document }
        if lower.contains("ubicacion") || lower.contains("location:") { return .location }
        if lower.contains("tarjeta de contacto") || lower.contains("contact card") { return .contact }
        if lower.contains("llamada") || lower.contains("call ended") || lower.contains("missed call") { return .call }
        if lower.contains("reel") && lower.contains("instagram") { return .reel }
        if lower.contains("historia") && lower.contains("instagram") { return .story }
        if lower.contains("publicacion") && lower.contains("instagram") { return .sharedPost }
        if let name = attachmentName { return classify(filename: name, fallbackText: text) }
        if containsURL(text) && text.trimmingCharacters(in: .whitespacesAndNewlines).split(whereSeparator: { $0.isWhitespace }).count <= 2 { return .link }
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .other : .text
    }

    static func classify(filename: String, fallbackText: String = "") -> ChatContentType {
        if isStickerFilename(filename) { return .sticker }
        switch URL(fileURLWithPath: filename).pathExtension.lowercased() {
        case "jpg", "jpeg", "png", "gif", "webp", "heic", "heif", "bmp", "tif", "tiff": return .image
        case "mov", "mp4", "m4v", "avi", "mkv", "webm", "3gp":
            if fallbackText.lowercased().contains("audio") || fallbackText.lowercased().contains("voice") { return .audio }
            return .video
        case "opus", "ogg", "mp3", "m4a", "aac", "wav", "flac", "aiff": return .audio
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "zip", "rar", "7z": return .document
        case "vcf": return .contact
        default: return .other
        }
    }

    private static func isStickerFilename(_ filename: String) -> Bool {
        let name = URL(fileURLWithPath: filename).lastPathComponent.uppercased()
        return name.contains("-STICKER-") || name.hasPrefix("STICKER-") || name.hasSuffix("-STICKER.WEBP")
    }

    static func containsURL(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        return urlRegex.value.firstMatch(in: text, range: range) != nil
    }
}

extension String {
    var chatHTMLDecoded: String {
        var value = self
        let entities = ["&nbsp;": " ", "&#160;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&apos;": "'"]
        for (entity, replacement) in entities { value = value.replacingOccurrences(of: entity, with: replacement) }
        let pattern = #"&#(?:x([0-9A-Fa-f]+)|([0-9]+));"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: value, range: NSRange(value.startIndex..., in: value)).reversed()
            for match in matches {
                let ns = value as NSString
                let hex = match.range(at: 1).location != NSNotFound ? ns.substring(with: match.range(at: 1)) : nil
                let dec = match.range(at: 2).location != NSNotFound ? ns.substring(with: match.range(at: 2)) : nil
                let scalar = hex.flatMap { UInt32($0, radix: 16) }.flatMap(UnicodeScalar.init) ?? dec.flatMap { UInt32($0) }.flatMap(UnicodeScalar.init)
                if let scalar, let range = Range(match.range, in: value) { value.replaceSubrange(range, with: String(Character(scalar))) }
            }
        }
        return value
    }
}
