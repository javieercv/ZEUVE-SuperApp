import Foundation
import ZEUVECore

public struct UniversalConverterPreset: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var options: ConverterOperationOptions
    public var isBuiltIn: Bool

    public init(id: UUID = UUID(), name: String, options: ConverterOperationOptions, isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        var sanitized = options
        sanitized.audioVideoImageURL = nil
        if sanitized.audioVideoBackground == .image { sanitized.audioVideoBackground = .black }
        sanitized.normalize()
        self.options = sanitized
        self.isBuiltIn = isBuiltIn
    }

    public static var defaults: [UniversalConverterPreset] {
        var image = ConverterOperationOptions()
        image.operation = .convert
        image.targetFormat = .png
        image.quality = .maximum

        var video = ConverterOperationOptions()
        video.operation = .convert
        video.targetFormat = .mp4
        video.quality = .maximum
        video.preferRemuxWhenPossible = false

        var frames = ConverterOperationOptions()
        frames.operation = .extractFrames
        frames.targetFormat = .png
        frames.frameFormat = .png
        frames.automaticHighBitDepthFrames = true
        frames.createFrameTimingCSV = true

        var audio = ConverterOperationOptions()
        audio.operation = .convert
        audio.targetFormat = .mp3
        audio.quality = .maximum

        var document = ConverterOperationOptions()
        document.operation = .convert
        document.targetFormat = .pdf
        document.quality = .maximum

        return [
            .init(name: "Imagen PNG sin pérdida", options: image, isBuiltIn: true),
            .init(name: "Vídeo MP4 compatible", options: video, isBuiltIn: true),
            .init(name: "Todos los fotogramas en PNG", options: frames, isBuiltIn: true),
            .init(name: "Audio MP3 de alta calidad", options: audio, isBuiltIn: true),
            .init(name: "Documento a PDF", options: document, isBuiltIn: true)
        ]
    }
}
