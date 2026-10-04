import Foundation
import ZEUVEEngines

/// Capacidades de las rutas aprobadas, compartidas por plan y comando.
/// Los datos técnicos son efímeros: nunca se incorporan a presets o Ajustes.
public struct ConverterMediaPolicy: Sendable {
    public init() {}

    public static func needsInspection(options: ConverterOperationOptions) -> Bool {
        options.targetFormat == .opus || options.targetFormat == .ogg || options.targetFormat == .webm
    }

    public static func permitsWebMRemux(_ options: ConverterOperationOptions) -> Bool {
        options.operation == .convert && options.advancedMode && options.preferRemuxWhenPossible
            && options.videoCodec == .automatic && options.videoResolution == .original
            && options.videoFrameRate == .original && options.videoAudioMode != .aac
    }

    public func validateWebM(options: ConverterOperationOptions, probe: MediaInspectionResult?) throws {
        guard Self.permitsWebMRemux(options) else {
            throw UniversalConverterError.incompatibleRecipe("WebM requiere copia rápida en modo avanzado, sin recodificar el vídeo. Elige MP4, MOV o MKV para una conversión real.")
        }
        if let probe, !["vp8", "vp9", "av1"].contains(probe.videoStream?.codec_name?.lowercased() ?? "") {
            throw UniversalConverterError.incompatibleRecipe("WebM solo puede conservar vídeo VP8, VP9 o AV1 con el motor incluido. Elige MP4, MOV o MKV para esta entrada.")
        }
        if let probe, options.videoAudioMode == .preserve {
            let streams = probe.audioStreams.filter { options.selectedAudioStreamIndex == nil || $0.index == options.selectedAudioStreamIndex }
            let copies = options.audioChannels == .automatic && options.audioSampleRate == .automatic
                && !options.normalizeAudio && options.audioBitrate == .automatic
                && streams.allSatisfy { ["opus", "vorbis"].contains($0.codec_name?.lowercased() ?? "") }
            if !copies {
                for stream in streams {
                    guard try opusBitrate(options: options, sourceChannels: stream.channels) != nil else {
                        throw UniversalConverterError.incompatibleRecipe("No se conocen los canales de una pista de audio para WebM.")
                    }
                }
            }
        }
    }

    public func audioStream(probe: MediaInspectionResult?, options: ConverterOperationOptions) -> MediaInspectionStream? {
        if options.operation == .extractAudio, let index = options.selectedAudioStreamIndex {
            return probe?.audioStreams.first { $0.index == index }
        }
        return probe?.audioStream
    }

    public func copiesAudio(target: ConverterFormat, options: ConverterOperationOptions, stream: MediaInspectionStream?) -> Bool {
        guard options.preferRemuxWhenPossible, options.audioChannels == .automatic,
              options.audioSampleRate == .automatic, !options.normalizeAudio, options.audioBitrate == .automatic else { return false }
        let codec = stream?.codec_name?.lowercased() ?? ""
        return target == .opus ? codec == "opus" : (target == .ogg && ["opus", "vorbis", "flac"].contains(codec))
    }

    public func opusBitrate(options: ConverterOperationOptions, sourceChannels: Int?) throws -> Int? {
        let channels = options.audioChannels == .automatic ? sourceChannels : options.audioChannels.rawValue
        guard let channels, channels > 0 else { return nil }
        // FFmpeg libopusenc 8.1.2: 500 ... 256000 * canales efectivos.
        let maximum = 256 * min(channels, 254)
        if options.audioBitrate != .automatic {
            let chosen = options.audioBitrate.rawValue
            guard chosen <= maximum else {
                throw UniversalConverterError.incompatibleRecipe("Opus/OGG con \(channels) canal(es) admite como máximo \(maximum) kb/s. Se han elegido \(chosen) kb/s; cambia el bitrate o los canales antes de convertir.")
            }
            return chosen
        }
        let requested: Int
        switch options.quality {
        case .low: requested = 128
        case .medium: requested = 192
        case .high: requested = 256
        case .maximum, .custom: requested = 320
        }
        return min(requested, maximum)
    }
}
