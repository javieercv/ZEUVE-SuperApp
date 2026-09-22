import XCTest
@testable import ChatAnalyzerModule
import ZEUVEStorage
import ZEUVECore

final class ChatAnalyzerTests: XCTestCase {
    func testManifestIsPrivateAndValid() throws {
        let manifest = try ChatAnalyzerModuleDefinition.manifest()
        XCTAssertEqual(manifest.identifier, chatAnalyzerModuleIdentifier)
        XCTAssertEqual(manifest.technology, .swift)
        XCTAssertEqual(manifest.executionMode, .builtIn)
        XCTAssertEqual(manifest.permissions, [.readUserSelectedFiles])
        XCTAssertFalse(manifest.permissions.contains(.networkAccess))
    }

    func testSafeArchivePathRejectsTraversalAndAbsolutePaths() throws {
        XCTAssertThrowsError(try SafeArchivePath.normalize("../secret.txt"))
        XCTAssertThrowsError(try SafeArchivePath.normalize("/tmp/secret.txt"))
        XCTAssertEqual(try SafeArchivePath.normalize("folder/chat.txt"), "folder/chat.txt")
        XCTAssertTrue(SafeArchivePath.shouldIgnore("__MACOSX/._chat.txt"))
    }

    func testArchiveRejectsEntriesThatNormalizeToTheSamePath() throws {
        let folder = try temporaryDirectory()
        let nested = folder.appendingPathComponent("folder", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data("hola".utf8).write(to: nested.appendingPathComponent("chat.txt"))
        let zip = try zipWithNormalizedDuplicate(in: folder)
        let reader = ChatArchiveReader(url: zip, limits: .init())

        XCTAssertThrowsError(try reader.catalog()) { error in
            guard case ChatAnalyzerError.archiveUnsafe(let detail) = error else {
                return XCTFail("Se esperaba archiveUnsafe y se obtuvo \(error)")
            }
            XCTAssertTrue(detail.contains("entrada duplicada"))
        }
    }

    func testArchiveStreamingCancellationStopsBetweenChunks() throws {
        let folder = try temporaryDirectory()
        let data = Data(repeating: 0x41, count: 512 * 1_024)
        try data.write(to: folder.appendingPathComponent("chat.txt"))
        let zip = try zipDirectory(folder)
        let reader = ChatArchiveReader(url: zip, limits: .init())
        let token = ChatCancellationToken()
        var received = 0

        XCTAssertThrowsError(
            try reader.stream(path: "chat.txt", chunkSize: 8 * 1_024, cancellation: { token.isCancelled }) { chunk in
                received += chunk.count
                token.cancel()
            }
        ) { error in
            XCTAssertEqual(error as? ChatAnalyzerError, .cancelled)
        }
        XCTAssertGreaterThan(received, 0)
        XCTAssertLessThan(received, data.count)
    }

    func testWhatsAppParsesVariantsMultilineAndAttachments() throws {
        let text = """
        \u{FEFF}[7/2/25, 0:20:54] Ana: Hola: qué tal
        segunda línea
        [07/02/2025, 12:21 PM] Bob: <adjunto: foto.webp>
        7-2-2025, 13:22 - Ana: imagen omitida
        [7/2/25, 13:23] Ana cambió el asunto
        """
        let url = try temporaryFile(name: "chat.txt", data: Data(text.utf8))
        let result = try WhatsAppImporter(settings: .init()).importText(at: url)
        XCTAssertEqual(result.messages.count, 4)
        XCTAssertEqual(result.messages[0].text, "Hola: qué tal\nsegunda línea")
        XCTAssertEqual(result.messages[1].contentType, .image)
        XCTAssertEqual(result.messages[2].contentType, .image)
        XCTAssertTrue(result.messages[3].isSystem)
    }

    func testWhatsAppArchiveInspectionAndMissingAttachment() throws {
        let folder = try temporaryDirectory()
        try Data("[7/2/25, 10:00] Ana: <adjunto: missing.jpg>\n".utf8).write(to: folder.appendingPathComponent("_chat.txt"))
        try Data([1, 2, 3]).write(to: folder.appendingPathComponent("other.webp"))
        let zip = try zipDirectory(folder)
        let importer = WhatsAppImporter(settings: .init())
        let inspection = try importer.inspectArchive(at: zip)
        XCTAssertEqual(inspection.validTextCandidates, ["_chat.txt"])
        let result = try importer.importArchive(at: zip)
        XCTAssertEqual(result.summary.missingAttachments, 1)
        XCTAssertEqual(result.summary.unreferencedAttachments, 1)
    }

    func testInstagramCatalogAndMultiplePages() throws {
        let folder = try temporaryDirectory()
        let root = folder.appendingPathComponent("export/your_instagram_activity/messages/inbox/ana_123", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let recent = metaHTML(author: "Ana", text: "Reciente", date: "ene. 16, 2026 1:35 pm")
        let old = metaHTML(author: "Yo", text: "Antiguo", date: "sept. 25, 2025 11:30 am")
        try Data(recent.utf8).write(to: root.appendingPathComponent("message_1.html"))
        try Data(old.utf8).write(to: root.appendingPathComponent("message_2.html"))
        let index = folder.appendingPathComponent("export/your_instagram_activity/messages/chats.html")
        try FileManager.default.createDirectory(at: index.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("<a href=\"inbox/ana_123/message_1.html\">Ana visible</a>".utf8).write(to: index)
        let zip = try zipDirectory(folder)
        let importer = InstagramImporter(settings: .init())
        let catalog = try importer.catalogArchive(at: zip)
        XCTAssertEqual(catalog.conversations.count, 1)
        XCTAssertEqual(catalog.conversations[0].displayName, "Ana visible")
        let result = try importer.importArchive(at: zip, conversationID: catalog.conversations[0].id)
        XCTAssertEqual(result.messages.map(\.text), ["Antiguo", "Reciente"])
        XCTAssertEqual(result.summary.processedHTMLPages, 2)
    }

    func testWhatsAppLargeTextIsDetectedWithoutApplyingSampleSizeAsFileLimit() throws {
        let folder = try temporaryDirectory()
        var text = "[7/2/25, 10:00] Ana: Inicio\n"
        text += String(repeating: "línea adicional para superar el tamaño de la muestra\n", count: 7_000)
        XCTAssertGreaterThan(Data(text.utf8).count, 256 * 1_024)
        try Data(text.utf8).write(to: folder.appendingPathComponent("_chat.txt"))
        let zip = try zipDirectory(folder)
        let importer = WhatsAppImporter(settings: .init())
        let inspection = try importer.inspectArchive(at: zip)
        XCTAssertEqual(inspection.validTextCandidates, ["_chat.txt"])
        XCTAssertEqual(try importer.importArchive(at: zip).messages.count, 1)
    }

    func testDirectWhatsAppTextMarksAttachmentsAsUnverifiedAndRecognizesStickerFilenames() throws {
        let text = """
        [7/2/25, 10:00] Ana: <adjunto: 00000110-STICKER-2025-02-07-00-36-15.webp>
        [7/2/25, 10:01] Ana: <adjunto: foto.webp>
        """
        let url = try temporaryFile(name: "chat.txt", data: Data(text.utf8))
        let result = try WhatsAppImporter(settings: .init()).importText(at: url)
        XCTAssertEqual(result.messages.map(\.contentType), [.sticker, .image])
        XCTAssertEqual(result.summary.referencedAttachments, 2)
        XCTAssertEqual(result.summary.unverifiedAttachments, 2)
        XCTAssertEqual(result.summary.missingAttachments, 0)
    }

    func testConversationFileLimitIsOptionalAndRejectsWithoutPartialAnalysis() throws {
        let text = "[7/2/25, 10:00] Ana: " + String(repeating: "x", count: 4_096)
        let url = try temporaryFile(name: "chat.txt", data: Data(text.utf8))
        XCTAssertNoThrow(try WhatsAppImporter(settings: .init()).importText(at: url))
        var limited = ChatAnalyzerSettings()
        limited.conversationFileMaximumBytes = 1_024
        XCTAssertThrowsError(try WhatsAppImporter(settings: limited).importText(at: url)) { error in
            guard case let ChatAnalyzerError.conversationFileLimit(name, size, maximum) = error else {
                return XCTFail("Se esperaba conversationFileLimit y se obtuvo \(error)")
            }
            XCTAssertEqual(name, "chat.txt")
            XCTAssertGreaterThan(size, maximum)
            XCTAssertEqual(maximum, 1_024)
        }
    }

    func testInstagramSingleConversationZipAndRebasedAttachmentPaths() throws {
        let folder = try temporaryDirectory()
        let chat = folder.appendingPathComponent("conversacion_123", isDirectory: true)
        let photos = chat.appendingPathComponent("photos", isDirectory: true)
        try FileManager.default.createDirectory(at: photos, withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: photos.appendingPathComponent("foto.jpg"))
        let html = """
        <html><head><base href="../../../../"></head><body>
        <div class="_a6-g">
          <div class="_a6-h">Ana</div>
          <div class="_a6-p">Foto</div>
          <img src="your_instagram_activity/messages/inbox/conversacion_123/photos/foto.jpg">
          <div class="_a6-o">January 1, 2026 10:00 am</div>
        </div>
        </body></html>
        """
        try Data(html.utf8).write(to: chat.appendingPathComponent("message_1.html"))
        let zip = try zipDirectory(folder)
        let importer = InstagramImporter(settings: .init())
        let catalog = try importer.catalogArchive(at: zip)
        XCTAssertEqual(catalog.conversations.count, 1)
        XCTAssertEqual(catalog.conversations[0].displayName, "conversacion")
        let result = try importer.importArchive(at: zip, conversationID: catalog.conversations[0].id)
        let attachment = try XCTUnwrap(result.messages.first?.attachment)
        XCTAssertEqual(attachment.path, "conversacion_123/photos/foto.jpg")
        XCTAssertTrue(attachment.exists)
        XCTAssertEqual(result.summary.missingAttachments, 0)
    }

    func testInstagramDuplicateDisplayNamesRemainDistinct() throws {
        let folder = try temporaryDirectory()
        for suffix in ["one_1", "two_2"] {
            let root = folder.appendingPathComponent("messages/inbox/\(suffix)", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try Data(metaHTML(author: "Ana", text: suffix, date: "January 1, 2026 10:00 am").utf8).write(to: root.appendingPathComponent("message_1.html"))
        }
        let index = folder.appendingPathComponent("messages/chats.html")
        try Data("<a href=\"inbox/one_1/message_1.html\">Igual</a><a href=\"inbox/two_2/message_1.html\">Igual</a>".utf8).write(to: index)
        let catalog = try InstagramImporter(settings: .init()).catalogArchive(at: zipDirectory(folder))
        XCTAssertEqual(Set(catalog.conversations.map(\.id)).count, 2)
        XCTAssertTrue(catalog.conversations.allSatisfy(\.duplicateDisplayName))
    }

    func testFiltersSupportOvernightWindow() {
        let messages = [message(author: "A", hour: 23), message(author: "A", hour: 3), message(author: "A", hour: 12)]
        let filter = ChatFilter(startHour: 22, endHour: 5)
        XCTAssertEqual(ChatAnalytics.filtered(messages, by: filter).count, 2)
    }

    func testWordsBigramsAndCompoundEmoji() {
        let messages = [message(text: "Hola qué tal. Hola qué tal 👨‍👩‍👧‍👦 👍🏽")]
        XCTAssertEqual(ChatAnalytics.words(messages, includeStopWords: false).first?.value, "hola")
        XCTAssertTrue(ChatAnalytics.bigrams(messages, includeStopWords: true).contains { $0.value == "hola qué" })
        let emojis = ChatAnalytics.emojis(messages)
        XCTAssertTrue(emojis.contains { $0.value == "👨‍👩‍👧‍👦" })
        XCTAssertTrue(emojis.contains { $0.value == "👍🏽" })
    }

    func testConversationsThresholdEqualityAndResponseTurns() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let messages = [
            message(author: "A", date: base),
            message(author: "A", date: base.addingTimeInterval(60)),
            message(author: "B", date: base.addingTimeInterval(180)),
            message(author: "A", date: base.addingTimeInterval(180 + 3_600)),
            message(author: "B", date: base.addingTimeInterval(180 + 7_201))
        ]
        let stats = ChatAnalytics.conversations(messages, threshold: 3_600)
        XCTAssertEqual(stats.conversations.count, 2)
        let response = ChatAnalytics.responseTimes(conversations: stats.conversations, maximumWindow: 24 * 3_600)
        XCTAssertEqual(response.samples.count, 2)
        XCTAssertEqual(response.samples.first?.delay, 120)
    }

    func testSearchContextDoesNotCrossSixHourGap() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let messages = [message(text: "antes", date: base), message(text: "objetivo", date: base.addingTimeInterval(7 * 3_600)), message(text: "después", date: base.addingTimeInterval(7 * 3_600 + 60))]
        var options = ChatSearchOptions(); options.query = "objetivo"; options.contextMessages = 1
        let result = ChatAnalytics.search(messages, filter: .init(), options: options)
        XCTAssertEqual(result.totalMessages, 1)
        XCTAssertTrue(result.matches[0].before.isEmpty)
        XCTAssertEqual(result.matches[0].after.count, 1)
    }

    func testHistoryPayloadContainsNoPrivateContent() throws {
        let temp = try temporaryDirectory().appendingPathComponent("history.sqlite")
        let container = try StorageContainer(databaseURL: temp)
        let now = Date()
        var summary = ChatImportSummary(); summary.sourceCount = 1; summary.processedFiles = 1
        let privateMessage = message(author: "Nombre privado", text: "Texto privado y secreto", date: now)
        let result = ChatAnalysisResult(id: UUID(), startedAt: now, finishedAt: now, messages: [privateMessage], summary: summary, settings: .init())
        try ChatAnalyzerHistoryService(repository: container.history).save(result)
        let record = try XCTUnwrap(container.history.records(moduleID: chatAnalyzerModuleIdentifier).first)
        let raw = String(data: record.payload, encoding: .utf8) ?? ""
        XCTAssertFalse(raw.contains("Nombre privado"))
        XCTAssertFalse(raw.contains("Texto privado"))
        XCTAssertNil(record.baseFolder)
    }


    func testSafeArchivePathAcceptsHarmlessDotComponents() throws {
        XCTAssertEqual(try SafeArchivePath.normalize("./folder/./chat.txt"), "folder/chat.txt")
    }

    func testInstagramExternalLinkIsNeverResolvedAsAttachment() throws {
        let html = #"<html><body><div class="_a6-g"><div class="_a6-h">Ana</div><div class="_a6-p">Mira esto</div><a href="https://example.invalid/private">enlace</a><div class="_a6-o">January 1, 2026 10:00 am</div></div></body></html>"#
        let url = try temporaryFile(name: "message_1.html", data: Data(html.utf8))
        let result = try InstagramImporter(settings: .init()).importHTMLFiles([url])
        let message = try XCTUnwrap(result.messages.first)
        XCTAssertEqual(message.contentType, .link)
        XCTAssertNil(message.attachment)
        XCTAssertEqual(result.summary.referencedAttachments, 0)
    }

    func testInstagramTimeZoneStrategiesUseRealZones() throws {
        let html = metaHTML(author: "Ana", text: "Hora", date: "January 15, 2026 10:00 am")
        let url = try temporaryFile(name: "message_1.html", data: Data(html.utf8))
        var california = ChatAnalyzerSettings(); california.instagramTimeZone = .californiaToSpain
        var spain = ChatAnalyzerSettings(); spain.instagramTimeZone = .alreadySpain
        let californiaDate = try XCTUnwrap(InstagramImporter(settings: california).importHTMLFiles([url]).messages.first?.timestamp)
        let spainDate = try XCTUnwrap(InstagramImporter(settings: spain).importHTMLFiles([url]).messages.first?.timestamp)
        XCTAssertEqual(californiaDate.timeIntervalSince(spainDate), 9 * 3_600, accuracy: 1)
    }

    func testSettingsPersistAndRestoreWithoutChangingExistingOperationCopy() throws {
        let container = try StorageContainer(databaseURL: temporaryDirectory().appendingPathComponent("settings.sqlite"))
        let service = ChatAnalyzerSettingsService(repository: container.settings)
        var defaults = ChatAnalyzerSettings(); defaults.conversationThresholdMinutes = 360; defaults.conversationFileMaximumBytes = 512 * 1_024 * 1_024
        var operation = ChatAnalyzerSettings(); operation.conversationThresholdMinutes = 30
        try service.save(defaults)
        XCTAssertEqual(service.load().conversationThresholdMinutes, 360)
        XCTAssertEqual(service.load().conversationFileMaximumBytes, 512 * 1_024 * 1_024)
        XCTAssertEqual(operation.conversationThresholdMinutes, 30)
        operation.responseWindowMinutes = 60
        try service.restoreDefaults()
        XCTAssertEqual(service.load(), ChatAnalyzerSettings())
        XCTAssertEqual(operation.responseWindowMinutes, 60)
    }

    func testTemporarySessionDeletesOwnedDatabaseAndWorkspace() throws {
        let workspace = try ChatTemporaryWorkspace(operationID: UUID())
        let directory = workspace.directory
        let store = try TemporaryChatStore(workspace: workspace)
        try store.replace(messages: [message()])
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.url.path))
        let now = Date(); var summary = ChatImportSummary(); summary.recognizedMessages = 1
        let result = ChatAnalysisResult(id: UUID(), startedAt: now, finishedAt: now, messages: [message()], summary: summary, settings: .init())
        let session = ChatAnalysisSession(result: result, store: store, workspace: workspace)
        session.close()
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testImportDoesNotModifyOriginalTextFile() throws {
        let data = Data("[7/2/25, 10:00] Ana: Original intacto\n".utf8)
        let url = try temporaryFile(name: "chat.txt", data: data)
        let fingerprint = try FileFingerprintSnapshot.read(url)
        _ = try WhatsAppImporter(settings: .init()).importText(at: url)
        XCTAssertEqual(try Data(contentsOf: url), data)
        XCTAssertEqual(try FileFingerprintSnapshot.read(url), fingerprint)
    }

    func testCancellationStopsWhatsAppImportBeforeReadingMessages() throws {
        let url = try temporaryFile(name: "chat.txt", data: Data("[7/2/25, 10:00] Ana: Hola\n".utf8))
        XCTAssertThrowsError(try WhatsAppImporter(settings: .init()).importText(at: url, cancellation: { true })) { error in
            XCTAssertEqual(error as? ChatAnalyzerError, .cancelled)
        }
    }

    func testDeduplicationPreservesDistinctMessagesInSameSecond() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let first = NormalizedMessage(id: "one", conversationID: "c", timestamp: date, originalDateText: "", timeZoneStrategy: "", author: "A", text: "igual", platform: .whatsapp, contentType: .text, sourceFile: "chat.txt", sourcePosition: 1)
        let second = NormalizedMessage(id: "two", conversationID: "c", timestamp: date, originalDateText: "", timeZoneStrategy: "", author: "A", text: "igual", platform: .whatsapp, contentType: .text, sourceFile: "chat.txt", sourcePosition: 2)
        let result = MessageDeduplicator.deduplicate([first, second])
        XCTAssertEqual(result.messages.count, 2)
        XCTAssertEqual(result.removed, 0)
    }

    func testInstagramNumericDateOrderIsAppliedAndMarkedUncertain() throws {
        let html = metaHTML(author: "Ana", text: "Ambigua", date: "07/02/2026 10:00")
        let url = try temporaryFile(name: "message_1.html", data: Data(html.utf8))
        var dayFirst = ChatAnalyzerSettings(); dayFirst.numericDateOrder = .dayMonthYear; dayFirst.instagramTimeZone = .alreadySpain
        var monthFirst = ChatAnalyzerSettings(); monthFirst.numericDateOrder = .monthDayYear; monthFirst.instagramTimeZone = .alreadySpain
        let first = try XCTUnwrap(InstagramImporter(settings: dayFirst).importHTMLFiles([url]).messages.first)
        let second = try XCTUnwrap(InstagramImporter(settings: monthFirst).importHTMLFiles([url]).messages.first)
        let calendar = ChatAnalytics.calendar
        XCTAssertEqual(calendar.component(.day, from: first.timestamp), 7)
        XCTAssertEqual(calendar.component(.month, from: first.timestamp), 2)
        XCTAssertEqual(calendar.component(.day, from: second.timestamp), 2)
        XCTAssertEqual(calendar.component(.month, from: second.timestamp), 7)
        XCTAssertTrue(first.hasUncertainDate)
        XCTAssertTrue(second.hasUncertainDate)
    }

    func testHistorySupportsCancelledAndFailedStatusesWithoutPrivateData() throws {
        let container = try StorageContainer(databaseURL: temporaryDirectory().appendingPathComponent("history-status.sqlite"))
        let service = ChatAnalyzerHistoryService(repository: container.history)
        var summary = ChatImportSummary(); summary.sourceCount = 2; summary.processedFiles = 3
        let privateMessage = message(author: "Persona confidencial", text: "Contenido confidencial")
        let started = Date(timeIntervalSince1970: 1_700_000_000)
        try service.save(id: UUID(), startedAt: started, finishedAt: started.addingTimeInterval(1), summary: summary, messages: [privateMessage], status: .cancelled)
        try service.save(id: UUID(), startedAt: started, finishedAt: started.addingTimeInterval(2), summary: summary, messages: [privateMessage], status: .failed)
        let records = try container.history.records(moduleID: chatAnalyzerModuleIdentifier)
        XCTAssertEqual(Set(records.map(\.status.rawValue)), Set([OperationStatus.cancelled.rawValue, OperationStatus.failed.rawValue]))
        for record in records {
            let raw = String(data: record.payload, encoding: .utf8) ?? ""
            XCTAssertFalse(raw.contains("Persona confidencial"))
            XCTAssertFalse(raw.contains("Contenido confidencial"))
            XCTAssertNil(record.baseFolder)
        }
    }

    func testWorkspaceRefusesToDeleteWithoutOwnershipMarker() throws {
        let workspace = try ChatTemporaryWorkspace(operationID: UUID())
        let directory = workspace.directory
        try FileManager.default.removeItem(at: directory.appendingPathComponent(".zeuve-chat-operation"))
        XCTAssertThrowsError(try workspace.cleanup())
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))
        try FileManager.default.removeItem(at: directory)
    }

    func testCoreSnapshotAppliesIdentityMapAndFiltersOnce() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let messages = [
            message(author: "Ana", text: "uno", date: start),
            message(author: "Ana móvil", text: "dos", date: start.addingTimeInterval(60)),
            message(author: "Luis", text: "tres", date: start.addingTimeInterval(120)),
        ]
        let filter = ChatFilter(participants: ["Ana"])
        let snapshot = ChatAnalytics.coreSnapshot(
            messages: messages,
            identityMap: ["Ana móvil": "Ana"],
            filter: filter
        )
        XCTAssertEqual(snapshot.messages.map(\.author), ["Ana", "Ana", "Luis"])
        XCTAssertEqual(snapshot.filteredMessages.count, 2)
        XCTAssertEqual(snapshot.summary.includedMessages, 2)
        XCTAssertEqual(snapshot.participantNames, ["Ana", "Luis"])
    }

    func testSearchIndexCanChangePagesWithoutRepeatingTheQuery() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let messages = (0..<60).map { index in
            message(author: index.isMultiple(of: 2) ? "A" : "B", text: "hola número \(index)", date: start.addingTimeInterval(Double(index)))
        }
        var options = ChatSearchOptions()
        options.query = "hola"
        options.pageSize = 25
        let index = ChatAnalytics.searchIndex(messages, filter: ChatFilter(), options: options)
        XCTAssertEqual(index.hits.count, 60)
        XCTAssertEqual(index.totalOccurrences, 60)

        let first = ChatAnalytics.searchResult(messages, index: index, options: options)
        XCTAssertEqual(first.matches.count, 25)
        XCTAssertEqual(first.matches.first?.message.text, "hola número 0")

        options.page = 2
        let third = ChatAnalytics.searchResult(messages, index: index, options: options)
        XCTAssertEqual(third.matches.count, 10)
        XCTAssertEqual(third.matches.first?.message.text, "hola número 50")
        XCTAssertEqual(third.totalMessages, first.totalMessages)
        XCTAssertEqual(third.totalOccurrences, first.totalOccurrences)
    }


    func testCompactSearchCacheMatchesDirectSearch() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let messages = [
            message(author: "A", text: "ÁRBOL y café", date: start),
            message(author: "B", text: "arbolado", date: start.addingTimeInterval(1)),
            message(author: "C", text: "Café árbol árbol", date: start.addingTimeInterval(2)),
        ]
        let directory = try temporaryDirectory().appendingPathComponent("search-index", isDirectory: true)
        let cache = ChatSearchTextCache(directory: directory)
        var options = ChatSearchOptions()
        options.query = "árbol"
        options.ignoreCase = true
        options.ignoreDiacritics = true
        options.wholeWords = true

        let compact = try cache.index(
            for: messages,
            ignoreCase: options.ignoreCase,
            ignoreDiacritics: options.ignoreDiacritics
        )
        let direct = ChatAnalytics.searchIndex(messages, filter: ChatFilter(), options: options)
        let cached = ChatAnalytics.searchIndex(
            messages,
            filter: ChatFilter(),
            options: options,
            textIndex: compact
        )

        XCTAssertEqual(cached, direct)
        XCTAssertEqual(cached.hits.count, 2)
        XCTAssertEqual(cached.totalOccurrences, 3)
        XCTAssertFalse(compact.isFileBacked)
    }

    func testLargeCompactSearchCacheUsesTemporaryMappedStorageAndCleansIt() throws {
        let messages = (0..<200).map { index in
            message(text: "mensaje número \(index) con bastante texto para forzar almacenamiento temporal")
        }
        let directory = try temporaryDirectory().appendingPathComponent("mapped-search-index", isDirectory: true)
        let cache = ChatSearchTextCache(directory: directory, memoryThresholdBytes: 1 * 1_024 * 1_024)
        // El mínimo interno es 1 MiB: se añade un mensaje grande para superar el umbral sin imponer un límite funcional.
        let largeMessages = messages + [message(text: String(repeating: "contenido ", count: 150_000))]
        let index = try cache.index(for: largeMessages, ignoreCase: true, ignoreDiacritics: true)

        XCTAssertTrue(index.isFileBacked)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))
        cache.clear()
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testSectionSnapshotsMatchDirectAnalytics() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let messages = (0..<120).map { index in
            message(
                author: index.isMultiple(of: 3) ? "A" : "B",
                text: index.isMultiple(of: 5) ? "hola mundo 😊" : "mensaje de prueba",
                date: start.addingTimeInterval(Double(index * 600))
            )
        }
        let settings = ChatAnalyzerSettings()
        let activity = ChatAnalytics.activitySnapshot(messages, granularity: .day)
        XCTAssertEqual(activity.series, ChatAnalytics.timeSeries(messages, granularity: .day))
        XCTAssertEqual(activity.hourly, ChatAnalytics.hourly(messages))
        XCTAssertEqual(activity.weekdays, ChatAnalytics.weekdays(messages))
        XCTAssertEqual(activity.heatmap, ChatAnalytics.heatmap(messages))
        XCTAssertEqual(activity.hourly.reduce(0, +), messages.count)
        XCTAssertEqual(activity.weekdays.reduce(0, +), messages.count)
        XCTAssertEqual(activity.heatmap.reduce(0) { $0 + $1.count }, messages.count)

        let participants = ChatAnalytics.participantsSnapshot(messages, settings: settings)
        XCTAssertEqual(participants.statistics.reduce(0) { $0 + $1.messages }, messages.count)

        let words = ChatAnalytics.wordsSnapshot(messages, participantNames: ["B", "A"], includeStopWords: false)
        XCTAssertEqual(words.words, ChatAnalytics.words(messages, includeStopWords: false, limit: 50))
        XCTAssertEqual(words.bigrams, ChatAnalytics.bigrams(messages, includeStopWords: false, limit: 50))
        XCTAssertEqual(words.emojis, ChatAnalytics.emojis(messages, limit: 50))
        XCTAssertEqual(words.participants.map(\.name), ["B", "A"])
        for participant in words.participants {
            let participantMessages = messages.filter { !$0.isSystem && $0.author == participant.name }
            XCTAssertEqual(participant.words, ChatAnalytics.words(participantMessages, includeStopWords: false, limit: 5))
            XCTAssertEqual(participant.emojis, ChatAnalytics.emojis(participantMessages, limit: 5))
        }

        let conversations = ChatAnalytics.conversationSnapshot(allMessages: messages, filteredMessages: messages, settings: settings)
        XCTAssertFalse(conversations.conversations.conversations.isEmpty)
        XCTAssertEqual(conversations.responses.samples, ChatAnalytics.responseTimes(
            conversations: conversations.conversations.conversations,
            maximumWindow: TimeInterval(settings.responseWindowMinutes * 60)
        ).samples)
    }

    func testLargeSyntheticSnapshotsKeepExpectedCounts() {
        let total = 35_000
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let messages = (0..<total).map { index in
            NormalizedMessage(
                id: "m-\(index)",
                conversationID: "large",
                timestamp: start.addingTimeInterval(Double(index * 30)),
                originalDateText: "",
                timeZoneStrategy: "",
                author: index.isMultiple(of: 2) ? "A" : "B",
                text: index.isMultiple(of: 10) ? "hola mundo enlace https://example.com 😊" : "mensaje sintético número \(index)",
                platform: index.isMultiple(of: 4) ? .instagram : .whatsapp,
                contentType: .text,
                sourceFile: "synthetic",
                sourcePosition: index
            )
        }
        let core = ChatAnalytics.coreSnapshot(messages: messages, identityMap: [:], filter: ChatFilter())
        XCTAssertEqual(core.filteredMessages.count, total)
        XCTAssertEqual(core.summary.includedMessages, total)
        XCTAssertEqual(core.participantNames, ["A", "B"])

        let activity = ChatAnalytics.activitySnapshot(core.filteredMessages, granularity: .month)
        XCTAssertEqual(activity.hourly.reduce(0, +), total)

        let participants = ChatAnalytics.participantsSnapshot(core.filteredMessages, settings: .init())
        XCTAssertEqual(participants.statistics.reduce(0) { $0 + $1.messages }, total)

        var search = ChatSearchOptions()
        search.query = "hola"
        let searchIndex = ChatAnalytics.searchIndex(core.messages, filter: ChatFilter(), options: search)
        XCTAssertEqual(searchIndex.hits.count, total / 10)
    }

    func testTemporaryStoreDeduplicatesOrdersAndPaginatesWithoutMaterializingAllMessages() throws {
        let workspace = try ChatTemporaryWorkspace(operationID: UUID())
        let store = try TemporaryChatStore(workspace: workspace)
        defer { store.closeAndDelete(); try? workspace.cleanup() }

        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let late = NormalizedMessage(id: "late", conversationID: "c", timestamp: base.addingTimeInterval(20), originalDateText: "", timeZoneStrategy: "", author: "B", text: "tarde", platform: .whatsapp, contentType: .text, sourceFile: "a", sourcePosition: 2)
        let early = NormalizedMessage(id: "early", conversationID: "c", timestamp: base, originalDateText: "", timeZoneStrategy: "", author: "A", text: "temprano", platform: .whatsapp, contentType: .text, sourceFile: "a", sourcePosition: 0)
        let middle = NormalizedMessage(id: "middle", conversationID: "c", timestamp: base.addingTimeInterval(10), originalDateText: "", timeZoneStrategy: "", author: "A", text: "medio", platform: .instagram, contentType: .text, sourceFile: "b", sourcePosition: 1)
        let duplicate = NormalizedMessage(id: "duplicate-id", conversationID: middle.conversationID, timestamp: middle.timestamp, originalDateText: middle.originalDateText, timeZoneStrategy: middle.timeZoneStrategy, author: middle.author, text: middle.text, platform: middle.platform, contentType: middle.contentType, sourceFile: middle.sourceFile, sourcePosition: middle.sourcePosition)

        XCTAssertEqual(try store.append(messages: [late, early]), 2)
        XCTAssertEqual(try store.append(messages: [middle, duplicate]), 1)
        XCTAssertEqual(try store.messageCount(), 3)
        try store.prepareTimeline()

        XCTAssertEqual(try store.messages(offset: 0, limit: 2).map(\.id), ["early", "middle"])
        XCTAssertEqual(try store.messages(offset: 2, limit: 2).map(\.id), ["late"])
        let stats = try store.statistics()
        XCTAssertEqual(stats.messages, 3)
        XCTAssertEqual(stats.participants, 2)
        XCTAssertEqual(stats.platforms, [.whatsapp, .instagram])
    }

    func testStoreAnalyticsMatchLegacyAnalyticsForRepresentativeDataset() throws {
        let workspace = try ChatTemporaryWorkspace(operationID: UUID())
        let store = try TemporaryChatStore(workspace: workspace)
        defer { store.closeAndDelete(); try? workspace.cleanup() }

        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let messages = (0..<120).map { index in
            NormalizedMessage(
                id: "m-\(index)", conversationID: "c", timestamp: base.addingTimeInterval(Double(index * 90)),
                originalDateText: "", timeZoneStrategy: "", author: index.isMultiple(of: 3) ? "Ana" : "Bob",
                text: index.isMultiple(of: 5) ? "hola mundo 😊" : "mensaje numero \(index)",
                platform: index.isMultiple(of: 4) ? .instagram : .whatsapp,
                contentType: .text, sourceFile: "fixture", sourcePosition: index
            )
        }
        XCTAssertEqual(try store.append(messages: messages), messages.count)
        try store.prepareTimeline()

        let filter = ChatFilter()
        let settings = ChatAnalyzerSettings()
        let legacyCore = ChatAnalytics.coreSnapshot(messages: messages, identityMap: [:], filter: filter)
        let storeCore = try ChatStoreAnalytics.coreSnapshot(store: store, identityMap: [:], filter: filter)
        XCTAssertEqual(storeCore.totalMessages, legacyCore.messages.count)
        XCTAssertEqual(storeCore.filteredMessageCount, legacyCore.filteredMessages.count)
        XCTAssertEqual(storeCore.participantNames, legacyCore.participantNames)
        XCTAssertEqual(storeCore.summary, legacyCore.summary)

        XCTAssertEqual(
            try ChatStoreAnalytics.activitySnapshot(store: store, identityMap: [:], filter: filter, granularity: .month),
            ChatAnalytics.activitySnapshot(legacyCore.filteredMessages, granularity: .month)
        )
        XCTAssertEqual(
            try ChatStoreAnalytics.participantsSnapshot(store: store, identityMap: [:], filter: filter, settings: settings).statistics,
            ChatAnalytics.participantsSnapshot(legacyCore.filteredMessages, settings: settings).statistics
        )
        XCTAssertEqual(
            try ChatStoreAnalytics.wordsSnapshot(store: store, identityMap: [:], filter: filter, participantNames: legacyCore.participantNames, includeStopWords: settings.includeStopWords),
            ChatAnalytics.wordsSnapshot(legacyCore.filteredMessages, participantNames: legacyCore.participantNames, includeStopWords: settings.includeStopWords)
        )

        let legacyConversation = ChatAnalytics.conversationSnapshot(allMessages: legacyCore.messages, filteredMessages: legacyCore.filteredMessages, settings: settings)
        let storeConversation = try ChatStoreAnalytics.conversationSnapshot(store: store, identityMap: [:], filter: filter, settings: settings)
        XCTAssertEqual(storeConversation.conversations.totalCount, legacyConversation.conversations.totalCount)
        XCTAssertEqual(storeConversation.conversations.averageDuration, legacyConversation.conversations.averageDuration, accuracy: 0.0001)
        XCTAssertEqual(storeConversation.conversations.medianDuration, legacyConversation.conversations.medianDuration, accuracy: 0.0001)
        XCTAssertEqual(storeConversation.conversations.averageMessages, legacyConversation.conversations.averageMessages, accuracy: 0.0001)
        XCTAssertEqual(storeConversation.conversations.singleParticipantCount, legacyConversation.conversations.singleParticipantCount)
        XCTAssertEqual(storeConversation.conversations.unansweredCount, legacyConversation.conversations.unansweredCount)
        XCTAssertEqual(storeConversation.responses.sampleCount, legacyConversation.responses.sampleCount)
        XCTAssertEqual(storeConversation.responses.average, legacyConversation.responses.average)
        XCTAssertEqual(storeConversation.responses.median, legacyConversation.responses.median)
        XCTAssertEqual(storeConversation.responses.fastest, legacyConversation.responses.fastest)
        XCTAssertEqual(storeConversation.responses.slowest, legacyConversation.responses.slowest)
        XCTAssertEqual(storeConversation.responses.percentile25, legacyConversation.responses.percentile25)
        XCTAssertEqual(storeConversation.responses.percentile75, legacyConversation.responses.percentile75)
        XCTAssertEqual(storeConversation.responses.participants, legacyConversation.responses.participants)
        XCTAssertEqual(storeConversation.responses.distribution, legacyConversation.responses.distribution)
        XCTAssertTrue(storeConversation.responses.samples.isEmpty)

        var search = ChatSearchOptions()
        search.query = "hola"
        search.pageSize = 25
        search.contextMessages = 1
        XCTAssertEqual(
            try ChatStoreAnalytics.searchResult(store: store, identityMap: [:], filter: filter, options: search),
            ChatAnalytics.search(legacyCore.messages, filter: filter, options: search)
        )
    }

    private func message(author: String = "A", text: String = "hola", date: Date? = nil, hour: Int? = nil) -> NormalizedMessage {
        var value = date ?? Date(timeIntervalSince1970: 1_700_000_000)
        if let hour { value = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: value)! }
        return NormalizedMessage(id: UUID().uuidString, conversationID: "c", timestamp: value, originalDateText: "", timeZoneStrategy: "", author: author, text: text, platform: .whatsapp, contentType: .text, sourceFile: "synthetic", sourcePosition: 0)
    }

    private func metaHTML(author: String, text: String, date: String) -> String {
        "<html><body><div class=\"_a6-g\"><div class=\"_a6-h\">\(author)</div><div class=\"_a6-p\">\(text)</div><div class=\"_a6-o\">\(date)</div></div></body></html>"
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ZEUVEChatTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func temporaryFile(name: String, data: Data) throws -> URL {
        let folder = try temporaryDirectory(); let url = folder.appendingPathComponent(name); try data.write(to: url); return url
    }

    private func zipWithNormalizedDuplicate(in folder: URL) throws -> URL {
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("ZEUVEChatDuplicate-\(UUID().uuidString).zip")
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = folder
        process.arguments = ["-q", destination.path, "folder/chat.txt", "folder//chat.txt"]
        try process.run(); process.waitUntilExit(); XCTAssertEqual(process.terminationStatus, 0)
        addTeardownBlock { try? FileManager.default.removeItem(at: destination) }
        return destination
    }

    private func zipDirectory(_ folder: URL) throws -> URL {
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("ZEUVEChatTests-\(UUID().uuidString).zip")
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = folder; process.arguments = ["-q", "-r", destination.path, "."]
        try process.run(); process.waitUntilExit(); XCTAssertEqual(process.terminationStatus, 0)
        addTeardownBlock { try? FileManager.default.removeItem(at: destination) }
        return destination
    }
}
