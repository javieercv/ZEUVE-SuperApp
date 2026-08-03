import Foundation

public struct WhatsAppInspection: Sendable, Equatable {
    public let catalog: ChatArchiveCatalog
    public let textCandidates: [String]
    public let validTextCandidates: [String]
    public init(catalog: ChatArchiveCatalog, textCandidates: [String], validTextCandidates: [String]) {
        self.catalog = catalog; self.textCandidates = textCandidates; self.validTextCandidates = validTextCandidates
    }
}

public struct WhatsAppImportResult: Sendable, Equatable {
    public let messages: [NormalizedMessage]
    public let summary: ChatImportSummary
    public let selectedTextPath: String
}

public struct WhatsAppImporter: Sendable {
    public let settings: ChatAnalyzerSettings
    public init(settings: ChatAnalyzerSettings) { self.settings = settings }

    public func inspectArchive(at url: URL) throws -> WhatsAppInspection {
        let reader = ChatArchiveReader(url: url, limits: settings.archiveLimits)
        let catalog = try reader.catalog()
        let candidates = catalog.entries
            .filter { !$0.isDirectory && $0.path.lowercased().hasSuffix(".txt") }
            .map(\.path)
        let samples = try reader.readPrefixes(paths: Set(candidates), maximumBytesPerEntry: 256 * 1_024)
        let valid = candidates.filter { path in
            guard let data = samples[path], let text = ChatTextDecoder.decode(data) else { return false }
            return text.split(whereSeparator: \.isNewline).prefix(100).contains { parseHeader(String($0)) != nil }
        }
        return WhatsAppInspection(catalog: catalog, textCandidates: candidates, validTextCandidates: valid)
    }

    public func importArchive(
        at url: URL,
        selectedTextPath: String? = nil,
        cancellation: @Sendable () -> Bool = { false }
    ) throws -> WhatsAppImportResult {
        let inspection = try inspectArchive(at: url)
        let selected: String
        if let selectedTextPath {
            guard inspection.validTextCandidates.contains(selectedTextPath) else { throw ChatAnalyzerError.whatsappTextNotFound }
            selected = selectedTextPath
        } else if inspection.validTextCandidates.count == 1 {
            selected = inspection.validTextCandidates[0]
        } else if inspection.validTextCandidates.isEmpty {
            throw ChatAnalyzerError.whatsappTextNotFound
        } else {
            throw ChatAnalyzerError.multipleWhatsAppTexts(inspection.validTextCandidates)
        }

        if let entry = inspection.catalog.entries.first(where: { $0.path == selected }) {
            try validateConversationFileSize(entry.size, name: URL(fileURLWithPath: selected).lastPathComponent)
        }

        let reader = ChatArchiveReader(url: url, limits: settings.archiveLimits)
        return try parse(
            sourceFile: selected,
            archiveEntries: inspection.catalog.entries,
            attachmentsVerified: true,
            initialWarnings: inspection.catalog.warnings,
            cancellation: cancellation
        ) { consume in
            let decoder = ChatStreamingLineDecoder()
            try reader.stream(path: selected, maximumBytesPerEntry: settings.conversationFileMaximumBytes) { chunk in
                if cancellation() { throw ChatAnalyzerError.cancelled }
                try decoder.append(chunk, consume: consume)
            }
            try decoder.finish(consume: consume)
        }
    }

    public func importText(at url: URL, cancellation: @Sendable () -> Bool = { false }) throws -> WhatsAppImportResult {
        let fingerprint = try FileFingerprintSnapshot.read(url)
        try validateConversationFileSize(fingerprint.size, name: url.lastPathComponent)
        return try parse(
            sourceFile: url.lastPathComponent,
            archiveEntries: [],
            attachmentsVerified: false,
            initialWarnings: [],
            cancellation: cancellation
        ) { consume in
            let decoder = ChatStreamingLineDecoder()
            let handle: FileHandle
            do { handle = try FileHandle(forReadingFrom: url) }
            catch { throw ChatAnalyzerError.unreadableFile(url.lastPathComponent) }
            defer { try? handle.close() }
            var total: Int64 = 0
            while true {
                if cancellation() { throw ChatAnalyzerError.cancelled }
                let chunk: Data
                do { chunk = try handle.read(upToCount: 64 * 1_024) ?? Data() }
                catch { throw ChatAnalyzerError.unreadableFile(url.lastPathComponent) }
                if chunk.isEmpty { break }
                let addition = total.addingReportingOverflow(Int64(chunk.count))
                if addition.overflow { throw ChatAnalyzerError.unreadableFile(url.lastPathComponent) }
                total = addition.partialValue
                if let maximum = settings.conversationFileMaximumBytes, total > maximum {
                    throw ChatAnalyzerError.conversationFileLimit(name: url.lastPathComponent, size: total, maximum: maximum)
                }
                try decoder.append(chunk, consume: consume)
            }
            try decoder.finish(consume: consume)
        }
    }

    private func validateConversationFileSize(_ size: Int64, name: String) throws {
        guard let maximum = settings.conversationFileMaximumBytes, size > maximum else { return }
        throw ChatAnalyzerError.conversationFileLimit(name: name, size: size, maximum: maximum)
    }

    private func parse(
        sourceFile: String,
        archiveEntries: [ChatArchiveEntry],
        attachmentsVerified: Bool,
        initialWarnings: [ChatImportWarning],
        cancellation: @Sendable () -> Bool,
        produceLines: (_ consume: (String) throws -> Void) throws -> Void
    ) throws -> WhatsAppImportResult {
        var messages: [NormalizedMessage] = []
        var warnings = initialWarnings
        var current: ParsedMessage?
        var discarded = 0
        var linePosition = 0
        let conversationID = "whatsapp:" + ChatStableID.make([sourceFile])
        let existingByBasename = Dictionary(
            grouping: archiveEntries.filter { !$0.isDirectory },
            by: { URL(fileURLWithPath: $0.path).lastPathComponent.lowercased() }
        )
        var referenced = Set<String>()

        func flush() {
            guard let item = current else { return }
            let attachmentName = Self.attachmentName(in: item.text)
            let attachmentEntry = attachmentName.flatMap { existingByBasename[$0.lowercased()]?.first }
            if let attachmentName { referenced.insert(attachmentName.lowercased()) }
            let type = ChatContentClassifier.classify(text: item.text, attachmentName: attachmentName)
            let attachment = attachmentName.map {
                ChatAttachmentReference(path: $0, exists: attachmentsVerified && attachmentEntry != nil, inferredType: type)
            }
            let id = ChatStableID.make([conversationID, item.dateText, item.author ?? "", item.text, String(item.position)])
            messages.append(NormalizedMessage(
                id: id,
                conversationID: conversationID,
                timestamp: item.date,
                originalDateText: item.dateText,
                timeZoneStrategy: "Hora local de WhatsApp",
                author: item.author ?? "Sistema",
                text: item.text,
                platform: .whatsapp,
                contentType: item.author == nil ? .system : type,
                sourceFile: sourceFile,
                sourcePosition: item.position,
                category: .chat,
                isSystem: item.author == nil,
                hasUncertainDate: item.uncertainDate,
                attachment: attachment
            ))
        }

        if cancellation() { throw ChatAnalyzerError.cancelled }
        try produceLines { rawLine in
            let line = rawLine.trimmingCharacters(in: CharacterSet(charactersIn: "\r"))
            if let header = parseHeader(line) {
                flush()
                current = ParsedMessage(
                    date: header.date,
                    dateText: header.dateText,
                    uncertainDate: header.uncertainDate,
                    author: header.author,
                    text: header.text,
                    position: linePosition
                )
            } else if current != nil {
                current?.text += "\n" + line
            } else if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                discarded += 1
            }
            linePosition += 1
        }
        flush()
        guard !messages.isEmpty else { throw ChatAnalyzerError.whatsappNoMessages }
        messages.sort { ($0.timestamp, $0.sourcePosition) < ($1.timestamp, $1.sourcePosition) }

        let missing = attachmentsVerified ? messages.compactMap(\.attachment).filter { !$0.exists }.count : 0
        let unverified = attachmentsVerified ? 0 : referenced.count
        let mediaEntries = archiveEntries.filter { !$0.isDirectory && !$0.path.lowercased().hasSuffix(".txt") }
        let unreferenced = attachmentsVerified
            ? mediaEntries.filter { !referenced.contains(URL(fileURLWithPath: $0.path).lastPathComponent.lowercased()) }.count
            : 0
        if missing > 0 {
            warnings.append(.init(code: "missing-attachments", message: "Faltan \(missing) adjuntos referenciados."))
        }
        if unverified > 0 {
            warnings.append(.init(
                code: "unverified-attachments",
                message: "No se han comprobado \(unverified) adjuntos porque solo se ha seleccionado el TXT."
            ))
        }
        if unreferenced > 0 {
            warnings.append(.init(code: "unreferenced-attachments", message: "Hay \(unreferenced) archivos adjuntos no vinculados a un mensaje reconocido."))
        }
        if messages.contains(where: \.hasUncertainDate) {
            warnings.append(.init(code: "ambiguous-dates", message: "Algunas fechas numéricas eran ambiguas y se interpretaron según el orden configurado."))
        }

        var summary = ChatImportSummary()
        summary.sourceCount = 1
        summary.processedFiles = 1
        summary.recognizedMessages = messages.count
        summary.discardedMessages = discarded
        summary.referencedAttachments = referenced.count
        summary.missingAttachments = missing
        summary.unverifiedAttachments = unverified
        summary.unreferencedAttachments = unreferenced
        summary.warnings = warnings
        return WhatsAppImportResult(messages: messages, summary: summary, selectedTextPath: sourceFile)
    }

    private struct ParsedMessage {
        let date: Date
        let dateText: String
        let uncertainDate: Bool
        let author: String?
        var text: String
        let position: Int
    }

    private struct Header {
        let date: Date
        let dateText: String
        let uncertainDate: Bool
        let author: String?
        let text: String
    }

    private func parseHeader(_ line: String) -> Header? { Self.parseHeader(line, settings: settings) }

    private static func parseHeader(_ line: String, settings: ChatAnalyzerSettings = .init()) -> Header? {
        let cleaned = line.replacingOccurrences(of: #"[\u200E\u200F\u202A-\u202E\u2066-\u2069]"#, with: "", options: .regularExpression)
        let dateText: String
        let remainder: String
        if cleaned.hasPrefix("["), let close = cleaned.firstIndex(of: "]") {
            dateText = String(cleaned[cleaned.index(after: cleaned.startIndex)..<close])
            remainder = String(cleaned[cleaned.index(after: close)...]).trimmingCharacters(in: .whitespaces)
        } else {
            let pattern = #"^\s*(\d{1,2}[./-]\d{1,2}[./-]\d{2,4}[,\s]+\d{1,2}:\d{2}(?::\d{2})?\s*(?:[aApP]\.?\s*[mM]\.?)?)\s*[-–—]\s*(.*)$"#
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
                  match.range.location != NSNotFound,
                  let dateRange = Range(match.range(at: 1), in: cleaned),
                  let restRange = Range(match.range(at: 2), in: cleaned) else { return nil }
            dateText = String(cleaned[dateRange]); remainder = String(cleaned[restRange])
        }
        guard let parsed = WhatsAppDateParser.parse(dateText, settings: settings) else { return nil }
        if let colon = remainder.firstIndex(of: ":") {
            let candidate = String(remainder[..<colon]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !candidate.isEmpty && candidate.count <= 200 {
                return Header(
                    date: parsed.date,
                    dateText: dateText,
                    uncertainDate: parsed.uncertain,
                    author: candidate,
                    text: String(remainder[remainder.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                )
            }
        }
        return Header(date: parsed.date, dateText: dateText, uncertainDate: parsed.uncertain, author: nil, text: remainder)
    }

    private static func attachmentName(in text: String) -> String? {
        let pattern = #"(?i)<\s*(?:adjunto|attached)\s*:\s*([^>]+)>"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private final class ChatStreamingLineDecoder {
    private enum Mode { case undecided, utf8, buffered }
    private var mode: Mode = .undecided
    private var pending = Data()
    private var buffered = Data()

    func append(_ chunk: Data, consume: (String) throws -> Void) throws {
        guard !chunk.isEmpty else { return }
        switch mode {
        case .buffered:
            buffered.append(chunk)
        case .utf8:
            pending.append(chunk)
            try emitUTF8Lines(consume: consume)
        case .undecided:
            pending.append(chunk)
            try decideModeIfPossible(final: false, consume: consume)
        }
    }

    func finish(consume: (String) throws -> Void) throws {
        if mode == .undecided { try decideModeIfPossible(final: true, consume: consume) }
        switch mode {
        case .utf8:
            if !pending.isEmpty {
                try consume(Self.decodeLine(pending))
                pending.removeAll(keepingCapacity: false)
            }
        case .buffered:
            guard let text = ChatTextDecoder.decode(buffered) else { return }
            for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                try consume(String(line))
            }
            buffered.removeAll(keepingCapacity: false)
        case .undecided:
            break
        }
    }

    private func decideModeIfPossible(final: Bool, consume: (String) throws -> Void) throws {
        guard pending.count >= 2 || final else { return }
        if pending.starts(with: [0xFF, 0xFE]) || pending.starts(with: [0xFE, 0xFF]) {
            mode = .buffered
            buffered.append(pending)
            pending.removeAll(keepingCapacity: false)
            return
        }
        guard pending.count >= 3 || final else { return }
        mode = .utf8
        if pending.starts(with: [0xEF, 0xBB, 0xBF]) { pending.removeFirst(3) }
        try emitUTF8Lines(consume: consume)
    }

    private func emitUTF8Lines(consume: (String) throws -> Void) throws {
        while let newline = pending.firstIndex(of: 0x0A) {
            let line = pending.subdata(in: pending.startIndex..<newline)
            pending.removeSubrange(pending.startIndex...newline)
            try consume(Self.decodeLine(line))
        }
    }

    private static func decodeLine(_ data: Data) -> String {
        String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? String(decoding: data, as: UTF8.self)
    }
}

private enum WhatsAppDateParser {
    static func parse(_ raw: String, settings: ChatAnalyzerSettings) -> (date: Date, uncertain: Bool)? {
        let normalized = raw.replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: #"(?i)(a|p)\.\s*m\."#, with: "$1m", options: .regularExpression)
        let pattern = #"^\s*(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})[,\s]+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([aApP][mM])?\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)),
              match.range.location != NSNotFound else { return nil }
        let ns = normalized as NSString
        func number(_ index: Int) -> Int? {
            match.range(at: index).location == NSNotFound ? nil : Int(ns.substring(with: match.range(at: index)))
        }
        guard var first = number(1), var second = number(2), var year = number(3), var hour = number(4), let minute = number(5) else { return nil }
        let secondValue = number(6) ?? 0
        let marker = match.range(at: 7).location == NSNotFound ? nil : ns.substring(with: match.range(at: 7)).lowercased()
        let uncertain = first <= 12 && second <= 12 && first != second
        if settings.numericDateOrder == .monthDayYear { swap(&first, &second) }
        if year < 100 { year += year >= 70 ? 1900 : 2000 }
        if marker == "pm" && hour < 12 { hour += 12 }
        if marker == "am" && hour == 12 { hour = 0 }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid") ?? .current
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: second,
            day: first,
            hour: hour,
            minute: minute,
            second: secondValue
        )
        guard let date = calendar.date(from: components) else { return nil }
        return (date, uncertain)
    }
}
