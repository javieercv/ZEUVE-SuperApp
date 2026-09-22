import Foundation

public struct YTDLPFormatSelection: Sendable, Equatable {
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

public struct YTDLPFormatSelector: Sendable {
    public init() {}

    public func selection(for item: UniversalDownloadItem, settings: UniversalDownloadSettings) -> YTDLPFormatSelection {
        let effective = effectiveSettings(for: item, settings: settings)
        if effective.mode == .original {
            return .init(
                selector: "bestvideo*+bestaudio/best",
                mergeOutputFormat: nil,
                explanation: "Se conservará el contenido original de máxima calidad, sin conversión automática.",
                willTranscode: false
            )
        }
        return selection(for: effective)
    }

    public func effectiveSettings(for item: UniversalDownloadItem, settings: UniversalDownloadSettings) -> UniversalDownloadSettings {
        guard settings.mode == .automatic else { return settings }
        return UniversalDownloadSettingsResolver().settings(
            for: item,
            operationSettings: settings,
            profiles: UniversalDownloadProfiles()
        )
    }

    public func effectivePlatform(for item: UniversalDownloadItem) -> UniversalDownloadPlatform {
        item.platform == .automatic ? UniversalDownloadPlatform.detect(from: item.sourceURL) : item.platform
    }

    public func summary(for items: [UniversalDownloadItem], settings: UniversalDownloadSettings) -> String {
        guard !items.isEmpty else { return selection(for: settings).explanation }
        if settings.mode == .automatic {
            return "Se aplicará el perfil predeterminado configurado para cada plataforma o dominio."
        }
        let explanations = Set(items.map { selection(for: $0, settings: settings).explanation })
        return explanations.sorted().joined(separator: " ")
    }

    public func summary(for plan: UniversalDownloadPlan) -> String {
        let explanations = Set(plan.items.map { item in
            selection(for: item, settings: plan.settings(for: item)).explanation
        })
        return explanations.sorted().joined(separator: " ")
    }

    public func selection(for settings: UniversalDownloadSettings) -> YTDLPFormatSelection {
        if settings.mode == .automatic {
            return .init(
                selector: "best",
                mergeOutputFormat: nil,
                explanation: "Se aplicará el perfil predeterminado configurado para la plataforma o el dominio.",
                willTranscode: false
            )
        }
        if settings.mode == .original {
            return .init(
                selector: "bestvideo*+bestaudio/best",
                mergeOutputFormat: nil,
                explanation: "Se conservará el contenido original de máxima calidad, sin conversión automática.",
                willTranscode: false
            )
        }
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

    private func audioExplanation(_ settings: UniversalDownloadSettings) -> String {
        if settings.audioOutput == .original {
            return "Se conservará el mejor flujo de audio original disponible."
        }
        if settings.audioOutput == .mp3 {
            return "El audio se convertirá a MP3 a \(settings.mp3Bitrate.spanishName)."
        }
        return "El audio se convertirá a \(settings.audioOutput.spanishName)."
    }

    private func mergeFormat(_ preference: ContainerPreference) -> String? {
        switch preference {
        case .automatic: return "mp4/mkv"
        case .mp4: return "mp4"
        case .mkv: return "mkv"
        case .webm: return "webm"
        }
    }
}
