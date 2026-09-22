import Foundation

final class ChatHTMLNode {
    let tag: String
    let attributes: [String: String]
    weak var parent: ChatHTMLNode?
    var children: [ChatHTMLNode] = []
    var ownText: [String] = []

    init(tag: String, attributes: [String: String] = [:]) {
        self.tag = tag.lowercased(); self.attributes = attributes
    }

    var classNames: String { attributes["class"]?.lowercased() ?? "" }
    var textContent: String {
        (ownText + children.map(\.textContent)).joined(separator: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func descendants(where predicate: (ChatHTMLNode) -> Bool) -> [ChatHTMLNode] {
        var result: [ChatHTMLNode] = []
        for child in children {
            if predicate(child) { result.append(child) }
            result.append(contentsOf: child.descendants(where: predicate))
        }
        return result
    }
}

struct ChatHTMLDocument {
    let root: ChatHTMLNode
    let baseHref: String?

    static func parse(_ html: String) -> ChatHTMLDocument {
        let root = ChatHTMLNode(tag: "document")
        var stack: [ChatHTMLNode] = [root]
        let voidTags: Set<String> = ["area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"]
        var cursor = html.startIndex
        var ignoringTag: String?

        while cursor < html.endIndex {
            guard let open = html[cursor...].firstIndex(of: "<") else {
                if ignoringTag == nil { appendText(String(html[cursor...]), to: stack.last) }
                break
            }
            if open > cursor, ignoringTag == nil { appendText(String(html[cursor..<open]), to: stack.last) }
            if html[open...].hasPrefix("<!--"), let close = html[open...].range(of: "-->")?.upperBound {
                cursor = close; continue
            }
            guard let close = findTagEnd(in: html, from: html.index(after: open)) else { break }
            let raw = String(html[html.index(after: open)..<close]).trimmingCharacters(in: .whitespacesAndNewlines)
            cursor = html.index(after: close)
            if raw.hasPrefix("!") || raw.hasPrefix("?") { continue }
            if raw.hasPrefix("/") {
                let tag = raw.dropFirst().split(whereSeparator: { $0.isWhitespace || $0 == ">" }).first.map { String($0).lowercased() } ?? ""
                if ignoringTag == tag { ignoringTag = nil }
                if let index = stack.lastIndex(where: { $0.tag == tag }), index > 0 { stack.removeSubrange(index...) }
                continue
            }
            let selfClosing = raw.hasSuffix("/")
            let parsed = parseTag(raw)
            guard !parsed.name.isEmpty else { continue }
            let node = ChatHTMLNode(tag: parsed.name, attributes: parsed.attributes)
            node.parent = stack.last
            stack.last?.children.append(node)
            if parsed.name == "script" || parsed.name == "style" { ignoringTag = parsed.name }
            if !selfClosing && !voidTags.contains(parsed.name) { stack.append(node) }
        }
        let base = root.descendants { $0.tag == "base" }.first?.attributes["href"]
        return ChatHTMLDocument(root: root, baseHref: base)
    }

    private static func appendText(_ raw: String, to node: ChatHTMLNode?) {
        let text = raw.chatHTMLDecoded
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { node?.ownText.append(text) }
    }

    private static func findTagEnd(in html: String, from start: String.Index) -> String.Index? {
        var quote: Character?
        var index = start
        while index < html.endIndex {
            let character = html[index]
            if character == "\"" || character == "'" {
                if quote == character { quote = nil } else if quote == nil { quote = character }
            } else if character == ">" && quote == nil { return index }
            index = html.index(after: index)
        }
        return nil
    }

    private static func parseTag(_ raw: String) -> (name: String, attributes: [String: String]) {
        let trimmed = raw.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard let firstSpace = trimmed.firstIndex(where: \.isWhitespace) else { return (trimmed.lowercased(), [:]) }
        let name = String(trimmed[..<firstSpace]).lowercased()
        let rest = String(trimmed[firstSpace...])
        let pattern = #"([A-Za-z_:][-A-Za-z0-9_:.]*)(?:\s*=\s*(?:\"([^\"]*)\"|'([^']*)'|([^\s\"'=<>`]+)))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return (name, [:]) }
        var attributes: [String: String] = [:]
        for match in regex.matches(in: rest, range: NSRange(rest.startIndex..., in: rest)) {
            guard let keyRange = Range(match.range(at: 1), in: rest) else { continue }
            let key = String(rest[keyRange]).lowercased()
            var value = ""
            for index in 2...4 where match.range(at: index).location != NSNotFound {
                if let range = Range(match.range(at: index), in: rest) { value = String(rest[range]).chatHTMLDecoded; break }
            }
            attributes[key] = value
        }
        return (name, attributes)
    }
}
