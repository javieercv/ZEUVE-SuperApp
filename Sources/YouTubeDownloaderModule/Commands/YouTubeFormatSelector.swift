import Foundation

public struct YouTubeFormatSelection: Sendable, Equatable {
    public let selector: String
    public let mergeOutputFormat: String?
    public let explanation: String
    public let willTranscode: Bool

    public init(selector: String, mergeOutputFormat: String?, explanation: String, willTranscode: Bool) {
        self.selector = selector
        self.mergeOutputFormat = mergeOutputFormat
        self.explanation = explanation
        self.willTranscode = willTranscode
    }
}

public struct YouTubeFormatSelector: Sendable {
    public init() {}

    public func selection(for settings: YouTubeDownloadSettings) -> YouTubeFormatSelection {
        if settings.mode == .audio {
            return .init(selector: settings.exactAudioFormatID ?? "bestaudio/best", mergeOutputFormat: nil,
                         explanation: audioExplanation(settings),
                         willTranscode: settings.audioOutput != .original)
        }
        if let video = settings.exactVideoFormatID {
            let selector = settings.exactAudioFormatID.map { "\(video)+\($0)" } ?? video
            return .init(selector: selector, mergeOutputFormat: mergeFormat(settings.container), explanation: settings.exactAudioFormatID == nil ? "Se utilizará el formato de vídeo seleccionado." : "Se unirán los flujos exactos de vídeo y audio sin recodificar cuando sean compatibles.", willTranscode: false)
        }

        let height = settings.maximumResolution == .best ? "" : "[height<=\(settings.maximumResolution.rawValue)]"
        let hdr: String
        switch settings.hdrPreference {
        case .automatic: hdr = ""
        case .preferSDR: hdr = "[dynamic_range!=HDR]"
        case .preferHDR: hdr = "[dynamic_range=HDR]"
        }
        let selector = "bestvideo\(height)\(hdr)+bestaudio/best\(height)"
        return .init(selector: selector, mergeOutputFormat: mergeFormat(settings.container), explanation: "Se elegirá el mejor vídeo y el mejor audio compatibles con el límite seleccionado.", willTranscode: false)
    }

    private func audioExplanation(_ settings: YouTubeDownloadSettings) -> String {
        if settings.audioOutput == .original {
            return "Se conservará el mejor flujo de audio original disponible."
        }
        if settings.audioOutput == .mp3 {
            return "El audio se convertirá a MP3 a \(settings.mp3Bitrate.spanishName)."
        }
        return "El audio se convertirá a \(settings.audioOutput.spanishName)."
    }

    private func mergeFormat(_ preference: YouTubeContainerPreference) -> String? {
        switch preference {
        case .automatic: return "mp4/mkv"
        case .mp4: return "mp4"
        case .mkv: return "mkv"
        case .webm: return "webm"
        }
    }
}
