import Foundation
import SwiftUI
import UniformTypeIdentifiers
import ZEUVECore
import ZEUVEStorage
import ZEUVEOperations
import ChatAnalyzerModule

@MainActor
enum ChatAnalyzerSection: String, CaseIterable, Identifiable {
    case summary, activity, participants, words, search, conversations, responses, comparison, fusions
    nonisolated var id: String { rawValue }
    var title: String {
        switch self {
        case .summary: return "Resumen"
        case .activity: return "Actividad"
        case .participants: return "Participantes"
        case .words: return "Palabras y emojis"
        case .search: return "Búsqueda"
        case .conversations: return "Conversaciones"
        case .responses: return "Tiempos de respuesta"
        case .comparison: return "Comparación"
        case .fusions: return "Fusiones"
        }
    }
    var icon: String {
        switch self {
        case .summary: return "rectangle.grid.2x2"
        case .activity: return "chart.xyaxis.line"
        case .participants: return "person.2"
        case .words: return "textformat"
        case .search: return "magnifyingglass"
        case .conversations: return "bubble.left.and.bubble.right"
        case .responses: return "timer"
        case .comparison: return "arrow.left.arrow.right"
        case .fusions: return "person.2.badge.gearshape"
        }
    }
}


@MainActor
enum ChatImportMode: String, CaseIterable, Identifiable {
    case whatsapp, instagram, both
    nonisolated var id: String { rawValue }
    var title: String {
        switch self {
        case .whatsapp: return "WhatsApp"
        case .instagram: return "Instagram"
        case .both: return "Ambas plataformas"
        }
    }
    func allows(_ platform: ChatPlatform) -> Bool {
        self == .both || (self == .whatsapp && platform == .whatsapp) || (self == .instagram && platform == .instagram)
    }
}

@MainActor
final class ChatAnalyzerViewModel: ObservableObject {
    @Published var inputs: [ChatInput] = []
    @Published var defaultSettings: ChatAnalyzerSettings
    @Published var operationSettings: ChatAnalyzerSettings {
        didSet {
            if !suppressAnalyticsInvalidation, oldValue != operationSettings {
                handleOperationSettingsChange(from: oldValue, to: operationSettings)
            }
        }
    }
    @Published var session: ChatAnalysisSession?
    @Published var filter = ChatFilter() {
        didSet {
            if !suppressAnalyticsInvalidation, oldValue != filter {
                if searchOptions.page != 0 { searchOptions.page = 0 }
                invalidateAnalytics(debounceNanoseconds: 120_000_000)
            }
        }
    }
    @Published var selectedSection: ChatAnalyzerSection = .summary {
        didSet {
            if !suppressAnalyticsInvalidation, oldValue != selectedSection { scheduleSelectedSection() }
        }
    }
    @Published var granularity: TimeGranularity {
        didSet {
            if !suppressAnalyticsInvalidation, oldValue != granularity {
                activityRevision = -1
                comparisonRevision = -1
                scheduleSelectedSection()
            }
        }
    }
    @Published var errorMessage: String?
    @Published var warningMessage: String?
    @Published var isAnalyzing = false
    @Published var isPreparingInput = false
    @Published var advancedMode = false
    @Published var importMode: ChatImportMode = .both
    @Published var instagramCatalogs: [URL: [InstagramConversationDescriptor]] = [:]
    @Published var instagramSelections: [URL: String] = [:]
    @Published var whatsappCandidates: [URL: [String]] = [:]
    @Published var whatsappSelections: [URL: String] = [:]
    @Published var searchOptions = ChatSearchOptions() {
        didSet {
            if !suppressAnalyticsInvalidation, oldValue != searchOptions { scheduleSearch(previous: oldValue) }
        }
    }
    @Published var selectedParticipant: String? {
        didSet {
            if !suppressAnalyticsInvalidation, oldValue != selectedParticipant { scheduleParticipantDetail() }
        }
    }
    @Published var comparisonA: String? {
        didSet {
            if !suppressAnalyticsInvalidation, oldValue != comparisonA {
                comparisonRevision = -1
                scheduleSelectedSection()
            }
        }
    }
    @Published var comparisonB: String? {
        didSet {
            if !suppressAnalyticsInvalidation, oldValue != comparisonB {
                comparisonRevision = -1
                scheduleSelectedSection()
            }
        }
    }
    @Published var fusionSelection: Set<String> = []
    @Published var fusionName = ""
    @Published private(set) var identityMap: [String: String] = [:] {
        didSet {
            if !suppressAnalyticsInvalidation, oldValue != identityMap { invalidateAnalytics(debounceNanoseconds: 0) }
        }
    }
    @Published private(set) var fusionHistory: [[String: String]] = []

    @Published private(set) var coreSnapshot: ChatStoreCoreAnalyticsSnapshot = .empty
    @Published private(set) var activitySnapshot: ChatActivityAnalyticsSnapshot = .empty
    @Published private(set) var participantsSnapshot: ChatParticipantsAnalyticsSnapshot = .empty
    @Published private(set) var wordsSnapshot: ChatWordsAnalyticsSnapshot = .empty
    @Published private(set) var conversationSnapshot: ChatConversationAnalyticsSnapshot = .empty
    @Published private(set) var comparisonSnapshot: ChatComparisonAnalyticsSnapshot = .empty
    @Published private(set) var searchResult: ChatSearchResult = .empty
    @Published private(set) var isUpdatingCore = false
    @Published private(set) var isUpdatingSection = false
    @Published private(set) var isSearching = false

    private let service: ChatAnalyzerService
    private let settingsService: ChatAnalyzerSettingsService
    private var coreTask: Task<Void, Never>?
    private var sectionTask: Task<Void, Never>?
    private var participantDetailTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var analyticsRevision = 0
    private var activityRevision = -1
    private var activityGranularity: TimeGranularity?
    private var participantsRevision = -1
    private var wordsRevision = -1
    private var conversationRevision = -1
    private var comparisonRevision = -1
    private var comparisonNames: [String] = []
    private var suppressAnalyticsInvalidation = false

    init(coordinator: OperationCoordinator, storage: StorageContainer?, logger: LocalLogger?) {
        let settingsService = ChatAnalyzerSettingsService(repository: storage?.settings)
        let loadedSettings = settingsService.load()
        self.service = ChatAnalyzerService(coordinator: coordinator, history: ChatAnalyzerHistoryService(repository: storage?.history), logger: logger)
        self.settingsService = settingsService
        defaultSettings = loadedSettings
        operationSettings = loadedSettings
        granularity = loadedSettings.granularity
        searchOptions.pageSize = loadedSettings.listLimit
        Task.detached(priority: .utility) { ChatTemporaryWorkspace.cleanupAbandoned() }
    }

    var messageCount: Int { coreSnapshot.totalMessages }
    var filteredMessageCount: Int { coreSnapshot.filteredMessageCount }
    var hasFilteredMessages: Bool { coreSnapshot.filteredMessageCount > 0 }
    var firstTimelineMessage: Date? { coreSnapshot.firstTimelineMessage }
    var lastTimelineMessage: Date? { coreSnapshot.lastTimelineMessage }
    var participants: [ParticipantStatistics] { participantsSnapshot.statistics }
    var participantNames: [String] { coreSnapshot.participantNames }
    var summary: ChatSummaryStatistics { coreSnapshot.summary }
    var conversations: ConversationStatistics { conversationSnapshot.conversations }
    var responseStatistics: ResponseStatistics { conversationSnapshot.responses }
    var isUpdatingStatistics: Bool { isUpdatingCore || isUpdatingSection }

    func add(urls: [URL]) {
        guard !urls.isEmpty else { return }
        isPreparingInput = true
        Task {
            defer { isPreparingInput = false }
            for url in urls { await prepare(url: url) }
        }
    }

    private func prepare(url: URL) async {
        let standardized = url.standardizedFileURL
        guard !inputs.contains(where: { $0.url.standardizedFileURL == standardized }) else {
            warningMessage = "«\(url.lastPathComponent)» ya está en la selección."
            return
        }
        let isSecurityScoped = standardized.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped { standardized.stopAccessingSecurityScopedResource() }
        }
        do {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            let fingerprint = try FileFingerprintSnapshot.read(url)
            if values.isDirectory == true {
                let currentSettings = operationSettings
                guard advancedMode else { throw ChatAnalyzerError.unsupportedInput(url.lastPathComponent) }
                let descriptors = try await Task.detached { try InstagramImporter(settings: currentSettings).catalogFolder(at: url) }.value
                guard importMode.allows(.instagram) else { throw ChatAnalyzerError.unsupportedInput("La operación actual está limitada a WhatsApp.") }
                let input = ChatInput(url: url, kind: .instagramFolder, estimatedPlatform: .instagram, fingerprint: fingerprint)
                inputs.append(input); instagramCatalogs[url] = descriptors
                if descriptors.count == 1 { instagramSelections[url] = descriptors[0].id }
                return
            }
            switch url.pathExtension.lowercased() {
            case "txt":
                guard importMode.allows(.whatsapp) else { throw ChatAnalyzerError.unsupportedInput("La operación actual está limitada a Instagram.") }
                try validateConversationFileSize(fingerprint.size, name: url.lastPathComponent)
                inputs.append(ChatInput(url: url, kind: .whatsappText, estimatedPlatform: .whatsapp, fingerprint: fingerprint))
            case "html", "htm":
                guard advancedMode else { throw ChatAnalyzerError.unsupportedInput(url.lastPathComponent) }
                guard importMode.allows(.instagram) else { throw ChatAnalyzerError.unsupportedInput("La operación actual está limitada a WhatsApp.") }
                try validateConversationFileSize(fingerprint.size, name: url.lastPathComponent)
                inputs.append(ChatInput(url: url, kind: .instagramHTML, estimatedPlatform: .instagram, fingerprint: fingerprint))
            case "zip":
                let reader = ChatArchiveReader(url: url, limits: operationSettings.archiveLimits)
                let catalog = try await Task.detached { try reader.catalog() }.value
                let instagram = catalog.entries.contains { entry in
                    guard !entry.isDirectory else { return false }
                    let name = URL(fileURLWithPath: entry.path).lastPathComponent
                    return name.range(of: #"(?i)^message_\d+\.html$"#, options: .regularExpression) != nil
                }
                let hasTextCandidates = catalog.entries.contains { $0.path.lowercased().hasSuffix(".txt") }
                let whatsappResult: WhatsAppInspection? = if importMode.allows(.whatsapp) && hasTextCandidates {
                    try await service.inspectWhatsApp(url: url, settings: operationSettings)
                } else {
                    nil
                }
                let whatsapp = whatsappResult?.validTextCandidates.isEmpty == false
                guard instagram || hasTextCandidates else { throw ChatAnalyzerError.chatNotFound }
                if whatsapp, let whatsappResult {
                    inputs.append(ChatInput(url: url, kind: .zip, estimatedPlatform: .whatsapp, fingerprint: fingerprint))
                    whatsappCandidates[url] = whatsappResult.validTextCandidates
                    if whatsappResult.validTextCandidates.count == 1 { whatsappSelections[url] = whatsappResult.validTextCandidates[0] }
                } else if instagram {
                    guard importMode.allows(.instagram) else { throw ChatAnalyzerError.unsupportedInput("La operación actual está limitada a WhatsApp.") }
                    let result = try await service.catalogInstagram(url: url, settings: operationSettings)
                    inputs.append(ChatInput(url: url, kind: .zip, estimatedPlatform: .instagram, fingerprint: fingerprint))
                    instagramCatalogs[url] = result.conversations
                    if result.conversations.count == 1 { instagramSelections[url] = result.conversations[0].id }
                } else if hasTextCandidates {
                    guard importMode.allows(.whatsapp) else { throw ChatAnalyzerError.unsupportedInput("La operación actual está limitada a Instagram.") }
                    throw ChatAnalyzerError.whatsappTextNotFound
                }
            default:
                throw ChatAnalyzerError.unsupportedInput(url.lastPathComponent)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func validateConversationFileSize(_ size: Int64, name: String) throws {
        guard let maximum = operationSettings.conversationFileMaximumBytes, size > maximum else { return }
        throw ChatAnalyzerError.conversationFileLimit(name: name, size: size, maximum: maximum)
    }

    func remove(_ input: ChatInput) {
        inputs.removeAll { $0.id == input.id }
        instagramCatalogs.removeValue(forKey: input.url); instagramSelections.removeValue(forKey: input.url)
        whatsappCandidates.removeValue(forKey: input.url); whatsappSelections.removeValue(forKey: input.url)
    }

    func clearInputs() {
        inputs.removeAll(); instagramCatalogs.removeAll(); instagramSelections.removeAll(); whatsappCandidates.removeAll(); whatsappSelections.removeAll()
    }

    func analyze() {
        guard !isAnalyzing else { return }
        for input in inputs where input.estimatedPlatform == .instagram && input.kind != .instagramHTML {
            guard instagramSelections[input.url] != nil else { errorMessage = "Selecciona la conversación de Instagram que quieres analizar."; return }
        }
        for input in inputs where input.estimatedPlatform == .whatsapp && input.kind == .zip {
            if (whatsappCandidates[input.url]?.count ?? 0) > 1 && whatsappSelections[input.url] == nil {
                errorMessage = "Selecciona el TXT de WhatsApp que quieres analizar."; return
            }
        }
        isAnalyzing = true; errorMessage = nil; warningMessage = nil
        let request = ChatAnalysisRequest(inputs: inputs, whatsappTextSelections: whatsappSelections, instagramConversationSelections: instagramSelections, settings: operationSettings)
        Task {
            let scopedURLs = request.inputs.map(\.url.standardizedFileURL)
            let activeScopes = scopedURLs.filter { $0.startAccessingSecurityScopedResource() }
            defer { activeScopes.forEach { $0.stopAccessingSecurityScopedResource() } }
            do {
                let newSession = try await service.analyze(request) { [weak self] warning in
                    Task { @MainActor in self?.warningMessage = warning }
                }
                suppressAnalyticsInvalidation = true
                session?.close()
                session = newSession
                filter = ChatFilter()
                identityMap = [:]
                fusionHistory = []
                selectedSection = .summary
                selectedParticipant = nil
                comparisonA = nil
                comparisonB = nil
                granularity = operationSettings.granularity
                searchOptions = ChatSearchOptions()
                searchOptions.pageSize = operationSettings.listLimit
                suppressAnalyticsInvalidation = false
                resetAnalyticsState()
                invalidateAnalytics(debounceNanoseconds: 0)
            } catch { errorMessage = error.localizedDescription }
            isAnalyzing = false
        }
    }

    func cancel() { Task { await service.cancel() } }

    func cancelAndWait() async { await service.cancel() }

    func closeAnalysis() {
        suppressAnalyticsInvalidation = true
        session?.close()
        session = nil
        filter = ChatFilter()
        identityMap = [:]
        fusionHistory = []
        selectedParticipant = nil
        comparisonA = nil
        comparisonB = nil
        searchOptions = ChatSearchOptions()
        searchOptions.pageSize = operationSettings.listLimit
        suppressAnalyticsInvalidation = false
        resetAnalyticsState()
    }

    func analyzeAnother() { closeAnalysis(); clearInputs() }

    func persistSettings() {
        do { try settingsService.save(defaultSettings) } catch { errorMessage = error.localizedDescription }
    }

    func applyDefaultSettingsToCurrentAnalysis() {
        operationSettings = defaultSettings
        granularity = defaultSettings.granularity
        searchOptions.pageSize = defaultSettings.listLimit
        searchOptions.page = 0
    }

    func restoreSettings() {
        do {
            try settingsService.restoreDefaults()
            defaultSettings = ChatAnalyzerSettings()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func mergeSelectedIdentities() {
        let name = fusionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard fusionSelection.count >= 2, !name.isEmpty else { errorMessage = "Selecciona al menos dos participantes e indica un nombre común."; return }
        guard name.count <= 200 else { errorMessage = "El nombre común es demasiado largo."; return }
        let unselected = Set(participantNames).subtracting(fusionSelection)
        guard !unselected.contains(name) else {
            errorMessage = "Ese nombre ya pertenece a un participante que no está incluido en la fusión."
            return
        }
        guard let store = session?.store else { return }
        do {
            let originals = try store.originalAuthors(
                matchingDisplayedParticipants: fusionSelection,
                identityMap: identityMap
            )
            fusionHistory.append(identityMap)
            var updatedMap = identityMap
            for original in originals { updatedMap[original] = name }
            suppressAnalyticsInvalidation = true
            identityMap = updatedMap
            suppressAnalyticsInvalidation = false
            fusionSelection.removeAll()
            fusionName = ""
            invalidateAnalytics(debounceNanoseconds: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func undoFusion() {
        guard let previous = fusionHistory.popLast() else { return }
        suppressAnalyticsInvalidation = true
        identityMap = previous
        suppressAnalyticsInvalidation = false
        invalidateAnalytics(debounceNanoseconds: 0)
    }

    func resetFusions() {
        guard !identityMap.isEmpty else { return }
        fusionHistory.append(identityMap)
        suppressAnalyticsInvalidation = true
        identityMap = [:]
        suppressAnalyticsInvalidation = false
        invalidateAnalytics(debounceNanoseconds: 0)
    }

    private nonisolated static func detachedStoreAnalyticsValue<T: Sendable>(
        _ operation: @escaping @Sendable () throws -> T
    ) async throws -> T {
        let worker = Task.detached(priority: .userInitiated, operation: operation)
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    private func handleOperationSettingsChange(from oldValue: ChatAnalyzerSettings, to newValue: ChatAnalyzerSettings) {
        guard session != nil else { return }

        let stopWordsChanged = oldValue.includeStopWords != newValue.includeStopWords
        let multimediaChanged = oldValue.multimediaDefinition != newValue.multimediaDefinition
            || oldValue.configurableMultimediaTypes != newValue.configurableMultimediaTypes
        let conversationChanged = oldValue.conversationThresholdMinutes != newValue.conversationThresholdMinutes
            || oldValue.responseWindowMinutes != newValue.responseWindowMinutes
            || oldValue.conversationFilterStrategy != newValue.conversationFilterStrategy

        if stopWordsChanged {
            wordsRevision = -1
            participantsSnapshot = ChatParticipantsAnalyticsSnapshot(statistics: participantsSnapshot.statistics)
        }
        if multimediaChanged {
            participantsRevision = -1
            comparisonRevision = -1
        }
        if conversationChanged {
            conversationRevision = -1
            comparisonRevision = -1
        }

        let currentSectionNeedsRefresh: Bool
        switch selectedSection {
        case .participants:
            currentSectionNeedsRefresh = stopWordsChanged || multimediaChanged
        case .words:
            currentSectionNeedsRefresh = stopWordsChanged
        case .conversations, .responses:
            currentSectionNeedsRefresh = conversationChanged
        case .comparison:
            currentSectionNeedsRefresh = multimediaChanged || conversationChanged
        default:
            currentSectionNeedsRefresh = false
        }
        if currentSectionNeedsRefresh { scheduleSelectedSection() }
    }

    private func resetAnalyticsState() {
        coreTask?.cancel()
        sectionTask?.cancel()
        participantDetailTask?.cancel()
        searchTask?.cancel()
        analyticsRevision += 1
        coreSnapshot = .empty
        activitySnapshot = .empty
        participantsSnapshot = .empty
        wordsSnapshot = .empty
        conversationSnapshot = .empty
        comparisonSnapshot = .empty
        searchResult = .empty
        activityRevision = -1
        activityGranularity = nil
        participantsRevision = -1
        wordsRevision = -1
        conversationRevision = -1
        comparisonRevision = -1
        comparisonNames = []
        isUpdatingCore = false
        isUpdatingSection = false
        isSearching = false
    }

    private func invalidateAnalytics(debounceNanoseconds: UInt64) {
        guard let store = session?.store else { return }
        analyticsRevision += 1
        let revision = analyticsRevision
        let currentIdentityMap = identityMap
        let currentFilter = filter

        coreTask?.cancel()
        sectionTask?.cancel()
        participantDetailTask?.cancel()
        searchTask?.cancel()
        activityRevision = -1
        participantsRevision = -1
        wordsRevision = -1
        conversationRevision = -1
        comparisonRevision = -1
        isUpdatingCore = true
        isUpdatingSection = false
        isSearching = false

        coreTask = Task { [weak self] in
            if debounceNanoseconds > 0 {
                do { try await Task.sleep(nanoseconds: debounceNanoseconds) }
                catch { return }
            }
            guard !Task.isCancelled else { return }
            do {
                let snapshot = try await Self.detachedStoreAnalyticsValue {
                    try ChatStoreAnalytics.coreSnapshot(
                    store: store,
                    identityMap: currentIdentityMap,
                    filter: currentFilter,
                    cancellation: { Task.isCancelled }
                )
                }
                guard let self, !Task.isCancelled, self.analyticsRevision == revision else { return }
                self.coreSnapshot = snapshot
                self.isUpdatingCore = false
                self.normalizeSelections()
                self.scheduleSelectedSection()
            } catch {
                guard let self, !Task.isCancelled, self.analyticsRevision == revision else { return }
                self.isUpdatingCore = false
                if (error as? ChatAnalyzerError) != .cancelled { self.errorMessage = error.localizedDescription }
            }
        }
    }

    private func scheduleSelectedSection() {
        guard session != nil, !isUpdatingCore else { return }
        sectionTask?.cancel()
        participantDetailTask?.cancel()
        if selectedSection != .search {
            searchTask?.cancel()
            isSearching = false
        }

        switch selectedSection {
        case .summary, .fusions:
            isUpdatingSection = false
        case .search:
            isUpdatingSection = false
            scheduleSearch(previous: nil)
        case .activity:
            scheduleActivity()
        case .participants:
            scheduleParticipants()
        case .words:
            scheduleWords()
        case .conversations, .responses:
            scheduleConversations()
        case .comparison:
            scheduleComparison()
        }
    }

    private func scheduleActivity() {
        guard let store = session?.store else { return }
        let revision = analyticsRevision
        let currentGranularity = granularity
        if activityRevision == revision, activityGranularity == currentGranularity {
            isUpdatingSection = false
            return
        }
        let currentIdentityMap = identityMap
        let currentFilter = filter
        isUpdatingSection = true
        sectionTask = Task { [weak self] in
            do {
                let snapshot = try await Self.detachedStoreAnalyticsValue {
                    try ChatStoreAnalytics.activitySnapshot(
                        store: store,
                        identityMap: currentIdentityMap,
                        filter: currentFilter,
                        granularity: currentGranularity,
                        cancellation: { Task.isCancelled }
                    )
                }
                guard let self, !Task.isCancelled,
                      self.analyticsRevision == revision,
                      self.granularity == currentGranularity else { return }
                self.activitySnapshot = snapshot
                self.activityRevision = revision
                self.activityGranularity = currentGranularity
                if self.selectedSection == .activity { self.isUpdatingSection = false }
            } catch {
                guard let self, !Task.isCancelled, self.analyticsRevision == revision else { return }
                if self.selectedSection == .activity { self.isUpdatingSection = false }
                if (error as? ChatAnalyzerError) != .cancelled { self.errorMessage = error.localizedDescription }
            }
        }
    }

    private func scheduleParticipants() {
        guard let store = session?.store else { return }
        let revision = analyticsRevision
        if participantsRevision == revision {
            isUpdatingSection = false
            scheduleParticipantDetail()
            return
        }
        let currentIdentityMap = identityMap
        let currentFilter = filter
        let settings = operationSettings
        let selectedName = selectedParticipant ?? coreSnapshot.participantNames.first
        isUpdatingSection = true
        sectionTask = Task { [weak self] in
            do {
                var snapshot = try await Self.detachedStoreAnalyticsValue {
                    try ChatStoreAnalytics.participantsSnapshot(
                        store: store,
                        identityMap: currentIdentityMap,
                        filter: currentFilter,
                        settings: settings,
                        cancellation: { Task.isCancelled }
                    )
                }
                if !Task.isCancelled, let selectedName,
                   snapshot.statistics.contains(where: { $0.name == selectedName }) {
                    let detail = try await Self.detachedStoreAnalyticsValue {
                        try ChatStoreAnalytics.participantDetail(
                            name: selectedName,
                            store: store,
                            identityMap: currentIdentityMap,
                            filter: currentFilter,
                            includeStopWords: settings.includeStopWords,
                            cancellation: { Task.isCancelled }
                        )
                    }
                    snapshot = ChatParticipantsAnalyticsSnapshot(
                        statistics: snapshot.statistics,
                        details: [selectedName: detail]
                    )
                }
                guard let self, !Task.isCancelled, self.analyticsRevision == revision else { return }
                self.participantsSnapshot = snapshot
                self.participantsRevision = revision
                if self.selectedParticipant == nil { self.selectedParticipant = selectedName }
                if self.selectedSection == .participants {
                    self.isUpdatingSection = false
                    self.scheduleParticipantDetail()
                }
            } catch {
                guard let self, !Task.isCancelled, self.analyticsRevision == revision else { return }
                if self.selectedSection == .participants { self.isUpdatingSection = false }
                if (error as? ChatAnalyzerError) != .cancelled { self.errorMessage = error.localizedDescription }
            }
        }
    }

    private func scheduleParticipantDetail() {
        guard selectedSection == .participants,
              !isUpdatingCore,
              participantsRevision == analyticsRevision,
              let name = selectedParticipant ?? participantNames.first else { return }
        if participantsSnapshot.details[name] != nil { return }

        guard let store = session?.store else { return }
        participantDetailTask?.cancel()
        let revision = analyticsRevision
        let currentIdentityMap = identityMap
        let currentFilter = filter
        let includeStopWords = operationSettings.includeStopWords
        isUpdatingSection = true
        participantDetailTask = Task { [weak self] in
            do {
                let detail = try await Self.detachedStoreAnalyticsValue {
                    try ChatStoreAnalytics.participantDetail(
                        name: name,
                        store: store,
                        identityMap: currentIdentityMap,
                        filter: currentFilter,
                        includeStopWords: includeStopWords,
                        cancellation: { Task.isCancelled }
                    )
                }
                guard let self, !Task.isCancelled,
                      self.analyticsRevision == revision,
                      (self.selectedParticipant ?? self.participantNames.first) == name else { return }
                var details = self.participantsSnapshot.details
                details[name] = detail
                self.participantsSnapshot = ChatParticipantsAnalyticsSnapshot(
                    statistics: self.participantsSnapshot.statistics,
                    details: details
                )
                self.isUpdatingSection = false
            } catch {
                guard let self, !Task.isCancelled, self.analyticsRevision == revision else { return }
                self.isUpdatingSection = false
                if (error as? ChatAnalyzerError) != .cancelled { self.errorMessage = error.localizedDescription }
            }
        }
    }

    private func scheduleWords() {
        guard let store = session?.store else { return }
        let revision = analyticsRevision
        if wordsRevision == revision {
            isUpdatingSection = false
            return
        }
        let currentIdentityMap = identityMap
        let currentFilter = filter
        let names = coreSnapshot.participantNames
        let includeStopWords = operationSettings.includeStopWords
        isUpdatingSection = true
        sectionTask = Task { [weak self] in
            do {
                let snapshot = try await Self.detachedStoreAnalyticsValue {
                    try ChatStoreAnalytics.wordsSnapshot(
                    store: store,
                    identityMap: currentIdentityMap,
                    filter: currentFilter,
                    participantNames: names,
                    includeStopWords: includeStopWords,
                    cancellation: { Task.isCancelled }
                )
                }
                guard let self, !Task.isCancelled, self.analyticsRevision == revision else { return }
                self.wordsSnapshot = snapshot
                self.wordsRevision = revision
                if self.selectedSection == .words { self.isUpdatingSection = false }
            } catch {
                guard let self, !Task.isCancelled, self.analyticsRevision == revision else { return }
                if self.selectedSection == .words { self.isUpdatingSection = false }
                if (error as? ChatAnalyzerError) != .cancelled { self.errorMessage = error.localizedDescription }
            }
        }
    }

    private func scheduleConversations() {
        guard let store = session?.store else { return }
        let revision = analyticsRevision
        if conversationRevision == revision {
            isUpdatingSection = false
            return
        }
        let currentIdentityMap = identityMap
        let currentFilter = filter
        let settings = operationSettings
        isUpdatingSection = true
        sectionTask = Task { [weak self] in
            do {
                let snapshot = try await Self.detachedStoreAnalyticsValue {
                    try ChatStoreAnalytics.conversationSnapshot(
                    store: store,
                    identityMap: currentIdentityMap,
                    filter: currentFilter,
                    settings: settings,
                    cancellation: { Task.isCancelled }
                )
                }
                guard let self, !Task.isCancelled, self.analyticsRevision == revision else { return }
                self.conversationSnapshot = snapshot
                self.conversationRevision = revision
                if self.selectedSection == .conversations || self.selectedSection == .responses {
                    self.isUpdatingSection = false
                }
            } catch {
                guard let self, !Task.isCancelled, self.analyticsRevision == revision else { return }
                if self.selectedSection == .conversations || self.selectedSection == .responses { self.isUpdatingSection = false }
                if (error as? ChatAnalyzerError) != .cancelled { self.errorMessage = error.localizedDescription }
            }
        }
    }

    private func scheduleComparison() {
        guard let store = session?.store else { return }
        let revision = analyticsRevision
        let names = [comparisonA, comparisonB].compactMap { $0 }
        guard names.count == 2, names[0] != names[1] else {
            comparisonSnapshot = .empty
            isUpdatingSection = false
            return
        }
        if comparisonRevision == revision, comparisonNames == names {
            isUpdatingSection = false
            return
        }

        let currentIdentityMap = identityMap
        let currentFilter = filter
        let settings = operationSettings
        let currentGranularity = granularity
        let cachedConversation = conversationRevision == revision ? conversationSnapshot : nil
        isUpdatingSection = true
        sectionTask = Task { [weak self] in
            do {
                let conversations: ChatConversationAnalyticsSnapshot
                if let cachedConversation {
                    conversations = cachedConversation
                } else {
                    conversations = try await Self.detachedStoreAnalyticsValue {
                        try ChatStoreAnalytics.conversationSnapshot(
                            store: store,
                            identityMap: currentIdentityMap,
                            filter: currentFilter,
                            settings: settings,
                            cancellation: { Task.isCancelled }
                        )
                    }
                }
                let comparison = try await Self.detachedStoreAnalyticsValue {
                    try ChatStoreAnalytics.comparisonSnapshot(
                        names: names,
                        store: store,
                        identityMap: currentIdentityMap,
                        filter: currentFilter,
                        conversations: conversations,
                        settings: settings,
                        granularity: currentGranularity,
                        cancellation: { Task.isCancelled }
                    )
                }
                guard let self, !Task.isCancelled,
                      self.analyticsRevision == revision,
                      self.granularity == currentGranularity,
                      [self.comparisonA, self.comparisonB].compactMap({ $0 }) == names else { return }
                self.conversationSnapshot = conversations
                self.conversationRevision = revision
                self.comparisonSnapshot = comparison
                self.comparisonRevision = revision
                self.comparisonNames = names
                if self.selectedSection == .comparison { self.isUpdatingSection = false }
            } catch {
                guard let self, !Task.isCancelled, self.analyticsRevision == revision else { return }
                if self.selectedSection == .comparison { self.isUpdatingSection = false }
                if (error as? ChatAnalyzerError) != .cancelled { self.errorMessage = error.localizedDescription }
            }
        }
    }

    private func scheduleSearch(previous: ChatSearchOptions?) {
        guard selectedSection == .search, let store = session?.store else { return }
        let trimmedQuery = searchOptions.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            searchTask?.cancel()
            searchResult = .empty
            isSearching = false
            return
        }
        guard !isUpdatingCore else { return }

        let criteriaChanged: Bool
        if let previous {
            criteriaChanged = previous.query.trimmingCharacters(in: .whitespacesAndNewlines) != trimmedQuery
                || previous.mode != searchOptions.mode
                || previous.ignoreCase != searchOptions.ignoreCase
                || previous.wholeWords != searchOptions.wholeWords
                || previous.ignoreDiacritics != searchOptions.ignoreDiacritics
            if criteriaChanged, searchOptions.page != 0 {
                suppressAnalyticsInvalidation = true
                searchOptions.page = 0
                suppressAnalyticsInvalidation = false
            }
        } else {
            criteriaChanged = true
        }

        searchTask?.cancel()
        let revision = analyticsRevision
        let currentIdentityMap = identityMap
        let currentFilter = filter
        let options = searchOptions
        isSearching = true

        searchTask = Task { [weak self] in
            if criteriaChanged {
                do { try await Task.sleep(nanoseconds: 200_000_000) }
                catch { return }
            }
            guard !Task.isCancelled else { return }
            do {
                let output = try await Self.detachedStoreAnalyticsValue {
                    try ChatStoreAnalytics.searchResult(
                        store: store,
                        identityMap: currentIdentityMap,
                        filter: currentFilter,
                        options: options,
                        cancellation: { Task.isCancelled }
                    )
                }
                guard let self, !Task.isCancelled,
                      self.analyticsRevision == revision,
                      self.selectedSection == .search else { return }
                self.searchResult = output
                self.isSearching = false
            } catch {
                guard let self, !Task.isCancelled, self.analyticsRevision == revision else { return }
                self.isSearching = false
                if (error as? ChatAnalyzerError) != .cancelled { self.errorMessage = error.localizedDescription }
            }
        }
    }

    private func normalizeSelections() {
        let orderedNames = participantNames
        let names = Set(orderedNames)
        let previousSuppression = suppressAnalyticsInvalidation
        suppressAnalyticsInvalidation = true
        if selectedParticipant == nil || !names.contains(selectedParticipant ?? "") {
            selectedParticipant = orderedNames.first
        }
        if comparisonA == nil || !names.contains(comparisonA ?? "") {
            comparisonA = orderedNames.first
        }
        if comparisonB == nil || !names.contains(comparisonB ?? "") || comparisonA == comparisonB {
            comparisonB = orderedNames.first(where: { $0 != comparisonA })
        }
        fusionSelection = fusionSelection.intersection(names)
        suppressAnalyticsInvalidation = previousSuppression
    }
}
