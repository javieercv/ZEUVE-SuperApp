import Foundation
import ZEUVECore

public struct UniversalConverterSettings: Codable, Sendable, Equatable {
    public var defaultAdvancedMode: Bool
    public var quality: ConverterQualityProfile
    public var conflictPolicy: ConverterConflictPolicy
    public var filenameStyle: ConverterFilenameStyle
    public var preserveMetadata: Bool
    public var preserveDates: Bool
    public var avoidUpscaling: Bool
    public var preferRemuxWhenPossible: Bool
    public var frameFormat: ConverterFrameFormat
    public var automaticHighBitDepthFrames: Bool
    public var createFrameTimingCSV: Bool
    public var audioVideoCanvas: ConverterVideoCanvas
    public var audioVideoWidth: Int
    public var audioVideoHeight: Int
    public var audioVideoFPS: Int
    public var audioVideoFit: ConverterImageFit
    public var recompressZIPResults: Bool
    public var pdfRasterDPI: Int
    public var imageResizeMode: ConverterImageResizeMode
    public var imageResizePercentage: Int
    public var imageMaximumWidth: Int
    public var imageMaximumHeight: Int
    public var imageMaintainAspectRatio: Bool
    public var audioBitrate: ConverterAudioBitrate
    public var audioSampleRate: ConverterAudioSampleRate
    public var audioChannels: ConverterAudioChannels
    public var normalizeAudio: Bool
    public var preserveCoverArt: Bool
    public var videoCodec: ConverterVideoCodec
    public var videoResolution: ConverterVideoResolution
    public var videoWidth: Int
    public var videoHeight: Int
    public var videoFrameRate: ConverterVideoFrameRate
    public var videoAudioMode: ConverterVideoAudioMode
    public var preserveSubtitles: Bool
    public var preserveChapters: Bool
    public var metadataPolicy: ConverterMetadataPolicy
    public var outputFolderMode: ConverterOutputFolderMode
    public var outputSubfolderName: String
    public var filenamePrefix: String
    public var filenameSuffix: String
    public var filenameSeparator: String
    public var zipStructureMode: ConverterZIPStructureMode
    public var parallelismMode: ConverterParallelismMode
    public var manualParallelism: Int
    public var accelerationMode: ConverterAccelerationMode
    public var rememberOutputFolder: Bool
    public var saveOutputPathsInHistory: Bool
    public var cleanupTemporaryMaximumAgeDays: Int
    public var archiveLimits: ConverterArchiveLimits

    public init(
        defaultAdvancedMode: Bool = false,
        quality: ConverterQualityProfile = .maximum,
        conflictPolicy: ConverterConflictPolicy = .renameAutomatically,
        filenameStyle: ConverterFilenameStyle = .prefix,
        preserveMetadata: Bool = true,
        preserveDates: Bool = true,
        avoidUpscaling: Bool = true,
        preferRemuxWhenPossible: Bool = false,
        frameFormat: ConverterFrameFormat = .png,
        automaticHighBitDepthFrames: Bool = true,
        createFrameTimingCSV: Bool = true,
        audioVideoCanvas: ConverterVideoCanvas = .horizontal1080,
        audioVideoWidth: Int = 1_920,
        audioVideoHeight: Int = 1_080,
        audioVideoFPS: Int = 30,
        audioVideoFit: ConverterImageFit = .fit,
        recompressZIPResults: Bool = false,
        pdfRasterDPI: Int = 300,
        imageResizeMode: ConverterImageResizeMode = .original,
        imageResizePercentage: Int = 100,
        imageMaximumWidth: Int = 1_920,
        imageMaximumHeight: Int = 1_080,
        imageMaintainAspectRatio: Bool = true,
        audioBitrate: ConverterAudioBitrate = .automatic,
        audioSampleRate: ConverterAudioSampleRate = .automatic,
        audioChannels: ConverterAudioChannels = .automatic,
        normalizeAudio: Bool = false,
        preserveCoverArt: Bool = true,
        videoCodec: ConverterVideoCodec = .automatic,
        videoResolution: ConverterVideoResolution = .original,
        videoWidth: Int = 1_920,
        videoHeight: Int = 1_080,
        videoFrameRate: ConverterVideoFrameRate = .original,
        videoAudioMode: ConverterVideoAudioMode = .preserve,
        preserveSubtitles: Bool = true,
        preserveChapters: Bool = true,
        metadataPolicy: ConverterMetadataPolicy = .allCompatible,
        outputFolderMode: ConverterOutputFolderMode = .subfolder,
        outputSubfolderName: String = "ZEUVE Converted",
        filenamePrefix: String = "ZEUVE - Converted - ",
        filenameSuffix: String = "",
        filenameSeparator: String = " - ",
        zipStructureMode: ConverterZIPStructureMode = .preserve,
        parallelismMode: ConverterParallelismMode = .automatic,
        manualParallelism: Int = 2,
        accelerationMode: ConverterAccelerationMode = .automatic,
        rememberOutputFolder: Bool = false,
        saveOutputPathsInHistory: Bool = false,
        cleanupTemporaryMaximumAgeDays: Int = 7,
        archiveLimits: ConverterArchiveLimits = ConverterArchiveLimits()
    ) {
        self.defaultAdvancedMode = defaultAdvancedMode
        self.quality = quality
        self.conflictPolicy = conflictPolicy
        self.filenameStyle = filenameStyle
        self.preserveMetadata = preserveMetadata
        self.preserveDates = preserveDates
        self.avoidUpscaling = avoidUpscaling
        self.preferRemuxWhenPossible = preferRemuxWhenPossible
        self.frameFormat = frameFormat
        self.automaticHighBitDepthFrames = automaticHighBitDepthFrames
        self.createFrameTimingCSV = createFrameTimingCSV
        self.audioVideoCanvas = audioVideoCanvas
        self.audioVideoWidth = audioVideoWidth
        self.audioVideoHeight = audioVideoHeight
        self.audioVideoFPS = audioVideoFPS
        self.audioVideoFit = audioVideoFit
        self.recompressZIPResults = recompressZIPResults
        self.pdfRasterDPI = pdfRasterDPI
        self.imageResizeMode = imageResizeMode
        self.imageResizePercentage = imageResizePercentage
        self.imageMaximumWidth = imageMaximumWidth
        self.imageMaximumHeight = imageMaximumHeight
        self.imageMaintainAspectRatio = imageMaintainAspectRatio
        self.audioBitrate = audioBitrate
        self.audioSampleRate = audioSampleRate
        self.audioChannels = audioChannels
        self.normalizeAudio = normalizeAudio
        self.preserveCoverArt = preserveCoverArt
        self.videoCodec = videoCodec
        self.videoResolution = videoResolution
        self.videoWidth = videoWidth
        self.videoHeight = videoHeight
        self.videoFrameRate = videoFrameRate
        self.videoAudioMode = videoAudioMode
        self.preserveSubtitles = preserveSubtitles
        self.preserveChapters = preserveChapters
        self.metadataPolicy = metadataPolicy
        self.outputFolderMode = outputFolderMode
        self.outputSubfolderName = outputSubfolderName
        self.filenamePrefix = filenamePrefix
        self.filenameSuffix = filenameSuffix
        self.filenameSeparator = filenameSeparator
        self.zipStructureMode = zipStructureMode
        self.parallelismMode = parallelismMode
        self.manualParallelism = manualParallelism
        self.accelerationMode = accelerationMode
        self.rememberOutputFolder = rememberOutputFolder
        self.saveOutputPathsInHistory = saveOutputPathsInHistory
        self.cleanupTemporaryMaximumAgeDays = cleanupTemporaryMaximumAgeDays
        self.archiveLimits = archiveLimits
    }

    public mutating func normalize() {
        audioVideoWidth = min(max(audioVideoWidth, 16), 8_192)
        audioVideoHeight = min(max(audioVideoHeight, 16), 8_192)
        audioVideoFPS = min(max(audioVideoFPS, 1), 120)
        pdfRasterDPI = min(max(pdfRasterDPI, 72), 600)
        imageResizePercentage = min(max(imageResizePercentage, 1), 400)
        imageMaximumWidth = min(max(imageMaximumWidth, 1), 32_768)
        imageMaximumHeight = min(max(imageMaximumHeight, 1), 32_768)
        videoWidth = min(max(videoWidth, 16), 8_192)
        videoHeight = min(max(videoHeight, 16), 8_192)
        if let dimensions = videoResolution.dimensions {
            videoWidth = dimensions.0
            videoHeight = dimensions.1
        }
        if let dimensions = audioVideoCanvas.dimensions {
            audioVideoWidth = dimensions.width
            audioVideoHeight = dimensions.height
        }
        manualParallelism = min(max(manualParallelism, 1), 8)
        cleanupTemporaryMaximumAgeDays = min(max(cleanupTemporaryMaximumAgeDays, 1), 365)
        outputSubfolderName = outputSubfolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        if outputSubfolderName.isEmpty { outputSubfolderName = "ZEUVE Converted" }
        if metadataPolicy == .removeAll { preserveMetadata = false }
    }
}

extension UniversalConverterSettings {
    public init(from decoder: Decoder) throws {
        let defaults = UniversalConverterSettings()
        let container = try decoder.container(keyedBy: ConverterCodingKey.self)
        self.init(
            defaultAdvancedMode: try container.value(Bool.self, for: "defaultAdvancedMode", default: defaults.defaultAdvancedMode),
            quality: try container.value(ConverterQualityProfile.self, for: "quality", default: defaults.quality),
            conflictPolicy: try container.value(ConverterConflictPolicy.self, for: "conflictPolicy", default: defaults.conflictPolicy),
            filenameStyle: try container.value(ConverterFilenameStyle.self, for: "filenameStyle", default: defaults.filenameStyle),
            preserveMetadata: try container.value(Bool.self, for: "preserveMetadata", default: defaults.preserveMetadata),
            preserveDates: try container.value(Bool.self, for: "preserveDates", default: defaults.preserveDates),
            avoidUpscaling: try container.value(Bool.self, for: "avoidUpscaling", default: defaults.avoidUpscaling),
            preferRemuxWhenPossible: try container.value(Bool.self, for: "preferRemuxWhenPossible", default: defaults.preferRemuxWhenPossible),
            frameFormat: try container.value(ConverterFrameFormat.self, for: "frameFormat", default: defaults.frameFormat),
            automaticHighBitDepthFrames: try container.value(Bool.self, for: "automaticHighBitDepthFrames", default: defaults.automaticHighBitDepthFrames),
            createFrameTimingCSV: try container.value(Bool.self, for: "createFrameTimingCSV", default: defaults.createFrameTimingCSV),
            audioVideoCanvas: try container.value(ConverterVideoCanvas.self, for: "audioVideoCanvas", default: defaults.audioVideoCanvas),
            audioVideoWidth: try container.value(Int.self, for: "audioVideoWidth", default: defaults.audioVideoWidth),
            audioVideoHeight: try container.value(Int.self, for: "audioVideoHeight", default: defaults.audioVideoHeight),
            audioVideoFPS: try container.value(Int.self, for: "audioVideoFPS", default: defaults.audioVideoFPS),
            audioVideoFit: try container.value(ConverterImageFit.self, for: "audioVideoFit", default: defaults.audioVideoFit),
            recompressZIPResults: try container.value(Bool.self, for: "recompressZIPResults", default: defaults.recompressZIPResults),
            pdfRasterDPI: try container.value(Int.self, for: "pdfRasterDPI", default: defaults.pdfRasterDPI),
            imageResizeMode: try container.value(ConverterImageResizeMode.self, for: "imageResizeMode", default: defaults.imageResizeMode),
            imageResizePercentage: try container.value(Int.self, for: "imageResizePercentage", default: defaults.imageResizePercentage),
            imageMaximumWidth: try container.value(Int.self, for: "imageMaximumWidth", default: defaults.imageMaximumWidth),
            imageMaximumHeight: try container.value(Int.self, for: "imageMaximumHeight", default: defaults.imageMaximumHeight),
            imageMaintainAspectRatio: try container.value(Bool.self, for: "imageMaintainAspectRatio", default: defaults.imageMaintainAspectRatio),
            audioBitrate: try container.value(ConverterAudioBitrate.self, for: "audioBitrate", default: defaults.audioBitrate),
            audioSampleRate: try container.value(ConverterAudioSampleRate.self, for: "audioSampleRate", default: defaults.audioSampleRate),
            audioChannels: try container.value(ConverterAudioChannels.self, for: "audioChannels", default: defaults.audioChannels),
            normalizeAudio: try container.value(Bool.self, for: "normalizeAudio", default: defaults.normalizeAudio),
            preserveCoverArt: try container.value(Bool.self, for: "preserveCoverArt", default: defaults.preserveCoverArt),
            videoCodec: try container.value(ConverterVideoCodec.self, for: "videoCodec", default: defaults.videoCodec),
            videoResolution: try container.value(ConverterVideoResolution.self, for: "videoResolution", default: defaults.videoResolution),
            videoWidth: try container.value(Int.self, for: "videoWidth", default: defaults.videoWidth),
            videoHeight: try container.value(Int.self, for: "videoHeight", default: defaults.videoHeight),
            videoFrameRate: try container.value(ConverterVideoFrameRate.self, for: "videoFrameRate", default: defaults.videoFrameRate),
            videoAudioMode: try container.value(ConverterVideoAudioMode.self, for: "videoAudioMode", default: defaults.videoAudioMode),
            preserveSubtitles: try container.value(Bool.self, for: "preserveSubtitles", default: defaults.preserveSubtitles),
            preserveChapters: try container.value(Bool.self, for: "preserveChapters", default: defaults.preserveChapters),
            metadataPolicy: try container.value(ConverterMetadataPolicy.self, for: "metadataPolicy", default: defaults.metadataPolicy),
            outputFolderMode: try container.value(ConverterOutputFolderMode.self, for: "outputFolderMode", default: defaults.outputFolderMode),
            outputSubfolderName: try container.value(String.self, for: "outputSubfolderName", default: defaults.outputSubfolderName),
            filenamePrefix: try container.value(String.self, for: "filenamePrefix", default: defaults.filenamePrefix),
            filenameSuffix: try container.value(String.self, for: "filenameSuffix", default: defaults.filenameSuffix),
            filenameSeparator: try container.value(String.self, for: "filenameSeparator", default: defaults.filenameSeparator),
            zipStructureMode: try container.value(ConverterZIPStructureMode.self, for: "zipStructureMode", default: defaults.zipStructureMode),
            parallelismMode: try container.value(ConverterParallelismMode.self, for: "parallelismMode", default: defaults.parallelismMode),
            manualParallelism: try container.value(Int.self, for: "manualParallelism", default: defaults.manualParallelism),
            accelerationMode: try container.value(ConverterAccelerationMode.self, for: "accelerationMode", default: defaults.accelerationMode),
            rememberOutputFolder: try container.value(Bool.self, for: "rememberOutputFolder", default: defaults.rememberOutputFolder),
            saveOutputPathsInHistory: try container.value(Bool.self, for: "saveOutputPathsInHistory", default: defaults.saveOutputPathsInHistory),
            cleanupTemporaryMaximumAgeDays: try container.value(Int.self, for: "cleanupTemporaryMaximumAgeDays", default: defaults.cleanupTemporaryMaximumAgeDays),
            archiveLimits: try container.value(ConverterArchiveLimits.self, for: "archiveLimits", default: defaults.archiveLimits)
        )
        normalize()
    }
}
