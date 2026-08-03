import Foundation
import ZEUVEEngines

public struct FFmpegPreparedCommand: Sendable, Equatable {
    public let request: ExternalProcessRequest
    public let outputURL: URL
    public let outputIsDirectory: Bool
    public init(request: ExternalProcessRequest, outputURL: URL, outputIsDirectory: Bool) {
        self.request = request
        self.outputURL = outputURL
        self.outputIsDirectory = outputIsDirectory
    }
}

public struct FFmpegCommandBuilder: Sendable {
    public init() {}

    public func command(
        ffmpeg: URL,
        source: URL,
        planItem: ConversionPlanItem,
        options: ConverterOperationOptions,
        destination: URL,
        probe: MediaProbeResult? = nil
    ) throws -> FFmpegPreparedCommand {
        let needsFrameTiming = planItem.operation == .extractFrames && options.createFrameTimingCSV
        var args = ["-hide_banner", "-nostdin", "-y", "-loglevel", needsFrameTiming ? "info" : "error", "-progress", "pipe:2", "-nostats"]
        var output = destination
        var directoryOutput = false

        switch planItem.operation {
        case .extractFrames:
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            directoryOutput = true
            let highDepth = options.automaticHighBitDepthFrames && (probe?.requiresHighBitDepthFrameOutput == true)
            output = destination.appendingPathComponent("fotograma_%08d.\(options.frameFormat.converterFormat.fileExtension)")
            let stream = "0:v:0"
            args += ["-i", source.path, "-map", stream, "-fps_mode", "passthrough", "-start_number", "1"]
            if needsFrameTiming { args += ["-vf", "showinfo=checksum=0"] }
            args += try frameCodecArguments(format: options.frameFormat, quality: options.quality, highDepth: highDepth)

        case .extractAudio:
            let stream = options.selectedAudioStreamIndex.map { "0:\($0)" } ?? "0:a:0"
            args += ["-i", source.path, "-map", stream, "-vn"]
            let transforms = audioProcessingArguments(options)
            args += transforms
            let permitCopy = options.preferRemuxWhenPossible
                && transforms.isEmpty
                && options.audioBitrate == .automatic
                && canCopyAudio(codec: selectedAudioCodec(probe: probe, requestedIndex: options.selectedAudioStreamIndex), into: planItem.targetFormat)
            args += try audioCodecArguments(
                for: planItem.targetFormat,
                options: options,
                permitCopy: permitCopy,
                sourceCodec: selectedAudioCodec(probe: probe, requestedIndex: options.selectedAudioStreamIndex)
            )
            args += metadataArguments(options)

        case .audioToVideo:
            let width = options.audioVideoWidth
            let height = options.audioVideoHeight
            let fps = options.audioVideoFPS
            if options.audioVideoBackground == .image {
                guard let image = options.audioVideoImageURL else {
                    throw UniversalConverterError.incompatibleRecipe("Selecciona una imagen para el vídeo.")
                }
                args += ["-loop", "1", "-framerate", String(fps), "-i", image.path, "-i", source.path]
                args += ["-filter_complex", imageFilter(width: width, height: height, fit: options.audioVideoFit, avoidUpscaling: options.avoidUpscaling)]
                args += ["-map", "[v]", "-map", "1:a:0"]
            } else {
                args += ["-f", "lavfi", "-i", "color=c=black:s=\(width)x\(height):r=\(fps)", "-i", source.path]
                args += ["-map", "0:v:0", "-map", "1:a:0"]
            }
            args += ["-shortest"]
            args += try videoCodecArguments(codec: options.videoCodec, target: planItem.targetFormat, acceleration: options.accelerationMode)
            args += videoQualityArguments(options.quality, codec: options.videoCodec, acceleration: options.accelerationMode)
            let audioCanCopy = canCopyAudioIntoVideoContainer(codec: probe?.audioStream?.codec_name, target: planItem.targetFormat)
                && audioProcessingArguments(options).isEmpty
            args += audioProcessingArguments(options)
            args += try audioCodecArguments(for: .m4a, options: options, permitCopy: audioCanCopy, sourceCodec: probe?.audioStream?.codec_name)
            args += metadataArguments(options)
            if planItem.targetFormat == .mp4 || planItem.targetFormat == .mov { args += ["-movflags", "+faststart"] }

        case .imagesToVideo:
            args += ["-f", "concat", "-safe", "0", "-i", source.path, "-vsync", "vfr"]
            args += ["-vf", "scale=\(options.videoWidth):\(options.videoHeight):force_original_aspect_ratio=decrease:flags=lanczos,pad=\(options.videoWidth):\(options.videoHeight):(ow-iw)/2:(oh-ih)/2:black,format=yuv420p"]
            args += try videoCodecArguments(codec: options.videoCodec, target: planItem.targetFormat, acceleration: options.accelerationMode)
            args += videoQualityArguments(options.quality, codec: options.videoCodec, acceleration: options.accelerationMode)
            args += ["-an"]
            if planItem.targetFormat == .mp4 || planItem.targetFormat == .mov { args += ["-movflags", "+faststart"] }

        case .animationToVideo:
            args += ["-i", source.path, "-map", "0:v:0"]
            args += videoFilterArguments(options)
            args += try videoCodecArguments(codec: options.videoCodec, target: planItem.targetFormat, acceleration: options.accelerationMode)
            args += videoQualityArguments(options.quality, codec: options.videoCodec, acceleration: options.accelerationMode)
            args += ["-an"]
            if planItem.targetFormat == .mp4 || planItem.targetFormat == .mov { args += ["-movflags", "+faststart"] }

        case .videoToAnimation:
            args += ["-i", source.path, "-map", "0:v:0"]
            var filters: [String] = []
            let fps = options.videoFrameRate == .original ? 15 : options.videoFrameRate.rawValue
            filters.append("fps=\(fps)")
            if options.videoResolution != .original {
                filters.append("scale=\(options.videoWidth):\(options.videoHeight):force_original_aspect_ratio=decrease:flags=lanczos")
            }
            if !filters.isEmpty { args += ["-vf", filters.joined(separator: ",")] }
            args += try animationCodecArguments(for: planItem.targetFormat, options: options)
            args += ["-an"]

        case .convert:
            switch planItem.sources.first?.category {
            case .image:
                let multipage = planItem.sources.first?.format == .tiff
                if multipage && planItem.targetFormat != planItem.sources.first?.format {
                    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                    directoryOutput = true
                    output = destination.appendingPathComponent("imagen_%08d.\(planItem.targetFormat.fileExtension)")
                }
                args += ["-i", source.path]
                args += metadataArguments(options)
                args += try imageCodecArguments(for: planItem.targetFormat, quality: options.quality)

            case .animation:
                args += ["-i", source.path]
                args += metadataArguments(options)
                if planItem.targetFormat.category == .animation {
                    args += try animationCodecArguments(for: planItem.targetFormat, options: options)
                } else if planItem.targetFormat.category == .video {
                    args += try videoCodecArguments(codec: options.videoCodec, target: planItem.targetFormat, acceleration: options.accelerationMode)
                    args += videoQualityArguments(options.quality, codec: options.videoCodec, acceleration: options.accelerationMode)
                } else {
                    args += try imageCodecArguments(for: planItem.targetFormat, quality: options.quality)
                }

            case .audio:
                args += ["-i", source.path, "-map", "0:a:0"]
                let preserveCover = options.preserveCoverArt && probe?.attachedPictureStream != nil && supportsAttachedCoverArt(planItem.targetFormat)
                if preserveCover {
                    let stream = probe?.attachedPictureStream?.index.map { "0:\($0)?" } ?? "0:v:0?"
                    args += ["-map", stream, "-c:v", "copy", "-disposition:v", "attached_pic"]
                } else { args += ["-vn"] }
                let audioTransforms = audioProcessingArguments(options)
                args += audioTransforms
                let permitCopy = options.preferRemuxWhenPossible
                    && audioTransforms.isEmpty
                    && options.audioBitrate == .automatic
                    && canCopyAudio(codec: probe?.audioStream?.codec_name, into: planItem.targetFormat)
                args += try audioCodecArguments(for: planItem.targetFormat, options: options, permitCopy: permitCopy, sourceCodec: probe?.audioStream?.codec_name)
                args += metadataArguments(options)

            case .video:
                args += ["-i", source.path, "-map", "0:v:0"]
                if options.videoAudioMode != .remove {
                    if let index = options.selectedAudioStreamIndex { args += ["-map", "0:\(index)?"] }
                    else { args += ["-map", "0:a?"] }
                }
                if options.preserveSubtitles {
                    if let index = options.selectedSubtitleStreamIndex { args += ["-map", "0:\(index)?"] }
                    else { args += ["-map", "0:s?"] }
                }

                let hasVideoTransform = options.videoCodec != .automatic || options.videoResolution != .original || options.videoFrameRate != .original
                let copyVideo = options.advancedMode
                    && options.preferRemuxWhenPossible
                    && !hasVideoTransform
                    && canCopyVideo(codec: probe?.videoStream?.codec_name, into: planItem.targetFormat)
                if copyVideo {
                    args += ["-c:v", "copy"]
                } else {
                    guard planItem.targetFormat != .webm else {
                        throw UniversalConverterError.incompatibleRecipe("WebM solo puede conservar vídeo VP8, VP9 o AV1 con el motor incluido; elige MKV, MOV o MP4 para recodificar.")
                    }
                    args += try videoCodecArguments(codec: options.videoCodec, target: planItem.targetFormat, acceleration: options.accelerationMode)
                    args += videoFilterArguments(options)
                    args += videoQualityArguments(options.quality, codec: options.videoCodec, acceleration: options.accelerationMode)
                }

                switch options.videoAudioMode {
                case .remove:
                    args += ["-an"]
                case .aac:
                    guard planItem.targetFormat != .webm else { throw UniversalConverterError.incompatibleRecipe("WebM no admite AAC.") }
                    args += audioProcessingArguments(options)
                    args += ["-c:a", "aac", "-b:a", selectedAudioBitrate(options)]
                case .preserve:
                    let audioTransforms = audioProcessingArguments(options)
                    let canCopy = audioTransforms.isEmpty && options.audioBitrate == .automatic
                        && canCopyAudioIntoVideoContainer(codec: selectedAudioCodec(probe: probe, requestedIndex: options.selectedAudioStreamIndex), target: planItem.targetFormat)
                    if canCopy { args += ["-c:a", "copy"] }
                    else if planItem.targetFormat == .webm { args += audioTransforms + ["-c:a", "libopus", "-b:a", selectedAudioBitrate(options)] }
                    else { args += audioTransforms + ["-c:a", "aac", "-b:a", selectedAudioBitrate(options)] }
                }
                if options.preserveSubtitles {
                    if planItem.targetFormat == .mp4 || planItem.targetFormat == .mov { args += ["-c:s", "mov_text"] }
                    else if planItem.targetFormat == .webm { args += ["-c:s", "webvtt"] }
                    else { args += ["-c:s", "copy"] }
                }
                args += metadataArguments(options)
                args += ["-map_chapters", options.preserveChapters ? "0" : "-1"]
                if planItem.targetFormat == .mp4 || planItem.targetFormat == .mov { args += ["-movflags", "+faststart"] }

            default:
                throw UniversalConverterError.incompatibleRecipe("Esta entrada no corresponde a una conversión de FFmpeg.")
            }

        case .pdfToImages, .pdfToText, .imagesToPDF:
            throw UniversalConverterError.incompatibleRecipe("Esta operación no corresponde a FFmpeg.")
        }

        args.append(output.path)
        return .init(
            request: ExternalProcessRequest(executable: ffmpeg, arguments: args, workingDirectory: destination.deletingLastPathComponent()),
            outputURL: directoryOutput ? destination : output,
            outputIsDirectory: directoryOutput
        )
    }

    private func frameCodecArguments(format: ConverterFrameFormat, quality: ConverterQualityProfile, highDepth: Bool) throws -> [String] {
        switch format {
        case .png: return ["-c:v", "png", "-compression_level", "3", "-pred", "up", "-pix_fmt", highDepth ? "rgb48be" : "rgb24"]
        case .jpeg: return ["-c:v", "mjpeg", "-q:v", jpegQ(quality), "-pix_fmt", "yuvj444p"]
        case .tiff: return ["-c:v", "tiff", "-pix_fmt", highDepth ? "rgb48le" : "rgb24"]
        case .webp: return ["-c:v", "libwebp", "-quality", webPQuality(quality), "-lossless", quality == .maximum ? "1" : "0"]
        }
    }

    private func imageCodecArguments(for format: ConverterFormat, quality: ConverterQualityProfile) throws -> [String] {
        switch format {
        case .png: return ["-c:v", "png", "-compression_level", quality == .low ? "9" : "6"]
        case .jpeg: return ["-c:v", "mjpeg", "-q:v", jpegQ(quality)]
        case .tiff: return ["-c:v", "tiff"]
        case .bmp: return ["-c:v", "bmp"]
        case .webp: return ["-c:v", "libwebp", "-quality", webPQuality(quality), "-lossless", quality == .maximum ? "1" : "0"]
        case .gif: return ["-c:v", "gif"]
        case .apng: return ["-c:v", "apng", "-plays", "0"]
        case .heic: return ["-c:v", "hevc_videotoolbox", "-tag:v", "hvc1", "-frames:v", "1"]
        default: throw UniversalConverterError.incompatibleRecipe("FFmpeg no admite la salida de imagen \(format.displayName).")
        }
    }

    private func animationCodecArguments(for format: ConverterFormat, options: ConverterOperationOptions) throws -> [String] {
        switch format {
        case .gif:
            return ["-c:v", "gif", "-loop", String(options.animationLoopCount)]
        case .webp:
            return ["-c:v", "libwebp", "-loop", String(options.animationLoopCount), "-quality", webPQuality(options.quality), "-lossless", options.quality == .maximum ? "1" : "0"]
        case .apng:
            return ["-c:v", "apng", "-plays", String(options.animationLoopCount)]
        default:
            throw UniversalConverterError.incompatibleRecipe("El formato elegido no admite esta animación.")
        }
    }

    private func audioCodecArguments(for format: ConverterFormat, options: ConverterOperationOptions, permitCopy: Bool, sourceCodec: String?) throws -> [String] {
        if permitCopy { return ["-c:a", "copy"] }
        let bitrate = selectedAudioBitrate(options)
        switch format {
        case .mp3: return ["-c:a", "libmp3lame", "-b:a", bitrate]
        case .m4a, .aac: return ["-c:a", "aac", "-b:a", bitrate]
        case .flac: return ["-c:a", "flac", "-compression_level", options.quality == .low ? "8" : "5"]
        case .wav: return ["-c:a", "pcm_s24le"]
        case .opus, .ogg: return ["-c:a", "libopus", "-b:a", options.audioBitrate == .automatic ? selectedAudioBitrate(options) : bitrate]
        default: throw UniversalConverterError.incompatibleRecipe("FFmpeg no admite la salida de audio \(format.displayName).")
        }
    }

    private func selectedAudioBitrate(_ options: ConverterOperationOptions) -> String {
        if options.audioBitrate != .automatic { return "\(options.audioBitrate.rawValue)k" }
        switch options.quality {
        case .low: return "128k"
        case .medium: return "192k"
        case .high: return "256k"
        case .maximum, .custom: return "320k"
        }
    }

    private func audioProcessingArguments(_ options: ConverterOperationOptions) -> [String] {
        var result: [String] = []
        if options.normalizeAudio { result += ["-af", "loudnorm=I=-16:LRA=11:TP=-1.5"] }
        if options.audioSampleRate != .automatic { result += ["-ar", String(options.audioSampleRate.rawValue)] }
        if options.audioChannels != .automatic { result += ["-ac", String(options.audioChannels.rawValue)] }
        return result
    }

    private func videoCodecArguments(codec: ConverterVideoCodec, target: ConverterFormat, acceleration: ConverterAccelerationMode) throws -> [String] {
        switch codec {
        case .automatic, .h264:
            switch acceleration {
            case .automatic, .software:
                return ["-c:v", "libx264", "-pix_fmt", "yuv420p"]
            case .hardware:
                return ["-c:v", "h264_videotoolbox", "-pix_fmt", "yuv420p"]
            }
        case .hevc:
            guard acceleration != .software else {
                throw UniversalConverterError.codecUnavailable("HEVC por software no está incluido. Utiliza Automático/Hardware o H.264 por software.")
            }
            var result = ["-c:v", "hevc_videotoolbox", "-pix_fmt", "yuv420p"]
            if target == .mp4 || target == .mov { result += ["-tag:v", "hvc1"] }
            return result
        case .proRes:
            guard target == .mov || target == .mkv else { throw UniversalConverterError.incompatibleRecipe("Apple ProRes requiere salida MOV o MKV.") }
            return ["-c:v", "prores_ks", "-profile:v", "3", "-pix_fmt", "yuv422p10le"]
        }
    }

    private func videoFilterArguments(_ options: ConverterOperationOptions) -> [String] {
        var filters: [String] = []
        if options.videoResolution != .original {
            let width = options.videoWidth
            let height = options.videoHeight
            if options.avoidUpscaling { filters.append("scale=w='min(iw\\,\(width))':h='min(ih\\,\(height))':force_original_aspect_ratio=decrease:flags=lanczos") }
            else { filters.append("scale=w=\(width):h=\(height):force_original_aspect_ratio=decrease:flags=lanczos") }
        }
        if options.videoFrameRate != .original { filters.append("fps=\(options.videoFrameRate.rawValue)") }
        return filters.isEmpty ? [] : ["-vf", filters.joined(separator: ",")]
    }

    private func videoQualityArguments(_ quality: ConverterQualityProfile, codec: ConverterVideoCodec = .h264, acceleration: ConverterAccelerationMode = .automatic) -> [String] {
        if codec == .proRes {
            switch quality { case .low: return ["-qscale:v", "13"]; case .medium: return ["-qscale:v", "9"]; case .high: return ["-qscale:v", "7"]; case .maximum, .custom: return ["-qscale:v", "5"] }
        }
        let usesSoftwareH264 = acceleration == .software || (acceleration == .automatic && (codec == .automatic || codec == .h264))
        if usesSoftwareH264 {
            switch quality { case .low: return ["-crf", "28", "-preset", "medium"]; case .medium: return ["-crf", "23", "-preset", "medium"]; case .high: return ["-crf", "19", "-preset", "slow"]; case .maximum, .custom: return ["-crf", "16", "-preset", "slow"] }
        }
        switch quality { case .low: return ["-b:v", "4M", "-maxrate", "6M", "-bufsize", "12M"]; case .medium: return ["-b:v", "8M", "-maxrate", "12M", "-bufsize", "24M"]; case .high: return ["-q:v", "60"]; case .maximum, .custom: return ["-q:v", "70"] }
    }

    private func metadataArguments(_ options: ConverterOperationOptions) -> [String] {
        switch options.metadataPolicy {
        case .allCompatible: return ["-map_metadata", "0"]
        case .essentialOnly:
            return [
                "-map_metadata", "0",
                "-metadata", "location=",
                "-metadata", "location-eng=",
                "-metadata", "comment=",
                "-metadata", "description=",
                "-metadata", "synopsis=",
                "-metadata", "encoded_by=",
                "-metadata", "encoder="
            ]
        case .removeAll: return ["-map_metadata", "-1"]
        }
    }

    private func imageFilter(width: Int, height: Int, fit: ConverterImageFit, avoidUpscaling: Bool) -> String {
        let flags = "flags=lanczos"
        switch fit {
        case .stretch: return "[0:v]scale=\(width):\(height):\(flags),format=yuv420p[v]"
        case .fit:
            let widthExpr = avoidUpscaling ? "min(iw\\,\(width))" : String(width)
            let heightExpr = avoidUpscaling ? "min(ih\\,\(height))" : String(height)
            return "[0:v]scale=w='\(widthExpr)':h='\(heightExpr)':force_original_aspect_ratio=decrease:\(flags),pad=\(width):\(height):(ow-iw)/2:(oh-ih)/2:black,format=yuv420p[v]"
        case .fill: return "[0:v]scale=\(width):\(height):force_original_aspect_ratio=increase:\(flags),crop=\(width):\(height),format=yuv420p[v]"
        }
    }

    private func jpegQ(_ quality: ConverterQualityProfile) -> String {
        switch quality { case .low: return "7"; case .medium: return "5"; case .high: return "3"; case .maximum, .custom: return "2" }
    }
    private func webPQuality(_ quality: ConverterQualityProfile) -> String {
        switch quality { case .low: return "70"; case .medium: return "82"; case .high: return "92"; case .maximum, .custom: return "100" }
    }

    private func selectedAudioCodec(probe: MediaProbeResult?, requestedIndex: Int?) -> String? {
        guard let requestedIndex else { return probe?.audioStream?.codec_name }
        return probe?.streams.first(where: { $0.index == requestedIndex && $0.codec_type == "audio" })?.codec_name
    }

    private func canCopyAudio(codec: String?, into target: ConverterFormat) -> Bool {
        guard let codec = codec?.lowercased() else { return false }
        switch target {
        case .mp3: return codec == "mp3"
        case .m4a: return ["aac", "alac"].contains(codec)
        case .aac: return codec == "aac"
        case .flac: return codec == "flac"
        case .wav: return codec.hasPrefix("pcm_")
        case .opus: return codec == "opus"
        case .ogg: return ["opus", "vorbis", "flac"].contains(codec)
        default: return false
        }
    }
    private func supportsAttachedCoverArt(_ target: ConverterFormat) -> Bool { target == .mp3 || target == .m4a || target == .flac }
    private func canCopyVideo(codec: String?, into target: ConverterFormat) -> Bool {
        guard let video = codec?.lowercased() else { return false }
        switch target { case .mp4, .mov: return ["h264", "hevc", "mpeg4", "av1"].contains(video); case .mkv: return true; case .webm: return ["vp8", "vp9", "av1"].contains(video); default: return false }
    }
    private func canCopyAudioIntoVideoContainer(codec: String?, target: ConverterFormat) -> Bool {
        guard let codec = codec?.lowercased() else { return true }
        switch target { case .mp4, .mov: return ["aac", "mp3", "alac", "ac3", "eac3"].contains(codec); case .mkv: return true; case .webm: return ["opus", "vorbis"].contains(codec); default: return false }
    }
}
