import Foundation
import ZEUVECore

public struct ConverterOperationOptions: Codable, Sendable, Equatable {
    public var operation: ConversionOperation
    public var targetFormat: ConverterFormat?
    public var advancedMode: Bool
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
    public var audioVideoBackground: ConverterAudioVideoBackground
    public var audioVideoImageURL: URL?
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
    public var saveOutputPathsInHistory: Bool
    public var selectedAudioStreamIndex: Int?
    public var selectedSubtitleStreamIndex: Int?
    public var sequenceOrder: ConverterSequenceOrder
    public var sequenceDurationPerImage: Double
    public var animationLoopCount: Int

    public init(settings: UniversalConverterSettings = UniversalConverterSettings()) {
        operation = .convert
        targetFormat = nil
        advancedMode = settings.defaultAdvancedMode
        quality = settings.quality
        conflictPolicy = settings.conflictPolicy
        filenameStyle = settings.filenameStyle
        preserveMetadata = settings.preserveMetadata
        preserveDates = settings.preserveDates
        avoidUpscaling = settings.avoidUpscaling
        preferRemuxWhenPossible = settings.preferRemuxWhenPossible
        frameFormat = settings.frameFormat
        automaticHighBitDepthFrames = settings.automaticHighBitDepthFrames
        createFrameTimingCSV = settings.createFrameTimingCSV
        audioVideoBackground = .black
        audioVideoImageURL = nil
        audioVideoCanvas = settings.audioVideoCanvas
        audioVideoWidth = settings.audioVideoWidth
        audioVideoHeight = settings.audioVideoHeight
        audioVideoFPS = settings.audioVideoFPS
        audioVideoFit = settings.audioVideoFit
        recompressZIPResults = settings.recompressZIPResults
        pdfRasterDPI = settings.pdfRasterDPI
        imageResizeMode = settings.imageResizeMode
        imageResizePercentage = settings.imageResizePercentage
        imageMaximumWidth = settings.imageMaximumWidth
        imageMaximumHeight = settings.imageMaximumHeight
        imageMaintainAspectRatio = settings.imageMaintainAspectRatio
        audioBitrate = settings.audioBitrate
        audioSampleRate = settings.audioSampleRate
        audioChannels = settings.audioChannels
        normalizeAudio = settings.normalizeAudio
        preserveCoverArt = settings.preserveCoverArt
        videoCodec = settings.videoCodec
        videoResolution = settings.videoResolution
        videoWidth = settings.videoWidth
        videoHeight = settings.videoHeight
        videoFrameRate = settings.videoFrameRate
        videoAudioMode = settings.videoAudioMode
        preserveSubtitles = settings.preserveSubtitles
        preserveChapters = settings.preserveChapters
        metadataPolicy = settings.metadataPolicy
        outputFolderMode = settings.outputFolderMode
        outputSubfolderName = settings.outputSubfolderName
        filenamePrefix = settings.filenamePrefix
        filenameSuffix = settings.filenameSuffix
        filenameSeparator = settings.filenameSeparator
        zipStructureMode = settings.zipStructureMode
        parallelismMode = settings.parallelismMode
        manualParallelism = settings.manualParallelism
        accelerationMode = settings.accelerationMode
        saveOutputPathsInHistory = settings.saveOutputPathsInHistory
        selectedAudioStreamIndex = nil
        selectedSubtitleStreamIndex = nil
        sequenceOrder = .natural
        sequenceDurationPerImage = 1.0
        animationLoopCount = 0
        normalize()
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
        sequenceDurationPerImage = min(max(sequenceDurationPerImage, 0.01), 3_600)
        animationLoopCount = min(max(animationLoopCount, 0), 100_000)
        outputSubfolderName = outputSubfolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        if outputSubfolderName.isEmpty { outputSubfolderName = "ZEUVE Converted" }
        preserveMetadata = metadataPolicy != .removeAll
        if operation != .audioToVideo {
            audioVideoImageURL = nil
            audioVideoBackground = .black
        }
        switch operation {
        case .extractFrames:
            targetFormat = frameFormat.converterFormat
        case .audioToVideo:
            targetFormat = .mp4
        case .pdfToImages:
            if targetFormat != .png && targetFormat != .jpeg { targetFormat = .png }
        case .pdfToText:
            targetFormat = .txt
        case .imagesToPDF:
            targetFormat = .pdf
        case .imagesToVideo:
            if targetFormat?.category != .video { targetFormat = .mp4 }
        case .animationToVideo:
            if targetFormat?.category != .video { targetFormat = .mp4 }
        case .videoToAnimation:
            if targetFormat != .gif && targetFormat != .webp && targetFormat != .apng { targetFormat = .gif }
        case .extractAudio:
            if targetFormat?.category != .audio { targetFormat = .m4a }
        case .convert:
            break
        }
    }
}

extension ConverterOperationOptions {
    public init(from decoder: Decoder) throws {
        var value = ConverterOperationOptions()
        let container = try decoder.container(keyedBy: ConverterCodingKey.self)
        value.operation = try container.value(ConversionOperation.self, for: "operation", default: value.operation)
        value.targetFormat = try container.decodeIfPresent(ConverterFormat.self, forKey: ConverterCodingKey("targetFormat"))
        value.advancedMode = try container.value(Bool.self, for: "advancedMode", default: value.advancedMode)
        value.quality = try container.value(ConverterQualityProfile.self, for: "quality", default: value.quality)
        value.conflictPolicy = try container.value(ConverterConflictPolicy.self, for: "conflictPolicy", default: value.conflictPolicy)
        value.filenameStyle = try container.value(ConverterFilenameStyle.self, for: "filenameStyle", default: value.filenameStyle)
        value.preserveMetadata = try container.value(Bool.self, for: "preserveMetadata", default: value.preserveMetadata)
        value.preserveDates = try container.value(Bool.self, for: "preserveDates", default: value.preserveDates)
        value.avoidUpscaling = try container.value(Bool.self, for: "avoidUpscaling", default: value.avoidUpscaling)
        value.preferRemuxWhenPossible = try container.value(Bool.self, for: "preferRemuxWhenPossible", default: value.preferRemuxWhenPossible)
        value.frameFormat = try container.value(ConverterFrameFormat.self, for: "frameFormat", default: value.frameFormat)
        value.automaticHighBitDepthFrames = try container.value(Bool.self, for: "automaticHighBitDepthFrames", default: value.automaticHighBitDepthFrames)
        value.createFrameTimingCSV = try container.value(Bool.self, for: "createFrameTimingCSV", default: value.createFrameTimingCSV)
        value.audioVideoBackground = try container.value(ConverterAudioVideoBackground.self, for: "audioVideoBackground", default: value.audioVideoBackground)
        value.audioVideoImageURL = try container.decodeIfPresent(URL.self, forKey: ConverterCodingKey("audioVideoImageURL"))
        value.audioVideoCanvas = try container.value(ConverterVideoCanvas.self, for: "audioVideoCanvas", default: value.audioVideoCanvas)
        value.audioVideoWidth = try container.value(Int.self, for: "audioVideoWidth", default: value.audioVideoWidth)
        value.audioVideoHeight = try container.value(Int.self, for: "audioVideoHeight", default: value.audioVideoHeight)
        value.audioVideoFPS = try container.value(Int.self, for: "audioVideoFPS", default: value.audioVideoFPS)
        value.audioVideoFit = try container.value(ConverterImageFit.self, for: "audioVideoFit", default: value.audioVideoFit)
        value.recompressZIPResults = try container.value(Bool.self, for: "recompressZIPResults", default: value.recompressZIPResults)
        value.pdfRasterDPI = try container.value(Int.self, for: "pdfRasterDPI", default: value.pdfRasterDPI)
        value.imageResizeMode = try container.value(ConverterImageResizeMode.self, for: "imageResizeMode", default: value.imageResizeMode)
        value.imageResizePercentage = try container.value(Int.self, for: "imageResizePercentage", default: value.imageResizePercentage)
        value.imageMaximumWidth = try container.value(Int.self, for: "imageMaximumWidth", default: value.imageMaximumWidth)
        value.imageMaximumHeight = try container.value(Int.self, for: "imageMaximumHeight", default: value.imageMaximumHeight)
        value.imageMaintainAspectRatio = try container.value(Bool.self, for: "imageMaintainAspectRatio", default: value.imageMaintainAspectRatio)
        value.audioBitrate = try container.value(ConverterAudioBitrate.self, for: "audioBitrate", default: value.audioBitrate)
        value.audioSampleRate = try container.value(ConverterAudioSampleRate.self, for: "audioSampleRate", default: value.audioSampleRate)
        value.audioChannels = try container.value(ConverterAudioChannels.self, for: "audioChannels", default: value.audioChannels)
        value.normalizeAudio = try container.value(Bool.self, for: "normalizeAudio", default: value.normalizeAudio)
        value.preserveCoverArt = try container.value(Bool.self, for: "preserveCoverArt", default: value.preserveCoverArt)
        value.videoCodec = try container.value(ConverterVideoCodec.self, for: "videoCodec", default: value.videoCodec)
        value.videoResolution = try container.value(ConverterVideoResolution.self, for: "videoResolution", default: value.videoResolution)
        value.videoWidth = try container.value(Int.self, for: "videoWidth", default: value.videoWidth)
        value.videoHeight = try container.value(Int.self, for: "videoHeight", default: value.videoHeight)
        value.videoFrameRate = try container.value(ConverterVideoFrameRate.self, for: "videoFrameRate", default: value.videoFrameRate)
        value.videoAudioMode = try container.value(ConverterVideoAudioMode.self, for: "videoAudioMode", default: value.videoAudioMode)
        value.preserveSubtitles = try container.value(Bool.self, for: "preserveSubtitles", default: value.preserveSubtitles)
        value.preserveChapters = try container.value(Bool.self, for: "preserveChapters", default: value.preserveChapters)
        value.metadataPolicy = try container.value(ConverterMetadataPolicy.self, for: "metadataPolicy", default: value.metadataPolicy)
        value.outputFolderMode = try container.value(ConverterOutputFolderMode.self, for: "outputFolderMode", default: value.outputFolderMode)
        value.outputSubfolderName = try container.value(String.self, for: "outputSubfolderName", default: value.outputSubfolderName)
        value.filenamePrefix = try container.value(String.self, for: "filenamePrefix", default: value.filenamePrefix)
        value.filenameSuffix = try container.value(String.self, for: "filenameSuffix", default: value.filenameSuffix)
        value.filenameSeparator = try container.value(String.self, for: "filenameSeparator", default: value.filenameSeparator)
        value.zipStructureMode = try container.value(ConverterZIPStructureMode.self, for: "zipStructureMode", default: value.zipStructureMode)
        value.parallelismMode = try container.value(ConverterParallelismMode.self, for: "parallelismMode", default: value.parallelismMode)
        value.manualParallelism = try container.value(Int.self, for: "manualParallelism", default: value.manualParallelism)
        value.accelerationMode = try container.value(ConverterAccelerationMode.self, for: "accelerationMode", default: value.accelerationMode)
        value.saveOutputPathsInHistory = try container.value(Bool.self, for: "saveOutputPathsInHistory", default: value.saveOutputPathsInHistory)
        value.selectedAudioStreamIndex = try container.decodeIfPresent(Int.self, forKey: ConverterCodingKey("selectedAudioStreamIndex"))
        value.selectedSubtitleStreamIndex = try container.decodeIfPresent(Int.self, forKey: ConverterCodingKey("selectedSubtitleStreamIndex"))
        value.sequenceOrder = try container.value(ConverterSequenceOrder.self, for: "sequenceOrder", default: value.sequenceOrder)
        value.sequenceDurationPerImage = try container.value(Double.self, for: "sequenceDurationPerImage", default: value.sequenceDurationPerImage)
        value.animationLoopCount = try container.value(Int.self, for: "animationLoopCount", default: value.animationLoopCount)
        value.normalize()
        self = value
    }
}
