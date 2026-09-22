import Foundation

public enum SpectrogramWindowFunction: String, Codable, CaseIterable, Sendable, Identifiable {
    case hann, hamming, blackmanHarris
    public var id: String { rawValue }
    public var displayName: String {
        switch self { case .hann: return "Hann"; case .hamming: return "Hamming"; case .blackmanHarris: return "Blackman–Harris" }
    }
}

public enum SpectrogramInitialChannel: String, Codable, CaseIterable, Sendable, Identifiable {
    case mix, firstChannel
    public var id: String { rawValue }
    public var displayName: String { self == .mix ? "Mezcla" : "Primer canal" }
}

public enum MultimediaInspectorInitialTab: String, Codable, CaseIterable, Sendable, Identifiable {
    case summary, tracks, spectrogram, metadata
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .summary: return "Resumen"
        case .tracks: return "Pistas"
        case .spectrogram: return "Espectrograma"
        case .metadata: return "Metadatos"
        }
    }
}

public enum MultimediaInspectorDetailLevel: String, Codable, CaseIterable, Sendable, Identifiable {
    case useful, technical
    public var id: String { rawValue }
    public var displayName: String { self == .useful ? "Útil" : "Técnico" }
}

public enum SpectrogramFrequencyScale: String, Codable, CaseIterable, Sendable, Identifiable {
    case linear, logarithmic
    public var id: String { rawValue }
    public var displayName: String { self == .linear ? "Lineal" : "Logarítmica" }
}

public enum MultimediaWaveformStyle: String, Codable, CaseIterable, Sendable, Identifiable {
    case compact, balanced, detailed
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .compact: return "Compacta"
        case .balanced: return "Equilibrada"
        case .detailed: return "Detallada"
        }
    }
}

public enum MultimediaWaveformRepresentation: String, Codable, CaseIterable, Sendable, Identifiable {
    case peaks, peaksAndEnergy
    public var id: String { rawValue }
    public var displayName: String { self == .peaks ? "Picos" : "Picos + energía" }
}

public struct MultimediaInspectorPreferences: Codable, Sendable, Equatable {
    public var defaultWindow: SpectrogramWindowFunction
    public var defaultFFTSize: Int
    public var allowedFFTSizes: [Int]
    public var defaultDynamicRange: ClosedRange<Float>
    public var spectrogramMaximumColumns: Int
    public var defaultFrequencyScale: SpectrogramFrequencyScale
    public var defaultChannel: SpectrogramInitialChannel
    public var spectrogramExportWidth: Int
    public var spectrogramExportHeight: Int
    public var outputSuffix: String
    public var preferredContainer: EditableMediaContainer?
    public var initialTab: MultimediaInspectorInitialTab
    public var detailLevel: MultimediaInspectorDetailLevel
    public var preserveMetadata: Bool
    public var waveformStyle: MultimediaWaveformStyle
    public var waveformRepresentation: MultimediaWaveformRepresentation
    public var waveformShowsCenterGuide: Bool
    public var showChapterMarkersOnWaveform: Bool
    public var showSignalOverlaysOnWaveform: Bool
    public var showSignalOverlaysOnSpectrogram: Bool
    public var showLoudnessTimeline: Bool
    public var previewVolume: Double
    public var previewSkipSeconds: Int
    public var previewTrackSwitchKeepsPosition: Bool
    public var previewTrackSwitchKeepsPlaybackState: Bool
    public var videoPreviewLimits: MultimediaVideoPreviewLimits
    public var videoPreviewDecoder: MultimediaVideoPreviewDecoder
    public var videoPreviewScaleMode: MultimediaVideoPreviewScaleMode
    public var previewPlaybackRate: Double
    public var subtitlePreviewFontSize: Double
    public var subtitlePreviewBackgroundOpacity: Double
    public var timelineZoomFactor: Double
    public var timelinePanFraction: Double
    public var signalSilenceThresholdDBFS: Double
    public var signalMinimumSilenceDuration: Double
    public var signalClippingThresholdDBFS: Double
    public var signalMinimumConsecutiveClippedSamples: Int
    public var automaticSpectrogramForSingleTrack: Bool
    public var automaticSignalAnalysisForSingleTrack: Bool
    public var automaticLoudnessForSingleTrack: Bool
    public var automaticAdvancedAudioAnalysisForSingleTrack: Bool
    public var batchFolderOptions: MultimediaBatchFolderOptions
    public var bitmapSubtitleOCROptions: BitmapSubtitleOCROptions
    public var showAdvancedAudioOverlays: Bool
    public var defaultReportFormat: MultimediaTechnicalReportFormat
    public var reportSections: MultimediaTechnicalReportSections
    public var defaultBatchPresetID: UUID?

    public init(
        defaultWindow: SpectrogramWindowFunction = .hann,
        defaultFFTSize: Int = 4096,
        allowedFFTSizes: [Int] = Self.defaultAllowedFFTSizes,
        defaultDynamicRange: ClosedRange<Float> = -120 ... 0,
        spectrogramMaximumColumns: Int = 1800,
        defaultFrequencyScale: SpectrogramFrequencyScale = .linear,
        defaultChannel: SpectrogramInitialChannel = .mix,
        spectrogramExportWidth: Int = 1600,
        spectrogramExportHeight: Int = 900,
        outputSuffix: String = "_editado",
        preferredContainer: EditableMediaContainer? = nil,
        initialTab: MultimediaInspectorInitialTab = .summary,
        detailLevel: MultimediaInspectorDetailLevel = .useful,
        preserveMetadata: Bool = true,
        waveformStyle: MultimediaWaveformStyle = .balanced,
        waveformRepresentation: MultimediaWaveformRepresentation = .peaks,
        waveformShowsCenterGuide: Bool = false,
        showChapterMarkersOnWaveform: Bool = true,
        showSignalOverlaysOnWaveform: Bool = true,
        showSignalOverlaysOnSpectrogram: Bool = true,
        showLoudnessTimeline: Bool = true,
        previewVolume: Double = 1,
        previewSkipSeconds: Int = 15,
        previewTrackSwitchKeepsPosition: Bool = true,
        previewTrackSwitchKeepsPlaybackState: Bool = true,
        videoPreviewLimits: MultimediaVideoPreviewLimits = .default,
        videoPreviewDecoder: MultimediaVideoPreviewDecoder = .automatic,
        videoPreviewScaleMode: MultimediaVideoPreviewScaleMode = .fit,
        previewPlaybackRate: Double = 1,
        subtitlePreviewFontSize: Double = 24,
        subtitlePreviewBackgroundOpacity: Double = 0.72,
        timelineZoomFactor: Double = 0.5,
        timelinePanFraction: Double = 0.5,
        signalSilenceThresholdDBFS: Double = -60,
        signalMinimumSilenceDuration: Double = 0.5,
        signalClippingThresholdDBFS: Double = -0.1,
        signalMinimumConsecutiveClippedSamples: Int = 3,
        automaticSpectrogramForSingleTrack: Bool = true,
        automaticSignalAnalysisForSingleTrack: Bool = true,
        automaticLoudnessForSingleTrack: Bool = true,
        automaticAdvancedAudioAnalysisForSingleTrack: Bool = false,
        batchFolderOptions: MultimediaBatchFolderOptions = .init(),
        bitmapSubtitleOCROptions: BitmapSubtitleOCROptions = .init(),
        showAdvancedAudioOverlays: Bool = true,
        defaultReportFormat: MultimediaTechnicalReportFormat = .markdown,
        reportSections: MultimediaTechnicalReportSections = .all,
        defaultBatchPresetID: UUID? = nil
    ) {
        self.defaultWindow = defaultWindow
        self.defaultFFTSize = defaultFFTSize
        self.allowedFFTSizes = allowedFFTSizes
        self.defaultDynamicRange = defaultDynamicRange
        self.spectrogramMaximumColumns = spectrogramMaximumColumns
        self.defaultFrequencyScale = defaultFrequencyScale
        self.defaultChannel = defaultChannel
        self.spectrogramExportWidth = spectrogramExportWidth
        self.spectrogramExportHeight = spectrogramExportHeight
        self.outputSuffix = outputSuffix
        self.preferredContainer = preferredContainer
        self.initialTab = initialTab
        self.detailLevel = detailLevel
        self.preserveMetadata = preserveMetadata
        self.waveformStyle = waveformStyle
        self.waveformRepresentation = waveformRepresentation
        self.waveformShowsCenterGuide = waveformShowsCenterGuide
        self.showChapterMarkersOnWaveform = showChapterMarkersOnWaveform
        self.showSignalOverlaysOnWaveform = showSignalOverlaysOnWaveform
        self.showSignalOverlaysOnSpectrogram = showSignalOverlaysOnSpectrogram
        self.showLoudnessTimeline = showLoudnessTimeline
        self.previewVolume = previewVolume
        self.previewSkipSeconds = previewSkipSeconds
        self.previewTrackSwitchKeepsPosition = previewTrackSwitchKeepsPosition
        self.previewTrackSwitchKeepsPlaybackState = previewTrackSwitchKeepsPlaybackState
        self.videoPreviewLimits = videoPreviewLimits
        self.videoPreviewDecoder = videoPreviewDecoder
        self.videoPreviewScaleMode = videoPreviewScaleMode
        self.previewPlaybackRate = previewPlaybackRate
        self.subtitlePreviewFontSize = subtitlePreviewFontSize
        self.subtitlePreviewBackgroundOpacity = subtitlePreviewBackgroundOpacity
        self.timelineZoomFactor = timelineZoomFactor
        self.timelinePanFraction = timelinePanFraction
        self.signalSilenceThresholdDBFS = signalSilenceThresholdDBFS
        self.signalMinimumSilenceDuration = signalMinimumSilenceDuration
        self.signalClippingThresholdDBFS = signalClippingThresholdDBFS
        self.signalMinimumConsecutiveClippedSamples = signalMinimumConsecutiveClippedSamples
        self.automaticSpectrogramForSingleTrack = automaticSpectrogramForSingleTrack
        self.automaticSignalAnalysisForSingleTrack = automaticSignalAnalysisForSingleTrack
        self.automaticLoudnessForSingleTrack = automaticLoudnessForSingleTrack
        self.automaticAdvancedAudioAnalysisForSingleTrack = automaticAdvancedAudioAnalysisForSingleTrack
        self.batchFolderOptions = batchFolderOptions
        self.bitmapSubtitleOCROptions = bitmapSubtitleOCROptions
        self.showAdvancedAudioOverlays = showAdvancedAudioOverlays
        self.defaultReportFormat = defaultReportFormat
        self.reportSections = reportSections
        self.defaultBatchPresetID = defaultBatchPresetID
        normalize()
    }

    public mutating func normalize() {
        let normalizedSizes = Array(Set(allowedFFTSizes.filter { $0 >= 256 && $0 <= 32768 && $0.nonzeroBitCount == 1 })).sorted()
        allowedFFTSizes = normalizedSizes.isEmpty ? Self.defaultAllowedFFTSizes : normalizedSizes
        if !allowedFFTSizes.contains(defaultFFTSize) { defaultFFTSize = allowedFFTSizes.contains(4096) ? 4096 : allowedFFTSizes[0] }
        let lower = min(max(defaultDynamicRange.lowerBound, -180), -20)
        let upper = min(max(defaultDynamicRange.upperBound, lower + 1), 12)
        defaultDynamicRange = lower ... upper
        spectrogramMaximumColumns = min(max(spectrogramMaximumColumns, 256), 8192)
        spectrogramExportWidth = min(max(spectrogramExportWidth, 320), 4096)
        spectrogramExportHeight = min(max(spectrogramExportHeight, 180), 4096)
        let trimmedSuffix = outputSuffix.trimmingCharacters(in: .whitespacesAndNewlines)
        outputSuffix = trimmedSuffix.isEmpty ? "_editado" : trimmedSuffix
        previewVolume = min(max(previewVolume.isFinite ? previewVolume : 1, 0), 1)
        if !Self.allowedPreviewSkipSeconds.contains(previewSkipSeconds) { previewSkipSeconds = 15 }
        videoPreviewLimits.normalize()
        previewPlaybackRate = min(max(previewPlaybackRate.isFinite ? previewPlaybackRate : 1, 0.5), 2)
        batchFolderOptions.normalize()
        bitmapSubtitleOCROptions.normalize()
        timelineZoomFactor = min(max(timelineZoomFactor.isFinite ? timelineZoomFactor : 0.5, 0.2), 0.9)
        timelinePanFraction = min(max(timelinePanFraction.isFinite ? timelinePanFraction : 0.5, 0.1), 1)
        signalSilenceThresholdDBFS = min(max(signalSilenceThresholdDBFS.isFinite ? signalSilenceThresholdDBFS : -60, -120), -10)
        signalMinimumSilenceDuration = min(max(signalMinimumSilenceDuration.isFinite ? signalMinimumSilenceDuration : 0.5, 0.05), 30)
        signalClippingThresholdDBFS = min(max(signalClippingThresholdDBFS.isFinite ? signalClippingThresholdDBFS : -0.1, -6), 0)
        signalMinimumConsecutiveClippedSamples = min(max(signalMinimumConsecutiveClippedSamples, 2), 64)
    }

    public static let defaultAllowedFFTSizes = [1024, 2048, 4096, 8192, 16384]
    public static let allowedPreviewSkipSeconds = [5, 10, 15, 30, 60]
    public static let defaults = MultimediaInspectorPreferences()

    public var batchConfigurationDefaults: MultimediaBatchConfiguration {
        MultimediaBatchConfiguration(
            analyzeSignal: automaticSignalAnalysisForSingleTrack,
            analyzeLoudness: automaticLoudnessForSingleTrack,
            exportSpectrogram: false,
            reportFormat: defaultReportFormat,
            reportSections: reportSections,
            spectrogramWindow: defaultWindow,
            spectrogramFFTSize: defaultFFTSize,
            spectrogramDynamicRange: defaultDynamicRange,
            spectrogramMaximumColumns: spectrogramMaximumColumns,
            spectrogramFrequencyScale: defaultFrequencyScale,
            spectrogramChannel: defaultChannel,
            spectrogramExportWidth: spectrogramExportWidth,
            spectrogramExportHeight: spectrogramExportHeight,
            signalSilenceThresholdDBFS: signalSilenceThresholdDBFS,
            signalMinimumSilenceDuration: signalMinimumSilenceDuration,
            signalClippingThresholdDBFS: signalClippingThresholdDBFS,
            signalMinimumConsecutiveClippedSamples: signalMinimumConsecutiveClippedSamples
        )
    }

    private enum CodingKeys: String, CodingKey {
        case defaultWindow, defaultFFTSize, allowedFFTSizes, defaultDynamicRange, spectrogramMaximumColumns
        case defaultFrequencyScale, defaultChannel, spectrogramExportWidth, spectrogramExportHeight
        case outputSuffix, preferredContainer, initialTab, detailLevel, preserveMetadata
        case waveformStyle, waveformRepresentation, waveformShowsCenterGuide
        case showChapterMarkersOnWaveform, showSignalOverlaysOnWaveform, showSignalOverlaysOnSpectrogram, showLoudnessTimeline
        case previewVolume, previewSkipSeconds, previewTrackSwitchKeepsPosition, previewTrackSwitchKeepsPlaybackState
        case videoPreviewLimits, videoPreviewDecoder, videoPreviewScaleMode, previewPlaybackRate
        case subtitlePreviewFontSize, subtitlePreviewBackgroundOpacity
        case timelineZoomFactor, timelinePanFraction
        case signalSilenceThresholdDBFS, signalMinimumSilenceDuration, signalClippingThresholdDBFS, signalMinimumConsecutiveClippedSamples
        case automaticSpectrogramForSingleTrack, automaticSignalAnalysisForSingleTrack, automaticLoudnessForSingleTrack
        case automaticAdvancedAudioAnalysisForSingleTrack, batchFolderOptions, bitmapSubtitleOCROptions, showAdvancedAudioOverlays
        case defaultReportFormat, reportSections, defaultBatchPresetID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.defaults
        defaultWindow = try container.decodeIfPresent(SpectrogramWindowFunction.self, forKey: .defaultWindow) ?? defaults.defaultWindow
        defaultFFTSize = try container.decodeIfPresent(Int.self, forKey: .defaultFFTSize) ?? defaults.defaultFFTSize
        allowedFFTSizes = try container.decodeIfPresent([Int].self, forKey: .allowedFFTSizes) ?? defaults.allowedFFTSizes
        defaultDynamicRange = try container.decodeIfPresent(ClosedRange<Float>.self, forKey: .defaultDynamicRange) ?? defaults.defaultDynamicRange
        spectrogramMaximumColumns = try container.decodeIfPresent(Int.self, forKey: .spectrogramMaximumColumns) ?? defaults.spectrogramMaximumColumns
        defaultFrequencyScale = try container.decodeIfPresent(SpectrogramFrequencyScale.self, forKey: .defaultFrequencyScale) ?? defaults.defaultFrequencyScale
        defaultChannel = try container.decodeIfPresent(SpectrogramInitialChannel.self, forKey: .defaultChannel) ?? defaults.defaultChannel
        spectrogramExportWidth = try container.decodeIfPresent(Int.self, forKey: .spectrogramExportWidth) ?? defaults.spectrogramExportWidth
        spectrogramExportHeight = try container.decodeIfPresent(Int.self, forKey: .spectrogramExportHeight) ?? defaults.spectrogramExportHeight
        outputSuffix = try container.decodeIfPresent(String.self, forKey: .outputSuffix) ?? defaults.outputSuffix
        preferredContainer = try container.decodeIfPresent(EditableMediaContainer.self, forKey: .preferredContainer)
        initialTab = try container.decodeIfPresent(MultimediaInspectorInitialTab.self, forKey: .initialTab) ?? defaults.initialTab
        detailLevel = try container.decodeIfPresent(MultimediaInspectorDetailLevel.self, forKey: .detailLevel) ?? defaults.detailLevel
        preserveMetadata = try container.decodeIfPresent(Bool.self, forKey: .preserveMetadata) ?? defaults.preserveMetadata
        waveformStyle = try container.decodeIfPresent(MultimediaWaveformStyle.self, forKey: .waveformStyle) ?? defaults.waveformStyle
        waveformRepresentation = try container.decodeIfPresent(MultimediaWaveformRepresentation.self, forKey: .waveformRepresentation) ?? defaults.waveformRepresentation
        waveformShowsCenterGuide = try container.decodeIfPresent(Bool.self, forKey: .waveformShowsCenterGuide) ?? defaults.waveformShowsCenterGuide
        showChapterMarkersOnWaveform = try container.decodeIfPresent(Bool.self, forKey: .showChapterMarkersOnWaveform) ?? defaults.showChapterMarkersOnWaveform
        showSignalOverlaysOnWaveform = try container.decodeIfPresent(Bool.self, forKey: .showSignalOverlaysOnWaveform) ?? defaults.showSignalOverlaysOnWaveform
        showSignalOverlaysOnSpectrogram = try container.decodeIfPresent(Bool.self, forKey: .showSignalOverlaysOnSpectrogram) ?? defaults.showSignalOverlaysOnSpectrogram
        showLoudnessTimeline = try container.decodeIfPresent(Bool.self, forKey: .showLoudnessTimeline) ?? defaults.showLoudnessTimeline
        previewVolume = try container.decodeIfPresent(Double.self, forKey: .previewVolume) ?? defaults.previewVolume
        previewSkipSeconds = try container.decodeIfPresent(Int.self, forKey: .previewSkipSeconds) ?? defaults.previewSkipSeconds
        previewTrackSwitchKeepsPosition = try container.decodeIfPresent(Bool.self, forKey: .previewTrackSwitchKeepsPosition) ?? defaults.previewTrackSwitchKeepsPosition
        previewTrackSwitchKeepsPlaybackState = try container.decodeIfPresent(Bool.self, forKey: .previewTrackSwitchKeepsPlaybackState) ?? defaults.previewTrackSwitchKeepsPlaybackState
        videoPreviewLimits = try container.decodeIfPresent(MultimediaVideoPreviewLimits.self, forKey: .videoPreviewLimits) ?? defaults.videoPreviewLimits
        videoPreviewDecoder = try container.decodeIfPresent(MultimediaVideoPreviewDecoder.self, forKey: .videoPreviewDecoder) ?? defaults.videoPreviewDecoder
        videoPreviewScaleMode = try container.decodeIfPresent(MultimediaVideoPreviewScaleMode.self, forKey: .videoPreviewScaleMode) ?? defaults.videoPreviewScaleMode
        previewPlaybackRate = try container.decodeIfPresent(Double.self, forKey: .previewPlaybackRate) ?? defaults.previewPlaybackRate
        subtitlePreviewFontSize = try container.decodeIfPresent(Double.self, forKey: .subtitlePreviewFontSize) ?? defaults.subtitlePreviewFontSize
        subtitlePreviewBackgroundOpacity = try container.decodeIfPresent(Double.self, forKey: .subtitlePreviewBackgroundOpacity) ?? defaults.subtitlePreviewBackgroundOpacity
        timelineZoomFactor = try container.decodeIfPresent(Double.self, forKey: .timelineZoomFactor) ?? defaults.timelineZoomFactor
        timelinePanFraction = try container.decodeIfPresent(Double.self, forKey: .timelinePanFraction) ?? defaults.timelinePanFraction
        signalSilenceThresholdDBFS = try container.decodeIfPresent(Double.self, forKey: .signalSilenceThresholdDBFS) ?? defaults.signalSilenceThresholdDBFS
        signalMinimumSilenceDuration = try container.decodeIfPresent(Double.self, forKey: .signalMinimumSilenceDuration) ?? defaults.signalMinimumSilenceDuration
        signalClippingThresholdDBFS = try container.decodeIfPresent(Double.self, forKey: .signalClippingThresholdDBFS) ?? defaults.signalClippingThresholdDBFS
        signalMinimumConsecutiveClippedSamples = try container.decodeIfPresent(Int.self, forKey: .signalMinimumConsecutiveClippedSamples) ?? defaults.signalMinimumConsecutiveClippedSamples
        automaticSpectrogramForSingleTrack = try container.decodeIfPresent(Bool.self, forKey: .automaticSpectrogramForSingleTrack) ?? defaults.automaticSpectrogramForSingleTrack
        automaticSignalAnalysisForSingleTrack = try container.decodeIfPresent(Bool.self, forKey: .automaticSignalAnalysisForSingleTrack) ?? defaults.automaticSignalAnalysisForSingleTrack
        automaticLoudnessForSingleTrack = try container.decodeIfPresent(Bool.self, forKey: .automaticLoudnessForSingleTrack) ?? defaults.automaticLoudnessForSingleTrack
        automaticAdvancedAudioAnalysisForSingleTrack = try container.decodeIfPresent(Bool.self, forKey: .automaticAdvancedAudioAnalysisForSingleTrack) ?? defaults.automaticAdvancedAudioAnalysisForSingleTrack
        batchFolderOptions = try container.decodeIfPresent(MultimediaBatchFolderOptions.self, forKey: .batchFolderOptions) ?? defaults.batchFolderOptions
        bitmapSubtitleOCROptions = try container.decodeIfPresent(BitmapSubtitleOCROptions.self, forKey: .bitmapSubtitleOCROptions) ?? defaults.bitmapSubtitleOCROptions
        showAdvancedAudioOverlays = try container.decodeIfPresent(Bool.self, forKey: .showAdvancedAudioOverlays) ?? defaults.showAdvancedAudioOverlays
        defaultReportFormat = try container.decodeIfPresent(MultimediaTechnicalReportFormat.self, forKey: .defaultReportFormat) ?? defaults.defaultReportFormat
        reportSections = try container.decodeIfPresent(MultimediaTechnicalReportSections.self, forKey: .reportSections) ?? defaults.reportSections
        defaultBatchPresetID = try container.decodeIfPresent(UUID.self, forKey: .defaultBatchPresetID)
        normalize()
    }
}
