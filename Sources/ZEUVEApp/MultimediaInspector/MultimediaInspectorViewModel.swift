import Foundation
import AppKit
import SwiftUI
import Combine
import UniformTypeIdentifiers
import ZEUVECore
import ZEUVEStorage
import ZEUVEOperations
import ZEUVEEngines
import MultimediaInspectorModule

enum MultimediaInspectorTab: String, CaseIterable, Identifiable {
    case summary, tracks, spectrogram, metadata
    var id: String { rawValue }
    var title: String { switch self { case .summary: return "Resumen"; case .tracks: return "Pistas"; case .spectrogram: return "Espectrograma"; case .metadata: return "Metadatos" } }
}

@MainActor
final class MultimediaInspectorViewModel: ObservableObject {
    @Published private(set) var selectedURL: URL?
    @Published private(set) var inspection: MediaInspectionResult?
    @Published private(set) var fingerprint: FileFingerprint?
    @Published private(set) var draftHistory: MediaEditDraftHistory?
    @Published private(set) var editPlan: MediaEditPlan?
    @Published private(set) var spectrogram: SpectrogramResult?
    private var fullSpectrogram: SpectrogramResult?
    @Published private(set) var spectrogramProgress = 0.0
    private var spectrogramGenerationID = UUID()
    @Published var selectedTab: MultimediaInspectorTab = .summary
    @Published var isTechnicalDetailExpanded = false
    @Published var errorMessage: String?
    @Published var warningMessage: String?
    @Published var isInspecting = false
    @Published var isExecuting = false
    @Published var isGeneratingSpectrogram = false
    @Published var isExportingSpectrogram = false
    @Published private(set) var isExtractingAttachment = false
    @Published private(set) var isProcessingArtwork = false
    @Published private(set) var artworkPreviewData: Data?
    @Published var isDropTargeted = false
    @Published var needsDiscardConfirmation = false
    @Published var isBatchMode = false
    @Published var pendingExternalCandidates: [ExternalTrackCandidate] = []
    @Published var pendingExternalKind: MediaTrackKind?
    @Published var selectedSubtitlePreviewStreamIndex: Int? {
        didSet {
            guard oldValue != selectedSubtitlePreviewStreamIndex else { return }
            loadSelectedSubtitlePreview()
        }
    }
    @Published private(set) var subtitlePreviewEvents: [MultimediaSubtitlePreviewEvent] = []
    @Published private(set) var isLoadingSubtitlePreview = false

    @Published var selectedVideoStreamIndex: Int? {
        didSet {
            guard oldValue != selectedVideoStreamIndex, !suppressPreviewSelectionSideEffects else { return }
            if previewSourceID != nil || videoPreviewSourceID != nil {
                restartVideoPreview(at: sessionPreferences.previewTrackSwitchKeepsPosition ? previewPosition : 0)
            }
        }
    }
    @Published var selectedAudioStreamIndex: Int? {
        didSet {
            guard oldValue != selectedAudioStreamIndex else { return }
            guard !suppressPreviewSelectionSideEffects else { return }
            let retainedPosition = sessionPreferences.previewTrackSwitchKeepsPosition ? previewPosition : 0
            let hadPreview = previewSourceID != nil || requestedPreviewSourceID != nil || activePreviewSource != nil
            if spectrogramChannel != .mix {
                suppressPreviewSelectionSideEffects = true
                spectrogramChannel = .mix
                suppressPreviewSelectionSideEffects = false
            }
            invalidateSpectrogram()
            if hadPreview, selectedAudioStreamIndex != nil {
                previewSelectedSpectrogram(
                    at: retainedPosition,
                    forceRestart: true,
                    preservePlaybackState: sessionPreferences.previewTrackSwitchKeepsPlaybackState
                )
            }
        }
    }
    @Published var spectrogramChannel: SpectrogramChannelSelection = .mix {
        didSet {
            guard oldValue != spectrogramChannel else { return }
            if !suppressPreviewSelectionSideEffects { stopPreview() }
            invalidateSpectrogram()
        }
    }
    @Published var spectrogramWindow: SpectrogramWindowFunction { didSet { if oldValue != spectrogramWindow { invalidateSpectrogram() } } }
    @Published var spectrogramFFTSize: Int { didSet { if oldValue != spectrogramFFTSize { invalidateSpectrogram() } } }
    @Published var spectrogramDynamicMinimum: Float { didSet { reinterpretSpectrogram() } }
    @Published var spectrogramFrequencyScale: SpectrogramFrequencyScale
    @Published private(set) var audioTimelineViewport = AudioTimelineViewport.full

    @Published private(set) var previewState: MultimediaPreviewPlaybackState = .idle
    @Published private(set) var previewPosition: TimeInterval = 0
    @Published private(set) var previewDuration: TimeInterval?
    @Published private(set) var previewTitle: String?
    @Published private(set) var previewSourceID: String?
    @Published private(set) var requestedPreviewSourceID: String?
    @Published private(set) var videoPreviewFrame: MultimediaVideoPreviewFrame?
    @Published private(set) var videoPreviewState: MultimediaPreviewPlaybackState = .idle
    @Published private(set) var videoPreviewSourceID: String?
    @Published var previewPlaybackRate: Double = 1 {
        didSet {
            let normalizedRate = min(max(previewPlaybackRate.isFinite ? previewPlaybackRate : 1, 0.5), 2)
            // @Published vuelve a entrar en didSet al asignarse: corregir solo si cambia.
            if previewPlaybackRate != normalizedRate {
                previewPlaybackRate = normalizedRate
                return
            }
            Task { [weak self] in await self?.previewService?.setPlaybackRate(Float(normalizedRate)) }
            if videoPreviewSourceID != nil { restartVideoPreview(at: previewPosition) }
        }
    }
    @Published var previewVolume: Double = 1 {
        didSet {
            let value = Float(min(max(previewVolume, 0), 1))
            Task { [weak self] in await self?.previewService?.setVolume(value) }
        }
    }

    @Published private(set) var waveform: MultimediaWaveformResult?
    @Published private(set) var isGeneratingWaveform = false
    @Published private(set) var loudnessResults: [String: AudioLoudnessResult] = [:]
    @Published private(set) var isAnalyzingLoudness = false
    @Published private(set) var loudnessProgress = 0.0
    @Published private(set) var loudnessSourceID: String?
    @Published private(set) var signalAnalysisResults: [String: AudioSignalAnalysisResult] = [:]
    @Published private(set) var isAnalyzingSignal = false
    @Published private(set) var signalAnalysisProgress = 0.0
    @Published private(set) var signalAnalysisSourceID: String?
    @Published private(set) var advancedAudioResults: [String: AudioSourceQualityAnalysis] = [:]
    @Published private(set) var isAnalyzingAdvancedAudio = false
    @Published private(set) var advancedAudioSourceID: String?
    @Published var ocrDraft: BitmapSubtitleOCRDraft?
    @Published private(set) var isRunningBitmapSubtitleOCR = false
    @Published private(set) var ocrSourceStreamIndex: Int?
    @Published var comparisonTrackAID: UUID?
    @Published var comparisonTrackBID: UUID?
    @Published private(set) var activeComparisonSlot: AudioComparisonSlot = .a
    @Published private(set) var isCompletingComparisonAnalysis = false
    @Published private(set) var comparisonAnalysisCurrentTrackID: UUID?
    @Published var defaultPreferences: MultimediaInspectorPreferences
    let batch: MultimediaBatchViewModel

    private var sessionPreferences: MultimediaInspectorPreferences
    private let inspector = MediaInspectionService()
    private let locator: MultimediaEngineLocator?
    private let editService: MultimediaEditService?
    private let spectrogramService: SpectrogramAnalysisService?
    private let previewService: MultimediaAudioPreviewService?
    private let videoPreviewService: MultimediaVideoPreviewService?
    private let subtitlePreviewService: MultimediaSubtitlePreviewService?
    private let waveformService: MultimediaWaveformAnalysisService?
    private let loudnessService: AudioLoudnessAnalysisService?
    private let signalAnalysisService: AudioSignalAnalysisService?
    private let advancedAudioService: AudioSourceQualityAnalysisService?
    private let bitmapSubtitleOCRService: BitmapSubtitleOCRService?
    private let attachmentExtractionService: MultimediaAttachmentExtractionService?
    private let artworkService: MultimediaArtworkService?
    private let history: MultimediaInspectorHistoryService
    private let spectrogramExportService: SpectrogramExportService
    private let settingsStore: MultimediaInspectorSettingsStore
    private let reportExporter = MultimediaTechnicalReportExporter()
    private var activePreviewSource: MultimediaAudioPreviewSource?
    private var activePreviewChannel: SpectrogramChannelSelection = .mix
    private var inspectionVideoTracks: [MediaEditableTrack] = []
    private var inspectionAudioTracks: [MediaEditableTrack] = []
    private var inspectionSubtitleTracks: [MediaEditableTrack] = []
    private var pendingOpenURL: URL?
    private var pendingCloseAnalysis = false
    private var inspectionTask: Task<Void, Never>?
    private var executionTask: Task<Void, Never>?
    private var spectrogramTask: Task<Void, Never>?
    private var exportTask: Task<Void, Never>?
    private var attachmentExtractionTask: Task<Void, Never>?
    private var artworkTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var previewMonitorTask: Task<Void, Never>?
    private var videoPreviewTask: Task<Void, Never>?
    private var subtitlePreviewTask: Task<Void, Never>?
    private var waveformTask: Task<Void, Never>?
    private var waveformGenerationID = UUID()
    private var loudnessTask: Task<Void, Never>?
    private var signalAnalysisTask: Task<Void, Never>?
    private var advancedAudioTask: Task<Void, Never>?
    private var bitmapSubtitleOCRTask: Task<Void, Never>?
    private var comparisonAnalysisTask: Task<Void, Never>?
    private var automaticAudioAnalysisTask: Task<Void, Never>?
    private var automaticAudioAnalysisSessionID = UUID()
    private var previewOperationID = UUID()
    private var suppressPreviewSelectionSideEffects = false
    private var batchObservation: AnyCancellable?

    init(coordinator: OperationCoordinator, storage: StorageContainer?, engineRegistry: EngineRegistry?, engineDiagnostics: EngineDiagnosticService?) {
        let store = MultimediaInspectorSettingsStore(repository: storage?.settings)
        var loadedPreferences = store.load()
        loadedPreferences.normalize()
        settingsStore = store
        defaultPreferences = loadedPreferences
        sessionPreferences = loadedPreferences
        spectrogramWindow = loadedPreferences.defaultWindow
        spectrogramFFTSize = loadedPreferences.defaultFFTSize
        spectrogramDynamicMinimum = loadedPreferences.defaultDynamicRange.lowerBound
        spectrogramFrequencyScale = loadedPreferences.defaultFrequencyScale
        spectrogramChannel = loadedPreferences.defaultChannel == .mix ? .mix : .channel(0)
        previewVolume = loadedPreferences.previewVolume
        previewPlaybackRate = loadedPreferences.previewPlaybackRate
        isTechnicalDetailExpanded = loadedPreferences.detailLevel == .technical
        switch loadedPreferences.initialTab {
        case .summary: selectedTab = .summary
        case .tracks: selectedTab = .tracks
        case .spectrogram: selectedTab = .spectrogram
        case .metadata: selectedTab = .metadata
        }
        history = MultimediaInspectorHistoryService(repository: storage?.history)
        spectrogramExportService = SpectrogramExportService(coordinator: coordinator, history: history)
        let batchProcessor: MultimediaBatchProcessor?
        if let engineRegistry {
            locator = MultimediaEngineLocator(registry: engineRegistry, diagnostics: engineDiagnostics)
            editService = MultimediaEditService(coordinator: coordinator, engineRegistry: engineRegistry, diagnostics: engineDiagnostics, history: history, preferences: loadedPreferences)
            spectrogramService = SpectrogramAnalysisService(coordinator: coordinator, engineRegistry: engineRegistry, diagnostics: engineDiagnostics)
            previewService = MultimediaAudioPreviewService()
            videoPreviewService = MultimediaVideoPreviewService()
            subtitlePreviewService = MultimediaSubtitlePreviewService()
            waveformService = MultimediaWaveformAnalysisService()
            loudnessService = AudioLoudnessAnalysisService(coordinator: coordinator, engineRegistry: engineRegistry, diagnostics: engineDiagnostics)
            signalAnalysisService = AudioSignalAnalysisService(coordinator: coordinator, engineRegistry: engineRegistry, diagnostics: engineDiagnostics)
            advancedAudioService = AudioSourceQualityAnalysisService(coordinator: coordinator)
            bitmapSubtitleOCRService = BitmapSubtitleOCRService(coordinator: coordinator)
            attachmentExtractionService = MultimediaAttachmentExtractionService(coordinator: coordinator, engineRegistry: engineRegistry, diagnostics: engineDiagnostics)
            artworkService = MultimediaArtworkService(coordinator: coordinator, engineRegistry: engineRegistry, diagnostics: engineDiagnostics)
            batchProcessor = MultimediaBatchProcessor(
                coordinator: coordinator,
                engineRegistry: engineRegistry,
                diagnostics: engineDiagnostics,
                history: history
            )
        } else {
            locator = nil
            editService = nil
            spectrogramService = nil
            previewService = nil
            videoPreviewService = nil
            subtitlePreviewService = nil
            waveformService = nil
            loudnessService = nil
            signalAnalysisService = nil
            advancedAudioService = nil
            bitmapSubtitleOCRService = nil
            attachmentExtractionService = nil
            artworkService = nil
            batchProcessor = nil
        }
        batch = MultimediaBatchViewModel(
            processor: batchProcessor,
            history: history,
            presetStore: MultimediaInspectorBatchPresetStore(repository: storage?.settings),
            ruleSetStore: MultimediaInspectorRuleSetStore(repository: storage?.settings),
            favoritesStore: MultimediaInspectorFavoritesStore(repository: storage?.settings),
            preferences: loadedPreferences,
            coordinator: coordinator,
            engineRegistry: engineRegistry,
            engineDiagnostics: engineDiagnostics
        )
        batchObservation = batch.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var isEditing: Bool { draftHistory != nil }
    var isDirty: Bool { draftHistory?.isDirty == true }
    var canUndo: Bool { draftHistory?.canUndo == true }
    var canRedo: Bool { draftHistory?.canRedo == true }
    var isBusy: Bool { batch.isRunning || batch.isPreflighting || batch.isExecutingStructural || isInspecting || isExecuting || isGeneratingSpectrogram || isExportingSpectrogram || isExtractingAttachment || isProcessingArtwork || isAnalyzingLoudness || isAnalyzingSignal || isAnalyzingAdvancedAudio || isRunningBitmapSubtitleOCR || isCompletingComparisonAnalysis }
    var hasPendingOpenRequest: Bool { pendingOpenURL != nil }
    var hasPendingCloseRequest: Bool { pendingCloseAnalysis }
    var audioTimingAnalysis: AudioTimingAnalysis? { inspection.map { AudioTimingAnalyzer().analyze($0) } }
    var previewSkipSeconds: Int { sessionPreferences.previewSkipSeconds }
    var waveformStyle: MultimediaWaveformStyle { sessionPreferences.waveformStyle }
    var waveformRepresentation: MultimediaWaveformRepresentation { sessionPreferences.waveformRepresentation }
    var waveformShowsCenterGuide: Bool { sessionPreferences.waveformShowsCenterGuide }
    var showChapterMarkersOnWaveform: Bool { sessionPreferences.showChapterMarkersOnWaveform }
    var showSignalOverlaysOnWaveform: Bool { sessionPreferences.showSignalOverlaysOnWaveform }
    var showSignalOverlaysOnSpectrogram: Bool { sessionPreferences.showSignalOverlaysOnSpectrogram }
    var showLoudnessTimeline: Bool { sessionPreferences.showLoudnessTimeline }
    var showAdvancedAudioOverlays: Bool { sessionPreferences.showAdvancedAudioOverlays }
    var currentDraft: MediaEditDraft? { draftHistory?.current }
    var videoTracks: [MediaEditableTrack] { currentDraft?.videoTracks ?? inspectionVideoTracks }
    var audioTracks: [MediaEditableTrack] { currentDraft?.audioTracks ?? inspectionAudioTracks }
    var subtitleTracks: [MediaEditableTrack] { currentDraft?.subtitleTracks ?? inspectionSubtitleTracks }
    var editableChapters: [MediaEditableChapter] { currentDraft?.chapters ?? [] }
    var editableAttachments: [MediaEditableAttachment] { currentDraft?.attachments ?? [] }
    var editableArtworks: [MediaEditableArtwork] { currentDraft?.artworks ?? inspection?.streams.compactMap(MediaEditableArtwork.from(stream:)) ?? [] }
    var selectedAudioTrack: MediaEditableTrack? {
        guard let selectedAudioStreamIndex else { return audioTracks.first }
        return audioTracks.first { $0.source.streamIndex == selectedAudioStreamIndex } ?? audioTracks.first
    }

    func chooseBatchFiles() {
        guard !isBusy, !isDirty else {
            if isDirty { errorMessage = "Cancela o publica el borrador antes de iniciar un lote." }
            return
        }
        let panel = NSOpenPanel()
        panel.title = "Seleccionar archivos multimedia"
        panel.prompt = "Añadir al lote"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.resolvesAliases = false
        if panel.runModal() == .OK {
            if isBatchMode { batch.append(urls: panel.urls) }
            else { beginBatch(urls: panel.urls) }
        }
    }

    func handleDroppedURLs(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        if isBatchMode {
            if !batch.isRunning { batch.append(urls: urls) }
        } else if urls.count == 1 {
            requestOpen(urls[0])
        } else {
            beginBatch(urls: urls)
        }
    }

    func beginBatch(urls: [URL]) {
        guard !isBusy, !urls.isEmpty else { return }
        guard !isDirty else { errorMessage = "Cancela o publica el borrador antes de iniciar un lote."; return }
        if inspection != nil || selectedURL != nil { resetCurrentInspectionSession() }
        batch.prepare(urls: urls)
        guard !batch.items.isEmpty else {
            errorMessage = batch.warningMessage ?? "No hay archivos válidos para analizar."
            return
        }
        isBatchMode = true
    }

    func closeBatch() {
        guard !batch.isRunning else { return }
        batch.clear()
        isBatchMode = false
    }

    func openBatchItem(_ url: URL) {
        guard !batch.isRunning else { return }
        isBatchMode = false
        requestOpen(url)
    }

    func chooseFile() {
        let panel = NSOpenPanel(); panel.title = "Seleccionar archivo multimedia"; panel.prompt = "Abrir"; panel.canChooseFiles = true; panel.canChooseDirectories = false; panel.allowsMultipleSelection = false; panel.resolvesAliases = false
        if panel.runModal() == .OK, let url = panel.url { requestOpen(url) }
    }

    func requestOpen(_ url: URL) {
        guard !isBusy else { return }
        if isDirty {
            pendingOpenURL = url
            pendingCloseAnalysis = false
            needsDiscardConfirmation = true
            return
        }
        open(url)
    }

    func requestCloseAnalysis() {
        guard !isBusy, selectedURL != nil || inspection != nil else { return }
        if isDirty {
            pendingOpenURL = nil
            pendingCloseAnalysis = true
            needsDiscardConfirmation = true
            return
        }
        closeAnalysis()
    }

    func confirmDiscard() {
        needsDiscardConfirmation = false
        if let url = pendingOpenURL {
            pendingOpenURL = nil
            pendingCloseAnalysis = false
            draftHistory = nil
            editPlan = nil
            open(url)
        } else if pendingCloseAnalysis {
            pendingCloseAnalysis = false
            draftHistory = nil
            editPlan = nil
            closeAnalysis()
        } else {
            confirmDiscardEditing()
        }
    }

    func keepCurrentDraft() {
        pendingOpenURL = nil
        pendingCloseAnalysis = false
        needsDiscardConfirmation = false
    }

    func closeAnalysis() {
        guard !isBusy else { return }
        resetCurrentInspectionSession()
        applyPreferencesToNewSession()
    }

    func open(_ url: URL) {
        inspectionTask?.cancel()
        resetCurrentInspectionSession()
        applyPreferencesToNewSession()
        errorMessage = nil
        warningMessage = nil
        isInspecting = true
        selectedURL = url.standardizedFileURL
        inspectionTask = Task { [weak self] in
            guard let self else { return }
            do {
                guard let locator else { throw MultimediaInspectorError.ffprobeUnavailable }
                let fp = try FileFingerprint.read(from: url)
                let ffprobe = try await locator.ffprobe()
                let result = try await inspector.inspect(url: url, ffprobe: ffprobe, fingerprint: fp)
                try Task.checkCancellation()
                guard !result.streams.isEmpty else { throw MultimediaInspectorError.unsupportedFile }
                self.fingerprint = fp
                self.cacheInspectionTracks(result)
                self.configureDefaultComparisonTracks()
                self.selectedVideoStreamIndex = result.videoStreams.first?.index
                self.selectedAudioStreamIndex = result.audioStreams.first(where: Self.isAnalyzableAudioStream)?.index ?? result.audioStreams.first?.index
                if result.audioStreams.isEmpty, self.selectedTab == .spectrogram {
                    self.selectedTab = .summary
                }
                self.inspection = result
                self.audioTimelineViewport = .full
                if result.isPartial {
                    self.warningMessage = "FFprobe ha devuelto un análisis parcial. Se muestran únicamente los datos confirmados; no se inventan campos ausentes."
                }
                self.isInspecting = false
                if let artworkIndex = result.streams.first(where: { $0.isAttachedPicture })?.index {
                    self.loadArtworkPreview(streamIndex: artworkIndex)
                }
                if MultimediaAutomaticAudioAnalysisPolicy.shouldRun(audioStreamCount: result.audioStreams.count),
                   result.audioStreams.contains(where: Self.isAnalyzableAudioStream) {
                    self.startAutomaticSingleTrackAudioAnalysis()
                }
                return
            } catch is CancellationError {
            } catch {
                self.inspectionAudioTracks = []
                self.inspectionSubtitleTracks = []
                self.inspection = nil
                self.fingerprint = nil
                self.errorMessage = Self.clean(error)
            }
            self.isInspecting = false
        }
    }

    private func resetCurrentInspectionSession() {
        stopPreview()
        automaticAudioAnalysisTask?.cancel()
        automaticAudioAnalysisSessionID = UUID()
        waveformTask?.cancel()
        loudnessTask?.cancel()
        signalAnalysisTask?.cancel()
        advancedAudioTask?.cancel()
        bitmapSubtitleOCRTask?.cancel()
        comparisonAnalysisTask?.cancel()
        Task { [weak self] in
            await self?.waveformService?.cancel()
            await self?.loudnessService?.cancel()
            await self?.signalAnalysisService?.cancel()
            await self?.advancedAudioService?.cancel()
            await self?.bitmapSubtitleOCRService?.cancel()
        }
        pendingOpenURL = nil
        pendingCloseAnalysis = false
        needsDiscardConfirmation = false
        pendingExternalCandidates = []
        pendingExternalKind = nil
        draftHistory = nil
        editPlan = nil
        spectrogramTask?.cancel()
        attachmentExtractionTask?.cancel()
        spectrogramGenerationID = UUID()
        spectrogram = nil
        fullSpectrogram = nil
        spectrogramProgress = 0
        isGeneratingSpectrogram = false
        isExtractingAttachment = false
        artworkPreviewData = nil
        audioTimelineViewport = .full
        waveform = nil
        isGeneratingWaveform = false
        loudnessResults = [:]
        isAnalyzingLoudness = false
        loudnessProgress = 0
        loudnessSourceID = nil
        signalAnalysisResults = [:]
        isAnalyzingSignal = false
        signalAnalysisProgress = 0
        advancedAudioResults = [:]
        isAnalyzingAdvancedAudio = false
        advancedAudioSourceID = nil
        ocrDraft = nil
        isRunningBitmapSubtitleOCR = false
        ocrSourceStreamIndex = nil
        signalAnalysisSourceID = nil
        comparisonTrackAID = nil
        comparisonTrackBID = nil
        activeComparisonSlot = .a
        isCompletingComparisonAnalysis = false
        comparisonAnalysisCurrentTrackID = nil
        selectedVideoStreamIndex = nil
        selectedSubtitlePreviewStreamIndex = nil
        subtitlePreviewEvents = []
        selectedAudioStreamIndex = nil
        selectedURL = nil
        inspectionVideoTracks = []
        inspectionAudioTracks = []
        inspectionSubtitleTracks = []
        inspection = nil
        fingerprint = nil
        errorMessage = nil
        warningMessage = nil
    }

    private static func isAnalyzableAudioStream(_ stream: MediaInspectionStream) -> Bool {
        guard stream.index != nil,
              let sampleRate = stream.sampleRateValue, sampleRate.isFinite, sampleRate > 0,
              let channels = stream.channels, channels > 0 else {
            return false
        }
        return true
    }

    private func applyPreferencesToNewSession() {
        var normalized = defaultPreferences
        normalized.normalize()
        sessionPreferences = normalized
        spectrogramWindow = normalized.defaultWindow
        spectrogramFFTSize = normalized.defaultFFTSize
        spectrogramDynamicMinimum = normalized.defaultDynamicRange.lowerBound
        spectrogramFrequencyScale = normalized.defaultFrequencyScale
        spectrogramChannel = normalized.defaultChannel == .mix ? .mix : .channel(0)
        previewVolume = normalized.previewVolume
        previewPlaybackRate = normalized.previewPlaybackRate
        isTechnicalDetailExpanded = normalized.detailLevel == .technical
        switch normalized.initialTab {
        case .summary: selectedTab = .summary
        case .tracks: selectedTab = .tracks
        case .spectrogram: selectedTab = .spectrogram
        case .metadata: selectedTab = .metadata
        }
        Task { [weak self] in
            guard let self else { return }
            await self.editService?.updatePreferences(normalized)
        }
    }

    func persistPreferences() {
        var normalized = defaultPreferences
        normalized.normalize()
        if normalized != defaultPreferences { defaultPreferences = normalized }
        do {
            try settingsStore.save(normalized)
            batch.updatePreferences(normalized)
            batch.refreshPresets(defaultPresetID: normalized.defaultBatchPresetID)
        } catch {
            errorMessage = "Los ajustes del Inspector se han aplicado a la interfaz, pero no se han podido guardar: \(error.localizedDescription)"
        }
    }

    func restoreDefaultPreferences() {
        do {
            defaultPreferences = try settingsStore.restoreDefaults()
            batch.restoreDefaultPresets()
            batch.updatePreferences(defaultPreferences)
        } catch {
            defaultPreferences = .defaults
            errorMessage = "No se han podido guardar todos los valores predeterminados del Inspector: \(error.localizedDescription)"
        }
    }

    func restorePersistentDefaultsForGlobalReset() -> [String] {
        var failures: [String] = []
        do {
            defaultPreferences = try settingsStore.restoreDefaults()
        } catch {
            defaultPreferences = .defaults
            failures.append("Inspector multimedia: \(error.localizedDescription)")
        }
        batch.restoreDefaultPresets()
        batch.updatePreferences(defaultPreferences)
        return failures
    }

    func beginEditing() {
        guard let url = selectedURL, let inspection, let fingerprint else { return }
        guard let container = EditableMediaContainer.detect(from: inspection, url: url) else { errorMessage = MultimediaInspectorError.notEditable("el contenedor no forma parte de MKV, MP4, MOV o WebM en la versión actual del Inspector").localizedDescription; return }
        do {
            draftHistory = MediaEditDraftHistory(try MediaEditDraft(originalURL: url, originalFingerprint: fingerprint, inspection: inspection, container: container))
            editPlan = nil
            configureDefaultComparisonTracks()
            selectedTab = .tracks
        }
        catch { errorMessage = Self.clean(error) }
    }

    func requestCancelEditing() {
        if isDirty {
            pendingOpenURL = nil
            pendingCloseAnalysis = false
            needsDiscardConfirmation = true
        } else {
            discardEditing()
        }
    }
    func confirmDiscardEditing() {
        needsDiscardConfirmation = false
        pendingOpenURL = nil
        pendingCloseAnalysis = false
        discardEditing()
    }
    private func discardEditing() {
        stopPreview()
        draftHistory = nil
        editPlan = nil
        configureDefaultComparisonTracks()
    }

    func undo() { guard var h = draftHistory else { return }; if h.undo() { draftHistory = h; editPlan = nil; configureDefaultComparisonTracks() } }
    func redo() { guard var h = draftHistory else { return }; if h.redo() { draftHistory = h; editPlan = nil; configureDefaultComparisonTracks() } }
    private func mutate(_ body: (inout MediaEditDraft) -> Void) {
        guard var h = draftHistory else { return }
        h.perform(body)
        draftHistory = h
        editPlan = nil
        configureDefaultComparisonTracks()
    }

    func removeTrack(_ id: UUID, kind: MediaTrackKind) {
        if kind == .audio, let track = audioTracks.first(where: { $0.id == id }), previewSourceID == previewSourceID(for: track) { stopPreview() }
        if kind == .video, let track = videoTracks.first(where: { $0.id == id }), track.source.streamIndex == selectedVideoStreamIndex {
            selectedVideoStreamIndex = videoTracks.first(where: { $0.id != id })?.source.streamIndex
        }
        mutate { draft in
            switch kind {
            case .video: draft.videoTracks.removeAll { $0.id == id }
            case .audio: draft.audioTracks.removeAll { $0.id == id }
            case .subtitle: draft.subtitleTracks.removeAll { $0.id == id }
            }
        }
    }

    func moveTrack(kind: MediaTrackKind, from offsets: IndexSet, to destination: Int) {
        mutate { draft in
            switch kind {
            case .video: draft.videoTracks.move(fromOffsets: offsets, toOffset: destination)
            case .audio: draft.audioTracks.move(fromOffsets: offsets, toOffset: destination)
            case .subtitle: draft.subtitleTracks.move(fromOffsets: offsets, toOffset: destination)
            }
        }
    }

    func reorderTrack(kind: MediaTrackKind, movingID: UUID, before targetID: UUID) {
        mutate { draft in
            var tracks: [MediaEditableTrack]
            switch kind { case .video: tracks = draft.videoTracks; case .audio: tracks = draft.audioTracks; case .subtitle: tracks = draft.subtitleTracks }
            guard let sourceIndex = tracks.firstIndex(where: { $0.id == movingID }),
                  let originalTargetIndex = tracks.firstIndex(where: { $0.id == targetID }), sourceIndex != originalTargetIndex else { return }
            let moved = tracks.remove(at: sourceIndex)
            let targetIndex = tracks.firstIndex(where: { $0.id == targetID }) ?? originalTargetIndex
            tracks.insert(moved, at: targetIndex)
            switch kind { case .video: draft.videoTracks = tracks; case .audio: draft.audioTracks = tracks; case .subtitle: draft.subtitleTracks = tracks }
        }
    }

    func updateTrack(_ track: MediaEditableTrack) {
        mutate { draft in
            switch track.kind {
            case .video:
                if let i = draft.videoTracks.firstIndex(where: { $0.id == track.id }) { draft.videoTracks[i] = track }
            case .audio:
                if let i = draft.audioTracks.firstIndex(where: { $0.id == track.id }) { draft.audioTracks[i] = track }
            case .subtitle:
                if let i = draft.subtitleTracks.firstIndex(where: { $0.id == track.id }) { draft.subtitleTracks[i] = track }
            }
        }
    }

    func setDefault(_ id: UUID, kind: MediaTrackKind, value: Bool) {
        mutate { draft in
            func apply(_ tracks: inout [MediaEditableTrack]) {
                for i in tracks.indices {
                    if tracks[i].id == id { tracks[i].isDefault = value }
                    else if value { tracks[i].isDefault = false }
                }
            }
            switch kind { case .video: apply(&draft.videoTracks); case .audio: apply(&draft.audioTracks); case .subtitle: apply(&draft.subtitleTracks) }
        }
    }
    func setForced(_ id: UUID, value: Bool) { mutate { draft in if let i=draft.subtitleTracks.firstIndex(where:{$0.id==id}) { draft.subtitleTracks[i].isForced=value } } }
    func authorizeSubtitleConversion(_ id: UUID, allowed: Bool) { mutate { draft in if allowed { draft.authorizedSubtitleConversions.insert(id) } else { draft.authorizedSubtitleConversions.remove(id) } } }

    func addChapterAtCurrentPosition() {
        guard let duration = inspection?.durationSeconds, duration > 0 else {
            errorMessage = "No se conoce una duración fiable para añadir capítulos."
            return
        }
        let time = min(max(previewPosition, 0), max(duration - 0.001, 0))
        guard !(currentDraft?.chapters.contains { abs($0.startTime - time) < 0.001 } ?? false) else {
            errorMessage = "Ya existe un capítulo en ese instante."
            return
        }
        mutate { draft in
            draft.chapters.append(.init(startTime: time, title: "Capítulo \(draft.chapters.count + 1)"))
            draft.chapters.sort { $0.startTime < $1.startTime }
        }
    }

    func removeChapter(_ id: UUID) {
        mutate { $0.chapters.removeAll { $0.id == id } }
    }

    func updateChapterTitle(_ id: UUID, title: String) {
        mutate { draft in
            guard let index = draft.chapters.firstIndex(where: { $0.id == id }) else { return }
            draft.chapters[index].title = title
        }
    }

    func updateChapterTime(_ id: UUID, time: Double) {
        guard let duration = inspection?.durationSeconds, time.isFinite, time >= 0, time < duration else { return }
        mutate { draft in
            guard let index = draft.chapters.firstIndex(where: { $0.id == id }) else { return }
            draft.chapters[index].startTime = time
            draft.chapters.sort { $0.startTime < $1.startTime }
        }
    }

    func seekToEditableChapter(_ chapter: MediaEditableChapter) {
        seekPreview(to: chapter.startTime)
    }

    func chooseAttachment() {
        guard isEditing else { return }
        let panel = NSOpenPanel()
        panel.title = "Añadir adjunto"
        panel.prompt = "Añadir"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        addAttachment(url)
    }

    func addAttachment(_ url: URL) {
        guard isEditing else { return }
        do {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                throw MultimediaInspectorError.invalidAttachment("debe ser un archivo regular y no un enlace simbólico")
            }
            let fingerprint = try FileFingerprint.read(from: url)
            let filename = url.lastPathComponent
            let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            guard !(currentDraft?.attachments.contains { $0.filename.caseInsensitiveCompare(filename) == .orderedSame } ?? false) else {
                throw MultimediaInspectorError.invalidAttachment("ya existe un adjunto llamado «\(filename)»")
            }
            let attachment = MediaEditableAttachment(source: .external(url: url, fingerprint: fingerprint), filename: filename, mimeType: mime)
            mutate { $0.attachments.append(attachment) }
        } catch {
            errorMessage = Self.clean(error)
        }
    }

    func removeAttachment(_ id: UUID) {
        mutate { $0.attachments.removeAll { $0.id == id } }
    }

    func updateAttachment(_ attachment: MediaEditableAttachment) {
        mutate { draft in
            guard let index = draft.attachments.firstIndex(where: { $0.id == attachment.id }) else { return }
            draft.attachments[index] = attachment
        }
    }

    func extractAttachment(streamIndex: Int) {
        guard let selectedURL, let fingerprint, let inspection, let service = attachmentExtractionService,
              let ordinal = inspection.attachmentStreams.firstIndex(where: { $0.index == streamIndex }),
              let stream = inspection.attachmentStreams.first(where: { $0.index == streamIndex }) else { return }
        let filename = stream.tags?.first(where: { $0.key.caseInsensitiveCompare("filename") == .orderedSame })?.value
            ?? stream.title
            ?? "adjunto-\(ordinal + 1).bin"
        let panel = NSSavePanel()
        panel.title = "Extraer adjunto"
        panel.prompt = "Extraer"
        panel.nameFieldStringValue = filename
        guard panel.runModal() == .OK, let target = panel.url else { return }
        isExtractingAttachment = true
        errorMessage = nil
        attachmentExtractionTask = Task { [weak self] in
            guard let self else { return }
            do {
                let output = try await service.extract(inputURL: selectedURL, inputFingerprint: fingerprint, attachmentOrdinal: ordinal, proposedOutput: target)
                self.warningMessage = "Adjunto extraído como \(output.lastPathComponent). El archivo multimedia original no se ha modificado."
            } catch MultimediaInspectorError.cancelled {
            } catch is CancellationError {
            } catch {
                self.errorMessage = Self.clean(error)
            }
            self.isExtractingAttachment = false
        }
    }

    func chooseArtwork() {
        guard isEditing else { return }
        let panel = NSOpenPanel(); panel.title = editableArtworks.isEmpty ? "Añadir carátula" : "Sustituir carátula"; panel.prompt = "Usar"
        panel.canChooseFiles = true; panel.canChooseDirectories = false; panel.allowsMultipleSelection = false; panel.resolvesAliases = false
        panel.allowedContentTypes = [.jpeg, .png]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        artworkTask?.cancel(); isProcessingArtwork = true
        artworkTask = Task { [weak self] in
            guard let self else { return }
            defer { self.isProcessingArtwork = false }
            do {
                let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
                guard values.isRegularFile == true, values.isSymbolicLink != true else { throw MultimediaInspectorError.invalidInput }
                let fp = try FileFingerprint.read(from: url)
                guard let locator = self.locator else { throw MultimediaInspectorError.ffprobeUnavailable }
                let probe = try await self.inspector.inspect(url: url, ffprobe: try await locator.ffprobe(), fingerprint: fp, useCache: false)
                guard let stream = probe.streams.first(where: { $0.codec_type == "video" }), let index = stream.index else { throw MultimediaInspectorError.invalidInput }
                let artwork = MediaEditableArtwork(source: .external(url: url, fingerprint: fp, streamIndex: index), codec: stream.codec_name ?? url.pathExtension, title: url.deletingPathExtension().lastPathComponent)
                self.mutate { $0.artworks = [artwork] }
                self.artworkPreviewData = (values.fileSize ?? Int.max) <= 32 * 1024 * 1024 ? (try? Data(contentsOf: url, options: [.mappedIfSafe])) : nil
            } catch { self.errorMessage = Self.clean(error) }
        }
    }

    func removeArtwork(_ id: UUID) {
        mutate { $0.artworks.removeAll { $0.id == id } }
        if currentDraft?.artworks.isEmpty == true { artworkPreviewData = nil }
    }

    func updateArtwork(_ artwork: MediaEditableArtwork) {
        mutate { draft in guard let index = draft.artworks.firstIndex(where: { $0.id == artwork.id }) else { return }; draft.artworks[index] = artwork }
    }

    func loadArtworkPreview(streamIndex: Int) {
        guard let selectedURL, let fingerprint, let service = artworkService else { return }
        artworkTask?.cancel()
        artworkTask = Task { [weak self] in
            guard let self else { return }
            do { self.artworkPreviewData = try await service.previewData(inputURL: selectedURL, fingerprint: fingerprint, streamIndex: streamIndex) }
            catch { self.artworkPreviewData = nil }
        }
    }

    func extractArtwork(streamIndex: Int) {
        guard let selectedURL, let fingerprint, let service = artworkService else { return }
        let codec = inspection?.streams.first(where: { $0.index == streamIndex })?.codec_name?.lowercased() ?? "mjpeg"
        let panel = NSSavePanel(); panel.title = "Extraer carátula"; panel.prompt = "Extraer"; panel.nameFieldStringValue = codec == "png" ? "caratula.png" : "caratula.jpg"
        guard panel.runModal() == .OK, let target = panel.url else { return }
        artworkTask?.cancel(); isProcessingArtwork = true
        artworkTask = Task { [weak self] in
            guard let self else { return }; defer { self.isProcessingArtwork = false }
            do {
                let output = try await service.extract(inputURL: selectedURL, fingerprint: fingerprint, streamIndex: streamIndex, proposedOutput: target)
                self.warningMessage = "Carátula extraída como \(output.lastPathComponent). El original no se ha modificado."
            } catch MultimediaInspectorError.cancelled { } catch is CancellationError { } catch { self.errorMessage = Self.clean(error) }
        }
    }

    func updateContainerMetadata(key: String, value: String) {
        mutate { $0.metadata.setContainerValue(value, for: key) }
    }

    func updateVideoMetadata(streamIndex: Int, key: String, value: String) {
        mutate { $0.metadata.setVideoValue(value, for: key, streamIndex: streamIndex) }
    }

    func chooseExternalTrack(kind: MediaTrackKind) {
        let panel=NSOpenPanel(); panel.title = kind == .video ? "Añadir pista de vídeo" : (kind == .audio ? "Añadir pista de audio" : "Añadir subtítulo"); panel.prompt="Inspeccionar"; panel.canChooseFiles=true; panel.canChooseDirectories=false; panel.allowsMultipleSelection=false
        if panel.runModal() == .OK, let url=panel.url { inspectExternal(url, kind:kind) }
    }
    func addDroppedExternalTrack(_ url: URL, kind: MediaTrackKind) {
        guard isEditing else { return }
        inspectExternal(url, kind: kind)
    }
    func addExternalFile(_ url: URL, kind: MediaTrackKind) {
        guard isEditing else { return }
        inspectExternal(url, kind: kind)
    }

    private func inspectExternal(_ url: URL, kind: MediaTrackKind) {
        Task { [weak self] in guard let self else{return}; do { guard let locator else {throw MultimediaInspectorError.ffprobeUnavailable}; let fp=try FileFingerprint.read(from:url); let probe=try await inspector.inspect(url:url,ffprobe:try await locator.ffprobe(),fingerprint:fp,useCache:false); let streams: [MediaInspectionStream]; switch kind { case .video: streams = probe.videoStreams; case .audio: streams = probe.audioStreams; case .subtitle: streams = probe.subtitleStreams }; let candidates=streams.map{ExternalTrackCandidate(url:url,fingerprint:fp,stream:$0,kind:kind)}; guard !candidates.isEmpty else {throw MultimediaInspectorError.unsupportedFile}; if candidates.count == 1 { self.addExternalCandidate(candidates[0]) } else { self.pendingExternalKind=kind; self.pendingExternalCandidates=candidates } } catch {self.errorMessage=Self.clean(error)} }
    }
    func addExternalCandidate(_ candidate: ExternalTrackCandidate) {
        guard let index=candidate.stream.index else { errorMessage="La pista externa no tiene un índice de stream utilizable."; return }
        let track = MediaEditableTrack(
            kind: candidate.kind,
            source: .external(url: candidate.url, fingerprint: candidate.fingerprint, streamIndex: index),
            codec: candidate.stream.codec_name ?? "unknown",
            language: candidate.stream.language ?? "",
            title: candidate.stream.title ?? "",
            isDefault: false,
            isForced: false,
            preservedDispositions: MediaEditableTrack.dispositionNames(candidate.stream.disposition),
            sampleRate: candidate.stream.sampleRateValue,
            channels: candidate.stream.channels,
            channelLayout: candidate.stream.channel_layout,
            duration: candidate.stream.durationSeconds,
            width: candidate.stream.width,
            height: candidate.stream.height,
            frameRate: candidate.stream.frameRate
        )
        mutate { draft in switch candidate.kind { case .video: draft.videoTracks.append(track); case .audio: draft.audioTracks.append(track); case .subtitle: draft.subtitleTracks.append(track) } }
        pendingExternalCandidates=[]; pendingExternalKind=nil
    }

    var comparisonAvailableTracks: [MediaEditableTrack] { audioTracks }

    func comparisonTrack(for slot: AudioComparisonSlot) -> MediaEditableTrack? {
        let id = slot == .a ? comparisonTrackAID : comparisonTrackBID
        guard let id else { return nil }
        return audioTracks.first { $0.id == id }
    }

    func setComparisonTrack(_ slot: AudioComparisonSlot, id: UUID?) {
        guard let id else {
            if slot == .a { comparisonTrackAID = nil } else { comparisonTrackBID = nil }
            return
        }
        guard audioTracks.contains(where: { $0.id == id }) else { return }
        let otherID = slot == .a ? comparisonTrackBID : comparisonTrackAID
        guard id != otherID else {
            warningMessage = "A y B deben ser pistas de audio distintas."
            return
        }
        if slot == .a { comparisonTrackAID = id } else { comparisonTrackBID = id }
    }

    func selectComparisonSlot(_ slot: AudioComparisonSlot) {
        guard let track = comparisonTrack(for: slot) else { return }
        activeComparisonSlot = slot
        let hasPreviewSession = previewSourceID != nil || requestedPreviewSourceID != nil || activePreviewSource != nil
        if hasPreviewSession {
            startPreviewTrack(track, synchronizeSpectrogramSelection: false, toggleIfAlreadyActive: false)
        }
    }

    func toggleComparisonPreview() {
        guard let track = comparisonTrack(for: activeComparisonSlot) else { return }
        startPreviewTrack(track, synchronizeSpectrogramSelection: false, toggleIfAlreadyActive: true)
    }

    var comparisonPlaybackState: MultimediaPreviewPlaybackState {
        guard let track = comparisonTrack(for: activeComparisonSlot) else { return .idle }
        return previewPlaybackState(for: previewSourceID(for: track))
    }

    var comparisonHasTwoTracks: Bool {
        guard let a = comparisonTrackAID, let b = comparisonTrackBID else { return false }
        return a != b && audioTracks.contains(where: { $0.id == a }) && audioTracks.contains(where: { $0.id == b })
    }

    func comparisonLabel(for track: MediaEditableTrack) -> String {
        let indexText = "#\(track.source.streamIndex)"
        let values = [indexText, track.language.nonEmpty, track.title.nonEmpty, track.codec.uppercased().nonEmpty].compactMap { $0 }
        return values.joined(separator: " · ")
    }

    func comparisonMetrics(for slot: AudioComparisonSlot) -> AudioTrackComparisonMetrics? {
        guard let track = comparisonTrack(for: slot) else { return nil }
        let stream: MediaInspectionStream?
        if case .original(let streamIndex) = track.source {
            stream = inspection?.audioStreams.first(where: { $0.index == streamIndex })
        } else {
            stream = nil
        }
        return AudioTrackComparisonMetrics(
            track: track,
            stream: stream,
            loudness: loudnessResult(for: track),
            signal: signalAnalysisResult(for: track)
        )
    }

    func comparisonNeedsAnalysis(for track: MediaEditableTrack) -> Bool {
        guard let id = previewSourceID(for: track) else { return true }
        return signalAnalysisResults[id] == nil || loudnessResults[id] == nil
    }

    func completeComparisonAnalysis() {
        guard comparisonHasTwoTracks,
              let first = comparisonTrack(for: .a),
              let second = comparisonTrack(for: .b),
              !isCompletingComparisonAnalysis, !isAnalyzingSignal, !isAnalyzingLoudness,
              !isGeneratingSpectrogram, !isExecuting, !isExportingSpectrogram else { return }
        let tracks = [first, second]
        comparisonAnalysisTask?.cancel()
        isCompletingComparisonAnalysis = true
        comparisonAnalysisTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.isCompletingComparisonAnalysis = false
                self.comparisonAnalysisCurrentTrackID = nil
            }
            do {
                for track in tracks {
                    try Task.checkCancellation()
                    self.comparisonAnalysisCurrentTrackID = track.id
                    let source = try await self.resolvePreviewSource(for: track)
                    if self.signalAnalysisResults[source.id] == nil {
                        try await self.runSignalAnalysis(source: source)
                    }
                    try Task.checkCancellation()
                    if self.loudnessResults[source.id] == nil {
                        try await self.runLoudnessAnalysis(source: source)
                    }
                }
            } catch MultimediaInspectorError.cancelled {
            } catch is CancellationError {
            } catch {
                self.errorMessage = Self.clean(error)
            }
        }
    }

    func previewSourceID(for track: MediaEditableTrack) -> String? {
        let fp: FileFingerprint
        switch track.source {
        case .original:
            guard let fingerprint else { return nil }
            fp = fingerprint
        case .external(_, let fingerprint, _):
            fp = fingerprint
        }
        let url: URL
        switch track.source {
        case .original:
            guard let selectedURL else { return nil }
            url = selectedURL
        case .external(let externalURL, _, _):
            url = externalURL
        }
        return MultimediaAudioPreviewSource.identity(url: url, fingerprint: fp, streamIndex: track.source.streamIndex)
    }

    func previewPlaybackState(for sourceID: String?) -> MultimediaPreviewPlaybackState {
        guard previewControlMatches(sourceID) else { return .idle }
        return previewState
    }

    private func previewControlMatches(_ sourceID: String?) -> Bool {
        guard let sourceID else { return false }
        switch previewState {
        case .loading:
            return requestedPreviewSourceID == sourceID
        case .playing, .paused, .finished:
            return previewSourceID == sourceID
        case .idle, .failed:
            return false
        }
    }

    func previewTrack(_ track: MediaEditableTrack) {
        startPreviewTrack(track, synchronizeSpectrogramSelection: true, toggleIfAlreadyActive: true)
    }

    private func startPreviewTrack(
        _ track: MediaEditableTrack,
        synchronizeSpectrogramSelection: Bool,
        toggleIfAlreadyActive: Bool
    ) {
        let targetSourceID = previewSourceID(for: track)
        switch previewPlaybackState(for: targetSourceID) {
        case .playing, .paused, .finished:
            if toggleIfAlreadyActive { togglePreviewPause() }
            return
        case .loading:
            return
        case .idle, .failed:
            break
        }

        if synchronizeSpectrogramSelection, case .original(let streamIndex) = track.source {
            synchronizeSelectedAudioStreamIndex(streamIndex)
        }

        let hasPreviewSession = previewSourceID != nil || requestedPreviewSourceID != nil || activePreviewSource != nil
        let retainedPosition = hasPreviewSession && sessionPreferences.previewTrackSwitchKeepsPosition ? previewPosition : 0
        let previous = previewTask
        previous?.cancel()
        previewMonitorTask?.cancel()
        invalidateWaveformForPreviewChange()
        let operationID = UUID()
        previewOperationID = operationID
        previewPosition = retainedPosition
        requestedPreviewSourceID = targetSourceID
        previewSourceID = nil
        previewState = .loading

        previewTask = Task { [weak self] in
            _ = await previous?.result
            guard let self, self.previewOperationID == operationID, !Task.isCancelled else { return }
            do {
                let source = try await self.resolvePreviewSource(for: track)
                try Task.checkCancellation()
                guard self.previewOperationID == operationID else { return }
                try await self.startPreview(
                    source: source,
                    at: retainedPosition,
                    channel: .mix,
                    preservePlaybackState: hasPreviewSession && sessionPreferences.previewTrackSwitchKeepsPlaybackState,
                    operationID: operationID
                )
            } catch is CancellationError {
            } catch {
                guard self.previewOperationID == operationID else { return }
                self.requestedPreviewSourceID = nil
                self.errorMessage = Self.clean(error)
                await self.refreshPreviewSnapshot(operationID: operationID)
            }
        }
    }

    func previewSelectedSpectrogram(
        at position: TimeInterval? = nil,
        forceRestart: Bool = false,
        preservePlaybackState: Bool = false
    ) {
        guard let url = selectedURL, let inspection,
              let stream = inspection.audioStreams.first(where: { $0.index == selectedAudioStreamIndex }) ?? inspection.audioStreams.first,
              let index = stream.index, let sampleRate = stream.sampleRateValue, let channels = stream.channels else {
            errorMessage = "Selecciona una pista de audio reproducible."
            return
        }
        guard let fingerprint else { errorMessage = "No se puede verificar el archivo para reproducirlo."; return }
        let source = MultimediaAudioPreviewSource(
            url: url,
            fingerprint: fingerprint,
            streamIndex: index,
            sampleRate: sampleRate,
            channels: channels,
            duration: stream.durationSeconds ?? inspection.durationSeconds,
            channelLayout: stream.channel_layout,
            title: previewDisplayName(stream: stream, fallback: url.lastPathComponent)
        )
        let desiredPosition = position ?? previewPosition
        if !forceRestart, position == nil {
            switch previewPlaybackState(for: source.id) {
            case .playing, .paused, .finished:
                togglePreviewPause()
                return
            case .loading:
                return
            case .idle, .failed:
                break
            }
        }

        let previous = previewTask
        previous?.cancel()
        previewMonitorTask?.cancel()
        invalidateWaveformForPreviewChange()
        let operationID = UUID()
        previewOperationID = operationID
        previewPosition = min(max(desiredPosition, 0), source.duration ?? max(desiredPosition, 0))
        requestedPreviewSourceID = source.id
        previewSourceID = nil
        previewState = .loading

        previewTask = Task { [weak self] in
            _ = await previous?.result
            guard let self, self.previewOperationID == operationID, !Task.isCancelled else { return }
            do {
                try Task.checkCancellation()
                try await self.startPreview(
                    source: source,
                    at: desiredPosition,
                    channel: self.spectrogramChannel,
                    preservePlaybackState: preservePlaybackState,
                    operationID: operationID
                )
            } catch is CancellationError {
            } catch {
                guard self.previewOperationID == operationID else { return }
                self.requestedPreviewSourceID = nil
                self.errorMessage = Self.clean(error)
                await self.refreshPreviewSnapshot(operationID: operationID)
            }
        }
    }

    func togglePreviewPause() {
        guard let previewService else { return }
        let previous = previewTask
        previous?.cancel()
        previewMonitorTask?.cancel()
        let operationID = UUID()
        previewOperationID = operationID

        previewTask = Task { [weak self] in
            _ = await previous?.result
            guard let self, self.previewOperationID == operationID, !Task.isCancelled else { return }
            if self.activePreviewSource == nil, self.videoPreviewSourceID != nil {
                switch self.previewState {
                case .playing, .loading:
                    await self.videoPreviewService?.stop()
                    self.videoPreviewState = .paused
                    self.previewState = .paused
                case .paused:
                    await self.startVideoPreview(at: self.previewPosition)
                    self.previewState = .loading
                case .finished:
                    self.previewPosition = 0
                    await self.startVideoPreview(at: 0)
                    self.previewState = .loading
                default:
                    break
                }
            } else {
                switch self.previewState {
                case .playing, .loading:
                    await previewService.pause()
                    await self.videoPreviewService?.stop()
                    self.videoPreviewState = .paused
                case .paused:
                    do {
                        try await previewService.resume()
                        await self.startVideoPreview(at: self.previewPosition)
                    } catch { self.errorMessage = Self.clean(error) }
                case .finished:
                    do {
                        self.previewPosition = 0
                        try await previewService.seek(to: 0)
                        await self.startVideoPreview(at: 0)
                    } catch { self.errorMessage = Self.clean(error) }
                default:
                    break
                }
            }
            guard self.previewOperationID == operationID else { return }
            await self.refreshPreviewSnapshot(operationID: operationID)
            self.beginPreviewMonitoring(operationID: operationID)
        }
    }

    func seekPreview(to position: TimeInterval) {
        let maximum = previewDuration ?? activePreviewSource?.duration ?? .greatestFiniteMagnitude
        let target = min(max(position, 0), maximum)

        guard let previewService, activePreviewSource != nil else {
            previewPosition = target
            if selectedVideoStreamIndex != nil { previewSelectedVideo(at: target) }
            else { previewSelectedSpectrogram(at: target) }
            return
        }

        // Seek optimista: la UI adopta el destino de inmediato. Al cancelar el monitor
        // anterior y versionar la operación, ningún snapshot viejo puede hacer rebotar
        // el playhead a la posición previa mientras FFmpeg/AVAudioEngine reinician.
        previewPosition = target
        previewMonitorTask?.cancel()
        let previous = previewTask
        previous?.cancel()
        let operationID = UUID()
        previewOperationID = operationID

        previewTask = Task { [weak self] in
            _ = await previous?.result
            guard let self, self.previewOperationID == operationID, !Task.isCancelled else { return }
            do {
                try await previewService.seek(to: target, preservePlaybackState: true)
                await self.startVideoPreview(at: target)
                guard self.previewOperationID == operationID else { return }
                await self.refreshPreviewSnapshot(operationID: operationID)
                self.beginPreviewMonitoring(operationID: operationID)
            } catch is CancellationError {
            } catch {
                guard self.previewOperationID == operationID else { return }
                self.errorMessage = Self.clean(error)
                await self.refreshPreviewSnapshot(operationID: operationID)
            }
        }
    }

    func skipPreview(by seconds: TimeInterval) {
        let maximum = previewDuration ?? .greatestFiniteMagnitude
        seekPreview(to: min(max(previewPosition + seconds, 0), maximum))
    }

    func stopPreview() {
        let previous = previewTask
        previous?.cancel()
        previewMonitorTask?.cancel()
        previewMonitorTask = nil
        invalidateWaveformForPreviewChange()
        let operationID = UUID()
        previewOperationID = operationID

        previewState = .idle
        previewPosition = 0
        previewDuration = nil
        previewTitle = nil
        previewSourceID = nil
        requestedPreviewSourceID = nil
        activePreviewSource = nil
        activePreviewChannel = .mix
        videoPreviewSourceID = nil
        videoPreviewFrame = nil
        videoPreviewState = .idle
        videoPreviewTask?.cancel()
        videoPreviewTask = nil

        previewTask = Task { [weak self] in
            _ = await previous?.result
            guard let self, self.previewOperationID == operationID, !Task.isCancelled else { return }
            await self.previewService?.stop()
            await self.videoPreviewService?.stop()
            await self.subtitlePreviewService?.cancel()
            await self.waveformService?.cancel()
        }
    }

    private func startPreview(
        source: MultimediaAudioPreviewSource,
        at position: TimeInterval,
        channel: SpectrogramChannelSelection,
        preservePlaybackState: Bool = false,
        operationID: UUID
    ) async throws {
        guard let previewService, let locator else { throw MultimediaInspectorError.previewUnavailable }
        try Task.checkCancellation()
        guard previewOperationID == operationID else { throw CancellationError() }

        let currentFingerprint = try FileFingerprint.read(from: source.url)
        if source.url.standardizedFileURL == selectedURL?.standardizedFileURL, let fingerprint, currentFingerprint != fingerprint {
            throw MultimediaInspectorError.originalChanged
        }

        let ffmpeg = try await locator.ffmpeg()
        try Task.checkCancellation()
        guard previewOperationID == operationID else { throw CancellationError() }

        try await previewService.replaceSource(
            ffmpeg: ffmpeg,
            with: source,
            startingAt: position,
            channelSelection: channel,
            preservePlaybackState: preservePlaybackState
        )
        guard previewOperationID == operationID else { throw CancellationError() }

        activePreviewSource = source
        activePreviewChannel = channel
        await previewService.setVolume(Float(min(max(previewVolume, 0), 1)))
        await previewService.setPlaybackRate(Float(previewPlaybackRate))
        if selectedVideoStreamIndex != nil {
            await startVideoPreview(at: position)
        }
        await refreshPreviewSnapshot(operationID: operationID)
        guard previewOperationID == operationID else { return }
        prepareWaveform(source: source, channel: channel, ffmpeg: ffmpeg)
        beginPreviewMonitoring(operationID: operationID)
    }

    private func resolvePreviewSource(for track: MediaEditableTrack) async throws -> MultimediaAudioPreviewSource {
        guard track.kind == .audio else { throw MultimediaInspectorError.invalidInput }
        switch track.source {
        case .original(let streamIndex):
            guard let url = selectedURL, let inspection,
                  let stream = inspection.audioStreams.first(where: { $0.index == streamIndex }),
                  let sampleRate = stream.sampleRateValue, sampleRate.isFinite, sampleRate > 0,
                  let channels = stream.channels, channels > 0 else {
                throw MultimediaInspectorError.invalidInput
            }
            guard let fingerprint else { throw MultimediaInspectorError.invalidInput }
            return .init(url: url, fingerprint: fingerprint, streamIndex: streamIndex, sampleRate: sampleRate, channels: channels,
                         duration: stream.durationSeconds ?? inspection.durationSeconds, channelLayout: stream.channel_layout,
                         title: previewDisplayName(stream: stream, fallback: track.title.isEmpty ? url.lastPathComponent : track.title))
        case .external(let url, let expectedFingerprint, let streamIndex):
            let current = try FileFingerprint.read(from: url)
            guard current == expectedFingerprint else { throw MultimediaInspectorError.inputChanged(url.lastPathComponent) }
            guard let locator else { throw MultimediaInspectorError.ffprobeUnavailable }
            let probe = try await inspector.inspect(url: url, ffprobe: try await locator.ffprobe(), fingerprint: current)
            guard let stream = probe.audioStreams.first(where: { $0.index == streamIndex }),
                  let sampleRate = stream.sampleRateValue, sampleRate.isFinite, sampleRate > 0,
                  let channels = stream.channels, channels > 0 else {
                throw MultimediaInspectorError.invalidInput
            }
            return .init(url: url, fingerprint: current, streamIndex: streamIndex, sampleRate: sampleRate, channels: channels,
                         duration: stream.durationSeconds ?? probe.durationSeconds, channelLayout: stream.channel_layout,
                         title: previewDisplayName(stream: stream, fallback: track.title.isEmpty ? url.lastPathComponent : track.title))
        }
    }

    func previewSelectedVideo(at position: TimeInterval? = nil) {
        guard selectedVideoStreamIndex != nil else {
            errorMessage = "Selecciona una pista de vídeo reproducible."
            return
        }
        let target = max(position ?? previewPosition, 0)
        let operationID = UUID()
        previewOperationID = operationID
        previewPosition = target
        previewState = .loading
        previewTask?.cancel()
        previewMonitorTask?.cancel()
        previewTask = Task { [weak self] in
            guard let self, self.previewOperationID == operationID, !Task.isCancelled else { return }
            do {
                try await self.startVideoPreviewOnly(at: target)
                guard self.previewOperationID == operationID else { return }
                self.beginPreviewMonitoring(operationID: operationID)
            } catch is CancellationError {
            } catch {
                guard self.previewOperationID == operationID else { return }
                self.previewState = .failed
                self.errorMessage = Self.clean(error)
            }
        }
    }

    private func startVideoPreviewOnly(at position: TimeInterval) async throws {
        try await startVideoPreview(at: position)
        guard let videoPreviewService else { throw MultimediaInspectorError.previewUnavailable }
        let snapshot = await videoPreviewService.snapshot(position: position)
        videoPreviewSourceID = snapshot.sourceID
        previewSourceID = snapshot.sourceID
        previewDuration = snapshot.duration
        previewTitle = selectedVideoTrack?.title.nonEmpty ?? "Previsualización de vídeo"
        previewState = snapshot.state
    }

    var currentSubtitlePreviewText: String? {
        subtitlePreviewEvents.first(where: { previewPosition >= $0.start && previewPosition <= $0.end })?.text
    }

    var textSubtitlePreviewStreams: [MediaInspectionStream] {
        inspection?.subtitleStreams.filter { $0.subtitleRepresentation == .text } ?? []
    }

    var bitmapSubtitleStreams: [MediaInspectionStream] {
        inspection?.subtitleStreams.filter { $0.subtitleRepresentation == .bitmap } ?? []
    }

    func disableSubtitlePreview() {
        selectedSubtitlePreviewStreamIndex = nil
        subtitlePreviewTask?.cancel()
        subtitlePreviewEvents = []
        isLoadingSubtitlePreview = false
    }

    private func loadSelectedSubtitlePreview() {
        subtitlePreviewTask?.cancel()
        subtitlePreviewEvents = []
        guard let streamIndex = selectedSubtitlePreviewStreamIndex,
              let selectedURL, let fingerprint, let locator, let subtitlePreviewService else {
            isLoadingSubtitlePreview = false
            return
        }
        guard inspection?.subtitleStreams.first(where: { $0.index == streamIndex })?.subtitleRepresentation == .text else {
            isLoadingSubtitlePreview = false
            return
        }
        isLoadingSubtitlePreview = true
        subtitlePreviewTask = Task { [weak self] in
            guard let self else { return }
            do {
                let ffmpeg = try await locator.ffmpeg()
                let events = try await subtitlePreviewService.load(ffmpeg: ffmpeg, url: selectedURL, fingerprint: fingerprint, streamIndex: streamIndex)
                guard !Task.isCancelled, self.selectedSubtitlePreviewStreamIndex == streamIndex else { return }
                self.subtitlePreviewEvents = events
                self.isLoadingSubtitlePreview = false
            } catch is CancellationError {
            } catch {
                guard self.selectedSubtitlePreviewStreamIndex == streamIndex else { return }
                self.isLoadingSubtitlePreview = false
                self.warningMessage = "No se ha podido preparar esta pista de subtítulos para la previsualización. Los estilos ASS/SSA avanzados no se reproducen de forma completa."
            }
        }
    }

    private var selectedVideoTrack: MediaEditableTrack? {
        guard let index = selectedVideoStreamIndex else { return videoTracks.first }
        return videoTracks.first(where: { $0.source.streamIndex == index }) ?? videoTracks.first
    }

    private func resolveVideoPreviewSource(for track: MediaEditableTrack) async throws -> MultimediaVideoPreviewSource {
        guard track.kind == .video else { throw MultimediaInspectorError.invalidInput }
        let url: URL
        let expectedFingerprint: FileFingerprint
        let stream: MediaInspectionStream
        let duration: TimeInterval?
        switch track.source {
        case .original(let streamIndex):
            guard let selectedURL, let fingerprint, let inspection,
                  let found = inspection.videoStreams.first(where: { $0.index == streamIndex }) else {
                throw MultimediaInspectorError.invalidInput
            }
            url = selectedURL
            expectedFingerprint = fingerprint
            stream = found
            duration = found.durationSeconds ?? inspection.durationSeconds
        case .external(let externalURL, let fingerprint, let streamIndex):
            let current = try FileFingerprint.read(from: externalURL)
            guard current == fingerprint else { throw MultimediaInspectorError.inputChanged(externalURL.lastPathComponent) }
            guard let locator else { throw MultimediaInspectorError.ffprobeUnavailable }
            let inspected = try await inspector.inspect(url: externalURL, ffprobe: try await locator.ffprobe(), fingerprint: current)
            guard let found = inspected.videoStreams.first(where: { $0.index == streamIndex }) else { throw MultimediaInspectorError.invalidInput }
            url = externalURL
            expectedFingerprint = current
            stream = found
            duration = found.durationSeconds ?? inspected.durationSeconds
        }
        guard let streamIndex = stream.index, let width = stream.width, let height = stream.height else { throw MultimediaInspectorError.invalidInput }
        return .init(
            url: url, fingerprint: expectedFingerprint, streamIndex: streamIndex, codec: stream.codec_name ?? track.codec,
            width: width, height: height, frameRate: stream.frameRate, duration: duration,
            title: previewDisplayName(stream: stream, fallback: track.title.nonEmpty ?? url.lastPathComponent)
        )
    }

    private func startVideoPreview(at position: TimeInterval) async {
        guard let videoPreviewService, let locator, let track = selectedVideoTrack else { return }
        do {
            let source = try await resolveVideoPreviewSource(for: track)
            let ffmpeg = try await locator.ffmpeg()
            try await videoPreviewService.start(
                ffmpeg: ffmpeg, source: source, from: position, limits: sessionPreferences.videoPreviewLimits,
                decoder: sessionPreferences.videoPreviewDecoder, playbackRate: previewPlaybackRate
            )
            videoPreviewSourceID = source.id
            videoPreviewState = .loading
            if activePreviewSource == nil {
                previewSourceID = source.id
                previewDuration = source.duration
                previewTitle = source.title
            }
        } catch is CancellationError {
        } catch {
            videoPreviewState = .failed
            if errorMessage == nil { errorMessage = Self.clean(error) }
        }
    }

    private func restartVideoPreview(at position: TimeInterval) {
        videoPreviewTask?.cancel()
        let shouldRun = previewState == .playing || previewState == .loading || activePreviewSource != nil
        guard shouldRun else { return }
        videoPreviewTask = Task { [weak self] in
            guard let self else { return }
            await self.videoPreviewService?.stop()
            guard !Task.isCancelled else { return }
            await self.startVideoPreview(at: position)
        }
    }

    private func previewDisplayName(stream: MediaInspectionStream, fallback: String) -> String {
        [stream.language, stream.title, stream.codec_name?.uppercased()].compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }.joined(separator: " · ").nonEmpty ?? fallback
    }

    private func beginPreviewMonitoring(operationID: UUID) {
        previewMonitorTask?.cancel()
        previewMonitorTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.previewOperationID == operationID else { return }
                await self.refreshPreviewSnapshot(operationID: operationID)
                guard self.previewOperationID == operationID else { return }
                if [.idle, .finished, .failed].contains(self.previewState) { return }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func refreshPreviewSnapshot(operationID: UUID) async {
        if let previewService, previewSourceID != nil || requestedPreviewSourceID != nil || activePreviewSource != nil {
            let snapshot = await previewService.snapshot()
            guard previewOperationID == operationID else { return }
            previewState = snapshot.state
            previewPosition = snapshot.position
            previewDuration = snapshot.duration
            previewTitle = snapshot.title
            previewSourceID = snapshot.sourceID
            if snapshot.sourceID == requestedPreviewSourceID || [.idle, .failed].contains(snapshot.state) {
                requestedPreviewSourceID = nil
            }
            if snapshot.state == .failed, let message = snapshot.errorMessage, errorMessage == nil { errorMessage = message }
        }
        if let videoPreviewService {
            let video = await videoPreviewService.snapshot(position: previewPosition)
            guard previewOperationID == operationID else { return }
            videoPreviewState = video.state
            videoPreviewSourceID = video.sourceID
            if let frame = video.frame { videoPreviewFrame = frame }
            if activePreviewSource == nil, let frame = video.frame {
                previewPosition = frame.timestamp
                previewDuration = video.duration
                previewSourceID = video.sourceID
                previewState = video.state
            }
            if video.state == .failed, let message = video.errorMessage, errorMessage == nil { errorMessage = message }
        }
    }

    private func synchronizeSelectedAudioStreamIndex(_ streamIndex: Int) {
        guard selectedAudioStreamIndex != streamIndex else { return }
        suppressPreviewSelectionSideEffects = true
        selectedAudioStreamIndex = streamIndex
        if spectrogramChannel != .mix { spectrogramChannel = .mix }
        suppressPreviewSelectionSideEffects = false
        invalidateSpectrogram()
    }

    private func invalidateWaveformForPreviewChange() {
        waveformTask?.cancel()
        waveformTask = nil
        waveformGenerationID = UUID()
        waveform = nil
        isGeneratingWaveform = false
    }

    private func prepareWaveform(
        source: MultimediaAudioPreviewSource,
        channel: SpectrogramChannelSelection,
        ffmpeg: URL
    ) {
        guard let waveformService else { return }
        let previous = waveformTask
        previous?.cancel()
        let generationID = UUID()
        waveformGenerationID = generationID
        waveform = nil
        isGeneratingWaveform = true
        waveformTask = Task { [weak self] in
            await waveformService.cancel()
            _ = await previous?.result
            guard let self else { return }
            do {
                try Task.checkCancellation()
                let result = try await waveformService.analyze(
                    ffmpeg: ffmpeg,
                    request: .init(source: source, channelSelection: channel, maximumBuckets: 65_536)
                )
                try Task.checkCancellation()
                guard self.waveformGenerationID == generationID,
                      self.previewSourceID == source.id else { return }
                self.waveform = result
            } catch is CancellationError {
            } catch {
                // La waveform es auxiliar: un fallo no debe interrumpir una reproducción que funciona.
            }
            if self.waveformGenerationID == generationID { self.isGeneratingWaveform = false }
        }
    }

    func seekToChapter(_ chapter: MediaInspectionChapter) {
        guard let seconds = MultimediaTimeParser.seconds(chapter.start_time) else { return }
        if previewSourceID != nil { seekPreview(to: seconds) }
        else { previewSelectedSpectrogram(at: seconds) }
    }

    func timingEntry(for track: MediaEditableTrack) -> AudioTimingEntry? {
        audioTimingAnalysis?.entries.first { $0.streamIndex == track.source.streamIndex }
    }

    func loudnessResult(for track: MediaEditableTrack) -> AudioLoudnessResult? {
        guard let id = previewSourceID(for: track) else { return nil }
        return loudnessResults[id]
    }

    func signalAnalysisResult(for track: MediaEditableTrack) -> AudioSignalAnalysisResult? {
        guard let id = previewSourceID(for: track) else { return nil }
        return signalAnalysisResults[id]
    }

    func isLoudnessAnalysisActive(for track: MediaEditableTrack) -> Bool {
        guard isAnalyzingLoudness, let id = previewSourceID(for: track) else { return false }
        return loudnessSourceID == id
    }

    func isSignalAnalysisActive(for track: MediaEditableTrack) -> Bool {
        guard isAnalyzingSignal, let id = previewSourceID(for: track) else { return false }
        return signalAnalysisSourceID == id
    }

    var selectedSpectrogramSourceID: String? {
        guard let url = selectedURL, let fingerprint, let inspection,
              let stream = inspection.audioStreams.first(where: { $0.index == selectedAudioStreamIndex }) ?? inspection.audioStreams.first,
              let index = stream.index else { return nil }
        return MultimediaAudioPreviewSource.identity(url: url, fingerprint: fingerprint, streamIndex: index)
    }

    var selectedAudioLoudness: AudioLoudnessResult? { selectedSpectrogramLoudness }

    var selectedSpectrogramLoudness: AudioLoudnessResult? {
        guard let id = selectedSpectrogramSourceID else { return nil }
        return loudnessResults[id]
    }

    var selectedSpectrogramSignalAnalysis: AudioSignalAnalysisResult? {
        guard let id = selectedSpectrogramSourceID else { return nil }
        return signalAnalysisResults[id]
    }

    var currentPreviewLoudness: AudioLoudnessResult? {
        guard let id = previewSourceID else { return nil }
        return loudnessResults[id]
    }

    var currentWaveformSignalAnalysis: AudioSignalAnalysisResult? {
        guard let id = waveform?.sourceID ?? previewSourceID ?? activePreviewSource?.id else { return nil }
        return signalAnalysisResults[id]
    }

    var audioTimelineTotalDuration: TimeInterval? {
        [previewDuration, activePreviewSource?.duration, waveform?.duration, fullSpectrogram?.endTime, inspection?.durationSeconds]
            .compactMap { value in guard let value, value.isFinite, value > 0 else { return nil }; return value }
            .max()
    }

    var audioTimelineVisibleRange: AudioTimelineVisibleRange? {
        guard let total = audioTimelineTotalDuration else { return nil }
        return audioTimelineViewport.visibleRange(totalDuration: total)
    }

    var isAudioTimelineZoomed: Bool { !audioTimelineViewport.isFull }

    var canZoomAudioTimelineIn: Bool {
        guard let range = audioTimelineVisibleRange else { return false }
        return range.duration > min(1, range.end) + 0.000_001
    }

    func audioTimelineVisibleRange(totalDuration: TimeInterval) -> AudioTimelineVisibleRange {
        audioTimelineViewport.visibleRange(totalDuration: totalDuration)
    }

    func zoomAudioTimelineIn() { updateAudioTimelineZoom(factor: sessionPreferences.timelineZoomFactor) }
    func zoomAudioTimelineOut() { updateAudioTimelineZoom(factor: 1 / sessionPreferences.timelineZoomFactor) }

    func panAudioTimeline(_ direction: Double) {
        guard let total = audioTimelineTotalDuration else { return }
        audioTimelineViewport = audioTimelineViewport.panned(byFraction: direction * sessionPreferences.timelinePanFraction, totalDuration: total)
        reinterpretSpectrogram()
    }

    func resetAudioTimelineViewport() {
        audioTimelineViewport = .full
        reinterpretSpectrogram()
    }

    private func updateAudioTimelineZoom(factor: Double) {
        guard let total = audioTimelineTotalDuration else { return }
        let hasPreviewSession = previewSourceID != nil || requestedPreviewSourceID != nil || activePreviewSource != nil
        audioTimelineViewport = audioTimelineViewport.zoomed(
            by: factor,
            around: hasPreviewSession ? previewPosition : nil,
            totalDuration: total,
            minimumDuration: 1
        )
        reinterpretSpectrogram()
    }

    var audioTimelineChapterMarkers: [AudioTimelineChapterMarker] {
        guard let selectedURL,
              let activePreviewSource,
              activePreviewSource.url.standardizedFileURL == selectedURL.standardizedFileURL else { return [] }
        if let chapters = currentDraft?.chapters {
            return chapters.enumerated().map { offset, chapter in
                AudioTimelineChapterMarker(id: offset, time: chapter.startTime, title: chapter.title.isEmpty ? "Capítulo \(offset + 1)" : chapter.title)
            }
        }
        return (inspection?.chapters ?? []).enumerated().compactMap { offset, chapter -> AudioTimelineChapterMarker? in
            guard let time = MultimediaTimeParser.seconds(chapter.start_time), time.isFinite, time >= 0 else { return nil }
            let rawTitle = chapter.tags?
                .first(where: { $0.key.caseInsensitiveCompare("title") == .orderedSame })?
                .value
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let title: String
            if let rawTitle, !rawTitle.isEmpty { title = rawTitle } else { title = "Capítulo \(offset + 1)" }
            return AudioTimelineChapterMarker(id: offset, time: time, title: title)
        }
    }

    private func startAutomaticSingleTrackAudioAnalysis() {
        guard let inspection,
              MultimediaAutomaticAudioAnalysisPolicy.shouldRun(audioStreamCount: inspection.audioStreams.count),
              let track = audioTracks.first(where: { $0.kind == .audio }) else { return }
        let preferences = sessionPreferences
        guard preferences.automaticSpectrogramForSingleTrack || preferences.automaticSignalAnalysisForSingleTrack || preferences.automaticLoudnessForSingleTrack || preferences.automaticAdvancedAudioAnalysisForSingleTrack else { return }

        automaticAudioAnalysisTask?.cancel()
        let sessionID = automaticAudioAnalysisSessionID

        if preferences.automaticSpectrogramForSingleTrack { generateSpectrogram() }
        automaticAudioAnalysisTask = Task { [weak self] in
            guard let self else { return }
            do {
                if preferences.automaticSpectrogramForSingleTrack {
                    while self.isGeneratingSpectrogram {
                        let currentSpectrogramTask = self.spectrogramTask
                        _ = await currentSpectrogramTask?.result
                        try Task.checkCancellation()
                        guard self.automaticAudioAnalysisSessionID == sessionID else { return }
                    }
                }

                if preferences.automaticSignalAnalysisForSingleTrack {
                    try Task.checkCancellation()
                    guard self.automaticAudioAnalysisSessionID == sessionID else { return }
                    self.analyzeSignal(track)
                    _ = await self.signalAnalysisTask?.result
                }

                if preferences.automaticLoudnessForSingleTrack {
                    try Task.checkCancellation()
                    guard self.automaticAudioAnalysisSessionID == sessionID else { return }
                    self.analyzeLoudness(track)
                    _ = await self.loudnessTask?.result
                }

                if preferences.automaticAdvancedAudioAnalysisForSingleTrack {
                    try Task.checkCancellation()
                    guard self.automaticAudioAnalysisSessionID == sessionID else { return }
                    self.analyzeAdvancedAudio(track)
                    _ = await self.advancedAudioTask?.result
                }
            } catch is CancellationError {
                // La cancelación de la sesión impide iniciar fases automáticas posteriores.
            } catch {
                // Las fases publican sus propios errores; la inspección técnica sigue siendo válida.
            }
        }
    }

    func analyzeSignal(_ track: MediaEditableTrack) {
        guard track.kind == .audio, !isAnalyzingSignal else { return }
        signalAnalysisTask?.cancel()
        signalAnalysisTask = Task { [weak self] in
            guard let self else { return }
            do {
                let source = try await self.resolvePreviewSource(for: track)
                try await self.runSignalAnalysis(source: source)
            } catch MultimediaInspectorError.cancelled {
            } catch is CancellationError {
            } catch {
                self.errorMessage = Self.clean(error)
            }
        }
    }

    private func runSignalAnalysis(source: MultimediaAudioPreviewSource) async throws {
        guard let signalAnalysisService else { throw MultimediaInspectorError.ffmpegUnavailable }
        isAnalyzingSignal = true
        signalAnalysisProgress = 0
        signalAnalysisSourceID = source.id
        defer {
            isAnalyzingSignal = false
            signalAnalysisSourceID = nil
        }
        let configuration = AudioSignalAnalysisConfiguration(
            silenceThresholdDBFS: sessionPreferences.signalSilenceThresholdDBFS,
            minimumSilenceDuration: sessionPreferences.signalMinimumSilenceDuration,
            clippingThresholdDBFS: sessionPreferences.signalClippingThresholdDBFS,
            minimumConsecutiveClippedSamples: sessionPreferences.signalMinimumConsecutiveClippedSamples
        )
        let result = try await signalAnalysisService.analyze(
            source: source,
            configuration: configuration
        ) { [weak self] fraction in
            Task { @MainActor [weak self] in
                guard let self, self.signalAnalysisSourceID == source.id else { return }
                self.signalAnalysisProgress = max(self.signalAnalysisProgress, min(max(fraction, 0), 1))
            }
        }
        signalAnalysisResults[source.id] = result
        signalAnalysisProgress = 1
    }

    func analyzeLoudness(_ track: MediaEditableTrack) {
        guard track.kind == .audio, !isAnalyzingLoudness else { return }
        loudnessTask?.cancel()
        loudnessTask = Task { [weak self] in
            guard let self else { return }
            do {
                let source = try await self.resolvePreviewSource(for: track)
                try await self.runLoudnessAnalysis(source: source)
            } catch MultimediaInspectorError.cancelled {
            } catch is CancellationError {
            } catch {
                self.errorMessage = Self.clean(error)
            }
        }
    }

    func analyzeCurrentPreviewLoudness() {
        guard let source = activePreviewSource, !isAnalyzingLoudness else { return }
        loudnessTask?.cancel()
        loudnessTask = Task { [weak self] in
            guard let self else { return }
            do { try await self.runLoudnessAnalysis(source: source) }
            catch MultimediaInspectorError.cancelled { }
            catch is CancellationError { }
            catch { self.errorMessage = Self.clean(error) }
        }
    }

    private func runLoudnessAnalysis(source: MultimediaAudioPreviewSource) async throws {
        guard let loudnessService else { throw MultimediaInspectorError.ffmpegUnavailable }
        isAnalyzingLoudness = true
        loudnessProgress = 0
        loudnessSourceID = source.id
        defer {
            isAnalyzingLoudness = false
            loudnessSourceID = nil
        }
        let result = try await loudnessService.analyze(source: source) { [weak self] fraction in
            Task { @MainActor [weak self] in
                guard let self, self.loudnessSourceID == source.id else { return }
                self.loudnessProgress = max(self.loudnessProgress, min(max(fraction, 0), 1))
            }
        }
        loudnessResults[source.id] = result
        loudnessProgress = 1
    }

    func advancedAudioResult(for track: MediaEditableTrack) -> AudioSourceQualityAnalysis? {
        guard let id = previewSourceID(for: track) else { return nil }
        return advancedAudioResults[id]
    }

    func isAdvancedAudioAnalysisActive(for track: MediaEditableTrack) -> Bool {
        guard isAnalyzingAdvancedAudio, let id = previewSourceID(for: track) else { return false }
        return advancedAudioSourceID == id
    }

    var selectedSpectrogramAdvancedAudio: AudioSourceQualityAnalysis? {
        guard let id = selectedSpectrogramSourceID else { return nil }
        return advancedAudioResults[id]
    }

    var currentWaveformAdvancedAudio: AudioSourceQualityAnalysis? {
        guard let id = waveform?.sourceID ?? previewSourceID ?? activePreviewSource?.id else { return nil }
        return advancedAudioResults[id]
    }

    func analyzeAdvancedAudio(_ track: MediaEditableTrack) {
        guard track.kind == .audio, !isAnalyzingAdvancedAudio else { return }
        advancedAudioTask?.cancel()
        advancedAudioTask = Task { [weak self] in
            guard let self else { return }
            do {
                let source = try await self.resolvePreviewSource(for: track)
                try await self.runAdvancedAudioAnalysis(source: source, codec: track.codec)
            } catch MultimediaInspectorError.cancelled {
            } catch is CancellationError {
            } catch {
                self.errorMessage = Self.clean(error)
            }
        }
    }

    private func runAdvancedAudioAnalysis(source: MultimediaAudioPreviewSource, codec: String) async throws {
        guard let advancedAudioService, let locator else { throw MultimediaInspectorError.ffmpegUnavailable }
        isAnalyzingAdvancedAudio = true
        advancedAudioSourceID = source.id
        defer {
            isAnalyzingAdvancedAudio = false
            advancedAudioSourceID = nil
        }
        let request = AudioSourceQualityRequest(
            url: source.url,
            fingerprint: source.fingerprint,
            streamIndex: source.streamIndex,
            sampleRate: source.sampleRate,
            channels: source.channels,
            duration: source.duration,
            codec: codec
        )
        let result = try await advancedAudioService.analyze(ffmpeg: try await locator.ffmpeg(), request: request)
        advancedAudioResults[source.id] = result
    }

    func runBitmapSubtitleOCR(streamIndex: Int) {
        guard !isRunningBitmapSubtitleOCR,
              let stream = inspection?.subtitleStreams.first(where: { $0.index == streamIndex }),
              stream.subtitleRepresentation == .bitmap,
              let selectedURL, let fingerprint, let locator, let bitmapSubtitleOCRService else {
            errorMessage = "Selecciona un subtítulo bitmap compatible con OCR."
            return
        }
        bitmapSubtitleOCRTask?.cancel()
        isRunningBitmapSubtitleOCR = true
        ocrSourceStreamIndex = streamIndex
        ocrDraft = nil
        let request = BitmapSubtitleOCRRequest(
            url: selectedURL,
            fingerprint: fingerprint,
            streamIndex: streamIndex,
            codec: stream.codec_name ?? "unknown",
            timeBase: stream.time_base,
            duration: stream.durationSeconds ?? inspection?.durationSeconds,
            language: stream.language
        )
        let options = sessionPreferences.bitmapSubtitleOCROptions
        bitmapSubtitleOCRTask = Task { [weak self] in
            guard let self else { return }
            defer { self.isRunningBitmapSubtitleOCR = false }
            do {
                let ffmpeg = try await locator.ffmpeg()
                self.ocrDraft = try await bitmapSubtitleOCRService.recognize(ffmpeg: ffmpeg, request: request, options: options)
            } catch MultimediaInspectorError.cancelled {
            } catch is CancellationError {
            } catch {
                self.errorMessage = Self.clean(error)
            }
        }
    }

    func dismissOCRDraft() {
        ocrDraft = nil
        ocrSourceStreamIndex = nil
    }

    func updateOCREvent(_ event: BitmapSubtitleOCREvent) {
        guard var draft = ocrDraft, let index = draft.events.firstIndex(where: { $0.id == event.id }) else { return }
        var normalized = event
        normalized.start = max(0, normalized.start.isFinite ? normalized.start : 0)
        normalized.end = max(normalized.start + 0.05, normalized.end.isFinite ? normalized.end : normalized.start + 0.05)
        normalized.text = normalized.text.replacingOccurrences(of: "\u{0000}", with: "")
        draft.events[index] = normalized
        ocrDraft = draft
    }

    func exportOCRDraft(addToEditing: Bool = false) {
        guard let draft = ocrDraft else { return }
        let panel = NSSavePanel()
        panel.title = addToEditing ? "Guardar y añadir subtítulos OCR" : "Exportar subtítulos OCR"
        panel.prompt = addToEditing ? "Guardar y añadir" : "Exportar"
        panel.allowedContentTypes = [UTType(filenameExtension: "srt")].compactMap { $0 }
        let base = selectedURL?.deletingPathExtension().lastPathComponent ?? "subtitulos"
        panel.nameFieldStringValue = base + "_ocr.srt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try BitmapSubtitleOCRExporter().writeSRT(from: draft, to: url)
            if addToEditing {
                guard isEditing else {
                    warningMessage = "SRT exportado como \(url.lastPathComponent). Activa edición para añadirlo al borrador."
                    return
                }
                addExternalFile(url, kind: .subtitle)
            } else {
                warningMessage = "SRT OCR exportado como \(url.lastPathComponent). La pista bitmap original no se ha modificado."
            }
        } catch {
            errorMessage = Self.clean(error)
        }
    }

    func exportTechnicalReport(_ format: MultimediaTechnicalReportFormat) {
        guard let selectedURL, let inspection, let timing = audioTimingAnalysis else { return }
        let panel = NSSavePanel()
        panel.title = "Exportar informe técnico"
        panel.prompt = "Exportar"
        panel.nameFieldStringValue = selectedURL.deletingPathExtension().lastPathComponent + "_informe_tecnico.\(format.rawValue)"
        switch format {
        case .text: panel.allowedContentTypes = [.plainText]
        case .markdown: panel.allowedContentTypes = [UTType(filenameExtension: "md")].compactMap { $0 }
        case .json: panel.allowedContentTypes = [.json]
        }
        guard panel.runModal() == .OK, let output = panel.url else { return }
        do {
            let items = audioTracks.compactMap { track -> AudioLoudnessReportItem? in
                guard let id = previewSourceID(for: track), let result = loudnessResults[id] else { return nil }
                return AudioLoudnessReportItem(label: reportLabel(for: track), result: result)
            }
            let signalItems = audioTracks.compactMap { track -> AudioSignalReportItem? in
                guard let id = previewSourceID(for: track), let result = signalAnalysisResults[id] else { return nil }
                return AudioSignalReportItem(label: reportLabel(for: track), result: result)
            }
            let advancedItems = audioTracks.compactMap { track -> AudioAdvancedReportItem? in
                guard let id = previewSourceID(for: track), let result = advancedAudioResults[id] else { return nil }
                return AudioAdvancedReportItem(label: reportLabel(for: track), result: result)
            }
            let ocrSummaries: [BitmapSubtitleOCRReportSummary] = ocrDraft.map { draft in
                [.init(
                    streamIndex: draft.sourceStreamIndex,
                    codec: draft.sourceCodec,
                    language: draft.language,
                    eventCount: draft.events.filter(\.included).count,
                    needsReviewCount: draft.events.filter { $0.included && $0.needsReview }.count
                )]
            } ?? []
            let structuralSummary = editPlan.map { plan in
                MultimediaStructuralEditReportSummary(
                    targetContainer: plan.targetContainer.displayName,
                    videoStreams: plan.videoTracks.count,
                    audioStreams: plan.audioTracks.count,
                    subtitleStreams: plan.subtitleTracks.count,
                    artworks: plan.artworks.count,
                    warnings: plan.warnings.count
                )
            }
            let context = MultimediaTechnicalReportContext(
                fileName: selectedURL.lastPathComponent,
                inspection: inspection,
                timing: timing,
                loudness: items,
                signal: signalItems,
                advancedAudio: advancedItems,
                ocrSummaries: ocrSummaries,
                structuralEdit: structuralSummary
            )
            let published = try reportExporter.export(
                context: context,
                format: format,
                proposedOutput: output,
                protectedOriginals: [selectedURL],
                sections: sessionPreferences.reportSections
            )
            warningMessage = "Informe técnico exportado como \(published.lastPathComponent)."
        } catch {
            errorMessage = Self.clean(error)
        }
    }

    private func reportLabel(for track: MediaEditableTrack) -> String {
        let base = [track.language.nonEmpty, track.title.nonEmpty, track.codec.uppercased().nonEmpty].compactMap { $0 }
        if !base.isEmpty { return base.joined(separator: " · ") }
        return "Pista de audio"
    }

    func preparePlan() {
        guard let draft=currentDraft else{return}
        do { editPlan=try MediaEditPlanner(preferences: sessionPreferences).plan(from:draft); if let plan=editPlan, plan.targetContainer != draft.targetContainer { warningMessage="Para evitar recodificar vídeo o audio, el resultado se propone como \(plan.targetContainer.displayName)." } }
        catch { errorMessage=Self.clean(error) }
    }

    func executePreparedPlan() {
        guard let plan = editPlan, let inspection, let editService else { return }
        stopPreview()
        let panel = NSSavePanel()
        panel.title = "Guardar archivo editado"
        panel.prompt = "Generar archivo nuevo"
        panel.nameFieldStringValue = MultimediaFilenamePolicy().suggestedName(
            original: plan.originalURL,
            container: plan.targetContainer,
            suffix: sessionPreferences.outputSuffix
        )
        panel.allowedContentTypes = [UTType(filenameExtension: plan.targetContainer.fileExtension)].compactMap { $0 }
        guard panel.runModal() == .OK, let output = panel.url else { return }
        isExecuting = true
        errorMessage = nil
        executionTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await editService.execute(plan: plan, originalInspection: inspection, proposedOutput: output)
                self.cacheInspectionTracks(result.inspection)
                self.inspection = result.inspection
                self.selectedURL = result.outputURL
                self.fingerprint = try? FileFingerprint.read(from: result.outputURL)
                self.draftHistory = nil
                self.editPlan = nil
                self.configureDefaultComparisonTracks()
                self.spectrogramTask?.cancel()
                self.spectrogramGenerationID = UUID()
                self.spectrogram = nil
                self.fullSpectrogram = nil
                self.waveformTask?.cancel()
                self.waveform = nil
                self.loudnessTask?.cancel()
                self.loudnessResults = [:]
                self.signalAnalysisTask?.cancel()
                self.signalAnalysisResults = [:]
                self.selectedVideoStreamIndex = result.inspection.videoStreams.first?.index
                self.selectedAudioStreamIndex = result.inspection.audioStreams.first?.index
                self.warningMessage = [
                    "Resultado publicado como \(result.outputURL.lastPathComponent). El original no se ha modificado.",
                    result.historyWarning,
                ].compactMap { $0 }.joined(separator: " ")
            } catch {
                self.errorMessage = Self.clean(error)
            }
            self.isExecuting = false
        }
    }

    private func cacheInspectionTracks(_ inspection: MediaInspectionResult) {
        inspectionVideoTracks = inspection.videoStreams.compactMap { .from(stream: $0, kind: .video) }
        inspectionAudioTracks = inspection.audioStreams.compactMap { .from(stream: $0, kind: .audio) }
        inspectionSubtitleTracks = inspection.subtitleStreams.compactMap { .from(stream: $0, kind: .subtitle) }
    }

    private func configureDefaultComparisonTracks() {
        let tracks = audioTracks
        let validIDs = Set(tracks.map(\.id))
        if let comparisonTrackAID, !validIDs.contains(comparisonTrackAID) { self.comparisonTrackAID = nil }
        if let comparisonTrackBID, !validIDs.contains(comparisonTrackBID) { self.comparisonTrackBID = nil }
        if comparisonTrackAID == nil { comparisonTrackAID = tracks.first?.id }
        if comparisonTrackBID == nil || comparisonTrackBID == comparisonTrackAID {
            comparisonTrackBID = tracks.first(where: { $0.id != comparisonTrackAID })?.id
        }
        if comparisonTrack(for: activeComparisonSlot) == nil {
            activeComparisonSlot = comparisonTrackAID != nil ? .a : .b
        }
    }

    private func invalidateSpectrogram() {
        spectrogramTask?.cancel()
        fullSpectrogram = nil; spectrogram = nil
        // La nueva petición espera a que la anterior termine y libere su proceso/coordinador.
        if isGeneratingSpectrogram { generateSpectrogram() }
    }

    func reinterpretSpectrogram() {
        guard let fullSpectrogram else { return }
        let visible = audioTimelineViewport.visibleRange(totalDuration: fullSpectrogram.endTime)
        spectrogram = fullSpectrogram
            .cropped(start: visible.start, duration: audioTimelineViewport.isFull ? nil : visible.duration)
            .displaying(dynamicRange: .init(minimumDB: spectrogramDynamicMinimum, maximumDB: 0))
    }

    func generateSpectrogram() {
        guard let url = selectedURL, let inspection, let service = spectrogramService,
              let stream = inspection.audioStreams.first(where: { $0.index == selectedAudioStreamIndex }) ?? inspection.audioStreams.first,
              let streamIndex = stream.index,
              let sampleRate = stream.sampleRateValue, sampleRate.isFinite, sampleRate > 0,
              let channels = stream.channels, channels > 0 else {
            errorMessage = "Selecciona una pista de audio con sample rate y canales reconocibles."; return
        }
        let request = SpectrogramAnalysisRequest(url: url, streamIndex: streamIndex, sampleRate: sampleRate, channels: channels,
            channelSelection: spectrogramChannel, window: spectrogramWindow, fftSize: spectrogramFFTSize,
            dynamicRange: .init(minimumDB: spectrogramDynamicMinimum, maximumDB: 0),
            duration: inspection.durationSeconds, maximumColumns: sessionPreferences.spectrogramMaximumColumns)
        let previous = spectrogramTask
        previous?.cancel()
        let generationID = UUID(); spectrogramGenerationID = generationID
        isGeneratingSpectrogram = true; spectrogramProgress = 0; errorMessage = nil
        spectrogramTask = Task { [weak self] in
            _ = await previous?.result
            guard let self else { return }
            do {
                try Task.checkCancellation()
                let result = try await service.analyze(request) { [weak self] fraction in
                    Task { @MainActor [weak self] in
                        guard let self, self.spectrogramGenerationID == generationID else { return }
                        self.spectrogramProgress = max(self.spectrogramProgress, fraction)
                    }
                }
                try Task.checkCancellation()
                guard self.spectrogramGenerationID == generationID else { return }
                self.fullSpectrogram = result
                self.reinterpretSpectrogram()
            } catch MultimediaInspectorError.cancelled {
                // Cancelación esperada, sin publicar resultados parciales.
            } catch is CancellationError {
                // También se cancela al sustituir una pista o parámetro analítico.
            } catch {
                if self.spectrogramGenerationID == generationID { self.errorMessage = Self.clean(error) }
            }
            if self.spectrogramGenerationID == generationID { self.isGeneratingSpectrogram = false }
        }
    }

    func exportSpectrogramPNG() {
        guard let spectrogram else { return }
        let panel = NSSavePanel()
        panel.title = "Exportar espectrograma"
        panel.prompt = "Exportar PNG"
        panel.nameFieldStringValue = (selectedURL?.deletingPathExtension().lastPathComponent ?? "espectrograma") + "_espectrograma.png"
        panel.allowedContentTypes = [.png]
        guard panel.runModal() == .OK, let target = panel.url else { return }
        isExportingSpectrogram = true
        exportTask = Task { [weak self] in
            guard let self else { return }
            do {
                let exportResult = try await spectrogramExportService.export(
                    result: spectrogram,
                    frequencyScale: spectrogramFrequencyScale,
                    proposedOutput: target,
                    protectedOriginals: selectedURL.map { [$0] } ?? [],
                    width: sessionPreferences.spectrogramExportWidth,
                    height: sessionPreferences.spectrogramExportHeight
                )
                self.warningMessage = [
                    "Espectrograma exportado como \(exportResult.outputURL.lastPathComponent).",
                    exportResult.historyWarning,
                ].compactMap { $0 }.joined(separator: " ")
            } catch MultimediaInspectorError.cancelled {
                // No se muestra una cancelación voluntaria como error.
            } catch is CancellationError {
                // Cancelación local de la tarea de exportación.
            } catch {
                self.errorMessage = Self.clean(error)
            }
            self.isExportingSpectrogram = false
        }
    }

    func cancelCurrentOperation() {
        if batch.isRunning { batch.cancel() }
        inspectionTask?.cancel()
        executionTask?.cancel()
        automaticAudioAnalysisTask?.cancel()
        spectrogramTask?.cancel()
        exportTask?.cancel()
        attachmentExtractionTask?.cancel()
        waveformTask?.cancel()
        loudnessTask?.cancel()
        signalAnalysisTask?.cancel()
        advancedAudioTask?.cancel()
        bitmapSubtitleOCRTask?.cancel()
        comparisonAnalysisTask?.cancel()
        Task {
            await inspector.cancel()
            await editService?.cancel()
            await spectrogramService?.cancel()
            await spectrogramExportService.cancel()
            await attachmentExtractionService?.cancel()
            await waveformService?.cancel()
            await loudnessService?.cancel()
            await signalAnalysisService?.cancel()
            await advancedAudioService?.cancel()
            await bitmapSubtitleOCRService?.cancel()
        }
    }

    func cancelAndWait() async {
        cancelCurrentOperation()
        await batch.cancelAndWait()
        await previewService?.stop()
        await waveformService?.cancel()
        await loudnessService?.cancel()
        await signalAnalysisService?.cancel()
        await advancedAudioService?.cancel()
        await bitmapSubtitleOCRService?.cancel()
        _ = await inspectionTask?.result
        _ = await executionTask?.result
        _ = await spectrogramTask?.result
        _ = await automaticAudioAnalysisTask?.result
        _ = await exportTask?.result
        _ = await attachmentExtractionTask?.result
        _ = await waveformTask?.result
        _ = await loudnessTask?.result
        _ = await signalAnalysisTask?.result
        _ = await advancedAudioTask?.result
        _ = await bitmapSubtitleOCRTask?.result
        _ = await comparisonAnalysisTask?.result
    }

    static func clean(_ error: Error) -> String { (error as? LocalizedError)?.errorDescription ?? error.localizedDescription }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
