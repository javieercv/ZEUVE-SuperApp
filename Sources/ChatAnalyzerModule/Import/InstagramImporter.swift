import Foundation

public struct InstagramCatalogResult: Sendable, Equatable {
    public let archiveCatalog: ChatArchiveCatalog
    public let conversations: [InstagramConversationDescriptor]
    public let warnings: [ChatImportWarning]
}

public struct InstagramImportResult: Sendable, Equatable {
    public let messages: [NormalizedMessage]
    public let summary: ChatImportSummary
    public let conversation: InstagramConversationDescriptor
}

public struct InstagramImporter: Sendable {
    public let settings: ChatAnalyzerSettings
    public init(settings: ChatAnalyzerSettings) { self.settings = settings }

    public func catalogArchive(at url: URL, cancellation: @Sendable () -> Bool = { false }) throws -> InstagramCatalogResult {
        let reader = ChatArchiveReader(url: url, limits: settings.archiveLimits)
        let archive = try reader.catalog(cancellation: cancellation)
        if cancellation() { throw ChatAnalyzerError.cancelled }
        let allMessagePages = archive.entries.filter { !$0.isDirectory && Self.pageNumber(from: $0.path) != nil }
        let standardPages = allMessagePages.filter { Self.isMessagePath($0.path) }
        let directGroups = Dictionary(grouping: allMessagePages, by: { URL(fileURLWithPath: $0.path).deletingLastPathComponent().path })
            .filter { _, entries in entries.contains { Self.pageNumber(from: $0.path) == 1 } }
        let usesDirectConversationLayout = standardPages.isEmpty && !directGroups.isEmpty
        let pages = standardPages.isEmpty ? directGroups.values.flatMap { $0 } : standardPages
        guard !pages.isEmpty else { throw ChatAnalyzerError.chatNotFound }
        let indexPaths = archive.entries.filter {
            let name = URL(fileURLWithPath: $0.path).lastPathComponent.lowercased()
            return !$0.isDirectory && ["start_here.html", "chats.html", "secret_conversations.html", "igd_broadcast_chats.html"].contains(name)
                && $0.path.lowercased().contains("messages")
        }.map(\.path)
        let indexData = try reader.read(paths: Set(indexPaths), maximumBytesPerEntry: 32 * 1_024 * 1_024, cancellation: cancellation)
        var namesByPage: [String: String] = [:]
        for path in indexPaths {
            if cancellation() { throw ChatAnalyzerError.cancelled }
            guard let data = indexData[path], let html = ChatTextDecoder.decode(data) else { continue }
            let document = ChatHTMLDocument.parse(html)
            for link in document.root.descendants(where: { $0.tag == "a" }) {
                guard let href = link.attributes["href"], href.lowercased().contains("message_1.html") else { continue }
                if let resolved = try? Self.resolve(href: href, relativeTo: path, baseHref: document.baseHref) {
                    let title = link.textContent.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !title.isEmpty { namesByPage[resolved] = title }
                }
            }
        }

        let grouped = Dictionary(grouping: pages, by: { Self.parentPath(of: $0.path) })
        var descriptors: [InstagramConversationDescriptor] = grouped.map { folder, entries in
            let sorted = entries.sorted { (Self.pageNumber(from: $0.path) ?? 0) < (Self.pageNumber(from: $1.path) ?? 0) }.map(\.path)
            let messageOne = sorted.first(where: { Self.pageNumber(from: $0) == 1 })
            let display = messageOne.flatMap { namesByPage[$0] } ?? Self.fallbackDisplayName(folder: folder)
            let category = Self.category(for: folder)
            let id = ChatStableID.make([category.rawValue, folder])
            return InstagramConversationDescriptor(id: id, displayName: display, category: category, normalizedPath: folder, pages: sorted)
        }
        let duplicateNames = Dictionary(grouping: descriptors, by: { $0.displayName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) })
            .filter { $0.value.count > 1 }.keys
        descriptors = descriptors.map { item in
            let key = item.displayName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return .init(id: item.id, displayName: item.displayName, category: item.category, normalizedPath: item.normalizedPath, pages: item.pages, duplicateDisplayName: duplicateNames.contains(key))
        }.sorted {
            if $0.category != $1.category { return $0.category.rawValue < $1.category.rawValue }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        if pages.count > settings.archiveLimits.htmlPageMaximumCount { throw ChatAnalyzerError.archiveLimit("demasiadas páginas HTML") }
        var warnings = archive.warnings
        if pages.count > settings.archiveLimits.htmlPageWarningCount {
            warnings.append(.init(code: "many-html-pages", message: "La exportación contiene muchas páginas HTML de mensajes."))
        }
        if indexPaths.isEmpty { warnings.append(.init(code: "instagram-index-fallback", message: "No se encontraron índices de Meta; el catálogo se construyó desde las carpetas de mensajes.")) }
        if usesDirectConversationLayout {
            warnings.append(.init(code: "instagram-single-chat-layout", message: "El ZIP contiene directamente una o varias conversaciones de Instagram y se ha adaptado su estructura."))
        }
        return InstagramCatalogResult(archiveCatalog: archive, conversations: descriptors, warnings: warnings)
    }

    public func importArchive(at url: URL, conversationID: String, cancellation: @Sendable () -> Bool = { false }) throws -> InstagramImportResult {
        let catalog = try catalogArchive(at: url, cancellation: cancellation)
        guard let conversation = catalog.conversations.first(where: { $0.id == conversationID }) else { throw ChatAnalyzerError.instagramConversationNotFound }
        if conversation.pages.count > settings.archiveLimits.htmlPageMaximumCount { throw ChatAnalyzerError.archiveLimit("demasiadas páginas HTML en la conversación") }
        for page in conversation.pages {
            if let entry = catalog.archiveCatalog.entries.first(where: { $0.path == page }) {
                try validateConversationFileSize(entry.size, name: URL(fileURLWithPath: page).lastPathComponent)
            }
        }
        let reader = ChatArchiveReader(url: url, limits: settings.archiveLimits)
        let pagesData = try reader.read(paths: Set(conversation.pages), maximumBytesPerEntry: settings.conversationFileMaximumBytes ?? .max, cancellation: cancellation)
        let allPaths = Set(catalog.archiveCatalog.entries.map(\.path))
        var messages: [NormalizedMessage] = []
        var warnings = catalog.warnings
        var discarded = 0
        var attachments = 0
        var missing = 0
        for pagePath in conversation.pages {
            if cancellation() { throw ChatAnalyzerError.cancelled }
            guard let data = pagesData[pagePath], let html = ChatTextDecoder.decode(data) else {
                warnings.append(.init(code: "html-unreadable", message: "No se pudo leer \(URL(fileURLWithPath: pagePath).lastPathComponent).")); continue
            }
            let page = Self.pageNumber(from: pagePath) ?? 0
            let parsed = parseMessages(html: html, pagePath: pagePath, pageNumber: page, conversation: conversation, archivePaths: allPaths)
            messages.append(contentsOf: parsed.messages)
            warnings.append(contentsOf: parsed.warnings)
            discarded += parsed.discarded
            attachments += parsed.attachments
            missing += parsed.missingAttachments
        }
        guard !messages.isEmpty else { throw ChatAnalyzerError.instagramNoMessages }
        messages.sort {
            if $0.timestamp != $1.timestamp { return $0.timestamp < $1.timestamp }
            if ($0.sourcePage ?? 0) != ($1.sourcePage ?? 0) { return ($0.sourcePage ?? 0) < ($1.sourcePage ?? 0) }
            return $0.sourcePosition < $1.sourcePosition
        }
        messages = MessageDeduplicator.deduplicate(messages).messages
        if messages.count > settings.archiveLimits.messageMaximumCount { throw ChatAnalyzerError.archiveLimit("demasiados mensajes") }
        if missing > 0 { warnings.append(.init(code: "instagram-missing-attachments", message: "Faltan \(missing) adjuntos internos referenciados.")) }
        var summary = ChatImportSummary()
        summary.sourceCount = 1; summary.processedFiles = conversation.pages.count; summary.processedHTMLPages = conversation.pages.count
        summary.recognizedMessages = messages.count; summary.discardedMessages = discarded
        summary.referencedAttachments = attachments; summary.missingAttachments = missing; summary.warnings = warnings
        return InstagramImportResult(messages: messages, summary: summary, conversation: conversation)
    }


    public func catalogFolder(at root: URL, cancellation: @Sendable () -> Bool = { false }) throws -> [InstagramConversationDescriptor] {
        let root = root.standardizedFileURL
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            throw ChatAnalyzerError.unreadableFile(root.lastPathComponent)
        }
        var pageURLs: [URL] = []
        var indexURLs: [URL] = []
        for case let url as URL in enumerator {
            if cancellation() { throw ChatAnalyzerError.cancelled }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            if values.isSymbolicLink == true { enumerator.skipDescendants(); continue }
            guard values.isRegularFile == true else { continue }
            let name = url.lastPathComponent.lowercased()
            if Self.pageNumber(from: name) != nil { pageURLs.append(url) }
            if ["start_here.html", "chats.html", "secret_conversations.html", "igd_broadcast_chats.html"].contains(name) { indexURLs.append(url) }
            if pageURLs.count > settings.archiveLimits.htmlPageMaximumCount { throw ChatAnalyzerError.archiveLimit("demasiadas páginas HTML") }
        }
        guard !pageURLs.isEmpty else { throw ChatAnalyzerError.chatNotFound }
        func relative(_ url: URL) -> String {
            let base = root.path.hasSuffix("/") ? root.path : root.path + "/"
            return url.standardizedFileURL.path.replacingOccurrences(of: base, with: "")
        }
        var namesByPage: [String: String] = [:]
        for indexURL in indexURLs {
            guard let html = try? String(contentsOf: indexURL, encoding: .utf8) else { continue }
            let document = ChatHTMLDocument.parse(html)
            let indexRelative = relative(indexURL)
            for link in document.root.descendants(where: { $0.tag == "a" }) {
                guard let href = link.attributes["href"], href.lowercased().contains("message_1.html"),
                      let resolved = try? Self.resolve(href: href, relativeTo: indexRelative, baseHref: document.baseHref) else { continue }
                if !link.textContent.isEmpty { namesByPage[resolved] = link.textContent }
            }
        }
        let grouped = Dictionary(grouping: pageURLs, by: { $0.deletingLastPathComponent().standardizedFileURL.path })
        var descriptors = grouped.map { folder, urls -> InstagramConversationDescriptor in
            let relativeFolder = relative(URL(fileURLWithPath: folder, isDirectory: true))
            let pages = urls.map(relative).sorted { (Self.pageNumber(from: $0) ?? 0) < (Self.pageNumber(from: $1) ?? 0) }
            let pageOne = pages.first(where: { Self.pageNumber(from: $0) == 1 })
            let display = pageOne.flatMap { namesByPage[$0] } ?? Self.fallbackDisplayName(folder: relativeFolder)
            let category = Self.category(for: relativeFolder)
            return .init(id: ChatStableID.make([root.path, relativeFolder]), displayName: display, category: category, normalizedPath: relativeFolder, pages: pages)
        }
        let duplicates = Dictionary(grouping: descriptors, by: { $0.displayName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) }).filter { $0.value.count > 1 }.keys
        descriptors = descriptors.map { item in
            let key = item.displayName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return .init(id: item.id, displayName: item.displayName, category: item.category, normalizedPath: item.normalizedPath, pages: item.pages, duplicateDisplayName: duplicates.contains(key))
        }
        return descriptors.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    public func importFolder(at root: URL, conversationID: String, cancellation: @Sendable () -> Bool = { false }) throws -> InstagramImportResult {
        let descriptors = try catalogFolder(at: root, cancellation: cancellation)
        guard let conversation = descriptors.first(where: { $0.id == conversationID }) else { throw ChatAnalyzerError.instagramConversationNotFound }
        let available = try availableFilePaths(in: root, cancellation: cancellation)
        var messages: [NormalizedMessage] = []
        var warnings: [ChatImportWarning] = []
        var discarded = 0, attachments = 0, missing = 0
        for path in conversation.pages {
            if cancellation() { throw ChatAnalyzerError.cancelled }
            let url = root.appendingPathComponent(path).standardizedFileURL
            if let size = try? FileFingerprintSnapshot.read(url).size { try validateConversationFileSize(size, name: url.lastPathComponent) }
            guard url.path.hasPrefix(root.standardizedFileURL.path), let data = try? Data(contentsOf: url), let html = ChatTextDecoder.decode(data) else {
                warnings.append(.init(code: "html-unreadable", message: "No se pudo leer \(URL(fileURLWithPath: path).lastPathComponent).")); continue
            }
            let parsed = parseMessages(html: html, pagePath: path, pageNumber: Self.pageNumber(from: path) ?? 0, conversation: conversation, archivePaths: available)
            messages += parsed.messages; warnings += parsed.warnings; discarded += parsed.discarded; attachments += parsed.attachments; missing += parsed.missingAttachments
        }
        guard !messages.isEmpty else { throw ChatAnalyzerError.instagramNoMessages }
        messages.sort { ($0.timestamp, $0.sourcePage ?? 0, $0.sourcePosition) < ($1.timestamp, $1.sourcePage ?? 0, $1.sourcePosition) }
        messages = MessageDeduplicator.deduplicate(messages).messages
        var summary = ChatImportSummary(); summary.sourceCount = 1; summary.processedFiles = conversation.pages.count; summary.processedHTMLPages = conversation.pages.count
        summary.recognizedMessages = messages.count; summary.discardedMessages = discarded; summary.referencedAttachments = attachments; summary.missingAttachments = missing; summary.warnings = warnings
        return .init(messages: messages, summary: summary, conversation: conversation)
    }

    public func importHTMLFiles(_ urls: [URL], cancellation: @Sendable () -> Bool = { false }) throws -> InstagramImportResult {
        guard !urls.isEmpty else { throw ChatAnalyzerError.noInput }
        let sortedURLs = urls.sorted { (Self.pageNumber(from: $0.lastPathComponent) ?? 0) < (Self.pageNumber(from: $1.lastPathComponent) ?? 0) }
        let descriptor = InstagramConversationDescriptor(id: ChatStableID.make(sortedURLs.map(\.standardizedFileURL.path)), displayName: sortedURLs.first?.deletingPathExtension().lastPathComponent ?? "Conversación de Instagram", category: .chat, normalizedPath: "html-selection", pages: sortedURLs.map(\.lastPathComponent))
        let available = Set(sortedURLs.map(\.lastPathComponent))
        var messages: [NormalizedMessage] = []; var warnings: [ChatImportWarning] = []; var discarded = 0, attachments = 0, missing = 0
        for (index, url) in sortedURLs.enumerated() {
            if cancellation() { throw ChatAnalyzerError.cancelled }
            let size = try FileFingerprintSnapshot.read(url).size
            try validateConversationFileSize(size, name: url.lastPathComponent)
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            guard let html = ChatTextDecoder.decode(data) else { throw ChatAnalyzerError.unreadableFile(url.lastPathComponent) }
            let parsed = parseMessages(html: html, pagePath: url.lastPathComponent, pageNumber: Self.pageNumber(from: url.lastPathComponent) ?? index + 1, conversation: descriptor, archivePaths: available)
            messages += parsed.messages; warnings += parsed.warnings; discarded += parsed.discarded; attachments += parsed.attachments; missing += parsed.missingAttachments
        }
        guard !messages.isEmpty else { throw ChatAnalyzerError.instagramNoMessages }
        messages.sort { ($0.timestamp, $0.sourcePage ?? 0, $0.sourcePosition) < ($1.timestamp, $1.sourcePage ?? 0, $1.sourcePosition) }
        messages = MessageDeduplicator.deduplicate(messages).messages
        var summary = ChatImportSummary(); summary.sourceCount = urls.count; summary.processedFiles = urls.count; summary.processedHTMLPages = urls.count
        summary.recognizedMessages = messages.count; summary.discardedMessages = discarded; summary.referencedAttachments = attachments; summary.missingAttachments = missing; summary.warnings = warnings
        return .init(messages: messages, summary: summary, conversation: descriptor)
    }


    /// Importa una conversación de ZIP página a página y entrega los mensajes por lotes.
    /// La deduplicación global se realiza en `TemporaryChatStore`, evitando retener la conversación completa.
    public func streamArchive(
        at url: URL,
        conversationID: String,
        cancellation: @Sendable () -> Bool = { false },
        consume: ([NormalizedMessage]) throws -> Void
    ) throws -> ChatImportSummary {
        let catalog = try catalogArchive(at: url, cancellation: cancellation)
        guard let conversation = catalog.conversations.first(where: { $0.id == conversationID }) else {
            throw ChatAnalyzerError.instagramConversationNotFound
        }
        if conversation.pages.count > settings.archiveLimits.htmlPageMaximumCount {
            throw ChatAnalyzerError.archiveLimit("demasiadas páginas HTML en la conversación")
        }
        for page in conversation.pages {
            if let entry = catalog.archiveCatalog.entries.first(where: { $0.path == page }) {
                try validateConversationFileSize(entry.size, name: URL(fileURLWithPath: page).lastPathComponent)
            }
        }

        let reader = ChatArchiveReader(url: url, limits: settings.archiveLimits)
        let allPaths = Set(catalog.archiveCatalog.entries.map(\.path))
        var warnings = catalog.warnings
        var recognized = 0
        var discarded = 0
        var attachments = 0
        var missing = 0
        for pagePath in conversation.pages {
            if cancellation() || Task.isCancelled { throw ChatAnalyzerError.cancelled }
            let pageData = try reader.read(
                paths: [pagePath],
                maximumBytesPerEntry: settings.conversationFileMaximumBytes ?? .max,
                cancellation: cancellation
            )
            guard let data = pageData[pagePath], let html = ChatTextDecoder.decode(data) else {
                warnings.append(.init(code: "html-unreadable", message: "No se pudo leer \(URL(fileURLWithPath: pagePath).lastPathComponent)."))
                continue
            }
            let parsed = parseMessages(
                html: html,
                pagePath: pagePath,
                pageNumber: Self.pageNumber(from: pagePath) ?? 0,
                conversation: conversation,
                archivePaths: allPaths
            )
            if !parsed.messages.isEmpty {
                recognized += parsed.messages.count
                try consume(parsed.messages)
            }
            warnings.append(contentsOf: parsed.warnings)
            discarded += parsed.discarded
            attachments += parsed.attachments
            missing += parsed.missingAttachments
        }
        guard recognized > 0 else { throw ChatAnalyzerError.instagramNoMessages }
        if missing > 0 {
            warnings.append(.init(code: "instagram-missing-attachments", message: "Faltan \(missing) adjuntos internos referenciados."))
        }
        var summary = ChatImportSummary()
        summary.sourceCount = 1
        summary.processedFiles = conversation.pages.count
        summary.processedHTMLPages = conversation.pages.count
        summary.recognizedMessages = recognized
        summary.discardedMessages = discarded
        summary.referencedAttachments = attachments
        summary.missingAttachments = missing
        summary.warnings = warnings
        return summary
    }

    /// Variante incremental para una exportación de Instagram ya descomprimida.
    public func streamFolder(
        at root: URL,
        conversationID: String,
        cancellation: @Sendable () -> Bool = { false },
        consume: ([NormalizedMessage]) throws -> Void
    ) throws -> ChatImportSummary {
        let descriptors = try catalogFolder(at: root, cancellation: cancellation)
        guard let conversation = descriptors.first(where: { $0.id == conversationID }) else {
            throw ChatAnalyzerError.instagramConversationNotFound
        }
        let available = try availableFilePaths(in: root, cancellation: cancellation)
        var warnings: [ChatImportWarning] = []
        var recognized = 0
        var discarded = 0
        var attachments = 0
        var missing = 0
        let standardizedRoot = root.standardizedFileURL
        let rootPrefix = standardizedRoot.path.hasSuffix("/") ? standardizedRoot.path : standardizedRoot.path + "/"
        for path in conversation.pages {
            if cancellation() || Task.isCancelled { throw ChatAnalyzerError.cancelled }
            let pageURL = standardizedRoot.appendingPathComponent(path).standardizedFileURL
            guard pageURL.path.hasPrefix(rootPrefix) else { throw ChatAnalyzerError.archiveUnsafe("ruta fuera de la exportación") }
            if let size = try? FileFingerprintSnapshot.read(pageURL).size {
                try validateConversationFileSize(size, name: pageURL.lastPathComponent)
            }
            guard let data = try? Data(contentsOf: pageURL, options: [.mappedIfSafe]), let html = ChatTextDecoder.decode(data) else {
                warnings.append(.init(code: "html-unreadable", message: "No se pudo leer \(URL(fileURLWithPath: path).lastPathComponent)."))
                continue
            }
            let parsed = parseMessages(
                html: html,
                pagePath: path,
                pageNumber: Self.pageNumber(from: path) ?? 0,
                conversation: conversation,
                archivePaths: available
            )
            if !parsed.messages.isEmpty {
                recognized += parsed.messages.count
                try consume(parsed.messages)
            }
            warnings.append(contentsOf: parsed.warnings)
            discarded += parsed.discarded
            attachments += parsed.attachments
            missing += parsed.missingAttachments
        }
        guard recognized > 0 else { throw ChatAnalyzerError.instagramNoMessages }
        var summary = ChatImportSummary()
        summary.sourceCount = 1
        summary.processedFiles = conversation.pages.count
        summary.processedHTMLPages = conversation.pages.count
        summary.recognizedMessages = recognized
        summary.discardedMessages = discarded
        summary.referencedAttachments = attachments
        summary.missingAttachments = missing
        summary.warnings = warnings
        return summary
    }

    /// Variante incremental para páginas HTML seleccionadas manualmente.
    public func streamHTMLFiles(
        _ urls: [URL],
        cancellation: @Sendable () -> Bool = { false },
        consume: ([NormalizedMessage]) throws -> Void
    ) throws -> ChatImportSummary {
        guard !urls.isEmpty else { throw ChatAnalyzerError.noInput }
        let sortedURLs = urls.sorted { (Self.pageNumber(from: $0.lastPathComponent) ?? 0) < (Self.pageNumber(from: $1.lastPathComponent) ?? 0) }
        let descriptor = InstagramConversationDescriptor(
            id: ChatStableID.make(sortedURLs.map(\.standardizedFileURL.path)),
            displayName: sortedURLs.first?.deletingPathExtension().lastPathComponent ?? "Conversación de Instagram",
            category: .chat,
            normalizedPath: "html-selection",
            pages: sortedURLs.map(\.lastPathComponent)
        )
        let available = Set(sortedURLs.map(\.lastPathComponent))
        var warnings: [ChatImportWarning] = []
        var recognized = 0
        var discarded = 0
        var attachments = 0
        var missing = 0
        for (index, pageURL) in sortedURLs.enumerated() {
            if cancellation() || Task.isCancelled { throw ChatAnalyzerError.cancelled }
            let size = try FileFingerprintSnapshot.read(pageURL).size
            try validateConversationFileSize(size, name: pageURL.lastPathComponent)
            let data: Data
            do { data = try Data(contentsOf: pageURL, options: [.mappedIfSafe]) }
            catch { throw ChatAnalyzerError.unreadableFile(pageURL.lastPathComponent) }
            guard let html = ChatTextDecoder.decode(data) else { throw ChatAnalyzerError.unreadableFile(pageURL.lastPathComponent) }
            let parsed = parseMessages(
                html: html,
                pagePath: pageURL.lastPathComponent,
                pageNumber: Self.pageNumber(from: pageURL.lastPathComponent) ?? index + 1,
                conversation: descriptor,
                archivePaths: available
            )
            if !parsed.messages.isEmpty {
                recognized += parsed.messages.count
                try consume(parsed.messages)
            }
            warnings.append(contentsOf: parsed.warnings)
            discarded += parsed.discarded
            attachments += parsed.attachments
            missing += parsed.missingAttachments
        }
        guard recognized > 0 else { throw ChatAnalyzerError.instagramNoMessages }
        var summary = ChatImportSummary()
        summary.sourceCount = urls.count
        summary.processedFiles = urls.count
        summary.processedHTMLPages = urls.count
        summary.recognizedMessages = recognized
        summary.discardedMessages = discarded
        summary.referencedAttachments = attachments
        summary.missingAttachments = missing
        summary.warnings = warnings
        return summary
    }


    private func availableFilePaths(in root: URL, cancellation: @Sendable () -> Bool) throws -> Set<String> {
        let root = root.standardizedFileURL
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { throw ChatAnalyzerError.unreadableFile(root.lastPathComponent) }
        let base = root.path.hasSuffix("/") ? root.path : root.path + "/"
        var result = Set<String>()
        for case let url as URL in enumerator {
            if cancellation() { throw ChatAnalyzerError.cancelled }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            if values.isSymbolicLink == true { enumerator.skipDescendants(); continue }
            guard values.isRegularFile == true else { continue }
            let relative = url.standardizedFileURL.path.replacingOccurrences(of: base, with: "")
            if let safe = try? SafeArchivePath.normalize(relative), !SafeArchivePath.shouldIgnore(safe) { result.insert(safe) }
        }
        return result
    }

    private func validateConversationFileSize(_ size: Int64, name: String) throws {
        guard let maximum = settings.conversationFileMaximumBytes, size > maximum else { return }
        throw ChatAnalyzerError.conversationFileLimit(name: name, size: size, maximum: maximum)
    }

    private static func resolveAttachmentPath(
        href: String,
        relativeTo pagePath: String,
        baseHref: String?,
        conversationPath: String,
        archivePaths: Set<String>
    ) -> String? {
        guard !isExternal(href) else { return href }
        let decoded = (href.removingPercentEncoding ?? href)
            .split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? href
        let withoutQuery = decoded.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? decoded
        let normallyResolved = try? resolve(href: withoutQuery, relativeTo: pagePath, baseHref: baseHref)
        if let normallyResolved, archivePaths.contains(normallyResolved) { return normallyResolved }

        let components = withoutQuery.replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
            .filter { $0 != "." && $0 != ".." }
        let conversationFolder = conversationPath.split(separator: "/", omittingEmptySubsequences: true).last.map(String.init) ?? conversationPath
        if let index = components.lastIndex(where: { $0 == conversationFolder }) {
            let suffix = components[index...].joined(separator: "/")
            let parent = Self.parentPath(of: conversationPath)
            let candidate = parent.isEmpty ? suffix : parent + "/" + suffix
            if archivePaths.contains(candidate) { return candidate }
            return candidate
        }

        if let normallyResolved { return normallyResolved }
        let pageFolder = Self.parentPath(of: pagePath)
        guard let normalized = try? SafeArchivePath.normalize(withoutQuery) else { return nil }
        return pageFolder.isEmpty ? normalized : pageFolder + "/" + normalized
    }

    private func parseMessages(html: String, pagePath: String, pageNumber: Int, conversation: InstagramConversationDescriptor, archivePaths: Set<String>) -> (messages: [NormalizedMessage], warnings: [ChatImportWarning], discarded: Int, attachments: Int, missingAttachments: Int) {
        let document = ChatHTMLDocument.parse(html)
        let nodes = [document.root] + document.root.descendants(where: { _ in true })
        let dateNodes = nodes.compactMap { node -> (ChatHTMLNode, Date, Bool)? in
            guard node.children.isEmpty || node.classNames.contains("_a6-o") || node.classNames.contains("timestamp") || node.classNames.contains("date") else { return nil }
            return InstagramDateParser.parse(node.textContent, strategy: settings.instagramTimeZone, numericOrder: settings.numericDateOrder).map { (node, $0.date, $0.uncertain) }
        }
        var seenContainers = Set<ObjectIdentifier>()
        var result: [NormalizedMessage] = []
        var warnings: [ChatImportWarning] = []
        var attachmentCount = 0
        var missingCount = 0
        for (position, pair) in dateNodes.enumerated() {
            let dateNode = pair.0; let date = pair.1; let uncertainDate = pair.2
            let container = Self.messageContainer(for: dateNode)
            guard seenContainers.insert(ObjectIdentifier(container)).inserted else { continue }
            let author = Self.extractAuthor(from: container, excluding: dateNode.textContent)
            let text = Self.extractContent(from: container, author: author, dateText: dateNode.textContent)
            let media = Self.extractMedia(from: container).first
            let resolved = media.flatMap {
                Self.resolveAttachmentPath(
                    href: $0.path,
                    relativeTo: pagePath,
                    baseHref: document.baseHref,
                    conversationPath: conversation.normalizedPath,
                    archivePaths: archivePaths
                )
            }
            let isExternal = media.map { Self.isExternal($0.path) } ?? false
            let exists = resolved.map { archivePaths.contains($0) } ?? false
            let type: ChatContentType
            if isExternal { type = .link }
            else if let media { type = ChatContentClassifier.classify(text: text, attachmentName: resolved ?? media.path, tagName: media.tag) }
            else { type = ChatContentClassifier.classify(text: text) }
            let attachment: ChatAttachmentReference?
            if let resolved, !isExternal {
                attachmentCount += 1; if !exists { missingCount += 1 }
                attachment = .init(path: resolved, exists: exists, inferredType: type)
            } else { attachment = nil }
            let system = author == nil
            if text.isEmpty && media == nil { continue }
            let displayAuthor = author ?? "Sistema"
            let id = ChatStableID.make([conversation.id, dateNode.textContent, displayAuthor, text, pagePath, String(position)])
            result.append(NormalizedMessage(
                id: id, conversationID: conversation.id, timestamp: date, originalDateText: dateNode.textContent,
                timeZoneStrategy: settings.instagramTimeZone.displayName, author: displayAuthor, text: text,
                platform: .instagram, contentType: system ? .system : type, sourceFile: URL(fileURLWithPath: pagePath).lastPathComponent,
                sourcePage: pageNumber, sourcePosition: position, category: conversation.category, isSystem: system,
                hasUncertainDate: uncertainDate, attachment: attachment
            ))
        }
        if dateNodes.isEmpty && !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            warnings.append(.init(code: "instagram-structure", message: "No se reconoció la estructura de \(URL(fileURLWithPath: pagePath).lastPathComponent)."))
        }
        if result.contains(where: \.hasUncertainDate) {
            warnings.append(.init(code: "ambiguous-dates", message: "Algunas fechas numéricas eran ambiguas y se interpretaron según el orden configurado."))
        }
        return (result, warnings, max(0, dateNodes.count - result.count), attachmentCount, missingCount)
    }

    private static func messageContainer(for dateNode: ChatHTMLNode) -> ChatHTMLNode {
        var candidate = dateNode.parent ?? dateNode
        for _ in 0..<4 {
            let classes = candidate.classNames
            if classes.contains("_a6-g") || classes.contains("message") || classes.contains("pam") { return candidate }
            guard let parent = candidate.parent, parent.tag != "body", parent.tag != "document" else { break }
            if parent.textContent.count > 20_000 { break }
            candidate = parent
        }
        return candidate
    }

    private static func extractAuthor(from container: ChatHTMLNode, excluding date: String) -> String? {
        let explicit = container.descendants { node in
            let classes = node.classNames
            return classes.contains("_a6-h") || classes.contains("sender") || classes.contains("author") || classes.contains("user")
        }.map(\.textContent).first { !$0.isEmpty && $0 != date }
        if let explicit { return explicit }
        let candidates = container.children.map(\.textContent).filter { !$0.isEmpty && $0 != date }
        guard let first = candidates.first, first.count <= 200, !InstagramDateParser.looksLikeDate(first) else { return nil }
        return first
    }

    private static func extractContent(from container: ChatHTMLNode, author: String?, dateText: String) -> String {
        let contentNodes = container.descendants { node in
            let classes = node.classNames
            return classes.contains("_a6-p") || classes.contains("content") || classes.contains("message-text")
        }
        if let explicit = contentNodes.map(\.textContent).first(where: { !$0.isEmpty && $0 != author && $0 != dateText }) { return explicit }
        var parts = container.children.map(\.textContent).filter { !$0.isEmpty && $0 != author && $0 != dateText && !InstagramDateParser.looksLikeDate($0) }
        if parts.isEmpty {
            parts = container.ownText.map { $0.chatHTMLDecoded.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty && $0 != author && $0 != dateText }
        }
        return parts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractMedia(from container: ChatHTMLNode) -> [(tag: String, path: String)] {
        container.descendants { ["img", "video", "audio", "source", "a"].contains($0.tag) }.compactMap { node in
            let value = node.attributes["src"] ?? node.attributes["href"]
            guard let value, !value.isEmpty else { return nil }
            if node.tag == "a" && !isExternal(value) && !value.contains("/") { return nil }
            return (node.tag, value)
        }
    }

    private static func isExternal(_ value: String) -> Bool {
        let lower = value.lowercased()
        return lower.hasPrefix("http://") || lower.hasPrefix("https://") || lower.hasPrefix("mailto:") || lower.hasPrefix("data:")
    }

    private static func resolve(href: String, relativeTo pagePath: String, baseHref: String?) throws -> String {
        guard !isExternal(href) else { return href }
        let decoded = href.removingPercentEncoding ?? href
        var baseComponents = pagePath.split(separator: "/").map(String.init)
        if !baseComponents.isEmpty { baseComponents.removeLast() }
        if let baseHref, !baseHref.isEmpty, !isExternal(baseHref) {
            baseComponents = try resolveComponents(baseHref, from: baseComponents)
            if !baseHref.hasSuffix("/") && !baseComponents.isEmpty { baseComponents.removeLast() }
        }
        return try resolveComponents(decoded, from: baseComponents).joined(separator: "/")
    }

    private static func resolveComponents(_ relative: String, from base: [String]) throws -> [String] {
        let cleaned = relative.replacingOccurrences(of: "\\", with: "/")
        guard !cleaned.hasPrefix("/") else { throw ChatAnalyzerError.archiveUnsafe(relative) }
        var output = base
        for component in cleaned.split(separator: "/", omittingEmptySubsequences: true).map(String.init) {
            if component == "." { continue }
            if component == ".." {
                guard !output.isEmpty else { throw ChatAnalyzerError.archiveUnsafe(relative) }
                output.removeLast()
            } else {
                guard !component.contains("\0") else { throw ChatAnalyzerError.archiveUnsafe(relative) }
                output.append(component)
            }
        }
        return output
    }

    private static func parentPath(of path: String) -> String {
        path.split(separator: "/", omittingEmptySubsequences: true).dropLast().joined(separator: "/")
    }

    private static func pageNumber(from path: String) -> Int? {
        let name = URL(fileURLWithPath: path).lastPathComponent
        guard let match = name.range(of: #"(?i)^message_(\d+)\.html$"#, options: .regularExpression) else { return nil }
        let number = name[match].replacingOccurrences(of: #"(?i)^message_|\.html$"#, with: "", options: .regularExpression)
        return Int(number)
    }

    private static func isMessagePath(_ path: String) -> Bool {
        let lower = "/" + path.lowercased()
        return lower.contains("/messages/inbox/") || lower.contains("/messages/message_requests/") || lower.contains("/messages/broadcast/") || lower.contains("/messages/secret")
    }

    private static func category(for path: String) -> ChatCategory {
        let lower = path.lowercased()
        if lower.contains("/message_requests/") { return .messageRequest }
        if lower.contains("/broadcast/") || lower.contains("igd_broadcast") { return .broadcast }
        if lower.contains("/secret") { return .secret }
        return .chat
    }

    private static func fallbackDisplayName(folder: String) -> String {
        let raw = folder.split(separator: "/", omittingEmptySubsequences: true).last.map(String.init) ?? ""
        let withoutSuffix = raw.replacingOccurrences(of: #"_[0-9]+$"#, with: "", options: .regularExpression)
        let value = withoutSuffix.replacingOccurrences(of: "_", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Conversación de Instagram" : value
    }
}

private enum InstagramDateParser {
    private static let months: [String: Int] = [
        "ene": 1, "enero": 1, "jan": 1, "january": 1,
        "feb": 2, "febrero": 2, "february": 2,
        "mar": 3, "marzo": 3, "march": 3,
        "abr": 4, "abril": 4, "apr": 4, "april": 4,
        "may": 5, "mayo": 5,
        "jun": 6, "junio": 6, "june": 6,
        "jul": 7, "julio": 7, "july": 7,
        "ago": 8, "agosto": 8, "aug": 8, "august": 8,
        "sep": 9, "sept": 9, "septiembre": 9, "setiembre": 9, "september": 9,
        "oct": 10, "octubre": 10, "october": 10,
        "nov": 11, "noviembre": 11, "november": 11,
        "dic": 12, "diciembre": 12, "dec": 12, "december": 12
    ]

    static func looksLikeDate(_ text: String) -> Bool { parse(text, strategy: .noConversion, numericOrder: .dayMonthYear) != nil }

    static func parse(_ raw: String, strategy: InstagramTimeZoneStrategy, numericOrder: AmbiguousNumericDateOrder) -> (date: Date, uncertain: Bool)? {
        let value = raw.replacingOccurrences(of: "\u{00A0}", with: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_ES"))
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let monthFirst = #"^([a-z]+)\s+(\d{1,2}),?\s+(\d{4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([ap]m)?$"#
        let dayFirst = #"^(\d{1,2})\s+([a-z]+)\s+(\d{4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([ap]m)?$"#
        let numeric = #"^(\d{1,2})[/-](\d{1,2})[/-](\d{4})[,\s]+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([ap]m)?$"#
        var components: (Int, Int, Int, Int, Int, Int, String?)?
        var uncertain = false
        if let values = captures(monthFirst, value), let month = months[values[0]] {
            components = (Int(values[1])!, month, Int(values[2])!, Int(values[3])!, Int(values[4])!, Int(values[5]) ?? 0, values[6].isEmpty ? nil : values[6])
        } else if let values = captures(dayFirst, value), let month = months[values[1]] {
            components = (Int(values[0])!, month, Int(values[2])!, Int(values[3])!, Int(values[4])!, Int(values[5]) ?? 0, values[6].isEmpty ? nil : values[6])
        } else if let values = captures(numeric, value) {
            var first = Int(values[0])!
            var second = Int(values[1])!
            uncertain = first <= 12 && second <= 12 && first != second
            if numericOrder == .monthDayYear { swap(&first, &second) }
            components = (first, second, Int(values[2])!, Int(values[3])!, Int(values[4])!, Int(values[5]) ?? 0, values[6].isEmpty ? nil : values[6])
        }
        guard var c = components else { return nil }
        if c.6 == "pm" && c.3 < 12 { c.3 += 12 }
        if c.6 == "am" && c.3 == 12 { c.3 = 0 }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = strategy.sourceTimeZone
        let dateComponents = DateComponents(calendar: calendar, timeZone: strategy.sourceTimeZone, year: c.2, month: c.1, day: c.0, hour: c.3, minute: c.4, second: c.5)
        guard let date = calendar.date(from: dateComponents) else { return nil }
        return (date, uncertain)
    }

    private static func captures(_ pattern: String, _ value: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern), let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)), match.range.location != NSNotFound else { return nil }
        return (1..<match.numberOfRanges).map { index in
            guard match.range(at: index).location != NSNotFound, let range = Range(match.range(at: index), in: value) else { return "" }
            return String(value[range])
        }
    }
}
